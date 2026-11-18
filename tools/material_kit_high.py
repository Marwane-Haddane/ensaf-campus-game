"""High-preset PBR surface kit for the campus (art_audit roadmap item 4).

blender -b --python tools/material_kit_high.py [-- --size=1024 --lookdev]

Writes seamless (tileable) albedo / normal / roughness PNGs to assets/runtime_surfaces_high/.
Albedo is a near-neutral multiplier: Godot multiplies it by each source material's own
colour (scripts/campus_materials.gd), so campus colours stay exactly as authored.
Normal maps use the OpenGL convention (green = up) that Godot expects.
Everything is procedural and deterministic (fixed seeds): no external images.
Skills: blender-director -> realistic-style -> materials -> texture-workflow -> lookdev.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'runtime_surfaces_high'
LOOKDEV = ROOT / 'art_audit' / 'work' / '04_materials'
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
N = int(next((a.split('=')[1] for a in ARGS if a.startswith('--size=')), 1024))

# Repeat size in metres for each kind. Godot uses uv1_scale = 1 / repeat (world triplanar).
REPEAT_M = {
    'paving': 2.4,        # same 4 x 4 staggered 0.60 m slab layout as the Medium texture
    'mineral': 2.0, 'limestone': 2.0, 'slate': 1.6, 'terrazzo': 1.25, 'floor_stone': 2.0,
    'wood': 1.2, 'wood_horizontal': 1.2, 'wood_transverse': 1.2,
    'asphalt': 1.5, 'carpet': 0.6, 'fabric': 0.25,
}
NORMAL_STRENGTH = {  # Godot normal_scale per kind
    'paving': 0.9, 'mineral': 0.45, 'limestone': 0.55, 'slate': 0.9, 'terrazzo': 0.2,
    'floor_stone': 0.15, 'wood': 0.35, 'wood_horizontal': 0.35, 'wood_transverse': 0.35,
    'asphalt': 0.8, 'carpet': 0.6, 'fabric': 0.5,
}


# ---------------------------------------------------------------- tileable noise
def _grid_interp(grid, n_out):
    """Periodic smooth (quintic) interpolation of an n x n grid up to n_out x n_out."""
    n = grid.shape[0]
    t = np.arange(n_out) * n / n_out
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * f * (f * (f * 6 - 15) + 10)
    i1 = (i0 + 1) % n
    rows = grid[i0][:, :] * (1 - f)[:, None] + grid[i1] * f[:, None]
    return rows[:, i0] * (1 - f)[None, :] + rows[:, i1] * f[None, :]


def vnoise(cells, seed, n=N):
    rng = np.random.default_rng(seed)
    return _grid_interp(rng.random((cells, cells)), n)


def fbm(cells, octaves, seed, gain=0.5, n=N):
    total, amp, norm = np.zeros((n, n)), 1.0, 0.0
    for o in range(octaves):
        c = cells * (2 ** o)
        if c > n:
            break
        total += amp * vnoise(c, seed + o * 101, n)
        norm += amp
        amp *= gain
    return total / norm


def worley(cells, seed, n=N, jitter=1.0):
    """Periodic cellular noise: returns (F1, F2, cell_id) in cell units."""
    rng = np.random.default_rng(seed)
    pts = rng.random((cells, cells, 2)) * jitter + (1 - jitter) * 0.5
    ids = rng.random((cells, cells))
    coord = (np.arange(n) + 0.5) * cells / n
    cy, cx = np.meshgrid(coord, coord, indexing='ij')
    iy, ix = np.floor(cy).astype(int), np.floor(cx).astype(int)
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    cid = np.zeros((n, n))
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            gy, gx = iy + dy, ix + dx
            p = pts[gy % cells, gx % cells]
            d = np.hypot(gy + p[..., 0] - cy, gx + p[..., 1] - cx)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, ids[gy % cells, gx % cells], cid)
            f1 = np.where(closer, d, f1)
    return f1, f2, cid


def uv(n=N):
    c = (np.arange(n) + 0.5) / n
    return np.meshgrid(c, c, indexing='ij')  # (v rows top->bottom, u cols)


def normal_from_height(h, strength_px):
    """OpenGL tangent normal (green up). h rows run top->bottom in the saved image."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength_px
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength_px
    nx, ny, nz = -dx, dy, np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length, ny / length, nz / length], -1) * 0.5 + 0.5


def norm01(a):
    lo, hi = np.percentile(a, 0.5), np.percentile(a, 99.5)
    return np.clip((a - lo) / max(hi - lo, 1e-6), 0, 1)


