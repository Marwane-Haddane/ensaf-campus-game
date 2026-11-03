extends SceneTree
var game
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func verify(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		print("GAME_UI_FAIL ",message)

func action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.player.force_update_transform()
	game.camera.force_update_transform()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tools/"+name+".png")

func run_test() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process_unhandled_input(false)
	while not game.ready_to_play: await process_frame
	for frame: int in range(20): await physics_frame
	verify(game.pause_menu.visible and not game.training._exploration.visible,"Initial native menu hides exploration HUD")
	verify(not game.moving,"Initial menu stops movement")
	await capture("game-ui-start")
	game._resume()
	verify(game.moving and not game._menu_visible(),"Start resumes the actual game")
	game._unhandled_input(action("ui_cancel"))
	verify(game.pause_menu.visible and not game.menu.visible,"Escape opens the full-screen pause UI")
	verify(game.pause_menu._heading.text=="Paused","Pause title uses the reference copy")
	verify(not game.moving and not game.training._exploration.visible,"Pause hides HUD and stops movement")
	await capture("game-ui-pause")
	game._show_destinations()
	verify(game.pause_menu.visible and game.pause_menu._destination_names.size()==6,"All six destinations use the new guide")
	await capture("game-ui-destinations")
	game.pause_menu.destination_requested.emit("Reception / response desk")
	for frame: int in range(20): await physics_frame
	verify(game.moving and not game._menu_visible(),"Choosing a destination resumes exploration")
	var station: Dictionary = game.stations[0]
	game.camera.look_at(station.screen,Vector3.UP)
	game._process(0.0)
	verify(game._closest.get("name","")==station.name,"Reception PC selected by exact crosshair")
	game._unhandled_input(action("interact"))
	verify(game.training.terminal_open and not game.moving,"E opens Linux desktop and stops player")
	verify(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Desktop releases mouse for native windows")
	await capture("game-ui-workstation")
	var desktop = game.training._desktop
	desktop.command_input.text = "ls"
	desktop.command_input.text_submitted.emit("ls")
	verify(desktop.output.text.contains("Evidence") and desktop.output.text.contains("Help"),"Real shell input runs ls")
	var before: Vector3 = game.player.position
	Input.action_press("move_forward")
	for frame: int in range(20): await physics_frame
	Input.action_release("move_forward")
	var travelled: Vector3 = game.player.position-before
	verify(Vector2(travelled.x,travelled.z).length()<0.01,"Typing/movement actions cannot move player while on PC")
	desktop.submit_command("ir inspect")
	verify(game.training.get_completion_count()==1,"IR command reaches mission engine")
	desktop.open_folder("~/Help")
	verify(desktop.file_window.visible and desktop.preview.text.contains("field guide"),"Help opens a real file/preview window")
	await capture("game-ui-help")
	game.training._input(action("ui_cancel"))
	verify(not game.training.terminal_open and game.moving,"Esc exits desktop directly to campus")
	game._spawn("Security training area")
	for frame: int in range(20): await physics_frame
	game.camera.look_at(game.stations[1].screen,Vector3.UP)
	game._process(0.0)
	game._unhandled_input(action("interact"))
	verify(game.training.terminal_open and game.training.get_completion_count()==1,"Another PC retains the same case progress")
	game.training.close_terminal()
	game._unhandled_input(action("ui_cancel"))
	verify(game.pause_menu.visible and game.pause_menu._case_title.text.contains("borrowed session"),"Pause reads active mission after workstation use")
	game._unhandled_input(action("ui_cancel"))
	verify(game.moving,"Esc resumes from the new pause menu")
	var result := {"passed":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://tools/game_ui_integration_test.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("GAME_UI_INTEGRATION ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
