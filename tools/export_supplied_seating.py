"""Convert the supplied Blender 5.1 bench and bin into colored game assets.

Run with Blender 5.1 --background --python this_file -- WORKSPACE.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def material(name, color, roughness, metallic=0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return result


def realize_instances(obj):
    if not any(mod.type == "NODES" for mod in obj.modifiers):
        return
    group = bpy.data.node_groups.new("Export realized geometry", "GeometryNodeTree")
    group.interface.new_socket(name="Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    group.interface.new_socket(name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    source = group.nodes.new("NodeGroupInput")
    realize = group.nodes.new("GeometryNodeRealizeInstances")
    output = group.nodes.new("NodeGroupOutput")
    group.links.new(source.outputs["Geometry"], realize.inputs["Geometry"])
    group.links.new(realize.outputs["Geometry"], output.inputs["Geometry"])
    modifier = obj.modifiers.new("Realize for game export", "NODES")
    modifier.node_group = group


def convert(root, source_name, output_name, height):
    source = root / (source_name + ".blend")
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    scene = bpy.context.scene
    objects = [obj for obj in scene.objects if obj.type == "MESH" and obj.name != "Plan"]
    for obj in list(scene.objects):
        if obj not in objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in objects:
        realize_instances(obj)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    seen = set()
    exported = []
    for obj in objects:
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
        mesh.transform(obj.matrix_world)
        coordinates = tuple(tuple(vertex.co) for vertex in mesh.vertices)
        # The supplied bench contains one exactly duplicated back crossbar.
        signature = (coordinates, tuple(tuple(face.vertices) for face in mesh.polygons))
        if signature in seen:
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        seen.add(signature)
        obj.modifiers.clear()
        obj.data = mesh
        obj.matrix_world.identity()
        exported.append(obj)

    points = [vertex.co for obj in exported for vertex in obj.data.vertices]
    low = Vector([min(point[i] for point in points) for i in range(3)])
    high = Vector([max(point[i] for point in points) for i in range(3)])
    offset = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    scale = height / (high.z - low.z)
    wood = material("Supplied bench warm wood", (.43, .22, .075), .48)
    navy = material("Supplied bench navy frame", (.018, .045, .065), .38, .15)
    green = material("Supplied bin green body", (.025, .22, .12), .48, .12)
    charcoal = material("Supplied bin charcoal lid", (.035, .045, .047), .42, .18)
    steel = material("Supplied bin steel handle", (.32, .36, .37), .30, .65)
    for obj in exported:
        for vertex in obj.data.vertices:
            vertex.co = (vertex.co - offset) * scale
        if source_name == "chaise":
            finish = wood if obj.name in ["top", "cross bottom.003", "cross bottom.005"] else navy
        else:
            finish = steel if obj.name == "Cube.001" else charcoal if obj.name == "Cylindre.001" else green
        obj.data.materials.clear()
        obj.data.materials.append(finish)
        for face in obj.data.polygons:
            face.material_index = 0
        bevel = obj.modifiers.new("Manufactured edge highlights", "BEVEL")
        bevel.width = .002
        bevel.segments = 2
        obj.modifiers.new("Weighted surface normals", "WEIGHTED_NORMAL")

    output = root / "ensaf-campus-v4-project/ENSA-Fes-Campus-v4/campus-game/assets/user_models"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in exported:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(output / (output_name + ".glb")), use_selection=True,
        export_apply=True, export_animations=False,
    )
    review = root / "output/user-chair-bin"
    bpy.ops.wm.save_as_mainfile(filepath=str(review / (output_name + "-colored.blend")), compress=True)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    for obj in exported:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    record = {
        "source": str(source), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output": str(output / (output_name + ".glb")), "triangles": triangles,
        "dimensions_meters": list((high - low) * scale), "removed_duplicate_parts": len(objects) - len(exported),
    }
    # Neutral studio review of the actual evaluated model.
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 800
    scene.render.resolution_y = 600
    scene.render.resolution_percentage = 100
    scene.world.use_nodes = True
    scene.world.node_tree.nodes.get("Background").inputs[0].default_value = (.42, .42, .42, 1)
    scene.world.node_tree.nodes.get("Background").inputs[1].default_value = .7
    bpy.ops.object.light_add(type="AREA", location=(1, -2, 3))
    lamp = bpy.context.object
    lamp.data.energy = 350
    lamp.data.shape = "DISK"
    lamp.data.size = 3
    lamp.rotation_euler = (Vector((0, 0, .4)) - lamp.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(1.8, -2.5, 1.65))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, .45)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.4 if source_name == "chaise" else 1.6
    scene.camera = camera
    scene.render.filepath = str(review / (output_name + "-preview.png"))
    bpy.ops.render.render(write_still=True)
    return record


if __name__ == "__main__":
    workspace = Path(sys.argv[sys.argv.index("--") + 1])
    records = [convert(workspace, "chaise", "supplied_bench", .9),
               convert(workspace, "poubelle", "supplied_bin", .9)]
    (workspace / "output/user-chair-bin/export-report.json").write_text(json.dumps(records, indent=2))
    print("SUPPLIED_MODELS_EXPORTED", json.dumps(records), flush=True)
