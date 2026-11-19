extends SceneTree
## After Hours survival flow on Easy, Medium and Hard: difficulty scaling,
## real enemy hunting (gunshot -> chase -> melee damage), the five levels,
## reinforcement waves, boss adds, extraction and checkpoint retry.
## Run: godot --headless --path . -s tools/antigravity/zombie/test_survival_levels.gd

const Difficulty = preload("res://scripts/antigravity/zombie/zombie_difficulty.gd")
var failures: Array[String] = []
var checks := 0
var counts := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	print("[PASS] " if ok else "[FAIL] ", label)
	if not ok: failures.append(label)

func _init() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	# Level logic runs in _process; physics ticks alone may skip it.
	for i: int in n: await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in Difficulty.IDS:
		await run_difficulty(id)
	check(counts.easy < counts.medium and counts.medium < counts.hard, "Harder difficulties field more infected (%s)" % [counts])
	print("SURVIVAL_TEST checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func live_waves(game: Node) -> Array:
	return game.level_director.wave_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead())

func run_difficulty(id: String) -> void:
	print("=== Difficulty: ", id, " ===")
	var tuning := Difficulty.settings(id)
	var game: Node3D = load("res://scenes/antigravity/zombie/zombie_game.tscn").instantiate()
	game.launcher_managed = false
	game.runtime_preferences = {"zombie_difficulty": id}
	root.add_child(game)
	for i: int in 2400:
		if game.initialization_finished: break
		await process_frame
	check(game.ready_to_play, "[%s] world ready" % id)
	if not game.ready_to_play:
		game.queue_free()
		return
	var player: CharacterBody3D = game.player
	var director = game.level_director
	check(game.difficulty_id == id and director.difficulty_id == id, "[%s] difficulty applied to game and director" % id)
	counts[id] = game.active_enemies.size()
	var walker: Node3D = null
	for enemy in game.active_enemies:
		if enemy.enemy_id == "walker_plaza_1": walker = enemy
	check(walker != null and is_equal_approx(walker.max_health, 55.0 * float(tuning.enemy_health)), "[%s] walker health scaled to %.1f" % [id, 55.0 * float(tuning.enemy_health)])
	check(walker != null and is_equal_approx(walker.attack_damage, 15.0 * float(tuning.enemy_damage)), "[%s] walker damage scaled" % id)
	check(game.inventory.get_item_count("medkit") == 1 + int(tuning.bonus_medkits), "[%s] starting medkits match difficulty" % id)

	# Level 1: unarmed opening keeps infected dormant; arming wakes them.
	await frames(10)
	check(director.current_level == 1, "[%s] run opens on level 1" % id)
	check(walker.get_meta("encounter_waiting", false), "[%s] infected wait while the player is unarmed" % id)
	game.spawned_pickups["item_intro_pistol"].interact(player)
	check(game.has_intro_weapon() and game.mission_state.current_step_index == 1, "[%s] pistol arms the player and completes exploration" % id)
	player.rotation.y = PI # look away from the plaza so encounters may enter
	await frames(6)
	check(not walker.get_meta("encounter_waiting", false) and walker.visible, "[%s] level 1 infected enter out of view once armed" % id)

	# Hunting: a gunshot draws the walker, it chases and lands melee hits.
	player.rotation.y = 0.0
	player.health = 1000.0
	player.max_health = 1000.0
	var start_distance: float = walker.global_position.distance_to(player.global_position)
	player.weapon_controller.trigger_fire()
	var hunted := false
	var min_distance := start_distance
	for i: int in 60 * 20:
		await physics_frame
		min_distance = minf(min_distance, walker.global_position.distance_to(player.global_position))
		if walker.state in [walker.State.CHASE, walker.State.ATTACK]: hunted = true
		if player.health < 1000.0 and min_distance < walker.attack_range + 0.5: break
	check(hunted, "[%s] walker hears the shot and hunts the player" % id)
	check(min_distance < walker.attack_range + 0.5, "[%s] walker closes from %.1fm to %.1fm" % [id, start_distance, min_distance])
	check(player.health < 1000.0, "[%s] walker lands a melee hit (%.1f damage)" % [id, 1000.0 - player.health])

	# Clear level 1 -> level-clear checkpoint.
	for enemy in game.active_enemies.duplicate():
		if is_instance_valid(enemy) and int(enemy.get_meta("level", 1)) == 1 and not enemy.is_dead():
			enemy.take_damage(9999.0)
	await frames(4)
	check(director.is_marked("level:1") and game.current_checkpoint_id == "cp_level_1", "[%s] clearing level 1 saves a checkpoint" % id)

	# Levels 2-3: relay, then the substation breach wave hunts the player.
	game.spawned_pickups["item_power_fuse"].interact(player)
	await frames(2)
	check(director.current_level == 2, "[%s] fuse opens level 2 (level %d step %d dead %s paused %s frozen %s ready %s entered %s)" % [id, director.current_level, game.mission_state.current_step_index, player.is_dead, paused, game.is_session_frozen, game.ready_to_play, game.has_entered_gameplay])
	game.inventory.add_item("item_power_relay", 1)
	game.collected_pickups.append("item_power_relay")
	game.mission_state.on_event("pickup_item", {"item_id": "item_power_relay"})
	await frames(2)
	check(director.current_level == 3, "[%s] relay opens level 3 (level %d step %d)" % [id, director.current_level, game.mission_state.current_step_index])
	var breach := Difficulty.scaled_count(3, id)
	for i: int in 60 * 10:
		await physics_frame
		if live_waves(game).size() >= breach and director._pending.is_empty(): break
	var waves := live_waves(game)
	check(waves.size() == breach, "[%s] substation breach sends %d infected" % [id, breach])
	check(waves.all(func(e): return e.relentless and e.state in [e.State.CHASE, e.State.ATTACK]), "[%s] wave infected spawn already hunting %s" % [id, waves.map(func(e): return [e.state, e.relentless])])

	# Level 4: power surge horde.
	for e in waves: e.take_damage(9999.0)
	game.mission_state.on_event("power_restored")
	await frames(2)
	check(director.current_level == 4, "[%s] power opens level 4" % id)
	var surge := Difficulty.scaled_count(4, id)
	for i: int in 60 * 12:
		await physics_frame
		if live_waves(game).size() >= surge and director._pending.is_empty(): break
	check(live_waves(game).size() == surge, "[%s] power surge horde of %d" % [id, surge])

	# Retry restores the checkpoint and replays the wave cleanly.
	game._create_checkpoint("cp_power", "Campus Power Restored")
	game._retry_checkpoint()
	await frames(2)
	check(live_waves(game).is_empty() and game.mission_state.current_step_index == 4, "[%s] retry clears wave actors and keeps progress" % id)
	for i: int in 60 * 12:
		await physics_frame
		if live_waves(game).size() >= surge and director._pending.is_empty(): break
	check(live_waves(game).size() == surge, "[%s] retried level replays its horde" % id)
	for e in live_waves(game): e.take_damage(9999.0)

	# Level 5: brute, its pack at half health, then the extraction rush.
	game.mission_state.on_event("talk_survivor")
	await frames(2)
	check(director.current_level == 5, "[%s] Shaun opens the boss level" % id)
	var boss: Node3D = game.brute_boss
	check(is_equal_approx(boss.max_health, 240.0 * float(tuning.enemy_health)), "[%s] brute health scaled" % id)
	boss.set_meta("encounter_waiting", false)
	boss.collision_layer = 4
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss.show()
	boss.take_damage(boss.max_health * 0.55, true)
	var adds := int(tuning.boss_adds)
	for i: int in 60 * 8:
		await physics_frame
		if live_waves(game).size() >= adds and director._pending.is_empty(): break
	check(live_waves(game).size() == adds, "[%s] brute summons %d adds at half health" % [id, adds])
	for e in live_waves(game): e.take_damage(9999.0)
	boss.take_damage(9999.0)
	await frames(2)
	check(game.mission_state.boss_killed and game.mission_state.current_step_index == 6, "[%s] brute death opens extraction" % id)
	var rush := Difficulty.scaled_count(3, id)
	for i: int in 60 * 10:
		await physics_frame
		if live_waves(game).size() >= rush and director._pending.is_empty(): break
	check(live_waves(game).size() == rush, "[%s] extraction rush of %d" % [id, rush])
	for e in live_waves(game): e.take_damage(9999.0)
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and int(enemy.get_meta("level", 1)) == 5 and not enemy.is_dead(): enemy.take_damage(9999.0)
	await frames(4)
	check(director.is_marked("level:5"), "[%s] final level cleared" % id)
	game.mission_state.on_event("reach_extraction")
	check(game.mission_state.extracted, "[%s] extraction completes the run" % id)
	get_root().get_tree().paused = false
	game.queue_free()
	for i: int in 10: await process_frame
