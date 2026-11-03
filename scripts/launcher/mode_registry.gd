extends RefCounted
## Metadata only. Loading this registry must not load a scene or GLB.
const MODES := [
	{"id":"incident_response","title":"ENSA Incident Response","subtitle":"Cybersecurity training",
	"availability":"available","scene_path":"res://main.tscn","adapter_version":1,"adapter_path":"res://scripts/launcher/incident_mode_adapter.gd","mission_ids":["IR-2026-001"],
	"save_namespace":"incident_response","settings_namespace":"incident_response",
	"artwork_path":"res://assets/antigravity/launcher/mode_cyber.png",
	"description":"Investigate a compromised workstation. Preserve evidence, contain access and recover safely."},
	{"id":"zombie_rpg","title":"Zombie RPG","subtitle":"Survival · Exploration · RPG",
	"availability":"coming_soon","scene_path":"","adapter_version":1,
	"save_namespace":"zombie_rpg","settings_namespace":"zombie_rpg",
	"artwork_path":"res://assets/antigravity/launcher/mode_zombie.png",
	"description":"A future campus survival experience. Preview only — not playable yet."}]
const ASSETS: Array[String] = ["res://assets/campus.glb",
	"res://assets/user_models/gamer_setup_pack.glb", "res://assets/user_models/office_desk_140x60.glb",
	"res://assets/user_models/office_chair.glb", "res://assets/user_models/server_rack.glb",
	"res://assets/user_models/server_rack_1.glb", "res://main.tscn"]
const REGISTRATION_PATH := "res://design/extra_modes.json"
static func entries(registration_path: String = REGISTRATION_PATH) -> Array:
	var modes := MODES.duplicate(true)
	# A future mode registers metadata plus its own adapter; the shared launcher
	# never needs dependencies on its scene, models, combat or mission system.
	var path := registration_path
	if FileAccess.file_exists(path):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Array:
			for mode: Variant in parser.data:
				if not mode is Dictionary or str(mode.get("id","")).is_empty() or mode.get("availability","") not in ["available","coming_soon"]: continue
				var existing := -1
				for idx: int in range(modes.size()):
					if modes[idx].id == mode.id: existing = idx
				if existing>=0:
					# A future descriptor can replace its coming-soon placeholder,
					# but cannot silently replace an existing available game.
					if modes[existing].availability == "coming_soon": modes[existing].merge(mode,true)
				else: modes.append(mode)
	return modes
static func asset_paths() -> Array[String]:
	var paths: Array[String] = ASSETS.duplicate()
	var campus_manifest := "res://assets/runtime_campus/manifest.json"
	if FileAccess.file_exists(campus_manifest):
		var sections: Variant = JSON.parse_string(FileAccess.get_file_as_string(campus_manifest))
		if sections is Dictionary and sections.get("version",0)==1 and not sections.get("chunks",[]).is_empty():
			paths.erase("res://assets/campus.glb")
			for path: String in sections.chunks: paths.append(path)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime_surfaces/manifest.json"))
	if manifest is Dictionary:
		for path: String in manifest.get("textures",[]): paths.append(path)
	return paths
static func find_mode(id: String, registration_path: String = REGISTRATION_PATH) -> Dictionary:
	for mode: Dictionary in entries(registration_path):
		if mode.id == id: return mode.duplicate(true)
	return {}
static func default_mission(id: String, registration_path: String = REGISTRATION_PATH) -> String:
	var ids: Variant = find_mode(id,registration_path).get("mission_ids",[])
	return str(ids[0]) if ids is Array and not ids.is_empty() else ""
static func can_launch(id: String, mission: String, registration_path: String = REGISTRATION_PATH) -> bool:
	var mode := find_mode(id,registration_path)
	return mode.get("availability","") == "available" and mission in mode.get("mission_ids",[]) and not str(mode.get("scene_path","")).is_empty() and not mission_for(id,mission,registration_path).is_empty()
static func mission() -> Dictionary:
	return {"id":"IR-2026-001","title":"The borrowed session","objective":"Find the marked workstation",
	"briefing":"A borrowed session is still active on a campus workstation. Inspect the timeline, preserve evidence, contain the workstation, revoke access, restore the approved baseline, verify recovery and submit your incident report. All systems and commands belong to this local fictional training exercise."}
static func mission_for(mode_id: String, mission_id: String, registration_path: String = REGISTRATION_PATH) -> Dictionary:
	if mode_id == "incident_response" and mission_id == "IR-2026-001": return mission()
	for data: Variant in find_mode(mode_id,registration_path).get("missions",[]):
		if not data is Dictionary or data.get("id","") != mission_id: continue
		var result: Dictionary = data.duplicate(true)
		var controls: Variant = result.get("controls",[])
		var hints: Array = []
		if controls is Array:
			for hint: Variant in controls:
				if hint is Dictionary and hint.get("action") is String and hint.get("binding") is String:
					hints.append(hint.duplicate(true))
		elif controls is String:
			# Legacy prose is retained for diagnostics, never passed to a Grid's
			# dictionary-based controls renderer as individual characters.
			result["controls_text"] = controls
		result["controls"] = hints
		return result
	return {}
