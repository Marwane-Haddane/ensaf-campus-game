extends SceneTree
const Player = preload("res://scripts/antigravity/zombie/player_controller.gd")
const Weapon = preload("res://scripts/antigravity/zombie/weapon_controller.gd")
var report := {"passed":false,"checks":0,"failures":[]}
class MockWeapon extends Node3D:
	var is_aiming := false
	func set_aim(value: bool) -> void: is_aiming=value
class MotionPlayer extends Player:
	func _setup_weapon() -> void:
		weapon_controller=MockWeapon.new()
		camera.add_child(weapon_controller)
class SceneHost extends Node3D:
	var campus: Node
class StateWeapon extends Weapon:
	func _ready() -> void: pass
class Target extends StaticBody3D:
	var health := 100.0
	func is_dead() -> bool: return health<=0
	func take_damage(value: float,_head: bool,_point: Vector3,_direction: Vector3) -> void: health-=value
func _init() -> void: call_deferred("run_test")
func check(ok: bool,label: String) -> void:
	report.checks+=1
	if not ok: report.failures.append(label)
func step(count: int) -> void:
	for tick: int in range(count): await physics_frame
func run_test() -> void:
	var settings=load("res://scripts/launcher/settings_store.gd").new()
	settings.path="user://ensagames/tests/zombie-motion.cfg"
	settings.initialize()
	var scene:=SceneHost.new()
	root.add_child(scene)
	var floor_body:=StaticBody3D.new()
	var floor_shape:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(30,.2,30)
	floor_shape.shape=shape
	floor_body.add_child(floor_shape)
	floor_body.position.y=-.1
	scene.add_child(floor_body)
	var actor:=MotionPlayer.new()
	actor.position.y=.05
	scene.add_child(actor)
	await step(12)
	check(actor.is_on_floor(),"Player rests on actual floor collision")
	Input.action_press("run")
	await step(15)
	check(actor.stamina==100,"Standing with sprint held spends no stamina")
	Input.action_release("run")
	Input.action_press("move_forward")
	await step(2)
	check(absf(actor.velocity.z)>0 and absf(actor.velocity.z)<actor.WALK_SPEED,"Movement accelerates instead of snapping to full speed")
	await step(45)
	check(actor.global_position.z < -2.0,"Forward input produces continuous physical movement")
	Input.action_release("move_forward")
	await step(18)
	check(Vector2(actor.velocity.x,actor.velocity.z).length()<.05,"Release brakes smoothly to a stable stop")
	Input.action_press("move_forward")
	Input.action_press("run")
	await step(20)
	check(actor.is_sprinting and actor.stamina<100,"Forward sprint increases speed and consumes stamina")
	actor.stamina=.01
	await step(4)
	check(actor.sprint_exhausted and not actor.is_sprinting,"Exhaustion prevents rapid sprint/recovery oscillation")
	Input.action_release("move_forward")
	Input.action_release("run")
	actor.reduced_motion=true
	actor.add_recoil(.03)
	var recoil:=actor.recoil_pitch_offset
	await step(15)
	check(absf(actor.recoil_pitch_offset)<absf(recoil) and actor.camera.rotation.z==0,"Reduced-motion recoil returns without camera roll")
	actor.take_damage(NAN)
	actor.take_damage(-10)
	check(actor.health==100,"Invalid/negative damage cannot poison health")
	actor.set_input_enabled(false)
	var position: Vector3=actor.global_position
	Input.action_press("move_forward")
	await step(12)
	Input.action_release("move_forward")
	check(actor.global_position.distance_to(position)<.02,"UI input ownership stops movement")
	actor.set_input_enabled(true)
	actor.global_position=Vector3(0,.03,0)
	actor.rotation=Vector3.ZERO
	actor.camera.rotation=Vector3.ZERO
	actor.set_physics_process(false)
	var weapon:=StateWeapon.new()
	weapon.player=actor
	weapon.camera=actor.camera
	actor.camera.add_child(weapon)
	weapon._apply_weapon_config("pistol")
	var target:=Target.new()
	target.add_to_group("enemies")
	target.collision_layer=4
	var target_shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.8,2,.8)
	target_shape.shape=box
	target_shape.position.y=1
	target.add_child(target_shape)
	target.position.z=-8
	scene.add_child(target)
	await step(3)
	weapon._perform_melee_strike()
	check(target.health==100,"Emergency melee cannot hit at firearm range")
	target.position.z=-1.6
	await step(3)
	weapon._perform_melee_strike()
	check(target.health==82,"Emergency melee deals bounded close-range damage")
	weapon.mag_ammo=0
	weapon.reserve_ammo=10
	weapon.start_reload()
	weapon.cancel_reload()
	check(weapon.mag_ammo==0 and weapon.reserve_ammo==10 and not weapon.is_reloading,"Cancelling reload creates no ammunition")
	weapon.start_reload()
	weapon._process(3.0)
	check(weapon.mag_ammo==10 and weapon.reserve_ammo==0 and not weapon.is_reloading,"Reload conserves magazine plus reserve ammunition")
	scene.queue_free()
	await process_frame
	report.passed=report.failures.is_empty()
	FileAccess.open("res://tools/zombie_polish/controls-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ZOMBIE_CONTROLS_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
