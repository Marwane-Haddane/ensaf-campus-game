extends Node
## After Hours level director. Groups the seven mission objectives into five
## levels (episode_01.json "levels"), gates which authored enemies may enter,
## fires reinforcement waves (episode_01.json "waves") and grants a checkpoint
## when a level is cleared. Progress markers live in the save's
## defeated_enemies list as "wave:<id>" and "level:<n>" strings.

const Difficulty = preload("res://scripts/antigravity/zombie/zombie_difficulty.gd")
const ZombieAudio = preload("res://scripts/antigravity/zombie/zombie_audio.gd")
const EnemyController = preload("res://scripts/antigravity/zombie/enemy_controller.gd")

signal level_changed(level: int, title: String)
signal level_cleared(level: int)

var game: Node3D
var levels: Array = []
var waves: Array = []
var difficulty_id := Difficulty.DEFAULT
var current_level := 0
var wave_enemies: Array[Node3D] = []
var _fired: Dictionary = {}
var _pending: Array[Dictionary] = []
var _spawn_timer := 0.0
var _hud_due := 0.0

func setup(owner_game: Node3D, episode: Dictionary, difficulty: String) -> void:
	game = owner_game
	levels = episode.get("levels", [])
	waves = episode.get("waves", [])
	difficulty_id = Difficulty.normalize(difficulty)

func level_count() -> int:
	return maxi(1, levels.size())

func level_for_step(step: int) -> int:
	for index: int in levels.size():
		if step in Array(levels[index].get("steps", [])).map(func(v): return int(v)):
			return index + 1
	return level_count()

func level_info(level: int) -> Dictionary:
	return levels[level - 1] if level >= 1 and level <= levels.size() else {}

func is_marked(marker: String) -> bool:
	return marker in game.defeated_enemies

func _mark(marker: String) -> void:
	if not is_marked(marker): game.defeated_enemies.append(marker)

## Forget transient wave actors after a checkpoint restore or restart.
func reset() -> void:
	for enemy in wave_enemies:
		if is_instance_valid(enemy):
			game.active_enemies.erase(enemy)
			enemy.queue_free()
	wave_enemies.clear()
	_pending.clear()
	_fired.clear()
	current_level = 0

func update(delta: float) -> void:
	if game == null or game.mission_state == null: return
	_prune()
	var step: int = game.mission_state.current_step_index
	var level := level_for_step(step)
	if level != current_level:
		_enter_level(level)
	_check_wave_triggers(step)
	_process_pending(delta)
	_check_level_clear(step)
	_hud_due -= delta
	if _hud_due <= 0.0:
		_hud_due = 0.25
		_push_hud()

## Dead non-boss enemies free themselves after 15 s; drop stale references.
func _prune() -> void:
	for list: Array in [game.active_enemies, wave_enemies]:
		for index: int in range(list.size() - 1, -1, -1):
			if not is_instance_valid(list[index]): list.remove_at(index)

func _enter_level(level: int) -> void:
	var first_time := current_level != 0 or not is_marked("level:%d" % level)
	current_level = level
	var info := level_info(level)
	var title := "LEVEL %d / %s" % [level, str(info.get("title", "")).to_upper()]
	if first_time and game.hud and game.has_entered_gameplay:
		game.hud.show_level_banner(title, "%s  ·  %s" % [str(info.get("location", "")), Difficulty.title(difficulty_id)])
		ZombieAudio.play_ui(game, "level_start", -8.0, 0.0)
	level_changed.emit(level, title)

# ── Waves ────────────────────────────────────────────────────────────────

func _check_wave_triggers(step: int) -> void:
	if not game.has_intro_weapon(): return
	for wave: Dictionary in waves:
		var id := str(wave.get("id", ""))
		if id.is_empty() or _fired.has(id) or is_marked("wave:" + id): continue
		if int(wave.get("step", -1)) != step: continue
		match str(wave.get("trigger", "step")):
			"boss_health":
				var boss: Node3D = game.brute_boss
				if not is_instance_valid(boss) or boss.is_dead() or boss.get_meta("encounter_waiting", false): continue
				if boss.health > boss.max_health * float(wave.get("threshold", 0.5)): continue
			"step":
				pass
			_:
				continue
		_fire_wave(wave)

func wave_size(wave: Dictionary) -> int:
	if str(wave.get("count_key", "")) == "boss_adds":
		return int(Difficulty.settings(difficulty_id).boss_adds)
	return Difficulty.scaled_count(int(wave.get("count", 3)), difficulty_id)

