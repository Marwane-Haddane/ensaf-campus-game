"""Bake the supplied Classical_Fountain.blend into a light game GLB.

blender -b --disable-autoexec Classical_Fountain.blend --python tools/export_fountain.py -- OUT.glb
Realizes modifiers/curves/geometry nodes, joins into one stone mesh and one
water mesh, decimates (1.19M tris -> ~70k) and exports with flat PBR colors
(the source uses procedural noise shaders that glTF cannot carry).
"""
import sys
import bpy
import bmesh

out = sys.argv[sys.argv.index("--") + 1]
STONE_TARGET = 60000
WATER_TARGET = 14000

dg = bpy.context.evaluated_depsgraph_get()
stone_bm = bmesh.new()
water_bm = bmesh.new()
for obj in list(bpy.data.objects):
    if obj.type not in ("MESH", "CURVE") or obj.hide_render:
        continue
    ev = obj.evaluated_get(dg)
    try:
        mesh = bpy.data.meshes.new_from_object(ev, depsgraph=dg)
    except RuntimeError:
        continue
    if len(mesh.polygons) == 0:
        bpy.data.meshes.remove(mesh)
        continue
    mesh.transform(ev.matrix_world)
    names = [s.material.name if s.material else "" for s in obj.material_slots]
    # Split per polygon so mixed stone/water meshes land in the right bucket.
    tmp = bmesh.new()
    tmp.from_mesh(mesh)
    water_faces = [f for f in tmp.faces if f.material_index < len(names) and names[f.material_index].startswith("Water")]
    stone_faces = [f for f in tmp.faces if f not in set(water_faces)]
    for faces, target in ((water_faces, water_bm), (stone_faces, stone_bm)):
        if not faces:
            continue
        part = tmp.copy()
        keep = {f.index for f in faces}
        bmesh.ops.delete(part, geom=[f for f in part.faces if f.index not in keep], context="FACES")
        m2 = bpy.data.meshes.new("part")
        part.to_mesh(m2)
        target.from_mesh(m2)
        bpy.data.meshes.remove(m2)
        part.free()
    tmp.free()
    bpy.data.meshes.remove(mesh)

def material(name, color, rough, alpha=1.0, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Alpha"].default_value = alpha
    if alpha < 1:
        m.blend_method = "BLEND"
    return m

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
scene = bpy.context.scene

def finish(bm, name, mat, target):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    me.materials.append(mat)
    for p in me.polygons:
        p.material_index = 0
    obj = bpy.data.objects.new(name, me)
    scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    for o in scene.objects: o.select_set(o == obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0008)
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode="OBJECT")
    tris = len(me.polygons)
    if tris > target:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = target / tris
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in me.polygons: p.use_smooth = True
    print("FOUNTAIN_PART", name, tris, "->", len(obj.data.polygons))
    return obj

stone = finish(stone_bm, "Fountain_Stone", material("Fountain limestone", (0.60, 0.49, 0.36), 0.62), STONE_TARGET)
water = finish(water_bm, "Fountain_Water", material("Fountain water", (0.55, 0.72, 0.74), 0.05, alpha=0.55, metallic=0.1), WATER_TARGET)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True,
    export_normals=True, export_texcoords=False, export_cameras=False, export_lights=False,
    export_animations=False, export_draco_mesh_compression_enable=False)
print("FOUNTAIN_EXPORTED", out)
