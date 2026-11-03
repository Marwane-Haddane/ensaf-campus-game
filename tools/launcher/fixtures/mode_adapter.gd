extends RefCounted
const Store = preload("res://tools/launcher/fixtures/save_store.gd")
var saves = Store.new()
func save_service() -> RefCounted: return saves
func entry_scene() -> String: return "res://tools/launcher/fixtures/session.tscn"
func required_resources() -> Array[String]: return [entry_scene()]
func create_session(resources: Dictionary,_preferences: Dictionary) -> Node3D:
	return (resources[entry_scene()] as PackedScene).instantiate() as Node3D
func initialization_finished(game: Node3D) -> bool: return game.initialization_finished
func validate_ready(game: Node3D) -> bool: return game.ready_to_play
func error_detail(game: Node3D) -> String: return game.initialization_error
func cancel(game: Node3D) -> void: game.cancelled = true
func freeze(game: Node3D) -> void:
	game.input_enabled = false
	game.hud.hide()
func start(game: Node3D) -> void:
	game.get_tree().paused = false
	game.input_enabled = true
	game.hud.show()
func set_input(game: Node3D,enabled: bool) -> void: game.input_enabled = enabled
func connect_events(game: Node3D,on_return: Callable,on_settings: Callable,on_progress: Callable) -> void:
	game.launcher_return_requested.connect(on_return)
	game.launcher_settings_requested.connect(on_settings)
	game.progress_changed.connect(on_progress)
func apply_preferences(_game: Node3D,_preferences: Dictionary) -> void: pass
func capture(game: Node3D) -> Dictionary: return saves.capture(game)
func restore(game: Node3D,checkpoint: Dictionary) -> bool: return saves.restore(game,checkpoint)
func is_ready(game: Node3D) -> bool: return game.ready_to_play
