extends RefCounted
## Validated, versioned per-mode checkpoint. Never evaluates commands or scripts.
var path := "user://ensagames/saves/incident_response/checkpoint.json"
var last_error := ""
const VERSION := 1
func summary(payload: Dictionary) -> String:
	return "The borrowed session · %d / 100 points" % int(payload.get("training",{}).get("points",0))

func read_save() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()>2000000:
		last_error = "The saved session cannot be read. New Mission is available."
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	var payload: Variant = parser.data if parse_error == OK else null
	if not payload is Dictionary or not validate(payload):
		last_error = "The saved session is incompatible or damaged. New Mission is available."
		return {}
	return payload

func validate(payload: Dictionary) -> bool:
	if payload.get("version") != VERSION or payload.get("mode_id") != "incident_response" or payload.get("mission_id") != "IR-2026-001": return false
	if not payload.get("training") is Dictionary or not payload.get("player") is Dictionary: return false
	var data: Dictionary = payload.training
	if not data.get("state") is Dictionary or not data.get("points") is float and not data.get("points") is int: return false
	for key: String in ["journal","command_history"]:
		if not data.get(key) is Array or data[key].size()>500: return false
		for line: Variant in data[key]:
			if not line is String or line.length()>12000: return false
	if not data.get("report_answers") is Dictionary or not data.get("submitted_report_text") is String: return false
	if not data.get("report_preview_valid") is bool: return false
	var mission: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://design/incident.json"))
	if not mission is Dictionary: return false
	var initial: Dictionary = mission.get("initial_state",{})
	for flag: String in initial:
		if not data.state.has(flag) or typeof(data.state[flag]) != typeof(initial[flag]): return false
	for flag: String in data.state:
		if not initial.has(flag): return false
	var earned := 0
	for step: Dictionary in mission.get("steps",[]):
		if bool(data.state.get(step.get("completion_flag",""),false)):
			for dependency: String in step.get("requires",[]):
				if not bool(data.state.get(dependency,false)): return false
			earned += int(step.get("on_success",{}).get("points",0))
	if earned != int(data.points): return false
	var position: Variant = payload.player.get("position")
	if not position is Array or position.size()!=3: return false
	for number: Variant in position:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number))>10000: return false
	for key: String in ["yaw","pitch"]:
		var number: Variant = payload.player.get(key)
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

func capture(game: Node3D) -> Dictionary:
	var ui: Node = game.get("training")
	var player: Node3D = game.get("player")
	return {"version":VERSION,"mode_id":"incident_response","mission_id":"IR-2026-001",
	"saved_at":Time.get_datetime_string_from_system(true),"player":{"position":[player.position.x,player.position.y,player.position.z],"yaw":player.rotation.y,"pitch":game.get("pitch")},
	"training":{"state":ui.get("state").duplicate(true),"points":ui.get("points"),"journal":Array(ui.get("journal")),
	"command_history":Array(ui.get("command_history")),"report_answers":ui.get("report_answers").duplicate(true),
	"report_preview_valid":ui.get("report_preview_valid"),"submitted_report_text":ui.get("submitted_report_text")}}

func write_save(payload: Dictionary) -> bool:
	last_error = ""
	if not validate(payload):
		last_error = "This checkpoint is inconsistent and was not saved."
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		last_error = "The session could not be saved."
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK: result = DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	if result != OK: last_error = "The session could not be saved ("+str(result)+")."
	return result == OK

func restore(game: Node3D, payload: Dictionary) -> bool:
	if not validate(payload): return false
	var ui: Node = game.get("training")
	var data: Dictionary = payload.training
	ui.set("state",data.state.duplicate(true))
	ui.set("points",int(data.points))
	ui.get("journal").assign(data.journal)
	ui.get("command_history").assign(data.command_history)
	ui.set("report_answers",data.report_answers.duplicate(true))
	ui.set("report_preview_valid",data.report_preview_valid)
	ui.set("submitted_report_text",data.submitted_report_text)
	ui.call("_refresh_ui")
	game.call("restore_safe_pose",payload.player)
	return true
