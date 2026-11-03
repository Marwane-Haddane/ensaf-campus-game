extends SceneTree
const Inventory = preload("res://scripts/antigravity/zombie/inventory.gd")
const Mission = preload("res://scripts/antigravity/zombie/mission_state.gd")
const Store = preload("res://scripts/antigravity/zombie/save_store.gd")
const Chest = preload("res://scripts/antigravity/zombie/loot_chest.gd")
var checks := 0
var failures: Array[String] = []
class Patient extends Node:
	var health := 20.0
	var max_health := 100.0
	func heal(amount: float) -> void: health = minf(max_health,health+amount)
class Game extends Node:
	var inventory: RefCounted
	var hud: Node
class StateOnlyCache extends Chest:
	# Exercise actual cache transactions and restore signals without asking the
	# headless dummy renderer to create/delete 3D meshes or audio generators.
	func _setup_collision_and_mesh() -> void: pass
	func _play_open_sound() -> void: pass
func _init() -> void: call_deferred("run_test")
func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("RPG_FAIL ",label)

func run_test() -> void:
	var inv := Inventory.new()
	var mission := Mission.new()
	mission.objective_completed.connect(func(id: String,xp: int,scrap: int): inv.claim_reward("objective:"+id,xp,scrap))
	mission.start()
	check(inv.get_rank()==1 and inv.get_medkit_healing()==40.0,"New arrivals start with baseline medicine")
	check(not inv.buy_upgrade("upgrade_armor",0) and not inv.buy_upgrade("fake_upgrade",-10),"Invalid or free upgrade purchases cannot create power")
	mission.on_event("pickup_item",{"item_id":"ammo_plaza_1"})
	mission.on_event("pickup_item",{"item_id":"ammo_plaza_1"})
	check(inv.experience==20 and mission.current_step_index==1,"A real supply event pays exploration once")
	mission.on_event("talk_survivor")
	check(mission.survivor_introduced and not mission.survivor_talked,"Early dialogue introduces Shaun without completing the later safety check-in")
	mission.on_event("reach_extraction")
	check(not mission.extracted,"The gate cannot skip the objective chain")
	mission.on_event("pickup_item",{"item_id":"item_power_relay"})
	check(mission.current_step_index==1,"Out-of-order relay remains useful but does not skip fuse")
	mission.on_event("pickup_item",{"item_id":"item_power_fuse"})
	check(mission.current_step_index==3 and inv.experience==90,"Both component objectives advance from the recorded events")
	check(inv.get_rank()==2 and inv.get_medkit_healing()==50.0,"Objective progression improves real healing efficacy")
	var patient := Patient.new()
	check(inv.use_medkit(patient) and patient.health==70.0 and inv.get_item_count("medkit")==0,"A promoted responder consumes one medkit and heals the actual ranked amount")
	patient.health = 100
	inv.add_item("medkit",1)
	check(not inv.use_medkit(patient) and inv.get_item_count("medkit")==1,"Full-health use does not waste supplies")
	patient.health = 0
	check(not inv.use_medkit(patient),"A medkit cannot resurrect the dead outside checkpoint retry")
	patient.free()
	check(mission.record_kill(0,"walker_test") and not mission.record_kill(0,"walker_test"),"Repeated enemy death cannot inflate kill statistics")
	mission.record_damage(26)
	mission.record_damage(-100)
	check(mission.total_kills==1 and mission.total_damage_dealt==26,"Kill bookkeeping does not double-count hit damage")
	check(inv.award_enemy_reward("walker_test") and not inv.award_enemy_reward("walker_test"),"One enemy pays one XP/scrap reward")
	inv.add_item("scrap",30)
	check(inv.buy_upgrade("upgrade_extended_mag",25),"A route-level scrap investment installs a real authored upgrade")
	check(not inv.buy_upgrade("upgrade_extended_mag",25),"Equipment cannot be purchased twice")
	check(inv.get_upgrade_options()[1].owned,"Workbench options expose the installed upgrade state")
	mission.on_event("power_restored")
	mission.on_event("talk_survivor")
	check(mission.current_step_index==5 and mission.survivor_talked,"The post-power conversation completes Shaun's actual safety check-in")
	mission.on_event("boss_killed")
	var victories := [0]
	mission.mission_completed.connect(func(_stats: Dictionary): victories[0]+=1)
	mission.tick_playtime(2.5)
	mission.on_event("reach_extraction")
	mission.on_event("reach_extraction")
	check(victories[0]==1 and mission.current_step_index==7,"Extraction and victory rewards happen once")
	check(mission.completed_steps.size()==7,"The journal marks the final objective complete")
	check(mission.get_elapsed_msec()==2500,"The debrief uses actual active playtime rather than load time")
	check(inv.get_rank()==4 and inv.get_medkit_healing()==60.0,"A full episode reaches a bounded rank with an actual field-medicine benefit")
	var restored := Inventory.new()
	restored.restore_state(inv.capture_state())
	check(restored.experience==inv.experience and not restored.award_enemy_reward("walker_test"),"XP and reward identity survive checkpoint restoration")
	var old := Inventory.new()
	old.restore_state({"items":{"scrap":13},"upgrades":[],"weapon_slots":[],"active_slot_index":0})
	check(old.experience==0 and old.get_rank()==1 and old.get_item_count("scrap")==13,"Older inventory saves keep their resources and receive safe progression defaults")
	var mission_restore := Mission.new()
	mission_restore.restore_state(mission.capture_state())
	check(not mission_restore.record_kill(0,"walker_test") and mission_restore.get_elapsed_msec()==2500,"Restored debrief statistics remain idempotent")
	# Exercise the real cache object and the inventory restoration notification.
	var game := Game.new()
	game.name = "ZombieGame"
	game.inventory = restored
	root.add_child(game)
	var cache := StateOnlyCache.new()
	cache.chest_id = "persistent_cache_test"
	cache.loot_type = "scrap"
	cache.loot_amount = 25
	game.add_child(cache)
	var before: int = restored.get_item_count("scrap")
	cache.interact(null)
	cache.interact(null)
	check(restored.get_item_count("scrap")==before+25 and cache.is_opened,"Opening a real cache twice grants resources once")
	var saved: Dictionary = restored.capture_state()
	restored.reset()
	check(not cache.is_opened,"A new mission resets the cache's visual state with the ledger")
	restored.restore_state(saved)
	check(cache.is_opened and cache.get_interaction_prompt().is_empty(),"Checkpoint restoration synchronizes an opened cache without duplicate loot")
	game.free()
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://tools/zombie_polish/progression-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RPG_PROGRESSION_RESULT ",JSON.stringify(report))
	await process_frame
	quit(0 if failures.is_empty() else 1)