# ---------------------------------------------------------------- recipes
# Each returns albedo multiplier A (0..1, near-white), relative roughness R (0..1), height H.
def k_mineral():  # cream render / plaster
    stipple = fbm(128, 3, 11)
    blotch = fbm(3, 4, 12)
    trowel = fbm(10, 3, 13)
    stains = np.clip((fbm(4, 5, 14) - 0.62) * 4, 0, 1)
    a = 0.93 + 0.05 * (blotch - 0.5) + 0.035 * (stipple - 0.5) - 0.05 * stains
    h = 0.65 * stipple + 0.35 * trowel
    r = 0.9 + 0.1 * stipple - 0.05 * stains
    return a, r, h


def k_limestone():
    mott = fbm(4, 5, 21)
    f1, _, _ = worley(90, 22)
    pits = np.clip(1 - f1 / 0.22, 0, 1) * (vnoise(90, 23) > 0.55)
    v, u = uv()
    warp = fbm(6, 3, 24)
    bedding = 0.5 + 0.5 * np.sin((v * 22 + warp * 3) * 2 * math.pi)
    a = 0.9 + 0.07 * (mott - 0.5) - 0.12 * pits + 0.015 * (bedding - 0.5)
    h = 0.5 * fbm(32, 4, 25) - 0.8 * pits
    r = 0.88 + 0.1 * mott + 0.05 * pits
    return a, r, h


def k_paving():
    """4 rows x 4 slabs per tile, alternate rows offset by half a slab (matches Medium)."""
    v, u = uv()
    rows = 4
    row = np.floor(v * rows).astype(int)
    shift = (row % 2) * 0.5
    x = u * 4 + shift
    col = np.floor(x).astype(int) % 4
    fx = x - np.floor(x)
    fy = v * rows - row
    joint_w = 0.012  # ~7 mm of a 0.6 m slab
    edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    rng = np.random.default_rng(31)
    tone = rng.uniform(0.86, 1.0, (rows, 4))
    tilt = rng.uniform(-1, 1, (rows, 4, 2))
    slab_tone = tone[row, col]
    chip_noise = fbm(48, 3, 32)
    chipped = edge < joint_w + 0.025 * np.clip(chip_noise - 0.55, 0, 1) * 4
    joint = edge < joint_w
    grime = fbm(6, 5, 33)
    grain = fbm(160, 2, 34)
    a = slab_tone * (0.95 + 0.06 * (grain - 0.5)) - 0.08 * np.clip(grime - 0.55, 0, 1) * 2
    a = np.where(chipped & ~joint, a * 0.9, a)
    a = np.where(joint, 0.55 + 0.1 * grime, a)
    slab_h = 0.6 + 0.04 * (tilt[row, col, 0] * (fx - 0.5) + tilt[row, col, 1] * (fy - 0.5)) + 0.05 * grain
    bevel = np.clip(edge / (joint_w + 0.02), 0, 1)
    h = np.where(joint, 0.0, slab_h * (0.55 + 0.45 * np.sqrt(bevel)))
    h = np.where(chipped & ~joint, h * 0.85, h)
    r = np.where(joint, 1.0, 0.86 + 0.08 * grain + 0.06 * (1 - slab_tone))
    return a, r, h


def k_floor_stone():  # honed interior stone, faint veining
    v, u = uv()
    warp = fbm(3, 5, 41)
    vein = np.abs(np.sin((u * 3 + v * 1 + warp * 2.2) * 2 * math.pi))
    vein = np.clip(1 - vein / 0.04, 0, 1)
    mott = fbm(5, 5, 42)
    a = 0.95 + 0.04 * (mott - 0.5) - 0.06 * vein
    h = 0.2 * fbm(64, 3, 43)
    r = 0.78 + 0.18 * (fbm(12, 3, 44) - 0.5) + 0.1 * vein
    return a, r, h


def k_terrazzo():
    base = fbm(24, 3, 51)
    a = 0.95 + 0.03 * (base - 0.5)
    h = np.zeros_like(a)
    for cells, size, seed, lo, hi in ((48, 0.32, 52, 0.55, 0.95), (110, 0.28, 53, 0.45, 1.0), (220, 0.25, 54, 0.7, 1.0)):
        f1, _, cid = worley(cells, seed)
        chip = f1 < size * (0.6 + 0.6 * cid)
        tone = lo + (hi - lo) * np.mod(cid * 7.13, 1.0)
        a = np.where(chip, tone, a)
        h = np.where(chip, 0.15, h)
    r = 0.82 + 0.1 * (base - 0.5)
    return a, r, h


