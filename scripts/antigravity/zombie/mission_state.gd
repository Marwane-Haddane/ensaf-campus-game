extends RefCounted
## Authored Mission and Progression State Machine for ZB-2026-001 (After Hours)

signal objective_updated(step_id: String, text: String, is_final: bool)
signal mission_completed(stats: Dictionary)
signal mission_failed(reason: String)
signal objective_completed(step_id: String, experience: int, scrap: int)

var mission_id: String = "ZB-2026-001"
var current_step_index: int = 0
var completed_steps: Array[String] = []

var power_restored: bool = false
var installed_power_parts: Array[String] = []
var survivor_talked: bool = false
var boss_killed: bool = false
var extracted: bool = false

var start_time_msec: int = 0
var total_kills: int = 0
var total_damage_dealt: float = 0.0
var killed_enemy_ids: Array[String] = []
var survivor_introduced := false
var _active_play_msec := 0.0
var _uses_active_clock := false

const OBJECTIVE_REWARDS := {
	"obj_explore":[20,0],"obj_fuse":[35,0],"obj_relay":[35,0],
	"obj_power":[60,10],"obj_survivor":[45,5],"obj_boss":[80,15],"obj_extract":[100,0]
}

const STEPS: Array[Dictionary] = [
	{
		"id": "obj_explore",
		"text": "Explore Reception and find the emergency pistol case.",
		"hint": "Walk to Reception and look for the marked pistol case. Then recover the breaker fuse before crossing the courtyard.",
		"chapter":"01 / STRANDED", "radio":"The emergency gate is offline. Find supplies before entering the buildings."
	},
	{
		"id": "obj_fuse",
		"text": "Recover the Main Breaker Fuse from Reception.",
		"hint": "Search the reception counter. Nearby scrap pays for one workbench upgrade: protection or magazine capacity.",
		"chapter":"02 / THE BROKEN GRID", "radio":"Shaun left a replacement fuse at Reception. The second component is in the glazed entrance."
	},
	{
		"id": "obj_relay",
		"text": "Recover the Control Bus Relay at the glazed entrance.",
		"hint": "Follow the portico to the glass doors. Watch the corners; draw isolated infected away from the doorway.",
		"chapter":"03 / CROSSING CAMPUS", "radio":"Two components, one working circuit. Stay mobile and keep a reserve magazine."
	},
	{
		"id": "obj_power",
		"text": "Install both components at the Security Substation.",
		"hint": "The breaker panel is inside Security. It consumes the fuse and relay; collect medical supplies before returning outside.",
		"chapter":"04 / POWER RETURNS", "radio":"Restore the emergency circuit. Shaun is waiting to confirm the evacuation route."
	},
	{
		"id": "obj_survivor",
		"text": "Check in with Shaun by the Auditorium.",
		"hint": "Speak to Shaun after restoring power. He will confirm the gate route and warn you about the brute.",
		"chapter":"05 / NOBODY LEFT BEHIND", "radio":"The lights are back. Find Shaun and make sure nobody is being left inside."
	},
	{
		"id": "obj_boss",
		"text": "Clear the brute blocking the evacuation route.",
		"hint": "Keep open space behind you. Dodge its committed swing, then fire during recovery. Do not trade hits at close range.",
		"chapter":"06 / HOLD THE COURTYARD", "radio":"The gate has power, but the brute controls the path. Clear it before approaching the truck."
	},
	{
		"id": "obj_extract",
		"text": "Board the extraction truck at the campus gate.",
		"hint": "Follow the headlights and use Interact to board. Use the movement controls to drive the truck through the open gate.",
		"chapter":"07 / AFTER HOURS", "radio":"The route is clear. Get to the truck and leave the campus together."
	}
]

func _init() -> void:
	start_time_msec = Time.get_ticks_msec()

func start() -> void:
	reset()

func reset() -> void:
	current_step_index = 0
	completed_steps.clear()
	collected_quest_items.clear()
	power_restored = false
	installed_power_parts.clear()
	survivor_talked = false
	boss_killed = false
	extracted = false
	total_kills = 0
	total_damage_dealt = 0.0
	killed_enemy_ids.clear()
	survivor_introduced = false
	_active_play_msec = 0.0
	_uses_active_clock = false
	start_time_msec = Time.get_ticks_msec()
	_notify_current()

func get_current_step() -> Dictionary:
	if current_step_index >= 0 and current_step_index < STEPS.size():
		return STEPS[current_step_index]
	return {"id": "done", "text": "Mission Complete", "hint": ""}

func get_current_objective_text() -> String:
	return str(get_current_step().get("text", ""))

func get_current_hint() -> String:
	return str(get_current_step().get("hint", ""))

var collected_quest_items: Array[String] = []

func on_event(event_name: String, data: Dictionary = {}) -> void:
	if extracted: return
	match event_name:
		"pickup_item":
			var item_id: String = data.get("item_id", "")
			if item_id.is_empty() or item_id in collected_quest_items: return
			collected_quest_items.append(item_id)
			
			if current_step_index == 0 and item_id == "item_intro_pistol":
				_advance_step() # Any pickup completes exploration step
			
			_evaluate_quest_progress()
		
		"power_restored":
			power_restored = true
			_evaluate_quest_progress()
		
		"talk_survivor":
			survivor_introduced = true
			# The introductory conversation is a lead, not the later safety
			# check-in. The survivor supports repeat interaction after power.
			if power_restored: survivor_talked = true
			_evaluate_quest_progress()
		
		"boss_killed":
			boss_killed = true
			_evaluate_quest_progress()
		
		"reach_extraction":
			if current_step_index == 6 and power_restored and survivor_talked and boss_killed:
				extracted = true
				_advance_step()
				mission_completed.emit(get_completion_summary())