func _fire_wave(wave: Dictionary) -> void:
	var id := str(wave.id)
	_fired[id] = true
	var types: Array = wave.get("types", ["walker"])
	for index: int in wave_size(wave):
		_pending.append({"wave": wave, "id": "%s_%d" % [id, index + 1], "type": str(types[index % types.size()])})
	_spawn_timer = float(wave.get("delay", 0.6))
	if game.hud and not str(wave.get("banner", "")).is_empty():
		game.hud.show_banner_message(str(wave.banner), 3.5)

func _process_pending(delta: float) -> void:
	if _pending.is_empty(): return
	_spawn_timer -= delta
	if _spawn_timer > 0.0: return
	var entry: Dictionary = _pending.pop_front()
	_spawn_timer = float(entry.wave.get("interval", 0.9))
	spawn_wave_enemy(entry.wave, str(entry.id), str(entry.type))

func _pick_spawn_point(points: Array) -> Vector3:
	var player_pos: Vector3 = game.player.global_position
	var best := Vector3.INF
	var best_score := -INF
	for raw: Variant in points:
		if not raw is Array or raw.size() < 3: continue
		var point: Vector3 = game._ground_point(Vector3(float(raw[0]), float(raw[1]), float(raw[2])))
		var distance := point.distance_to(player_pos)
		var score := minf(distance, 22.0) + randf() * 3.0
		if distance < 6.0: score -= 100.0
		if game.player.camera and game.player.camera.is_position_in_frustum(point + Vector3.UP): score -= 15.0
		if score > best_score:
			best_score = score
			best = point
	return best

func spawn_wave_enemy(wave: Dictionary, enemy_id: String, type: String) -> Node3D:
	var point := _pick_spawn_point(wave.get("points", []))
	if not point.is_finite(): return null
	var enemy := EnemyController.new()
	enemy.enemy_id = enemy_id
	enemy.enemy_type = type
	enemy.difficulty = Difficulty.settings(difficulty_id)
	enemy.relentless = true
	enemy.position = point + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	enemy.set_meta("wave", str(wave.id))
	enemy.set_meta("level", int(wave.get("level", current_level)))
	game.add_child(enemy)
	game.register_enemy(enemy)
	wave_enemies.append(enemy)
	if is_instance_valid(game.player):
		enemy.target_player = game.player
		enemy.last_known_position = game.player.global_position
		enemy.look_at(Vector3(game.player.global_position.x, enemy.global_position.y, game.player.global_position.z), Vector3.UP)
		enemy._become_aggressive(false)
	return enemy

# ── Level progress ───────────────────────────────────────────────────────

func level_hostiles(level: int) -> int:
	var count := 0
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and not enemy.is_dead() and int(enemy.get_meta("level", 1)) == level:
			count += 1
	for entry: Dictionary in _pending:
		if int(entry.wave.get("level", level)) == level: count += 1
	return count

func _waves_done(level: int, step: int) -> bool:
	for wave: Dictionary in waves:
		if int(wave.get("level", 0)) != level: continue
		var id := str(wave.get("id", ""))
		if is_marked("wave:" + id) or _fired.has(id): continue
		# A wave whose step already passed (e.g. a boss killed before its
		# adds threshold) is skipped; one still ahead blocks the clear.
		if step > int(wave.get("step", -1)): continue
		return false
	return true

func _check_level_clear(step: int) -> void:
	if not game.has_intro_weapon() or is_marked("level:%d" % current_level): return
	if level_hostiles(current_level) > 0 or not _waves_done(current_level, step): return
	for wave: Dictionary in waves:
		if int(wave.get("level", 0)) == current_level and _fired.has(str(wave.get("id", ""))):
			_mark("wave:" + str(wave.id))
	_mark("level:%d" % current_level)
	if game.hud:
		game.hud.show_level_banner("LEVEL %d CLEARED" % current_level, "Checkpoint saved. Catch your breath.")
	ZombieAudio.play_ui(game, "level_clear", -8.0, 0.0)
	level_cleared.emit(current_level)
	game._create_checkpoint("cp_level_%d" % current_level, "Level %d Cleared" % current_level)

func status_text() -> String:
	var info := level_info(current_level)
	var hostiles := level_hostiles(current_level)
	var state := "%d HOSTILE%s" % [hostiles, "" if hostiles == 1 else "S"] if hostiles > 0 else "AREA CLEAR"
	return "LVL %d/%d  %s  ·  %s  ·  %s" % [current_level, level_count(), str(info.get("title", "")).to_upper(), state, Difficulty.title(difficulty_id).to_upper()]

func _push_hud() -> void:
	if game.hud and game.hud.has_method("update_level_status"):
		game.hud.update_level_status(status_text())
