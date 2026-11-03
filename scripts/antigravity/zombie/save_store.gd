extends RefCounted
## Independent Checkpoint and Save Store for Zombie RPG (Mission ZB-2026-001)
## Stored strictly under user://ensagames/saves/zombie_rpg/ without touching Incident Response saves.

var path: String = "user://ensagames/saves/zombie_rpg/checkpoint.json"
var last_error: String = ""

const SCHEMA_VERSION: int = 1
const MODE_ID: String = "zombie_rpg"
const MISSION_ID: String = "ZB-2026-001"

func _init(custom_path: String = "") -> void:
	if not custom_path.is_empty():
		path = custom_path
	_ensure_directory()

func _ensure_directory() -> void:
	var dir_path := path.get_base_dir()
	if not dir_path.is_empty():
		var global_dir := ProjectSettings.globalize_path(dir_path)
		if not DirAccess.dir_exists_absolute(global_dir):
			var err := DirAccess.make_dir_recursive_absolute(global_dir)
			if err != OK:
				push_warning("Failed to create save directory: " + global_dir)

func has_save() -> bool:
	return FileAccess.file_exists(path)

func validate(payload: Dictionary) -> bool:
	last_error = ""
	if payload.is_empty():
		last_error = "Checkpoint payload is empty"
		return false
	
	if int(payload.get("schema_version", 0)) != SCHEMA_VERSION:
		last_error = "Incompatible schema version: %s (expected %d)" % [str(payload.get("schema_version")), SCHEMA_VERSION]
		return false
	
	if str(payload.get("mode_id", "")) != MODE_ID:
		last_error = "Mismatched mode_id in checkpoint: %s (expected %s)" % [str(payload.get("mode_id")), MODE_ID]
		return false
	
	if str(payload.get("mission_id", "")) != MISSION_ID:
		last_error = "Mismatched mission_id in checkpoint: %s (expected %s)" % [str(payload.get("mission_id")), MISSION_ID]
		return false
	
	# Verify root checkpoint metadata
	if not payload.get("checkpoint_id") is String or str(payload.get("checkpoint_id")).is_empty():
		last_error = "Missing or invalid checkpoint_id"
		return false
	
	if not payload.get("checkpoint_name") is String:
		last_error = "Missing or invalid checkpoint_name"
		return false
	
	# Verify nested structures
	if not payload.get("player_state") is Dictionary:
		last_error = "player_state must be a Dictionary"
		return false
	
	if not payload.get("objectives") is Dictionary:
		last_error = "objectives must be a Dictionary"
		return false
	
	if not payload.get("inventory") is Dictionary:
		last_error = "inventory must be a Dictionary"
		return false
	
	if not payload.get("defeated_enemies") is Array:
		last_error = "defeated_enemies must be an Array"
		return false
	for e in payload["defeated_enemies"]:
		if not e is String:
			last_error = "defeated_enemies entries must be strings"
			return false
	
	if not payload.get("collected_pickups") is Array:
		last_error = "collected_pickups must be an Array"
		return false
	for p in payload["collected_pickups"]:
		if not p is String:
			last_error = "collected_pickups entries must be strings"
			return false
	
	# 1. Validate player_state
	var p_state: Dictionary = payload["player_state"]
	for k in ["health", "max_health", "stamina", "max_stamina"]:
		var val = p_state.get(k)
		if not (val is int or val is float) or not is_finite(float(val)):
			last_error = "player_state.%s must be a finite number" % k
			return false
	
	var max_hp := float(p_state["max_health"])
	var hp := float(p_state["health"])
	if max_hp < 1.0 or max_hp > 1000.0 or hp < 0.0 or hp > max_hp:
		last_error = "player_state health (%.1f / %.1f) is out of valid range" % [hp, max_hp]
		return false
	
	var max_stam := float(p_state["max_stamina"])
	var stam := float(p_state["stamina"])
	if max_stam < 1.0 or max_stam > 1000.0 or stam < 0.0 or stam > max_stam:
		last_error = "player_state stamina (%.1f / %.1f) is out of valid range" % [stam, max_stam]
		return false
	
	if p_state.has("position"):
		var pos = p_state["position"]
		if not pos is Array or pos.size() != 3:
			last_error = "player_state.position must be a 3-element Array"
			return false
		for coord in pos:
			if not (coord is int or coord is float) or not is_finite(float(coord)) or absf(float(coord)) > 10000.0:
				last_error = "player_state.position contains invalid coordinate"
				return false
	
	if p_state.has("rotation_y"):
		var ry = p_state["rotation_y"]
		if not (ry is int or ry is float) or not is_finite(float(ry)):
			last_error = "player_state.rotation_y must be finite"
			return false
	
	if p_state.has("camera_pitch"):
		var cp = p_state["camera_pitch"]
		if not (cp is int or cp is float) or not is_finite(float(cp)):
			last_error = "player_state.camera_pitch must be finite"
			return false
	
	# 2. Validate inventory
	var inv: Dictionary = payload["inventory"]
	if inv.has("items"):
		if not inv["items"] is Dictionary:
			last_error = "inventory.items must be a Dictionary"
			return false
		for item_key in inv["items"]:
			var count = inv["items"][item_key]
			if not (count is int or count is float) or not is_finite(float(count)) or int(count) < 0:
				last_error = "inventory item count for %s must be a non-negative integer" % str(item_key)
				return false
	
	if inv.has("upgrades"):
		if not inv["upgrades"] is Array:
			last_error = "inventory.upgrades must be an Array"
			return false
		for u in inv["upgrades"]:
			if not u is String:
				last_error = "inventory.upgrades entry must be a String"
				return false
	
	if inv.has("weapon_slots"):
		if not inv["weapon_slots"] is Array:
			last_error = "inventory.weapon_slots must be an Array"
			return false
		for slot in inv["weapon_slots"]:
			if not slot is Dictionary or not slot.has("id") or not slot.has("unlocked"):
				last_error = "inventory.weapon_slots entries must contain id and unlocked"
				return false
	
	if inv.has("active_slot_index"):
		var idx = inv["active_slot_index"]
		if not (idx is int or idx is float) or int(idx) < 0:
			last_error = "inventory.active_slot_index must be a non-negative integer"
			return false
	
	# 3. Validate objectives
	var objs: Dictionary = payload["objectives"]
	if objs.has("current_step_index"):
		var step_idx = objs["current_step_index"]
		if not (step_idx is int or step_idx is float) or int(step_idx) < 0 or int(step_idx) > 20:
			last_error = "objectives.current_step_index out of valid range"
			return false
	
	if objs.has("completed_steps"):
		if not objs["completed_steps"] is Array:
			last_error = "objectives.completed_steps must be an Array"
			return false
		for step in objs["completed_steps"]:
			if not step is String:
				last_error = "objectives.completed_steps entries must be strings"
				return false
	
	if objs.has("collected_quest_items"):
		if not objs["collected_quest_items"] is Array:
			last_error = "objectives.collected_quest_items must be an Array"
			return false
		for item in objs["collected_quest_items"]:
			if not item is String:
				last_error = "objectives.collected_quest_items entries must be strings"
				return false
	
	for flag in ["power_restored", "survivor_talked", "boss_killed", "extracted"]:
		if objs.has(flag) and not objs[flag] is bool:
			last_error = "objectives.%s must be a boolean" % flag
			return false
	
	return true