func get_completion_summary() -> Dictionary:
	var elapsed_sec := float(get_elapsed_msec()) / 1000.0
	return {
		"mission_id": mission_id,
		"time_seconds": elapsed_sec,
		"time_formatted": "%02d:%02d" % [int(elapsed_sec) / 60, int(elapsed_sec) % 60],
		"kills": total_kills,
		"damage_dealt": total_damage_dealt,
		"completed": extracted,
		"completed_objectives": completed_steps.size(),
		"survivor_safe": survivor_talked
	}

func _evaluate_quest_progress() -> void:
	if current_step_index == 1 and "item_power_fuse" in collected_quest_items:
		_advance_step()
	if current_step_index == 2 and "item_power_relay" in collected_quest_items:
		_advance_step()
	if current_step_index == 3 and power_restored:
		_advance_step()
	if current_step_index == 4 and survivor_talked:
		_advance_step()
	if current_step_index == 5 and boss_killed:
		_advance_step()

func record_kill(_damage: float = 0.0, enemy_id: String = "") -> bool:
	if not enemy_id.is_empty():
		if enemy_id in killed_enemy_ids: return false
		killed_enemy_ids.append(enemy_id)
	total_kills += 1
	# Damage is recorded by actual hits. Adding an enemy's maximum health at
	# death double-counted the very same shots in the previous debrief.
	return true

func record_damage(amount: float) -> void:
	if is_finite(amount) and amount>0: total_damage_dealt += amount

func tick_playtime(delta: float) -> void:
	if not is_finite(delta) or delta<=0 or extracted: return
	_uses_active_clock = true
	_active_play_msec += delta*1000.0

func get_elapsed_msec() -> int:
	return int(_active_play_msec) if _uses_active_clock else maxi(0,Time.get_ticks_msec()-start_time_msec)

func _advance_step() -> void:
	if current_step_index < STEPS.size():
		var finished_step: String = str(STEPS[current_step_index].id)
		if not finished_step in completed_steps:
			completed_steps.append(finished_step)
			var reward: Array = OBJECTIVE_REWARDS.get(finished_step,[0,0])
			objective_completed.emit(finished_step,int(reward[0]),int(reward[1]))
		current_step_index += 1
		_notify_current()

func _notify_current() -> void:
	var cur := get_current_step()
	var is_final := (current_step_index == STEPS.size() - 1)
	objective_updated.emit(str(cur.id), str(cur.text), is_final)

func capture_state() -> Dictionary:
	return {
		"current_step_index": current_step_index,
		"completed_steps": completed_steps.duplicate(),
		"collected_quest_items": collected_quest_items.duplicate(),
		"power_restored": power_restored,
		"installed_power_parts": installed_power_parts.duplicate(),
		"survivor_talked": survivor_talked,
		"boss_killed": boss_killed,
		"extracted": extracted,
		"total_kills": total_kills,
		"total_damage_dealt": total_damage_dealt,
		"elapsed_msec":get_elapsed_msec(),"killed_enemy_ids":killed_enemy_ids.duplicate(),
		"survivor_introduced":survivor_introduced,"active_clock":_uses_active_clock
	}

func restore_state(data: Dictionary) -> void:
	current_step_index = clampi(int(data.get("current_step_index", 0)),0,STEPS.size())
	completed_steps.clear()
	for s in data.get("completed_steps", []):
		if str(s) in OBJECTIVE_REWARDS and not str(s) in completed_steps: completed_steps.append(str(s))
	collected_quest_items.clear()
	for q in data.get("collected_quest_items", []):
		if not str(q).is_empty() and not str(q) in collected_quest_items: collected_quest_items.append(str(q))
	power_restored = bool(data.get("power_restored", false))
	installed_power_parts.clear()
	var saved_parts: Variant = data.get("installed_power_parts", [])
	for part in ["item_power_fuse", "item_power_relay"]:
		if power_restored or (saved_parts is Array and part in saved_parts):
			installed_power_parts.append(part)
	survivor_talked = bool(data.get("survivor_talked", false))
	boss_killed = bool(data.get("boss_killed", false))
	extracted = bool(data.get("extracted", false))
	total_kills = maxi(0,int(data.get("total_kills", 0)))
	total_damage_dealt = maxf(0.0,float(data.get("total_damage_dealt", 0.0)))
	killed_enemy_ids.clear()
	for id: Variant in data.get("killed_enemy_ids",[]):
		if id is String and not id.is_empty() and not id in killed_enemy_ids: killed_enemy_ids.append(id)
	survivor_introduced = bool(data.get("survivor_introduced",survivor_talked))
	_active_play_msec = maxf(0.0,float(data.get("elapsed_msec",0)))
	_uses_active_clock = bool(data.get("active_clock",false))
	start_time_msec = Time.get_ticks_msec() - int(_active_play_msec)
	_notify_current()
