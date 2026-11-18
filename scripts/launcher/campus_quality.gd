extends RefCounted
## Campus geometry per Graphics Preset (Settings > Graphics Preset).
##   low    -> game-ready rebuild (fewer triangles, faster)   assets/campus_low.glb
##   medium -> original campus look                           assets/campus.glb
##   high   -> extra detail, reserved                         assets/campus_high.glb
## A level whose files are missing falls back to medium, so High is safe to pick
## before its assets exist. Changing the preset applies on the next campus load.

const PREFS_PATH := "user://ensagames/preferences.cfg"
const DEFAULT := "medium"
const LEVELS := {
	"low": {"glb": "res://assets/campus_low.glb", "chunks": "res://assets/runtime_campus_low/manifest.json"},
	"medium": {"glb": "res://assets/campus.glb", "chunks": "res://assets/runtime_campus/manifest.json"},
	"high": {"glb": "res://assets/campus_high.glb", "chunks": "res://assets/runtime_campus_high/manifest.json"},
}

## Tests and capture harnesses can force a level; `--campus-quality=low` works too.
static var override_preset := ""


static func requested_preset(preferences: Dictionary = {}) -> String:
	if not override_preset.is_empty():
		return override_preset
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--campus-quality="):
			return arg.trim_prefix("--campus-quality=")
	if preferences.has("graphics_preset"):
		return str(preferences.graphics_preset)
	var config := ConfigFile.new()
	if config.load(PREFS_PATH) == OK:
		return str(config.get_value("preferences", "graphics_preset", DEFAULT))
	return DEFAULT


## Level actually used: the requested one if its campus exists, otherwise medium.
static func active_preset(preferences: Dictionary = {}) -> String:
	var preset := requested_preset(preferences)
	if LEVELS.has(preset) and ResourceLoader.exists(LEVELS[preset].glb):
		return preset
	return DEFAULT


static func campus_path(preferences: Dictionary = {}) -> String:
	return LEVELS[active_preset(preferences)].glb


## Pre-baked campus sections for the active level, or [] to load the single GLB.
static func chunk_paths(preferences: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	var manifest_path: String = LEVELS[active_preset(preferences)].chunks
	if not FileAccess.file_exists(manifest_path):
		return result
	var sections: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if sections is Dictionary and sections.get("version", 0) == 1:
		for path: String in sections.get("chunks", []):
			result.append(path)
	return result


## Every campus resource the loader must prepare for the active level.
static func resource_paths(preferences: Dictionary = {}) -> Array[String]:
	var chunks := chunk_paths(preferences)
	if chunks.is_empty():
		return [campus_path(preferences)]
	return chunks


static func is_campus_section(path: String) -> bool:
	return "/runtime_campus" in path and path.ends_with(".scn")
