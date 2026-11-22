extends RefCounted
## One embedded Chromium (gdcef, res://cef_artifacts) per game session.
## CEF can only be initialised once per process, so the auditorium screen and the
## workstation browser share this node. It lives under the game node, so every
## browser closes with the session. Started lazily on the first web request.

const GROUP := "shared_gdcef"
static var last_error := ""

static var _extension_tried := false

static func supported() -> bool:
	return _ensure_extension() and last_error.is_empty()

## Release zips: Godot's start-up load of res://cef_artifacts/gdcef.gdextension uses a
## relative path, so Windows cannot find libcef.dll (libgdcef.dll's dependency) and
## the class is missing. Loading the shipped cef_artifacts/gdcef_release.gdextension
## by absolute path makes Windows search that folder, so it works on any PC.
static func _ensure_extension() -> bool:
	if ClassDB.class_exists("GDCef"): return true
	if _extension_tried or not OS.has_feature("template"): return false
	_extension_tried = true
	var path := OS.get_executable_path().get_base_dir().path_join("cef_artifacts/gdcef_release.gdextension")
	if not FileAccess.file_exists(path): return false
	var status := GDExtensionManager.load_extension(path)
	if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		push_warning("Embedded browser library could not load (status %d)." % status)
	return ClassDB.class_exists("GDCef")

## Returns the shared GDCef node (created under `host` on first use) or null.
static func cef(host: Node) -> Node:
	if not is_instance_valid(host) or not host.is_inside_tree(): return null
	var existing := host.get_tree().get_first_node_in_group(GROUP)
	if is_instance_valid(existing) and not existing.is_queued_for_deletion(): return existing
	if not supported(): return null
	var node: Node = ClassDB.instantiate("GDCef")
	node.name = "SharedCEF"
	node.add_to_group(GROUP)
	host.add_child(node)
	# Chromium profile lives in user:// (always writable, also in exported builds),
	# never inside cef_artifacts next to the game files.
	# One folder per running game: Chromium locks its profile, so a second open copy
	# of the game would otherwise get no browser. The session is incognito anyway;
	# folders of games that have closed are removed here.
	var base := OS.get_user_data_dir().path_join("cinema_browser")
	_remove_stale_caches(base)
	var cache := base.path_join("session_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(cache)
	var ok: bool = node.initialize({
		"artifacts": "res://cef_artifacts/",
		"root_cache_path": cache,
		"cache_path": cache.path_join("profile"),
		"log_file": cache.path_join("debug.log"),
		"persist_session_cookies": false,
		"incognito": true,
		"locale": "en-US",
		"enable_media_stream": false,
		"user_gesture_required": false,
		"remote_debugging_port": 0,
		"log_severity": "error"})
	if not ok:
		last_error = str(node.get_error())
		push_warning("Embedded browser unavailable: " + last_error)
		node.remove_from_group(GROUP)
		node.queue_free()
		return null
	return node

static func _remove_stale_caches(base: String) -> void:
	var dir := DirAccess.open(base)
	if dir == null: return
	for name: String in dir.get_directories():
		if name.begins_with("session_") and name != "session_%d" % OS.get_process_id():
			_remove_tree(base.path_join(name))

## Best effort: files a running game still holds stay until that game closes.
static func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for name: String in dir.get_directories(): _remove_tree(path.path_join(name))
	for name: String in dir.get_files(): DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)

static func normalise_url(text: String) -> String:
	text = text.strip_edges()
	if text.is_empty(): return "https://www.google.com"
	if text.contains("://") or text.begins_with("about:"): return text
	if not text.contains(".") or text.contains(" "):
		return "https://www.google.com/search?q=" + text.uri_encode()
	return "https://" + text
