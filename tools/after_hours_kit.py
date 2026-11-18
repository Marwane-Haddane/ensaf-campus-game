"""After Hours ruin-dressing kit (roadmap item #8).

  blender -b --factory-startup --python tools/after_hours_kit.py

Writes assets/antigravity/zombie/after_hours/:
  after_hours_kit.glb  SM_AH_BurntCar, SM_AH_JerseyBarrier, SM_AH_PlankBarricade, SM_AH_RubblePile
                       (no UVs: Godot maps the textures with local triplanar; vertex colours
                       carry soot/rust tint; material slots AH_Concrete / AH_BurntMetal / AH_Wood /
                       AH_Char)
  concrete_albedo/normal, burnt_metal_albedo/normal, wood_albedo/normal,
  crate_wood_albedo, crate_military_albedo   512 px tileable
  scorch.png                                  512 px RGBA ground decal (alpha)
Procedural with fixed seeds; reuses the noise helpers of tools/vegetation_kit_high.py.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from vegetation_kit_high import fbm, normal_from_height, save_png, smooth_noise  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'antigravity' / 'zombie' / 'after_hours'
N = 512
CONCRETE, METAL, WOOD, CHAR = range(4)

# ---------------------------------------------------------------- textures


def tex_concrete():
    h = fbm(8, 8, 301, N, N, 5)
    pits = (smooth_noise(96, 96, 303, N, N) > 0.82).astype(float)
    streak = fbm(40, 3, 305, N, N, 3)
    shade = 0.78 + 0.32 * (h - 0.5) - 0.18 * pits - 0.10 * np.clip(streak - 0.55, 0, 1) * 4
    col = np.array([0.56, 0.55, 0.52]) * shade[..., None]
    return np.clip(col, 0, 1), normal_from_height(h * 0.6 - pits * 0.4, 5.0)


def tex_burnt_metal():
    h = fbm(6, 6, 401, N, N, 5)
    rust = np.clip((fbm(5, 5, 403, N, N, 4) - 0.48) * 4, 0, 1)
    ash = np.clip((fbm(9, 9, 405, N, N, 3) - 0.6) * 5, 0, 1)
    char = np.array([0.05, 0.045, 0.04])
    rust_c = np.array([0.33, 0.15, 0.06]) * (0.7 + 0.6 * h)[..., None]
    ash_c = np.array([0.32, 0.31, 0.29])
    col = char * (1 - rust[..., None]) + rust_c * rust[..., None]
    col = col * (1 - ash[..., None] * 0.7) + ash_c * ash[..., None] * 0.7
    blister = smooth_noise(70, 70, 407, N, N)
    return np.clip(col, 0, 1), normal_from_height(h * 0.5 + blister * 0.5 * rust, 6.0)


def tex_wood(seed=501, plank_m=0.2, repeat_m=1.0, tint=(0.42, 0.34, 0.24), gaps=True):
    v = (np.arange(N) / N)[:, None] * np.ones((1, N))
    grain = fbm(4, 60, seed, N, N, 4)  # long grain along u
    planks = int(round(repeat_m / plank_m))
    board = np.floor(v * planks)
    rng = np.random.default_rng(seed)
    tone = rng.uniform(0.8, 1.15, planks)[board.astype(int) % planks]
    frac = v * planks - board
    gap = ((frac < 0.035) | (frac > 0.965)).astype(float) if gaps else 0
    col = np.array(tint) * (tone * (0.75 + 0.5 * grain))[..., None]
    col = col * (1 - 0.8 * gap)[..., None] if gaps else col
    h = grain * 0.6 - (gap * 0.8 if gaps else 0)
    return np.clip(col, 0, 1), normal_from_height(h, 6.0)


def tex_crate_military():
    h = fbm(6, 6, 601, N, N, 4)
    wear = np.clip((fbm(18, 18, 603, N, N, 3) - 0.64) * 6, 0, 1)
    olive = np.array([0.20, 0.25, 0.15]) * (0.85 + 0.3 * h)[..., None]
    metal = np.array([0.42, 0.42, 0.40])
    col = olive * (1 - wear[..., None]) + metal * wear[..., None]
    # Pale stencil band across the middle third.
    v = np.arange(N)[:, None] / N * np.ones((1, N))
    band = ((v > 0.44) & (v < 0.56)).astype(float) * (smooth_noise(64, 8, 605, N, N) > 0.35)
    col = col * (1 - band[..., None] * 0.6) + np.array([0.62, 0.60, 0.50]) * band[..., None] * 0.6
    return np.clip(col, 0, 1)


def tex_scorch():
    yy, xx = np.mgrid[0:N, 0:N] / N - 0.5
    r = np.hypot(xx, yy) * 2
    edge = 0.8 + 0.25 * (fbm(6, 6, 701, N, N, 4) - 0.5)
    alpha = np.clip((edge - r) / 0.35, 0, 1) ** 1.3
    soot = fbm(10, 10, 703, N, N, 4)
    col = np.array([0.03, 0.028, 0.025]) * (0.7 + 0.6 * soot)[..., None]
    return col, alpha * (0.75 + 0.25 * soot)

# ---------------------------------------------------------------- meshes


def new_obj(name, bm, materials, colors=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in materials:
        mesh.materials.append(m)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def add_box(bm, size, center, mat, rot=None, jitter=0.0, rng=None):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret['verts']
    m = Matrix.Diagonal((*size, 1.0))
    if rot is not None:
        m = rot.to_4x4() @ m
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)) @ m, verts=verts)
    if jitter and rng is not None:
        for v in verts:
            v.co += Vector(rng.normal(size=3)) * jitter
    for f in {f for v in verts for f in v.link_faces}:
        f.material_index = mat
    return verts


def add_cylinder(bm, radius, depth, center, axis_rot, mat, segments=10):
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)) @ axis_rot.to_4x4(), verts=ret['verts'])
    for f in {f for v in ret['verts'] for f in v.link_faces}:
        f.material_index = mat


def jersey_barrier():
    bm = bmesh.new()
    # Classic New Jersey profile (y = across, z = up), extruded 2.0 m along x.
    prof = [(-0.30, 0.0), (0.30, 0.0), (0.30, 0.08), (0.20, 0.33), (0.08, 0.81), (-0.08, 0.81), (-0.20, 0.33), (-0.30, 0.08)]
    L = 2.0
    a = [bm.verts.new((-L / 2, y, z)) for y, z in prof]
    b = [bm.verts.new((L / 2, y, z)) for y, z in prof]
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.material_index = CONCRETE
    # Chipped corner block and a lifting-slot recess are implied by texture; keep it light.
    return bm


def plank_barricade(rng):
    bm = bmesh.new()
    for x in (-0.8, 0.8):  # sawhorse A-frames
        for s in (-1, 1):
            add_box(bm, (0.07, 0.07, 1.15), (x, s * 0.18, 0.55), WOOD, Matrix.Rotation(math.radians(14 * s), 3, 'X'))
        add_box(bm, (0.07, 0.42, 0.06), (x, 0, 0.35), WOOD)
    for i, (z, tilt) in enumerate(((0.95, 4), (0.62, -9), (0.30, 13))):
        add_box(bm, (2.1 + rng.uniform(-0.1, 0.15), 0.035, 0.18), (rng.uniform(-0.08, 0.08), -0.24, z),
                WOOD, Matrix.Rotation(math.radians(tilt), 3, 'Y'))
    # A red/white warning plank on top uses the wood material; tint via vertex colour in Godot is not needed.
    return bm


def rubble_pile(rng):
    bm = bmesh.new()
    for i in range(16):
        r = rng.uniform(0, 0.75)
        a = rng.uniform(0, 2 * math.pi)
        s = rng.uniform(0.15, 0.45) * (1.25 - r * 0.6)
        size = (s * rng.uniform(0.7, 1.6), s * rng.uniform(0.7, 1.4), s * rng.uniform(0.4, 0.9))
        rot = Matrix.Rotation(rng.uniform(0, 6.3), 3, 'Z') @ Matrix.Rotation(rng.uniform(-0.5, 0.5), 3, 'X')
        z = size[2] * 0.35 + max(0, 0.35 - r * 0.45)
        add_box(bm, size, (math.cos(a) * r, math.sin(a) * r, z), CONCRETE, rot, jitter=0.025, rng=rng)
    for i in range(4):  # bent rebar
        a = rng.uniform(0, 2 * math.pi)
        rot = Matrix.Rotation(a, 3, 'Z') @ Matrix.Rotation(math.radians(rng.uniform(55, 80)), 3, 'Y')
        add_cylinder(bm, 0.012, rng.uniform(0.6, 1.0), (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0.35), rot, METAL, 5)
    return bm


def burnt_car(rng):
    bm = bmesh.new()
    # Lower body sits low: tyres burnt away, car resting on its rims.
    body = add_box(bm, (4.3, 1.78, 0.62), (0, 0, 0.62), METAL)
    # Hood and boot slope: pull the front/back top edges down.
    for v in body:
        if v.co.z > 0.8 and abs(v.co.x) > 2.0:
            v.co.z -= 0.1
    cabin = add_box(bm, (2.25, 1.55, 0.52), (-0.15, 0, 1.18), CHAR)
    for v in cabin:
        if v.co.z > 1.3:
            v.co.x *= 0.78  # raked windscreen/back glass
            v.co.y *= 0.92
    # Roof skin (slightly crumpled) over the charred, glassless cabin.
    add_box(bm, (1.72, 1.45, 0.05), (-0.15, 0, 1.46), METAL, Matrix.Rotation(math.radians(1.5), 3, 'Y'), 0.01, rng)
    # Pillars.
    for x in (-1.05, 0.72):
        for y in (-0.7, 0.7):
            add_box(bm, (0.08, 0.06, 0.55), (x * 0.92, y, 1.18), METAL, Matrix.Rotation(math.radians(-22 if x > 0 else 18), 3, 'Y'))
    # Rims.
    for x in (-1.35, 1.35):
        for y in (-0.82, 0.82):
            add_cylinder(bm, 0.3, 0.16, (x, y, 0.3), Matrix.Rotation(math.pi / 2, 3, 'X'), METAL, 12)
    # Bumpers.
    for x in (-2.18, 2.18):
        add_box(bm, (0.12, 1.7, 0.18), (x, 0, 0.45), METAL, None, 0.01, rng)
    # Light dents everywhere.
    for v in bm.verts:
        v.co += Vector(rng.normal(size=3)) * 0.012
    return bm


def make_materials():
    out = []
    for name in ('AH_Concrete', 'AH_BurntMetal', 'AH_Wood', 'AH_Char'):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        out.append(m)
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    c, n = tex_concrete(); save_png(OUT / 'concrete_albedo.png', c, 'sRGB'); save_png(OUT / 'concrete_normal.png', n, 'Non-Color')
    c, n = tex_burnt_metal(); save_png(OUT / 'burnt_metal_albedo.png', c, 'sRGB'); save_png(OUT / 'burnt_metal_normal.png', n, 'Non-Color')
    c, n = tex_wood(); save_png(OUT / 'wood_albedo.png', c, 'sRGB'); save_png(OUT / 'wood_normal.png', n, 'Non-Color')
    c, _ = tex_wood(seed=511, plank_m=0.15, repeat_m=0.6, tint=(0.50, 0.38, 0.24)); save_png(OUT / 'crate_wood_albedo.png', c, 'sRGB')
    save_png(OUT / 'crate_military_albedo.png', tex_crate_military(), 'sRGB')
    c, a = tex_scorch(); save_png(OUT / 'scorch.png', c, 'sRGB', a)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()
    rng = np.random.default_rng(808)
    for name, bm in (('SM_AH_JerseyBarrier', jersey_barrier()), ('SM_AH_PlankBarricade', plank_barricade(rng)),
                     ('SM_AH_RubblePile', rubble_pile(rng)), ('SM_AH_BurntCar', burnt_car(rng))):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj = new_obj(name, bm, mats)
        for poly in obj.data.polygons:
            poly.use_smooth = False
        print(name, 'tris', sum(len(p.vertices) - 2 for p in obj.data.polygons))
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'after_hours_kit.glb'), export_format='GLB',
                              export_materials='EXPORT', export_image_format='NONE', export_yup=True)
    print('AFTER_HOURS_KIT_DONE')


main()
