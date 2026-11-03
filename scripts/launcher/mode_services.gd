extends RefCounted
## Lazy mode adapters and their independent save services. No game scenes or
## models are loaded here; only the selected mode's lightweight adapter script.
const Registry = preload("res://scripts/launcher/mode_registry.gd")
const ADAPTER_METHODS := ["required_resources","entry_scene","create_session","initialization_finished","validate_ready","freeze","start","set_input","connect_events","capture","restore","apply_preferences","cancel","is_ready","error_detail","save_service"]
var registration_path := Registry.REGISTRATION_PATH
var test_save_path := ""
var last_error := ""
var _adapters: Dictionary = {}
var _saves: Dictionary = {}

func adapter_for(mode_id: String) -> RefCounted:
	last_error = ""
	if _adapters.has(mode_id): return _adapters[mode_id]
	var mode: Dictionary = Registry.find_mode(mode_id,registration_path)
	if mode.get("availability","") != "available":
		last_error = "This mode is not available."
		return null
	var path: String = str(mode.get("adapter_path",""))
	var script := load(path) as GDScript if not path.is_empty() and ResourceLoader.exists(path) else null
	if script == null or not script.can_instantiate():
		last_error = "The game-mode adapter is unavailable: "+path
		return null
	var adapter: RefCounted = script.new()
	for method: String in ADAPTER_METHODS:
		if not adapter.has_method(method):
			last_error = "Missing adapter method: "+method
			return null
	var service: RefCounted = adapter.save_service()
	if service == null:
		last_error = "The mode has no checkpoint service."
		return null
	for method: String in ["read_save","write_save","summary"]:
		if not service.has_method(method):
			last_error = "Missing checkpoint method: "+method
			return null
	if not has_property(service,"path") or not has_property(service,"last_error"):
		last_error = "Checkpoint services must expose path and last_error."
		return null
	if not test_save_path.is_empty():
		if not mode_id.is_valid_identifier():
			last_error = "Invalid mode identity for isolated storage."
			return null
		service.set("path",isolated_save_path(mode_id))
	_adapters[mode_id] = adapter
	_saves[mode_id] = service
	return adapter

func save_for(mode_id: String) -> RefCounted:
	if adapter_for(mode_id) == null: return null
	return _saves[mode_id]

func checkpoint_for(mode_id: String) -> Dictionary:
	var service: RefCounted = save_for(mode_id)
	if service == null: return {}
	var checkpoint: Dictionary = service.read_save()
	if checkpoint.is_empty(): return {}
	if checkpoint.get("mode_id","") != mode_id or not Registry.can_launch(mode_id,str(checkpoint.get("mission_id","")),registration_path):
		service.set("last_error","The checkpoint does not belong to this mode and mission.")
		return {}
	return checkpoint

func isolated_save_path(mode_id: String) -> String:
	if mode_id == "incident_response": return test_save_path
	return test_save_path.get_basename()+"-"+mode_id+".json"

static func has_property(object: Object, key: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.name == key: return true
	return false

static func summary_text(service: RefCounted, checkpoint: Dictionary) -> String:
	var value: Variant = service.summary(checkpoint)
	if value is String: return value
	if value is Dictionary:
		for key: String in ["label","checkpoint_name","title"]:
			if value.get(key) is String and not value[key].is_empty(): return value[key]
	return "Saved mission" if not checkpoint.is_empty() else ""
