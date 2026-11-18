"""Game-ready rebuild of the E9 sculpted auditorium chair (Blender 4.3, in memory only).

Skills: blender-director -> asset-optimization -> retopology (decimate-based) -> lod-pipeline.
Source chair: 23,276 tris, 6 materials, 4 master meshes (two colourways duplicated).
Result: one shared mesh per colourway, 3 materials, ~1.5k tris. Godot import keeps
`generate_lods=true`, so LOD1/LOD2 are produced automatically on import.

Never saves the .blend. Called from tools/export_campus.py and tools/chair_preview.py.
"""
import bmesh
import bpy
from mathutils import Vector

CHAIR_PREFIX = 'E9 auditorium row '
TARGET_TRIS = 1500
# Materials folded into the three kept slots (upholstery, plywood, steel).
FOLD = {
    'piping': 'upholstery',          # stitched piping tube -> removed; kept slot fallback
    'plywood edge': 'plywood',
    'silver hardware': 'steel',
}


def _slot_kind(name):
    n = name.lower()
    if 'piping' in n:
        return 'piping'
    if 'upholstery' in n:
        return 'upholstery'
    if 'plywood edge' in n:
        return 'plywood edge'
    if 'plywood' in n:
        return 'plywood'
    if 'hardware' in n:
        return 'silver hardware'
    return 'steel'