func read_save() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Save file does not exist at path: " + path
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Failed to open save file for reading: " + str(FileAccess.get_open_error())
		return {}
	
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		last_error = "Corrupted save file: parse error at line " + str(json.get_error_line())
		return {}
	
	var data: Variant = json.data
	if not data is Dictionary:
		last_error = "Malformed save file: root is not a Dictionary"
		return {}
	
	if not validate(data):
		return {}
	
	return data

func write_save(payload: Dictionary) -> bool:
	last_error = ""
	_ensure_directory()
	
	# Enrich with schema and mode metadata if not explicitly provided
	var save_data := payload.duplicate(true)
	save_data["schema_version"] = save_data.get("schema_version", SCHEMA_VERSION)
	save_data["mode_id"] = save_data.get("mode_id", MODE_ID)
	save_data["mission_id"] = save_data.get("mission_id", MISSION_ID)
	if not save_data.has("checkpoint_id"):
		save_data["checkpoint_id"] = "cp_start"
	if not save_data.has("checkpoint_name"):
		save_data["checkpoint_name"] = "Campus Plaza Arrival"
	if not save_data.has("timestamp"):
		save_data["timestamp"] = Time.get_datetime_string_from_system()
	if not save_data.has("defeated_enemies"):
		save_data["defeated_enemies"] = []
	if not save_data.has("collected_pickups"):
		save_data["collected_pickups"] = []
	if save_data.has("player_state") and save_data["player_state"] is Dictionary:
		var ps: Dictionary = save_data["player_state"]
		if not ps.has("stamina"): ps["stamina"] = 100.0
		if not ps.has("max_stamina"): ps["max_stamina"] = 100.0
	
	if not validate(save_data):
		return false
	
	var json_str := JSON.stringify(save_data, "  ")
	
	var tmp_path := path + ".tmp"
	var bak_path := path + ".bak"
	
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open temporary save file: " + str(FileAccess.get_open_error())
		return false
	
	file.store_string(json_str)
	file.flush()
	var write_err := file.get_error()
	file.close()
	
	if write_err != OK:
		last_error = "Failed to write temporary save file: " + str(write_err)
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return false
	
	# Atomic commit: preserve last valid file if commit fails
	var global_path := ProjectSettings.globalize_path(path)
	var global_tmp := ProjectSettings.globalize_path(tmp_path)
	var global_bak := ProjectSettings.globalize_path(bak_path)
	
	var had_existing := FileAccess.file_exists(path)
	if had_existing:
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(global_bak)
		var bak_err := DirAccess.rename_absolute(global_path, global_bak)
		if bak_err != OK:
			last_error = "Failed to create backup during commit: " + str(bak_err)
			DirAccess.remove_absolute(global_tmp)
			return false
	
	var ren_err := DirAccess.rename_absolute(global_tmp, global_path)
	if ren_err != OK:
		last_error = "Failed to commit save file: " + str(ren_err)
		# Restore original file from backup
		if had_existing and FileAccess.file_exists(bak_path):
			DirAccess.rename_absolute(global_bak, global_path)
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(global_tmp)
		return false
	
	# Commit successful; remove backup
	if had_existing and FileAccess.file_exists(bak_path):
		DirAccess.remove_absolute(global_bak)
	
	return true

