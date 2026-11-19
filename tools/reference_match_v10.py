"""Campus revision 10: match buildings B and D to the November 2026 photo set.

Opens revision 9 (never modified) and saves revision 10 next to it:
    blender -b 3D-modeling/campus-design-v9/ensaf-campus-v9-final.blend \
            --python campus-game/tools/reference_match_v10.py

Building D (glazed block, photos 1-5)
  * darker blue-green solar glass, ochre stepped seating, cream polished hall floor
  * garden approach: grey interlocking paver path, lawns, a row of Washingtonia
    fan palms, bollard lamps, a concrete slab framed by two mosaic-rimmed basins
Building B (university block, photos 6-14)
  * the navy circle tower is rebuilt as a clean slab (the boolean ngon mesh
    triangulated into shards in the game) with white discs and grilled portholes
  * taupe render on the long wing, pale blue-grey tile cladding with panel joints,
    royal-blue facade stripes, blue university sign panel with white lettering,
    navy flat canopy beside the tower
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / '3D-modeling' / 'campus-design-v10'
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT = OUT_DIR / 'ensaf-campus-v10.blend'


def log(*items):
    print('[V10]', *items, flush=True)


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def srgb(r, g, b):
    return (lin(r), lin(g), lin(b), 1.0)


def set_color(mat, rgba, roughness=None, metallic=None):
    mat.diffuse_color = rgba
    if mat.use_nodes:
        bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf:
            for link in list(bsdf.inputs['Base Color'].links):
                mat.node_tree.links.remove(link)
            bsdf.inputs['Base Color'].default_value = rgba
            if roughness is not None:
                bsdf.inputs['Roughness'].default_value = roughness
            if metallic is not None:
                bsdf.inputs['Metallic'].default_value = metallic


def material(name, rgba, roughness=0.7, metallic=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    set_color(mat, rgba, roughness, metallic)
    return mat


def collection(name, parent='R4 - ENSA campus design'):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.data.collections[parent].children.link(col)
    return col


def hide(name):
    obj = bpy.data.objects.get(name)
    if obj is None:
        log('missing', name)
        return 0
    obj.hide_render = True
    obj.hide_set(True)
    obj.hide_viewport = True
    return 1


def mesh_object(name, bm, mat, col):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in (mat if isinstance(mat, list) else [mat]):
        me.materials.append(m)
    obj = bpy.data.objects.new(name, me)
    col.objects.link(obj)
    for poly in me.polygons:
        poly.use_smooth = False
    return obj


def add_box(bm, lo, hi, mat_index=0):
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    v = [bm.verts.new(p) for p in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]]
    for idx in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        f = bm.faces.new([v[i] for i in idx])
        f.material_index = mat_index


def box(name, lo, hi, mat, col):
    bm = bmesh.new()
    add_box(bm, lo, hi)
    return mesh_object(name, bm, mat, col)


def add_disc_xz(bm, cx, cz, y, radius, segments=24, depth=0.02, mat_index=0, inner=0.0):
    """Disc (or ring when inner>0) on a -Y facing facade, extruded toward -Y."""
    def ring(r, yy):
        return [bm.verts.new((cx + r * math.cos(2 * math.pi * i / segments), yy,
                              cz + r * math.sin(2 * math.pi * i / segments))) for i in range(segments)]
    if inner <= 0.0:
        back, front = ring(radius, y), ring(radius, y - depth)
        bm.faces.new(list(reversed(front))).material_index = mat_index
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new([back[i], back[j], front[j], front[i]]).material_index = mat_index
        return
    outer_f, inner_f = ring(radius, y - depth), ring(inner, y - depth)
    outer_b, inner_b = ring(radius, y), ring(inner, y)
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new([outer_f[i], inner_f[i], inner_f[j], outer_f[j]]).material_index = mat_index
        bm.faces.new([outer_b[i], outer_b[j], outer_f[j], outer_f[i]]).material_index = mat_index
        bm.faces.new([inner_b[j], inner_b[i], inner_f[i], inner_f[j]]).material_index = mat_index


def world_bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return (Vector([min(p[i] for p in pts) for i in range(3)]),
            Vector([max(p[i] for p in pts) for i in range(3)]))


report = {'hidden': 0, 'created': []}

# ---------------------------------------------------------------- materials
M = bpy.data.materials
set_color(M['Warm mineral plaster'], srgb(172, 163, 152), 0.86)          # taupe render, photos 11-14
set_color(M['R4 B entrance grey cladding'], srgb(196, 204, 214), 0.62)   # pale blue-grey tiles
set_color(M['R4 B latest blue circular facade panel'], srgb(44, 58, 86), 0.55)  # navy tower
set_color(M['D7 blue solar control glazing'], srgb(34, 58, 68), 0.06, 0.2)       # dark blue-green glass
set_color(M['D7 warm ochre stepped seating'], srgb(201, 163, 86), 0.42)          # mustard painted tiers
set_color(M['D7 honed cream interior stone'], srgb(232, 222, 196), 0.22)         # glossy cream resin floor
set_color(M['D7 sandstone approach paving'], srgb(186, 178, 168), 0.88)          # grey concrete pavers
cobalt = material('B royal blue facade stripe accent', srgb(38, 78, 168), 0.5)
navy = M['R4 B latest blue circular facade panel']
white_disc = material('B white painted tower disc accent', srgb(236, 238, 240), 0.5)
porthole_dark = material('B dark porthole recess', srgb(28, 32, 40), 0.8)
sign_panel = material('B university sign cobalt panel', srgb(36, 64, 158), 0.38, 0.1)
sign_white = material('B sign white lettering', srgb(246, 247, 249), 0.35)
joint_mat = material('B cladding dark joint grout', srgb(120, 128, 138), 0.8)
paver = material('D10 interlocking paver path', srgb(168, 150, 140), 0.9)
lawn = material('D10 irrigated green lawn', srgb(92, 142, 54), 0.95)
curb = M['Off-white precast edges']
bark = material('D10 palm trunk bark', srgb(112, 94, 76), 0.95)
skirt = material('D10 palm dry frond skirt leaves', srgb(96, 78, 56), 0.95)
frond = material('D10 fan palm leaves', srgb(64, 112, 50), 0.7)
mosaic = material('D10 zellige mosaic basin rim', srgb(120, 138, 150), 0.35)
basin_bed = material('D10 dark gravel basin bed soil', srgb(70, 66, 60), 0.95)
concrete = material('D10 cast concrete garden slab', srgb(196, 178, 160), 0.85)
bollard = material('D10 black bollard lamp metal', srgb(30, 32, 34), 0.45, 0.6)
globe = material('D10 opal bollard light diffuser', srgb(245, 243, 236), 0.3)

# ---------------------------------------------------------------- building B
colB = collection('B10 - Photo-matched university entrance facade')

# 1. Navy circle tower: replace the bevelled boolean ngon slab.
for name in ['Circular perforated vertical facade'] + \
        [o.name for o in bpy.data.objects if o.name.startswith(('B pale circular inset behind facade', 'Circle opening grille'))]:
    report['hidden'] += hide(name)
box('B10 navy circle tower facade wall', (-5.975, -0.60, 0.225), (-3.525, -0.12, 10.375), navy, colB)
FRONT = -0.60
discs = [  # (x, z, radius) laid out like photos 12-14: scattered white discs
    (-5.30, 9.95, 0.20), (-4.15, 9.55, 0.16), (-5.35, 8.55, 0.17), (-4.40, 8.20, 0.13),
    (-5.30, 7.30, 0.15), (-4.95, 5.70, 0.13), (-4.25, 5.10, 0.22), (-4.30, 3.55, 0.15),
    (-4.95, 2.75, 0.17), (-4.15, 2.15, 0.14), (-5.30, 1.55, 0.19), (-4.40, 0.95, 0.12),
    (-5.40, 6.30, 0.11), (-3.95, 6.05, 0.10), (-5.55, 4.95, 0.10), (-3.95, 8.95, 0.10),
]
bm = bmesh.new()
for x, z, r in discs:
    add_disc_xz(bm, x, z, FRONT, r, segments=20, depth=0.025)
mesh_object('B10 white tower disc accents', bm, white_disc, colB)
portholes = [(-4.95, 9.05, 0.42), (-4.55, 7.05, 0.50), (-5.05, 4.20, 0.36)]
bm_ring, bm_dark = bmesh.new(), bmesh.new()
for x, z, r in portholes:
    add_disc_xz(bm_ring, x, z, FRONT, r, segments=32, depth=0.05, inner=r - 0.07)
    add_disc_xz(bm_dark, x, z, FRONT + 0.002, r - 0.06, segments=32, depth=0.004)
    for k in range(-3, 4):  # horizontal grille bars
        zz = z + k * (r - 0.07) / 3.6
        half = math.sqrt(max((r - 0.07) ** 2 - (zz - z) ** 2, 0.0))
        if half > 0.03:
            add_box(bm_ring, (x - half, FRONT - 0.035, zz - 0.012), (x + half, FRONT - 0.005, zz + 0.012))
mesh_object('B10 grilled porthole rings', bm_ring, white_disc, colB)
mesh_object('B10 porthole dark recess', bm_dark, porthole_dark, colB)

# 2. Royal-blue stripes (wider, brighter than the navy tower) plus the top band.
for name in ['B blue entrance facade stripe', 'B blue entrance facade stripe.001']:
    report['hidden'] += hide(name)
box('B10 royal blue facade stripe centre', (-10.50, -0.225, 6.48), (-5.975, -0.16, 6.80), cobalt, colB)
box('B10 royal blue facade stripe right', (-3.525, -0.225, 6.48), (4.0, -0.16, 6.80), cobalt, colB)
box('B10 royal blue parapet stripe right', (-3.525, -0.225, 9.38), (4.0, -0.16, 9.62), cobalt, colB)

# 3. Tile cladding joint grid on every front-facing grey cladding surface.
PITCH_X, PITCH_Z, J = 1.10, 0.80, 0.022
bm = bmesh.new()
clad_count = 0
for obj in bpy.data.objects:
    if obj.type != 'MESH' or obj.hide_render:
        continue
    if not any(s.material and s.material.name == 'R4 B entrance grey cladding' for s in obj.material_slots):
        continue
    lo, hi = world_bounds(obj)
    if hi.y > 1.0 or hi.y - lo.y > 0.6 or lo.y < -0.7:
        continue
    clad_count += 1
    y0, y1 = lo.y - 0.004, lo.y + 0.002
    gx = math.ceil(lo.x / PITCH_X) * PITCH_X
    while gx < hi.x - 0.01:
        add_box(bm, (gx - J / 2, y0, lo.z), (gx + J / 2, y1, hi.z))
        gx += PITCH_X
    gz = math.ceil((lo.z - 0.5) / PITCH_Z) * PITCH_Z + 0.5
    while gz < hi.z - 0.01:
        add_box(bm, (lo.x, y0, gz - J / 2), (hi.x, y1, gz + J / 2))
        gz += PITCH_Z
mesh_object('B10 cladding panel joint grid', bm, joint_mat, colB)
log('cladding pieces with joints', clad_count)

# 4. University sign: blue panel behind the existing lettering, lettering white.
box('B10 university sign blue panel', (-15.95, -0.200, 2.86), (-12.05, -0.166, 4.32), sign_panel, colB)
for name in ['School sign large', 'School sign second', 'School sign affiliation']:
    obj = bpy.data.objects.get(name)
    if obj:
        obj.data.materials.clear()
        obj.data.materials.append(sign_white)

# 5. Navy flat canopy beside the tower (photos 12-14).
box('B10 navy portico canopy roof', (-3.525, -3.40, 3.00), (2.60, -0.16, 3.32), navy, colB)
box('B10 navy portico canopy fascia', (-3.525, -3.46, 2.78), (2.60, -3.34, 3.32), navy, colB)
box('B10 navy portico canopy column', (2.28, -3.40, 0.52), (2.56, -3.12, 3.00), navy, colB)

# 6. Flat modern parapet: taupe slab edges instead of white classical cornices.
for name in ['R3 main roof slab', 'R3 main upper slab', 'R3 main middle slab', 'R3 main lower slab']:
    obj = bpy.data.objects.get(name)
    if obj:
        obj.data.materials.clear()
        obj.data.materials.append(M['Warm mineral plaster'])

# ---------------------------------------------------------------- building D garden
colD = collection('D10 - Photo-matched garden approach')
for name in ['Campus rectangular lawn.002', 'Courtyard planting.002'] + \
        [f'Campus lawn border.{i:03d}' for i in range(8, 12)]:
    obj = bpy.data.objects.get(name)
    if obj:
        lo, hi = world_bounds(obj)
        if lo.y > 60 and hi.y < 80 and lo.x > -6 and hi.x < 4:
            report['hidden'] += hide(name)

PATH_X0, PATH_X1, PATH_Y0, PATH_Y1 = -6.0, -2.0, 64.5, 97.2
box('D10 interlocking paver approach path', (PATH_X0, PATH_Y0, 0.15), (PATH_X1, PATH_Y1, 0.285), paver, colD)
bm = bmesh.new()
for x in (PATH_X0 - 0.12, PATH_X1):
    add_box(bm, (x, PATH_Y0, 0.15), (x + 0.12, 93.0, 0.33))
mesh_object('D10 path edge curb', bm, curb, colD)
lawns = {'west': (-21.0, PATH_X0 - 0.12, 66.0, 93.0), 'east': (PATH_X1 + 0.12, 8.0, 66.0, 93.0)}
for side, (x0, x1, y0, y1) in lawns.items():
    box(f'D10 {side} lawn', (x0, y0, 0.16), (x1, y1, 0.32), lawn, colD)
    bm = bmesh.new()
    add_box(bm, (x0 - 0.12, y0 - 0.12, 0.15), (x1, y0, 0.34))
    add_box(bm, (x0 - 0.12, y1, 0.15), (x1, y1 + 0.12, 0.34))
    if side == 'west':
        add_box(bm, (x0 - 0.12, y0, 0.15), (x0, y1, 0.34))
    else:
        add_box(bm, (x1, y0, 0.15), (x1 + 0.12, y1, 0.34))
    mesh_object(f'D10 {side} lawn border', bm, curb, colD)

# Concrete slab framed by two zellige-rimmed basins (photos 2-4).
box('D10 cast concrete garden slab', (-15.6, 74.4, 0.16), (-11.6, 78.2, 0.42), concrete, colD)
for i, (x0, y0, x1, y1) in enumerate([(-18.4, 79.0, -13.0, 80.1), (-14.2, 72.5, -8.8, 73.6)]):
    bm = bmesh.new()
    rim = 0.16
    add_box(bm, (x0, y0, 0.16), (x1, y0 + rim, 0.40))
    add_box(bm, (x0, y1 - rim, 0.16), (x1, y1, 0.40))
    add_box(bm, (x0, y0, 0.16), (x0 + rim, y1, 0.40))
    add_box(bm, (x1 - rim, y0, 0.16), (x1, y1, 0.40))
    mesh_object(f'D10 zellige basin rim {i + 1}', bm, mosaic, colD)
    box(f'D10 basin gravel bed soil {i + 1}', (x0 + rim, y0 + rim, 0.16), (x1 - rim, y1 - rim, 0.30), basin_bed, colD)

# Bollard lamps along both path edges.
bm_post, bm_globe = bmesh.new(), bmesh.new()
y = 66.5
while y < 95.0:
    for x in (PATH_X0 - 0.45, PATH_X1 + 0.45):
        bmesh.ops.create_cone(bm_post, cap_ends=True, segments=10, radius1=0.05, radius2=0.04, depth=0.85,
                              matrix=Matrix.Translation((x, y, 0.33 + 0.425)))
        bmesh.ops.create_uvsphere(bm_globe, u_segments=12, v_segments=8, radius=0.11,
                                  matrix=Matrix.Translation((x, y, 0.33 + 0.95)))
    y += 4.0
mesh_object('D10 bollard lamp posts', bm_post, bollard, colD)
mesh_object('D10 bollard lamp globes', bm_globe, globe, colD)


def build_palm(name, height, lean, seed):
    """Washingtonia fan palm in one mesh: ringed tapered trunk (mat 0),
    dry frond skirt (mat 1) and 22 cupped fan fronds (mat 2)."""
    import random
    rnd = random.Random(seed)
    bm = bmesh.new()
    seg, rings = 12, 18
    prev = None
    for k in range(rings + 1):
        t = k / rings
        r = 0.30 - 0.08 * t + (0.025 if k % 2 else 0.0)  # boot-scar rings
        cx = lean * t * t
        ring = [bm.verts.new((cx + r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), t * height))
                for i in range(seg)]
        if prev:
            for i in range(seg):
                j = (i + 1) % seg
                bm.faces.new([prev[i], prev[j], ring[j], ring[i]]).material_index = 0
        prev = ring
    top = Vector((lean, 0.0, height))
    s_top, s_bot = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        s_top.append(bm.verts.new(top + Vector((0.30 * math.cos(a), 0.30 * math.sin(a), 0.05))))
        s_bot.append(bm.verts.new(top + Vector((0.36 * math.cos(a), 0.36 * math.sin(a), -0.55))))
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new([s_bot[i], s_bot[j], s_top[j], s_top[i]]).material_index = 1
    for n in range(22):
        az = 2 * math.pi * n / 22 + rnd.uniform(-0.12, 0.12)
        el = math.radians(rnd.uniform(-35, 55))
        d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
        side = Vector((-math.sin(az), math.cos(az), 0.0))
        up = d.cross(side).normalized()
        base = top + d * 0.15
        stalk = base + d * 1.05
        w = 0.03
        p = [bm.verts.new(v) for v in (base - side * w, base + side * w, stalk + side * w, stalk - side * w)]
        bm.faces.new(p).material_index = 2
        blade_r = rnd.uniform(1.05, 1.30)
        for k in range(15):  # spiky leaflets with gaps, drooping toward the tips
            a = math.radians(-78 + 156 * k / 14)
            tip_dir = (d * math.cos(a) + side * math.sin(a)).normalized()
            perp = tip_dir.cross(up).normalized()
            inner = stalk + tip_dir * 0.18
            droop = Vector((0, 0, -0.30 * blade_r * (0.6 + 0.4 * abs(math.sin(a)))))
            mid = stalk + tip_dir * (blade_r * 0.55) + up * 0.05 + droop * 0.3
            tip = stalk + tip_dir * blade_r + droop
            v = [bm.verts.new(inner - perp * 0.035), bm.verts.new(inner + perp * 0.035),
                 bm.verts.new(mid + perp * 0.045), bm.verts.new(tip), bm.verts.new(mid - perp * 0.045)]
            bm.faces.new(v).material_index = 2
    return mesh_object(name, bm, [bark, skirt, frond], colD)


templates = [build_palm('Campus fan palm D10 row 01', 6.4, 0.10, 3),
             build_palm('Campus fan palm D10 row 02', 5.6, -0.12, 7)]
palm_ys = [67.5, 71.0, 74.5, 78.0, 81.5, 85.0, 88.5, 92.0]
for i, py in enumerate(palm_ys):
    if i < 2:
        obj = templates[i]
    else:
        obj = templates[i % 2].copy()  # linked mesh data: one mesh per template in the GLB
        obj.name = f'Campus fan palm D10 row {i + 1:02d}'
        colD.objects.link(obj)
    obj.location = (PATH_X0 - 1.15, py, 0.30)
    obj.rotation_euler = (0, 0, math.radians(37 * i))

bpy.context.view_layer.update()
report['created'] = sorted(o.name for o in list(colB.objects) + list(colD.objects))
log('hidden', report['hidden'], 'created', len(report['created']))
# Review cameras that match the photo viewpoints.
cams = {
    'D10 Camera 01 - palm path to glazed block': ((-9.0, 58.0, 1.6), (-4.0, 98.0, 6.0)),
    'D10 Camera 02 - lawn basins and glazed corner': ((-34.0, 70.0, 1.7), (-6.0, 98.0, 5.0)),
    'B10 Camera 01 - university entrance': ((-8.0, -5.4, 1.6), (-8.0, 0.0, 4.5)),
    'B10 Camera 02 - circle tower oblique': ((4.0, -5.6, 1.6), (-6.0, 0.0, 5.0)),
}
review = collection('B10 D10 - Review cameras', parent='R4 - ENSA campus design')
for name, (loc, target) in cams.items():
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        review.objects.link(cam)
    cam.data.lens = 22
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

bpy.ops.wm.save_as_mainfile(filepath=str(OUT), compress=True, copy=True)
log('SAVED', OUT)
