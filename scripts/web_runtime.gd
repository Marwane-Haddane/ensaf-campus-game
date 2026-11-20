extends RefCounted
## One embedded Chromium (gdcef, res://cef_artifacts) per game session.
## CEF can only be initialised once per process, so the auditorium screen and the
## workstation browser share this node. It lives under the game node, so every
## browser closes with the session. Started lazily on the first web request.

const GROUP := "shared_gdcef"
static var last_error := ""

static func supported() -> bool:
	return ClassDB.class_exists("GDCef") and last_error.is_empty()

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
	var cache := OS.get_user_data_dir().path_join("cinema_browser")
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

static func normalise_url(text: String) -> String:
	text = text.strip_edges()
	if text.is_empty(): return "https://www.google.com"
	if text.contains("://") or text.begins_with("about:"): return text
	if not text.contains(".") or text.contains(" "):
		return "https://www.google.com/search?q=" + text.uri_encode()
	return "https://" + text
