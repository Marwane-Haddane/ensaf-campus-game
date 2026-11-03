extends Node3D
## Tiny real scene for exercising shared mode ownership without importing or
## editing Antigravity's still-active gameplay module or production saves.
signal initialization_progress(label: String, stage: String, completed: Variant, total: Variant)
signal launcher_return_requested
signal launcher_settings_requested
signal progress_changed
var initialization_finished := false
var ready_to_play := false
var initialization_error := ""
var cancelled := false
var score := 0
var ticks := 0
var input_enabled := false
var hud: CanvasLayer

class Actor extends Node:
	func _physics_process(_delta: float) -> void:
		get_parent().ticks += 1

func _ready() -> void:
	hud = CanvasLayer.new()
	hud.name = "IndependentModeHUD"
	add_child(hud)
	add_child(Actor.new())
	_build.call_deferred()

func _build() -> void:
	for index: int in range(3):
		if cancelled: break
		var section := Node3D.new()
		section.name = "Section%d" % index
		add_child(section)
		initialization_progress.emit("Creating fixture sections","fixture_sections",index+1,3)
		await get_tree().process_frame
	initialization_error = "Cancelled" if cancelled else ""
	ready_to_play = not cancelled
	initialization_finished = true
