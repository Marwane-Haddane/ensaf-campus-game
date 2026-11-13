"""Inspect the four user-provided GLBs without changing the originals."""
import json
import hashlib
import math
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = {
    "chair": "office_chair.glb",
    "desk": "office_desk_140x60.glb",
    "server_rack": "server_rack.glb",
    "server_rack_1": "server_rack (1).glb",
}


def matrix_multiply(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def transform(node):
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    s = node.get("scale", [1, 1, 1])
    t = node.get("translation", [0, 0, 0])
    r = [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
         [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
         [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]
    return [[r[i][j] * s[j] for j in range(3)] + [t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def inspect(filename):
    path = ROOT / "3D-modeling" / "3d models" / "cyber" / filename
    data = path.read_bytes()
    length, tag = struct.unpack_from("<II", data, 12)
    doc = json.loads(data[20:20+length])
    result = {
        "original": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "asset": doc.get("asset"),
        "extras": doc.get("extras"), "extensions_used": doc.get("extensionsUsed", []),
        "materials": doc.get("materials", []), "images": doc.get("images", []),
        "textures": doc.get("textures", []), "meshes": [],
    }
    identity = [[float(r == c) for c in range(4)] for r in range(4)]
    low = [math.inf] * 3
    high = [-math.inf] * 3

    def visit(index, parent):
        node = doc["nodes"][index]
        matrix = matrix_multiply(parent, transform(node))
        if "mesh" in node:
            mesh = doc["meshes"][node["mesh"]]
            mesh_low = [math.inf] * 3
            mesh_high = [-math.inf] * 3
            vertices = 0
            for primitive in mesh["primitives"]:
                accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
                vertices += accessor["count"]
                for bits in range(8):
                    p = [accessor["max" if bits & (1 << axis) else "min"][axis] for axis in range(3)] + [1]
                    q = [sum(matrix[r][c] * p[c] for c in range(4)) for r in range(3)]
                    for axis in range(3):
                        low[axis] = min(low[axis], q[axis])
                        high[axis] = max(high[axis], q[axis])
                        mesh_low[axis] = min(mesh_low[axis], q[axis])
                        mesh_high[axis] = max(mesh_high[axis], q[axis])
            result["meshes"].append({"node": node.get("name", str(index)), "mesh": mesh.get("name"),
                                     "min": mesh_low, "max": mesh_high, "vertices": vertices})
        for child in node.get("children", []):
            visit(child, matrix)

    scene = doc["scenes"][doc.get("scene", 0)]
    for index in scene.get("nodes", []):
        visit(index, identity)
    result["source_bounds"] = {"min": low, "max": high, "size": [high[i]-low[i] for i in range(3)]}
    result["nodes"] = doc["nodes"]
    return result


if __name__ == "__main__":
    output = {kind: inspect(filename) for kind, filename in SOURCES.items()}
    target = pathlib.Path(__file__).with_name("furniture_sources.json")
    target.write_text(json.dumps(output, indent=2), encoding="utf-8")
    copies = {"chair": "office_chair.glb", "desk": "office_desk_140x60.glb",
              "server_rack": "server_rack.glb", "server_rack_1": "server_rack_1.glb"}
    dimensions = json.loads(target.with_name("furniture_dimensions.json").read_text(encoding="utf-8"))
    manifest = {"api": "FurnitureProps.place(parent: Node3D, kind: String, position: Vector3, yaw: float = 0.0) -> Node3D",
                "placement": "parent-local floor centre; yaw in radians; front +Z at yaw 0",
                "models": {}}
    for kind, record in output.items():
        copy = ROOT / "campus-game" / "assets" / "user_models" / copies[kind]
        assert hashlib.sha256(copy.read_bytes()).hexdigest() == record["sha256"], "Approved copy must match original"
        manifest["models"][kind] = {"path": "res://assets/user_models/" + copies[kind],
                                    "source_sha256": record["sha256"], "original_unchanged": True,
                                    "credit": record["asset"]["extras"], "measurements": dimensions[kind],
                                    "front_correction_degrees": 180 if kind == "server_rack" else 0,
                                    "previews": ["tools/furniture_" + kind + "_" + view + ".png" for view in ("front", "rear")]}
    target.with_name("furniture_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    for kind, record in output.items():
        print(kind, json.dumps({"asset": record["asset"], "bounds": record["source_bounds"],
                                "meshes": len(record["meshes"]), "images": len(record["images"])}))