def k_slate():
    v, u = uv()
    warp = fbm(4, 4, 61)
    strata = np.mod(v * 7 + warp * 1.6, 1.0)
    terrace = np.floor(strata * 3) / 3
    cleft = fbm(16, 5, 62)
    a = 0.82 + 0.1 * (fbm(6, 4, 63) - 0.5) + 0.05 * terrace
    h = 0.6 * cleft + 0.4 * terrace
    r = 0.86 + 0.12 * (cleft - 0.5)
    return a, r, h


def _planks(horizontal, seed, planks=3):  # 0.40 m boards per 1.2 m repeat
    v, u = uv()
    across, along = (v, u) if horizontal else (u, v)
    idx = np.floor(across * planks).astype(int)
    rng = np.random.default_rng(seed)
    tone = rng.uniform(0.84, 1.0, planks)[idx % planks]
    offs = rng.uniform(0, 10, planks)[idx % planks]
    warp = fbm(4, 4, seed + 1)
    rings = 0.5 + 0.5 * np.sin(((across * planks - idx) * 9 + warp * 4 + offs) * 2 * math.pi)
    streak = vnoise(256, seed + 2) * 0.5 + fbm(64, 3, seed + 3) * 0.5
    seam = np.minimum(across * planks - idx, 1 - (across * planks - idx)) < 0.02
    a = tone * (0.9 + 0.08 * rings + 0.05 * (streak - 0.5))
    a = np.where(seam, a * 0.82, a)
    h = 0.5 + 0.15 * rings + 0.1 * streak
    h = np.where(seam, 0.2, h)
    r = 0.88 + 0.1 * (1 - rings) * 0.5
    return a, r, h


def k_wood():
    return _planks(False, 71)


def k_wood_horizontal():
    return _planks(True, 72)


def k_wood_transverse():
    return _planks(True, 73, planks=2)


def k_asphalt():
    f1, _, cid = worley(220, 81)
    stone = f1 < 0.33 + 0.15 * cid
    a = 0.82 + 0.06 * (fbm(8, 4, 82) - 0.5)
    a = np.where(stone, 0.78 + 0.22 * cid, a)
    h = np.where(stone, 0.6 + 0.3 * (1 - f1), 0.3) + 0.1 * fbm(64, 3, 83)
    r = np.where(stone, 0.85, 1.0)
    return a, r, h


def k_carpet():
    fibre = fbm(256, 2, 91)
    loop = 0.5 + 0.25 * (np.sin(np.arange(N)[None, :] * 2 * math.pi * 96 / N) + np.sin(np.arange(N)[:, None] * 2 * math.pi * 96 / N))
    a = 0.9 + 0.08 * (fibre - 0.5) + 0.02 * (fbm(4, 3, 92) - 0.5)
    h = 0.6 * loop + 0.4 * fibre
    r = np.ones_like(a)
    return a, r, h


def k_fabric():
    x = np.arange(N) * 2 * math.pi * 64 / N
    warp = 0.5 + 0.5 * np.sin(x)[None, :]
    weft = 0.5 + 0.5 * np.sin(x)[:, None]
    over = np.where((np.floor(np.arange(N) * 64 / N)[:, None] + np.floor(np.arange(N) * 64 / N)[None, :]) % 2 == 0, warp, weft)
    slub = fbm(32, 3, 101)
    a = 0.9 + 0.06 * (over - 0.5) + 0.04 * (slub - 0.5)
    h = over
    r = np.ones_like(a)
    return a, r, h


RECIPES = {name[2:]: fn for name, fn in globals().items() if name.startswith('k_')}


# ---------------------------------------------------------------- output
def save_png(path, rgb, colorspace):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(path.stem, w, h, alpha=False)
    img.colorspace_settings.name = colorspace
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1))], -1)
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())  # Blender rows: bottom-up
    img.filepath_raw = str(path)
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {'provenance': 'Procedural, deterministic (tools/material_kit_high.py); no external images.',
                'size': N, 'kinds': {}, 'textures': []}
    for kind, fn in sorted(RECIPES.items()):
        a, r, h = fn()
        a = np.clip(a, 0, 1)
        r = np.clip(r, 0, 1)
        px_per_m = N / REPEAT_M[kind]
        nrm = normal_from_height(norm01(h), strength_px=px_per_m * 0.004)
        files = {}
        for channel, data, cs in (('albedo', np.repeat(a[..., None], 3, -1), 'sRGB'),
                                  ('normal', nrm, 'Non-Color'),
                                  ('roughness', np.repeat(r[..., None], 3, -1), 'Non-Color')):
            path = OUT / f'{kind}_{channel}.png'
            save_png(path, data, cs)
            files[channel] = f'res://assets/runtime_surfaces_high/{path.name}'
            manifest['textures'].append(files[channel])
        manifest['kinds'][kind] = {'repeat_m': REPEAT_M[kind], 'normal_scale': NORMAL_STRENGTH[kind],
                                   'albedo_mean': round(float(a.mean()), 3), 'files': files}
        print('KIT', kind, 'albedo', round(float(a.min()), 2), '-', round(float(a.max()), 2),
              'rough', round(float(r.min()), 2), '-', round(float(r.max()), 2), flush=True)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    return manifest


