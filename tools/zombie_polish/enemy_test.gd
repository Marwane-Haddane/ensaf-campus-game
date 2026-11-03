extends SceneTree
const Enemy = preload("res://scripts/antigravity/zombie/enemy_controller.gd")
var report := {"checks":0,"failures":[],"passed":false}
class TestEnemy extends Enemy:
	func _setup_model() -> void:
		model_instance = Node3D.new()
		add_child(model_instance)
		anim_player = AnimationPlayer.new()
		model_instance.add_child(anim_player)
		var library := AnimationLibrary.new()
		for clip: String in ["Idle","Walk","Run","Crawl","Punch","HitReact","Death"]:
			var animation := Animation.new()
			animation.length = 1.0
			library.add_animation(clip,animation)
		anim_player.add_animation_library("",library)
		_play_anim("Idle")
class TestPlayer extends CharacterBody3D:
	var health := 100.0
	var is_dead := false
	func take_damage(amount: float) -> void: health = maxf(0.0,health-amount)
func _init() -> void: call_deferred("run_test")
func check(value: bool,label: String) -> void:
	report.checks += 1
	if not value:
		report.failures.append(label)
		print("ENEMY_TEST_FAIL ",label)
func sync_physics() -> void:
	for frame: int in range(3): await physics_frame
func body(position: Vector3,size: Vector3) -> StaticBody3D:
	var node := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	node.add_child(collision)
	node.position = position
	root.add_child(node)
	return node
func attack(enemy: CharacterBody3D,player: CharacterBody3D) -> void:
	enemy._enter_state(Enemy.State.IDLE)
	enemy.target_player = player
	enemy.rotation.y = 0.0
	enemy.velocity = Vector3.ZERO
	enemy._enter_state(Enemy.State.ATTACK)
func run_test() -> void:
	var floor_body := body(Vector3(0,-0.1,0),Vector3(40,0.2,40))
	var player := TestPlayer.new()
	player.add_to_group("player")
	player.position = Vector3(0,0.9,-1.25)
	root.add_child(player)
	var enemy := TestEnemy.new()
	root.add_child(enemy)
	enemy.set_physics_process(false)
	await sync_physics()
	attack(enemy,player)
	check(enemy.attack_phase=="windup" and enemy.attack_contact_timer>0.0,"Attack exposes a real windup phase")
	enemy._physics_process(0.3)
	check(player.health==100.0,"Windup cannot damage early")
	enemy._physics_process(0.31)
	check(player.health==85.0 and enemy.attack_phase=="recovery","Contact occurs once after windup")
	enemy._physics_process(0.3)
	check(player.health==85.0,"One swing never applies duplicate damage")
	player.health = 100.0
	player.position = Vector3(0,0.9,-1.25)
	attack(enemy,player)
	enemy._physics_process(0.4)
	player.position = Vector3(1.25,0.9,0)
	enemy._physics_process(0.21)
	check(player.health==100.0,"A late sidestep outside attack arc dodges contact")
	player.position = Vector3(0,0.9,-1.25)
	attack(enemy,player)
	player.position.z = -4.0
	enemy._physics_process(0.61)
	check(player.health==100.0,"Leaving melee reach dodges contact")
	player.position = Vector3(0,0.9,-1.25)
	var wall := body(Vector3(0,1,-0.65),Vector3(2,2,0.15))
	await sync_physics()
	attack(enemy,player)
	enemy._try_apply_attack_damage()
	check(player.health==100.0,"Closed world geometry blocks melee damage")
	check(not enemy._check_perception(),"Walls prevent visual detection")
	wall.queue_free()
	await sync_physics()
	enemy.target_player = null
	player.position = Vector3(0,0.9,6)
	check(not enemy._check_perception(),"Distant targets behind an idle enemy are outside its FOV")
	player.position.z = -6
	check(enemy._check_perception(),"A visible target in front is acquired")
	enemy.last_known_position = Vector3(0,0,-3)
	enemy._can_see_target = false
	enemy._lost_sight_time = 3.0
	enemy._enter_state(Enemy.State.CHASE)
	enemy._process_chase(0.1)
	check(enemy.state==Enemy.State.INVESTIGATE,"Losing sight enters an investigate state")
	player.position.x = 9
	check(enemy.last_known_position==Vector3(0,0,-3),"Investigation does not track an unseen player's new position")
	enemy.velocity = Vector3.ZERO
	enemy._steer_towards(Vector3(0,0,-10),enemy.run_speed,1.0/60.0)
	check(Vector2(enemy.velocity.x,enemy.velocity.z).length()<=enemy._acceleration/60.0+0.001,"Chase accelerates smoothly rather than snapping to full speed")
	var neighbor := TestEnemy.new()
	neighbor.position = Vector3(-0.5,0,0)
	root.add_child(neighbor)
	neighbor.set_physics_process(false)
	enemy._update_separation()
	check(enemy._separation.x>0.0,"Nearby enemies steer apart")
	neighbor.queue_free()
	player.position = Vector3(0,0.9,-1.25)
	attack(enemy,player)
	enemy.set_physics_process(true)
	enemy.take_damage(1.0,true)
	enemy.set_physics_process(false)
	check(enemy.state==Enemy.State.HIT_REACT and enemy.attack_contact_timer<0.0,"A stagger cancels an unfinished attack")
	player.health = 100
	enemy._physics_process(0.7)
	check(player.health==100.0,"Cancelled attack cannot deliver delayed damage")
	var brute := TestEnemy.new()
	brute.enemy_type = "brute"
	brute.position = Vector3(5,0,0)
	root.add_child(brute)
	brute.set_physics_process(false)
	check(brute.run_speed<enemy.run_speed and brute.attack_contact_time>enemy.attack_contact_time,"Brute is slower with a longer readable windup")
	check(brute.health>enemy.max_health and brute.attack_damage>enemy.attack_damage,"Brute has distinct durability and threat")
	attack(brute,player)
	brute.set_physics_process(true)
	brute.take_damage(10.0,false)
	check(brute.state==Enemy.State.ATTACK,"Brute resists body-shot stunlock")
	brute.take_damage(10.0,true)
	check(brute.state==Enemy.State.HIT_REACT and brute.attack_contact_timer<0.0,"Brute headshot interrupts windup")
	brute.state_timer = 0.1
	brute.take_damage(1.0,true)
	check(is_equal_approx(brute.state_timer,0.1),"Repeated hits cannot reset stagger recovery indefinitely")
	var hp: float = brute.health
	brute.take_damage(-100.0,false)
	brute.take_damage(NAN,false)
	check(brute.health==hp,"Invalid damage cannot heal or corrupt enemy health")
	paused = true
	brute.take_damage(10.0,true)
	paused = false
	check(brute.health==hp,"Pause suspends enemy damage")
	var deaths := [0]
	brute.enemy_died.connect(func(_id: String,_boss: bool): deaths[0]+=1)
	brute.take_damage(10000.0,false)
	brute.take_damage(10000.0,false)
	check(brute.is_dead() and deaths[0]==1,"Death and reward signal occur exactly once")
	check(brute.attack_contact_timer<0.0 and brute.collision_layer==0,"Death cancels attacks and removes blocking hit collision")
	check(brute.xp_reward>enemy.xp_reward and brute.scrap_reward>enemy.scrap_reward,"Enemy-specific RPG reward values are exposed")
	for node: Node in [enemy,brute,player,floor_body]: node.queue_free()
	await process_frame
	report.passed = report.failures.is_empty()
	FileAccess.open("res://tools/zombie_polish/enemy-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ENEMY_TEST_RESULT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
