import json

with open("3d models/zombie/pistol_animation_wip__really_stiff.glb", "rb") as f:
    header = f.read(12)
    chunk0_header = f.read(8)
    json_length = int.from_bytes(chunk0_header[:4], 'little')
    json_bytes = f.read(json_length)
    gltf = json.loads(json_bytes.decode('utf-8'))

print("Nodes count:", len(gltf.get('nodes', [])))
print("Meshes count:", len(gltf.get('meshes', [])))
print("Skins count:", len(gltf.get('skins', [])))
print("Animations count:", len(gltf.get('animations', [])))
for i, anim in enumerate(gltf.get('animations', [])):
    print(f"  Anim {i}: {anim.get('name')}")

for i, mesh in enumerate(gltf.get('meshes', [])):
    print(f"  Mesh {i}: {mesh.get('name')}")

for i, skin in enumerate(gltf.get('skins', [])):
    print(f"  Skin {i}: {skin.get('name')} joints={len(skin.get('joints', []))}")
