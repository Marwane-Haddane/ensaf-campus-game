extends Control
## Always usable when optional presentation assets are absent.
signal intent_requested(action: StringName,payload: Dictionary)
var content: VBoxContainer
var current: Dictionary = {}
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101b29")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,56)
	add_child(margin)
	content = VBoxContainer.new()
	margin.add_child(content)
func get_contract_version() -> int: return 1
func set_preferences_preview(_preferences: Dictionary) -> void: pass
func present(model: Dictionary) -> void:
	current = model
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "ENSA Games · " + str(model.page).capitalize()
	title.add_theme_font_size_override("font_size",32)
	content.add_child(title)
	var status := Label.new()
	status.text = str(model.get("loading",{}).get("stage_label","Choose your experience."))
	if model.page == "error": status.text = str(model.error.message)
	content.add_child(status)
	if model.page in ["home","modes","briefing"]:
		button("Start The borrowed session", "start_mission",{"mode_id":"incident_response","mission_id":"IR-2026-001"})
		button("How to Play","show_how_to_play")
	if model.page == "loading": button("Cancel loading","cancel_loading",{"request_id":model.loading.request_id})
	if model.page == "ready": button("Enter Mission","enter_game",{"request_id":model.loading.request_id})
	if model.page == "error": button("Retry","retry_loading",{"request_id":model.loading.request_id})
	if not model.page in ["home","loading"]: button("Return to menu","return_to_menu")
	button("Quit","quit")
func button(text: String,action: String,payload: Dictionary = {}) -> void:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
	node.pressed.connect(func():intent_requested.emit(StringName(action),payload))
	content.add_child(node)
func focus_primary() -> void:
	for child: Node in content.get_children():
		if child is Button:
			child.grab_focus()
			return
