"""Game-ready rebuild of the E9 unified smooth stone roof/frame (Blender 4.3, in memory only).

Skills: blender-director -> asset-optimization -> retopology (planar dissolve + collapse) -> qa-review.
Source: one closed uniform ~4 cm quad remesh, 819,826 quads (1.64M tris), 21 x 24.5 x 5.8 m.
Flat walls/roof carry almost all of that density. Planar dissolve removes it, then a
collapse pass keeps the rounded corners within budget. Never saves the .blend.
"""
import bpy

ROOF_PREFIX = 'E9 unified smooth stone roof'
TARGET_TRIS = 15000
PRE_COLLAPSE_TRIS = 120000
PLANAR_ANGLE = 0.0175   # 1 degree
SMOOTH_ANGLE = 0.52     # 30 degrees: rounded corners smooth, wall/roof break stays crisp


def tri_count(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def _select_only(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def _apply(obj, mod):
    bpy.ops.object.modifier_apply(modifier=mod.name)


def build_game_roof(obj, target=TARGET_TRIS, log=print):
    """Replace obj.data with a decimated copy. Returns (before, after) triangle counts."""
    before = tri_count(obj.data)
    obj.data = obj.data.copy()
    obj.modifiers.clear()
    _select_only(obj)
    # Pre-collapse: planar dissolve is near-quadratic on 820k faces (>10 min).
    # A gentle collapse first (fast, uniform grid) keeps the shape and makes dissolve quick.
    pre = obj.modifiers.new('pre_collapse', 'DECIMATE')
    pre.decimate_type = 'COLLAPSE'
    pre.ratio = min(1.0, PRE_COLLAPSE_TRIS / max(1, before))
    pre.use_collapse_triangulate = True
    _apply(obj, pre)
    log('Roof pre-collapse', before, '->', tri_count(obj.data))
    dis = obj.modifiers.new('planar', 'DECIMATE')
    dis.decimate_type = 'DISSOLVE'
    dis.angle_limit = PLANAR_ANGLE
    dis.delimit = {'NORMAL'}
    _apply(obj, dis)
    tri = obj.modifiers.new('tri', 'TRIANGULATE')
    tri.quad_method = 'BEAUTY'
    tri.ngon_method = 'BEAUTY'
    _apply(obj, tri)
    mid = tri_count(obj.data)
    log('Roof planar dissolve', before, '->', mid)
    if mid > target:
        col = obj.modifiers.new('collapse', 'DECIMATE')
        col.decimate_type = 'COLLAPSE'
        col.ratio = target / mid
        col.use_collapse_triangulate = True
        _apply(obj, col)
    bpy.ops.object.shade_smooth_by_angle(angle=SMOOTH_ANGLE)
    for m in list(obj.modifiers):
        _apply(obj, m)
    obj.data.name = 'SM_E9_StoneRoofFrame'
    after = tri_count(obj.data)
    log('Roof', obj.name, 'tris', before, '->', after)
    return before, after


def optimize_roof(objects, log=print):
    roofs = [o for o in objects if o.type == 'MESH' and o.name.startswith(ROOF_PREFIX)]
    return [dict(zip(('tris_before', 'tris_after'), build_game_roof(o, log=log)), name=o.name) for o in roofs]
