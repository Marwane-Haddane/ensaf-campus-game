extends RefCounted
## After Hours difficulty presets. Saved as `zombie_difficulty` with the other
## launcher preferences (user://ensagames/preferences.cfg).

const DEFAULT := "medium"
const IDS := ["easy", "medium", "hard"]
const PREFERENCES_PATH := "user://ensagames/preferences.cfg"

const PRESETS := {
	"easy": {
		"title": "Easy",
		"enemy_health": 0.7, "enemy_damage": 0.6, "enemy_speed": 0.88,
		"enemy_detection": 0.85, "attack_cooldown": 1.25, "enemy_memory": 0.8,
		"wave_count": 0.6, "spawn_tier": 0,
		"ammo_drop_chance": 0.55, "medkit_drop_chance": 0.14,
		"bonus_medkits": 1, "bonus_reserve": 24, "boss_adds": 1,
	},
	"medium": {
		"title": "Medium",
		"enemy_health": 1.0, "enemy_damage": 1.0, "enemy_speed": 1.0,
		"enemy_detection": 1.0, "attack_cooldown": 1.0, "enemy_memory": 1.0,
		"wave_count": 1.0, "spawn_tier": 1,
		"ammo_drop_chance": 0.35, "medkit_drop_chance": 0.07,
		"bonus_medkits": 0, "bonus_reserve": 0, "boss_adds": 2,
	},
	"hard": {
		"title": "Hard",
		"enemy_health": 1.35, "enemy_damage": 1.45, "enemy_speed": 1.12,
		"enemy_detection": 1.25, "attack_cooldown": 0.85, "enemy_memory": 1.6,
		"wave_count": 1.5, "spawn_tier": 2,
		"ammo_drop_chance": 0.2, "medkit_drop_chance": 0.03,
		"bonus_medkits": 0, "bonus_reserve": -12, "boss_adds": 4,
	},
}

static func normalize(id: Variant) -> String:
	var text := str(id).to_lower()
	return text if text in IDS else DEFAULT

## Difficulty from live preferences, falling back to the saved launcher file
## (standalone runs have no launcher dictionary).
static func requested(preferences: Dictionary = {}) -> String:
	if preferences.has("zombie_difficulty"):
		return normalize(preferences.zombie_difficulty)
	var config := ConfigFile.new()
	if config.load(PREFERENCES_PATH) == OK:
		return normalize(config.get_value("preferences", "zombie_difficulty", DEFAULT))
	return DEFAULT

static func settings(id: String) -> Dictionary:
	return PRESETS[normalize(id)]

static func title(id: String) -> String:
	return str(settings(id).title)

## Scales an integer count (wave size, boss adds) with a floor of one.
static func scaled_count(base: int, id: String) -> int:
	return maxi(1, int(round(float(base) * float(settings(id).wave_count))))

## Spawns tagged `min_difficulty` appear only at that tier or harder.
static func allows_spawn(spawn: Dictionary, id: String) -> bool:
	var needed := normalize(spawn.get("min_difficulty", "easy"))
	return IDS.find(needed) <= int(settings(id).spawn_tier)