func delete_save() -> bool:
	last_error = ""
	var global_path := ProjectSettings.globalize_path(path)
	var global_tmp := ProjectSettings.globalize_path(path + ".tmp")
	var global_bak := ProjectSettings.globalize_path(path + ".bak")
	
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(global_path)
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(global_tmp)
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(global_bak)
	return true

func summary(payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return {}
	var p_state: Dictionary = payload.get("player_state", {})
	var objs: Dictionary = payload.get("objectives", {})
	var cp_name: String = payload.get("checkpoint_name", "Checkpoint")
	var scrap_val: int = int(payload.get("inventory", {}).get("items", {}).get("scrap", p_state.get("scrap", 0)))
	return {
		"valid": true,
		"label": "After Hours · " + cp_name,
		"mode_id": payload.get("mode_id", MODE_ID),
		"mission_id": payload.get("mission_id", MISSION_ID),
		"checkpoint_id": payload.get("checkpoint_id", "cp_start"),
		"checkpoint_name": cp_name,
		"health": float(p_state.get("health", 100.0)),
		"max_health": float(p_state.get("max_health", 100.0)),
		"scrap": scrap_val,
		"current_objective": objs.get("current_id", "obj_explore"),
		"timestamp": payload.get("timestamp", "")
	}

func capture(game: Node3D) -> Dictionary:
	if game == null or not is_instance_valid(game):
		return {}
	
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"mode_id": MODE_ID,
		"mission_id": MISSION_ID,
		"checkpoint_id": str(game.get("current_checkpoint_id")),
		"checkpoint_name": str(game.get("current_checkpoint_name")),
		"timestamp": Time.get_datetime_string_from_system(),
		"player_state": {},
		"objectives": {},
		"inventory": {},
		"defeated_enemies": [],
		"collected_pickups": []
	}
	
	var player = game.get("player")
	if player and is_instance_valid(player):
		payload["player_state"] = player.call("capture_state")
	
	var mission = game.get("mission_state")
	if mission and is_instance_valid(mission):
		payload["objectives"] = mission.call("capture_state")
	
	var inventory = game.get("inventory")
	if inventory and is_instance_valid(inventory):
		payload["inventory"] = inventory.call("capture_state")
	
	var def_e = game.get("defeated_enemies")
	payload["defeated_enemies"] = Array(def_e) if def_e != null else []
	
	var col_p = game.get("collected_pickups")
	payload["collected_pickups"] = Array(col_p) if col_p != null else []
	
	return payload

func restore(game: Node3D, checkpoint: Dictionary) -> bool:
	if game == null or not is_instance_valid(game) or checkpoint.is_empty():
		last_error = "Cannot restore to null game or from empty checkpoint"
		return false
	
	if not validate(checkpoint):
		return false
	
	game.set("current_checkpoint_id", checkpoint.get("checkpoint_id", "cp_start"))
	game.set("current_checkpoint_name", checkpoint.get("checkpoint_name", "Campus Plaza Arrival"))
	game.set("defeated_enemies", Array(checkpoint.get("defeated_enemies", [])))
	game.set("collected_pickups", Array(checkpoint.get("collected_pickups", [])))
	
	var player = game.get("player")
	if player and is_instance_valid(player) and checkpoint.has("player_state"):
		player.call("restore_state", checkpoint["player_state"])
	
	var inventory = game.get("inventory")
	if inventory and is_instance_valid(inventory) and checkpoint.has("inventory"):
		inventory.call("restore_state", checkpoint["inventory"])
	
	var mission = game.get("mission_state")
	if mission and is_instance_valid(mission) and checkpoint.has("objectives"):
		mission.call("restore_state", checkpoint["objectives"])
	
	return true
