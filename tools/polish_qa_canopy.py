"""Read source crown topology and authored normals; never modify campus GLB."""
import json
import math
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
data = (ROOT / "assets" / "campus.glb").read_bytes()
json_length, _ = struct.unpack_from("<II", data, 12)
doc = json.loads(data[20:20 + json_length])
binary_start = 20 + json_length + 8


def accessor(index):
    value = doc["accessors"][index]
    view = doc["bufferViews"][value["bufferView"]]
    code = {5123: "H", 5125: "I", 5126: "f"}[value["componentType"]]
    components = {"SCALAR": 1, "VEC3": 3}[value["type"]]
    fmt = "<" + code * components
    step = view.get("byteStride", struct.calcsize(fmt))
    start = binary_start + view.get("byteOffset", 0) + value.get("byteOffset", 0)
    return [struct.unpack_from(fmt, data, start + i * step) for i in range(value["count"])]


reports = []
for node in doc["nodes"]:
    if not node.get("name", "").startswith("Campus plaza shade tree"):
        continue
    mesh = doc["meshes"][node["mesh"]]
    for primitive in mesh["primitives"]:
        material = doc["materials"][primitive["material"]].get("name", "")
        if "Leaf" not in material:
            continue
        vertices = accessor(primitive["attributes"]["POSITION"])
        normals = accessor(primitive["attributes"]["NORMAL"])
        indices = [v[0] for v in accessor(primitive["indices"])]
        neighbors = [set() for _ in vertices]
        for i in range(0, len(indices), 3):
            triangle = indices[i:i+3]
            for index in triangle:
                neighbors[index].update(triangle)
        remaining = set(range(len(vertices)))
        components = []
        while remaining:
            todo = [remaining.pop()]
            component = set(todo)
            while todo:
                for neighbor in neighbors[todo.pop()]:
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        component.add(neighbor)
                        todo.append(neighbor)
            components.append(component)
        dots = []
        for component in components:
            center = [sum(vertices[i][axis] for i in component) / len(component) for axis in range(3)]
            for i in component:
                radial = [vertices[i][a] - center[a] for a in range(3)]
                length = math.sqrt(sum(v*v for v in radial))
                normal_length = math.sqrt(sum(v*v for v in normals[i]))
                dots.append(sum(radial[a] * normals[i][a] for a in range(3)) / max(1e-10, length * normal_length))
        reports.append({"node": node["name"], "material": material, "vertices": len(vertices),
                        "triangles": len(indices) // 3, "lobe_vertices": [len(v) for v in components],
                        "normal_radial_dot_min": min(dots), "normal_radial_dot_mean": sum(dots)/len(dots)})
    break
result = {"source": "assets/campus.glb", "note": "One representative source tree; source normals are already smooth if radial dot is near 1.", "surfaces": reports}
(ROOT / "tools" / "polish_qa_canopy.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
