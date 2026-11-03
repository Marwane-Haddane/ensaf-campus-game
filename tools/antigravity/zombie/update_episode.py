import json

path = "design/antigravity/zombie/episode_01.json"
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

# Check if screamer already in spawns
existing_ids = [s["id"] for s in data["enemy_spawns"]]
if "screamer_auditorium_1" not in existing_ids:
    new_spawns = [
        {
            "id": "screamer_auditorium_1",
            "type": "screamer",
            "position": [-43.0, 1.5, -116.0],
            "patrol_points": [[-43.0, 1.5, -116.0], [-40.0, 1.5, -112.0]]
        },
        {
            "id": "stalker_colonnade_1",
            "type": "stalker",
            "position": [-16.0, 2.1, -99.0],
            "patrol_points": [[-16.0, 2.1, -99.0], [-11.0, 2.4, -101.0]]
        }
    ]
    # Insert before the brute_boss (last element)
    data["enemy_spawns"] = data["enemy_spawns"][:-1] + new_spawns + [data["enemy_spawns"][-1]]
    print("Added screamer and stalker to enemy_spawns")

# Update vehicle prop to armored pickup
for prop in data.get("props", []):
    if "Vehicle_Pickup.tscn" in prop.get("scene", ""):
        prop["scene"] = "res://assets/antigravity/zombie/props/Vehicle_Pickup_Armored.tscn"
        print("Updated extraction vehicle to Vehicle_Pickup_Armored.tscn")

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)

print("Saved updated episode_01.json successfully")
