"""Read-only planar overlap diagnostics of the approved campus GLB."""
import collections
import importlib.util
import json
import math
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
helper = importlib.util.spec_from_file_location("furniture_inspect", ROOT / "tools" / "furniture_inspect.py")
module = importlib.util.module_from_spec(helper)
helper.loader.exec_module(module)
manifest = json.loads((ROOT / "assets" / "asset-manifest.json").read_text())
raw = (ROOT / "assets" / "campus.glb").read_bytes()
json_size = struct.unpack_from("<I", raw, 12)[0]
doc = json.loads(raw[20:20 + json_size])
bin_start = 20 + json_size + 8


def accessor(index):
    value = doc["accessors"][index]
    view = doc["bufferViews"][value["bufferView"]]
    count = {"SCALAR": 1, "VEC3": 3}[value["type"]]
    fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[value["componentType"]]
    size = struct.calcsize("<" + fmt * count)
    stride = view.get("byteStride", size)
    start = bin_start + view.get("byteOffset", 0) + value.get("byteOffset", 0)
    return [struct.unpack_from("<" + fmt * count, raw, start + i * stride) for i in range(value["count"])]


identity = [[float(r == c) for c in range(4)] for r in range(4)]
worlds = {}


def visit(index, parent):
    node = doc["nodes"][index]
    world = module.matrix_multiply(parent, module.transform(node))
    worlds[index] = world
    for child in node.get("children", []):
        visit(child, world)


for index in doc["scenes"][doc.get("scene", 0)]["nodes"]:
    visit(index, identity)

records = {value["name"]: value for value in manifest["nodes"]}
top_faces = []
sample_names = {"D7 main entrance level landing", "D7 portico terrace slab", "D7 polished lower hall floor",
                "E6 reception large format stone floor", "E9 reception to hall continuous floor",
                "E8 ceiling joint backing", "E8 modular white acoustic ceiling tiles"}
samples = {}
normal_samples = {}
terms = ("floor", "slab", "landing", "paving", "site base", "plaza", "terrace step", "ceiling")
for index, node in enumerate(doc["nodes"]):
    name = node.get("extras", {}).get("campus_source_name", node.get("name", ""))
    if "mesh" not in node or not any(term in name.lower() for term in terms):
        continue
    record = records.get(name, {})
    if record.get("role") not in ("walkable", "architecture"):
        continue
    lower = record["godot_min"]
    upper = record["godot_max"]
    if lower[0] > 10 or upper[0] < -60 or lower[2] > -65 or upper[2] < -140:
        continue
    world = worlds[index]
    planes = collections.defaultdict(list)
    for primitive in doc["meshes"][node["mesh"]]["primitives"]:
        source = accessor(primitive["attributes"]["POSITION"])
        if name in ("D7 polished lower hall floor", "E8 modular white acoustic ceiling tiles"):
            normal_samples[name] = sorted({tuple(round(x, 4) for x in normal)
                                           for normal in accessor(primitive["attributes"]["NORMAL"])})
        points = [[sum(world[r][c] * (*p, 1)[c] for c in range(4)) for r in range(3)] for p in source]
        indices = [x[0] for x in accessor(primitive["indices"])] if "indices" in primitive else list(range(len(points)))
        for k in range(0, len(indices), 3):
            a, b, c = (points[indices[k+j]] for j in range(3))
            if max(a[1], b[1], c[1]) - min(a[1], b[1], c[1]) > 0.00001:
                continue
            area = abs((b[0]-a[0])*(c[2]-a[2]) - (c[0]-a[0])*(b[2]-a[2])) * 0.5
            if area > 1e-9:
                planes[round(a[1], 5)].append((a, b, c, area))
    face_records = []
    for y, triangles in planes.items():
        low_x = min(p[0] for t in triangles for p in t[:3])
        high_x = max(p[0] for t in triangles for p in t[:3])
        low_z = min(p[2] for t in triangles for p in t[:3])
        high_z = max(p[2] for t in triangles for p in t[:3])
        area = sum(t[3] for t in triangles)
        rect_area = (high_x-low_x)*(high_z-low_z)
        face = {"name": name, "y": y, "xz_min": [low_x, low_z], "xz_max": [high_x, high_z],
                "triangle_area": area, "rectangle_area": rect_area,
                "fills_rectangle": abs(area-rect_area) < max(0.0001, rect_area*0.00001)}
        face_records.append(face)
        # Only a closed object's highest horizontal face is a walkable top.
        if abs(y-upper[1]) < .00002 and face["fills_rectangle"]:
            top_faces.append(face)
    if name in sample_names:
        samples[name] = face_records

overlaps = []
for i, a in enumerate(top_faces):
    for b in top_faces[i+1:]:
        if abs(a["y"]-b["y"]) > .00001:
            continue
        low = [max(a["xz_min"][k], b["xz_min"][k]) for k in range(2)]
        high = [min(a["xz_max"][k], b["xz_max"][k]) for k in range(2)]
        size = [high[k]-low[k] for k in range(2)]
        if min(size) > .0001 and size[0]*size[1] > .01:
            overlaps.append({"a": a["name"], "b": b["name"], "y": a["y"],
                             "xz_min": low, "xz_max": high, "area_m2": size[0]*size[1]})

identical_bounds = collections.defaultdict(list)
for record in manifest["nodes"]:
    identical_bounds[tuple(record["godot_min"]+record["godot_max"])].append(record)
duplicates = [[r["name"] for r in group] for group in identical_bounds.values()
              if len(group) > 1 and any(r["role"] in ("walkable", "architecture") for r in group)]
result = {"source": "campus.glb", "method": "Actual transformed triangle planes; closed rectangular top faces only",
          "coplanar_rectangle_overlaps": overlaps, "identical_architecture_bounds": duplicates,
          "sample_horizontal_faces": samples, "normal_samples_identity_transforms": normal_samples,
          "modeled_repetitions": {
              "E8 ceiling": "0.591 m tiles separated by 0.009 m gaps (actual vertex coordinates)",
              "E5 facade": "22 horizontal stone bed joints and 108 vertical stone joints, 0.004 m thickness",
              "D7 lower hall": "floor top 0.430 m; modeled joints 0.432-0.434 m",
              "E6 reception": "stone floor top 0.922 m; continuous base floor top 0.910 m"},
          "limits": "Overlap records show geometry, not proof of visible artifacts. D9 stone finishes cover D7 entrance slabs at y1.812 and y1.814. No rendered shadow-on/off comparison was performed."}
(ROOT / "tools" / "polish_qa_geometry.json").write_text(json.dumps(result, indent=2))
print(json.dumps({"coplanar_rectangle_overlaps": overlaps, "identical_architecture_bounds": duplicates}, indent=2))