def tri_count(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


KEEP_PART_TRIS = 250      # small parts (legs, feet, armrests) stay untouched
PART_RATIO = 0.055        # big curved shells keep ~5.5% of their triangles
PART_MIN_TRIS = 220
MIN_BOLT_SIZE = 0.03      # metres; smaller hardware is sub-pixel in game
PERFORATED_MIN_TRIS = 2000
HIDDEN_FACE_DOT = 0.5       # cushion faces facing their shell closer than ~60 deg


def _loose_parts(bm):
    bm.faces.ensure_lookup_table()
    seen, parts = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, grp = [f], []
        seen.add(f.index)
        while stack:
            x = stack.pop()
            grp.append(x)
            for e in x.edges:
                for y in e.link_faces:
                    if y.index not in seen:
                        seen.add(y.index)
                        stack.append(y)
        parts.append(grp)
    return parts


def _part_size(faces):
    cos = [v.co for f in faces for v in f.verts]
    return max(max(c[i] for c in cos) - min(c[i] for c in cos) for i in range(3))


def _select_only(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def build_game_chair(src_mesh, name):
    """Return a new optimized mesh built from a chair master mesh."""
    mats = list(src_mesh.materials)
    kinds = [_slot_kind(m.name) if m else 'steel' for m in mats]
    keep_order = ['upholstery', 'plywood', 'steel']
    kept = {}
    for m, k in zip(mats, kinds):
        if k in keep_order and k not in kept and m is not None:
            kept[k] = m
    remap = [keep_order.index(FOLD.get(k, k)) for k in kinds]

    # 1. Split into loose parts; drop piping tubes/tufting dots and tiny bolts.
    bm = bmesh.new()
    bm.from_mesh(src_mesh)
    part_meshes = []
    parts = _loose_parts(bm)
    bm.normal_update()

    def centroid(fs):
        cos = [v.co for f in fs for v in f.verts]
        return sum(cos, Vector()) / len(cos)

    shells = [centroid(fs) for fs in parts
              if kinds[fs[0].material_index] == 'plywood' and len(fs) > 50]
    for i, faces in enumerate(parts):
        kind = kinds[faces[0].material_index]
        if kind == 'piping':
            continue
        if kind == 'silver hardware' and _part_size(faces) < MIN_BOLT_SIZE:
            continue
        if kind == 'upholstery' and shells:
            # Hidden cushion faces that press against their plywood shell poke
            # through it once both are decimated. Drop them (never visible).
            c = centroid(faces)
            shell = min(shells, key=lambda s: (s - c).length)
            towards = (shell - c).normalized()
            faces = [f for f in faces if f.normal.dot(towards) < HIDDEN_FACE_DOT]
        pbm = bmesh.new()
        vmap = {}
        for f in faces:
            for v in f.verts:
                if v not in vmap:
                    vmap[v] = pbm.verts.new(v.co)
            nf = pbm.faces.new([vmap[v] for v in f.verts])
            nf.material_index = remap[f.material_index]
            nf.smooth = f.smooth
        tris_here = sum(len(f.verts) - 2 for f in faces)
        if kind == 'plywood' and tris_here > PERFORATED_MIN_TRIS and _part_size(faces) < 0.6:
            # Perforated seat-underside slab: dimples shred under collapse.
            # Its convex hull is the clean slab silhouette (bevels kept, holes gone).
            mat_index = remap[faces[0].material_index]
            hull = bmesh.ops.convex_hull(pbm, input=pbm.verts[:])
            bmesh.ops.delete(pbm, geom=[g for g in hull['geom_interior'] + hull['geom_unused']
                                        if isinstance(g, bmesh.types.BMVert)], context='VERTS')
            old = [f for f in pbm.faces if f not in set(g for g in hull['geom'] if isinstance(g, bmesh.types.BMFace))]
            bmesh.ops.delete(pbm, geom=old, context='FACES_ONLY')
            for f in pbm.faces:
                f.material_index = mat_index
                f.smooth = True
            bmesh.ops.recalc_face_normals(pbm, faces=pbm.faces[:])
        pm = bpy.data.meshes.new(f'__part_{i}')
        pbm.to_mesh(pm)
        pbm.free()
        part_meshes.append(pm)
    bm.free()

    # 2. Decimate each big shell to its own budget; small parts stay exact.
    objs = []
    for pm in part_meshes:
        for k in keep_order:
            pm.materials.append(kept.get(k))
        o = bpy.data.objects.new(pm.name, pm)
        bpy.context.scene.collection.objects.link(o)
        tris = tri_count(pm)
        if tris > KEEP_PART_TRIS:
            target = max(PART_MIN_TRIS, tris * PART_RATIO)
            _select_only(o)
            mod = o.modifiers.new('collapse', 'DECIMATE')
            mod.decimate_type = 'COLLAPSE'
            mod.ratio = min(1.0, target / tris)
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        objs.append(o)

    # 3. Join, triangulate, smooth-by-angle (keeps creases on frame/legs).
    _select_only(objs[0])
    for o in objs[1:]:
        o.select_set(True)
    bpy.ops.object.join()
    tmp = bpy.context.view_layer.objects.active
    tri = tmp.modifiers.new('tri', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    bpy.ops.object.shade_smooth_by_angle(angle=0.61)  # 35 deg
    for m in list(tmp.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    mesh = tmp.data
    mesh.name = name
    bpy.data.objects.remove(tmp, do_unlink=True)
    for pm in part_meshes:
        try:
            if pm != mesh and pm.users == 0:
                bpy.data.meshes.remove(pm)
        except ReferenceError:
            pass
    return mesh


def tri_count_eval(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    m = ev.to_mesh()
    t = tri_count(m)
    ev.to_mesh_clear()
    return t


def colourway(mesh):
    for m in mesh.materials:
        if m and 'upholstery' in m.name.lower():
            return m.name
    return mesh.name


def optimize_chairs(objects, log=print):
    """Replace every auditorium chair mesh with a shared game-ready mesh per colourway."""
    chairs = [o for o in objects if o.type == 'MESH' and o.name.startswith(CHAIR_PREFIX)]
    by_way = {}
    for o in chairs:
        by_way.setdefault(colourway(o.data), []).append(o)
    report = []
    for way, users in sorted(by_way.items()):
        src = users[0].data
        before = tri_count(src)
        game = build_game_chair(src, 'SM_E9_AuditoriumChair_' + ('Crimson' if 'crimson' in way.lower() else 'Blue'))
        for o in users:
            o.modifiers.clear()
            o.data = game
        after = tri_count(game)
        report.append({'colourway': way, 'users': len(users), 'source_meshes': sorted({u.name for u in users})[:1],
                       'tris_before': before, 'tris_after': after, 'mesh': game.name,
                       'materials': [m.name if m else None for m in game.materials]})
        log('Chair', game.name, 'users', len(users), 'tris', before, '->', after)
    return report