def lookdev(manifest):
    """Eevee lookdev: one 1 m cube + 2 m floor tile per kind, box-projected like Godot triplanar."""
    LOOKDEV.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x, scene.render.resolution_y = 1800, 900
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
    world.node_tree.nodes['Background'].inputs[1].default_value = 0.6
    scene.world = world
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(55), 0, math.radians(35))
    scene.collection.objects.link(sun)
    tint = {'mineral': (0.93, 0.86, 0.72), 'limestone': (0.88, 0.82, 0.68), 'paving': (0.82, 0.76, 0.64),
            'slate': (0.32, 0.33, 0.35), 'terrazzo': (0.85, 0.84, 0.8), 'floor_stone': (0.8, 0.8, 0.78),
            'wood': (0.45, 0.25, 0.14), 'wood_horizontal': (0.62, 0.45, 0.28), 'wood_transverse': (0.5, 0.33, 0.2),
            'asphalt': (0.18, 0.18, 0.19), 'carpet': (0.55, 0.06, 0.08), 'fabric': (0.12, 0.16, 0.4)}
    kinds = sorted(manifest['kinds'])
    for i, kind in enumerate(kinds):
        info = manifest['kinds'][kind]
        mat = bpy.data.materials.new(kind)
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes['Principled BSDF']
        coord = nt.nodes.new('ShaderNodeTexCoord')
        mapping = nt.nodes.new('ShaderNodeMapping')
        mapping.inputs['Scale'].default_value = [1 / info['repeat_m']] * 3
        nt.links.new(coord.outputs['Object'], mapping.inputs['Vector'])

        def tex(channel, cs):
            node = nt.nodes.new('ShaderNodeTexImage')
            node.image = bpy.data.images.load(str(OUT / Path(info['files'][channel]).name))
            node.image.colorspace_settings.name = cs
            node.projection = 'BOX'
            node.projection_blend = 0.2
            nt.links.new(mapping.outputs['Vector'], node.inputs['Vector'])
            return node
        alb = tex('albedo', 'sRGB')
        mix = nt.nodes.new('ShaderNodeMix')
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs['Factor'].default_value = 1.0
        mix.inputs[6].default_value = (*tint[kind], 1)
        nt.links.new(alb.outputs['Color'], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
        rough = tex('roughness', 'Non-Color')
        nt.links.new(rough.outputs['Color'], bsdf.inputs['Roughness'])
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nm.inputs['Strength'].default_value = info['normal_scale'] * 2
        nt.links.new(tex('normal', 'Non-Color').outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
        x, y = (i % 6) * 2.6, -(i // 6) * 3.2
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, 0.5))
        bpy.context.object.data.materials.append(mat)
        bpy.ops.mesh.primitive_plane_add(size=2.4, location=(x, y, 0))
        bpy.context.object.data.materials.append(mat)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.lens = 32
    cam.location = (6.5, -14.5, 7.5)
    cam.rotation_euler = (math.radians(62), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = str(LOOKDEV / 'lookdev_high_kit.png')
    bpy.ops.render.render(write_still=True)
    # Close-ups of the four most visible kinds.
    for name, (x, y) in {'close_paving_mineral': (5.2 + 1.3, 0), 'close_limestone_wood': (0, -3.2)}.items():
        cam.location = (x - 1.8, y - 3.8, 2.2)
        cam.rotation_euler = (math.radians(68), 0, math.radians(-12))
        scene.render.filepath = str(LOOKDEV / f'{name}.png')
        bpy.ops.render.render(write_still=True)
    print('LOOKDEV', LOOKDEV, 'order', kinds)


manifest = build()
if '--lookdev' in ARGS:
    lookdev(manifest)
print('MATERIAL_KIT_DONE', len(manifest['kinds']), 'kinds')
