"""Export the approved Blender interior as a delta against the campus source.

Blender: --background --python-exit-code 1 --python this_file -- ORIGINAL APPROVED OUTPUT_DIR
"""

import hashlib
import json
import math
import struct
import sys
import zlib
from pathlib import Path

import bpy
import numpy as np


def interior_objects():
    return {
        obj.name: obj for obj in bpy.context.scene.objects
        if obj.type in {"MESH", "FONT"}
        and any(col.name.startswith(("B -", "B10")) for col in obj.users_collection)
        and not obj.hide_render and not obj.hide_get()
    }


def signature(obj):
    mesh = obj.data
    coords = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    indices = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.vertices.foreach_get("co", coords)
    mesh.loops.foreach_get("vertex_index", indices)
    return (
        tuple(tuple(row) for row in obj.matrix_world),
        hashlib.sha256(coords.tobytes() + indices.tobytes()).digest(),
        tuple(material.name if material else "" for material in mesh.materials),
    )


def role(name, original_roles):
    label = name.lower()
    if any(word in label for word in ("continuous finish", "continuous outward stair", "continuous return stair")):
        return "walkable"
    if any(word in label for word in ("partition", "lift white core", "lift brushed sliding door",
                                      "solid stair parapet", "planter edge", "observation glazing")):
        return "architecture"
    if name.startswith("B10"):
        return "detail"
    return original_roles.get(name, "detail")


def texture(path, kind):
    rng = np.random.default_rng(234)
    size = 256
    grain = rng.normal(0, 1, (size, size))
    if kind == "floor":
        base = np.array([181, 176, 160]) + grain[:, :, None] * 13
        base[[0, -1], :] = [122, 119, 106]
        base[:, [0, -1]] = [122, 119, 106]
    elif kind == "wood":
        grain = grain * .25 + rng.normal(0, 1, (size, 1)) * .75
        base = np.array([173, 116, 67]) + grain[:, :, None] * 9
    else:
        base = np.array([191, 181, 158]) + grain[:, :, None] * 11
    rows = np.clip(base, 0, 255).astype(np.uint8)

    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"".join(b"\0" + row.tobytes() for row in rows), 9))
        + chunk(b"IEND", b"")
    )
    return bpy.data.images.load(str(path))


def mapped_kind(material):
    return {
        "B10 diagonal 60cm terrazzo": "floor",
        "B10 warm plywood grain": "wood",
        "B10 honed limestone coping": "stone",
    }.get(material.name)


def add_uv(obj):
    mesh = obj.data
    # Godot 4.3 reads base color from the primary UV set.
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    uv = mesh.uv_layers.new(name="InteriorFinish")
    mesh.uv_layers.active = uv
    uv.active_render = True
    coords = [obj.matrix_world @ v.co for v in mesh.vertices]
    for face in mesh.polygons:
        material = mesh.materials[face.material_index] if mesh.materials else None
        kind = mapped_kind(material) if material else None
        for index in face.loop_indices:
            vertex_index = mesh.loops[index].vertex_index
            x, y, z = coords[vertex_index]
            if kind == "floor" and abs(face.normal.z) > .5:
                point = ((x + y) / (.6 * math.sqrt(2)), (x - y) / (.6 * math.sqrt(2)))
            elif kind == "wood":
                local = mesh.vertices[vertex_index].co
                point = (local.x * .6, (local.y + local.z) * 2)
            else:
                point = (x * 2, (y + z) * 2)
            uv.data[index].uv = point


def export(original, approved, output):
    output.mkdir(parents=True, exist_ok=True)
    manifest = Path(__file__).resolve().parents[1] / "assets/asset-manifest.json"
    original_roles = {item["name"]: item["role"] for item in json.loads(manifest.read_text(encoding="utf-8"))["nodes"]}
    bpy.ops.wm.open_mainfile(filepath=str(original))
    baseline = {name: signature(obj) for name, obj in interior_objects().items() if obj.type == "MESH"}

    bpy.ops.wm.open_mainfile(filepath=str(approved))
    current = interior_objects()
    changed = [obj for name, obj in current.items() if name not in baseline or signature(obj) != baseline[name]]
    removed = set(baseline) - set(current)
    replaced = removed | {obj.name for obj in changed if obj.name in baseline}
    bpy.ops.object.select_all(action="DESELECT")
    for obj in changed:
        obj.select_set(True)
        obj["campus_source_name"] = obj.name
        obj["campus_role"] = role(obj.name, original_roles)
        if obj.type == "MESH" and any(mapped_kind(m) for m in obj.data.materials if m):
            # Each tiled finish gets UVs in world coordinates, aligned across joins.
            obj.data = obj.data.copy()
            add_uv(obj)

    materials = {m for obj in changed for m in obj.data.materials if m}
    for material in materials:
        kind = mapped_kind(material)
        if not material.use_nodes:
            continue
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        for link in list(bsdf.inputs["Base Color"].links):
            links.remove(link)
            bsdf.inputs["Base Color"].default_value = material.diffuse_color
        for link in list(bsdf.inputs["Normal"].links):
            links.remove(link)
        if kind:
            image_node = nodes.new("ShaderNodeTexImage")
            image_node.image = texture(output / f"{kind}.png", kind)
            uv = nodes.new("ShaderNodeUVMap")
            uv.uv_map = "InteriorFinish"
            links.new(uv.outputs["UV"], image_node.inputs["Vector"])
            links.new(image_node.outputs["Color"], bsdf.inputs["Base Color"])
        if bsdf.inputs["Transmission Weight"].default_value > .2:
            bsdf.inputs["Transmission Weight"].default_value = 0
            bsdf.inputs["Alpha"].default_value = .3
            material.surface_render_method = "BLENDED"

    node_roles = {o.name: o["campus_role"] for o in changed}
    lights = []
    for obj in bpy.context.scene.objects:
        if obj.name.startswith(("B10 hall warm fixture", "Classroom LED ceiling panel")):
            x, y, z = obj.matrix_world.translation
            lights.append({"position": [x, z - .12, -y], "energy": .34 if obj.type == "LIGHT" else .25})
    for index, obj in enumerate(changed):
        obj.name = f"TeachingInterior{index:04d}"
    bpy.ops.export_scene.gltf(
        filepath=str(output / "teaching_interior.glb"), use_selection=True,
        export_extras=True, export_apply=True, export_animations=False, export_lights=False,
    )
    (output / "teaching_interior.json").write_text(
        json.dumps({"replaces": sorted(replaced), "nodes": node_roles, "lights": lights}, indent=2),
        encoding="utf-8",
    )
    print(f"Exported {len(changed)} interior nodes and {len(replaced)} replacements", flush=True)


if __name__ == "__main__":
    export(*(Path(arg).resolve() for arg in sys.argv[sys.argv.index("--") + 1:]))
