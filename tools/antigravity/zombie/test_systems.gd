@tool
extends SceneTree
## Unit test suite for Zombie RPG core gameplay systems:
## Inventory, SaveStore, MissionState, Weapon, Adapter, and Metadata Contract.

var report := {
	"total_checks": 0,
	"passed_checks": 0,
	"failures": []
}

func _init() -> void:
	call_deferred("run_all_tests")

func assert_true(condition: bool, test_name: String, detail: Variant = null) -> void:
	report["total_checks"] += 1
	if condition:
		report["passed_checks"] += 1
	else:
		report["failures"].append({"test": test_name, "detail": str(detail)})
		print("[FAIL] ", test_name, " detail: ", detail)

func run_all_tests() -> void:
	print("=== Running Zombie RPG Core Systems Tests ===")
	test_inventory()
	test_save_store()
	test_mission_state()
	test_weapon_system()
	test_mode_adapter()
	test_metadata_contract()
	
	print("\n--- Test Results ---")
	print("Total: ", report["total_checks"], " Passed: ", report["passed_checks"], " Failures: ", report["failures"].size())
	if report["failures"].is_empty():
		print("ALL SYSTEMS TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		print("TESTS FAILED with ", report["failures"].size(), " failures.")
		quit(1)

func test_inventory() -> void:
	print("Testing Inventory...")
	var inv_script: Script = load("res://scripts/antigravity/zombie/inventory.gd")
	var inv: RefCounted = inv_script.new()
	
	# Initial items
	assert_true(inv.get_item_count("ammo") == 36, "Initial ammo is 36")
	assert_true(inv.get_item_count("medkit") == 1, "Initial medkit is 1")
	assert_true(inv.get_item_count("scrap") == 0, "Initial scrap is 0")
	
	# Add items
	inv.add_item("scrap", 30)
	assert_true(inv.get_item_count("scrap") == 30, "Added 30 scrap")
	assert_true(inv.can_afford_upgrade(25), "Can afford 25 scrap upgrade")
	
	# Buy upgrade
	var bought: bool = bool(inv.buy_upgrade("upgrade_armor", 25))
	assert_true(bought, "Upgrade armor bought successfully")
	assert_true(inv.get_item_count("scrap") == 5, "Scrap deducted to 5")
	assert_true(inv.has_upgrade("upgrade_armor"), "Has upgrade_armor in list")
	
	# Idempotent upgrade purchase (cannot buy same upgrade twice)
	var bought_again: bool = bool(inv.buy_upgrade("upgrade_armor", 5))
	assert_true(not bought_again, "Cannot buy same upgrade twice")
	
	# Quest items
	inv.add_item("item_power_fuse", 1)
	inv.add_item("item_power_relay", 1)
	assert_true(inv.has_item("item_power_fuse"), "Has power fuse")
	assert_true(inv.has_item("item_power_relay"), "Has power relay")
	
	# Weapon slots
	assert_true(inv.get_weapon_slots().size() == 2, "Inventory has 2 weapon slots")
	assert_true(inv.get_equipped_weapon().get("id") == "pistol", "Default equipped weapon is pistol")
	var switched = inv.switch_slot(1)
	assert_true(switched.get("id") == "scorpion", "Switched to slot 2 scorpion")
	assert_true(inv.get_equipped_weapon().get("id") == "scorpion", "Equipped weapon is now scorpion")
	inv.switch_slot(0)
	assert_true(inv.get_equipped_weapon().get("id") == "pistol", "Switched back to slot 1 pistol")

	# Capture & Restore
	var cap: Dictionary = inv.capture_state()
	var inv2: RefCounted = inv_script.new()
	inv2.restore_state(cap)
	assert_true(inv2.get_item_count("scrap") == 5, "Restored scrap count")
	assert_true(inv2.has_upgrade("upgrade_armor"), "Restored upgrades list")
	assert_true(inv2.has_item("item_power_fuse"), "Restored power fuse")
	assert_true(inv2.get_weapon_slots().size() == 2, "Restored weapon slots")
	assert_true(inv2.get_equipped_weapon().get("id") == "pistol", "Restored equipped weapon")

func test_save_store() -> void:
	print("Testing SaveStore...")
	var save_script: Script = load("res://scripts/antigravity/zombie/save_store.gd")
	var store: RefCounted = save_script.new()
	
	# Verify overridable path
	assert_true(store.path == "user://ensagames/saves/zombie_rpg/checkpoint.json", "Production path default is set")
	var test_path := "user://ensagames/saves/zombie_rpg/test_checkpoint_custom.json"
	store.path = test_path
	assert_true(store.path == test_path, "Store path is overridable for isolated tests")
	
	# Ensure clean test state
	store.delete_save()
	assert_true(not store.has_save(), "Save file deleted for test")
	
	# Base valid payload
	var valid_payload: Dictionary = {
		"schema_version": 1,
		"mode_id": "zombie_rpg",
		"mission_id": "ZB-2026-001",
		"checkpoint_id": "test_cp_01",
		"checkpoint_name": "Test Checkpoint",
		"player_state": {
			"health": 85.0,
			"max_health": 100.0,
			"stamina": 90.0,
			"max_stamina": 100.0,
			"position": [-27.0, 1.25, -85.0],
			"rotation_y": 0.0,
			"camera_pitch": 0.0
		},
		"objectives": {
			"current_step_index": 2,
			"completed_steps": ["obj_explore", "obj_fuse"],
			"collected_quest_items": ["item_power_fuse"],
			"power_restored": false,
			"survivor_talked": false,
			"boss_killed": false,
			"extracted": false
		},
		"inventory": {
			"items": {"ammo": 24, "medkit": 2, "scrap": 15},
			"upgrades": ["upgrade_armor"],
			"weapon_slots": [{"id": "pistol", "unlocked": true}, {"id": "scorpion", "unlocked": true}],
			"active_slot_index": 0
		},
		"defeated_enemies": ["walker_01", "walker_02"],
		"collected_pickups": ["ammo_plaza_1", "item_power_fuse"]
	}
	
	# Schema & Mode/Mission Validation
	assert_true(store.validate(valid_payload), "Valid payload passes validation")
	
	var bad_mode = valid_payload.duplicate(true)
	bad_mode["mode_id"] = "incident_response"
	assert_true(not store.validate(bad_mode), "Invalid mode_id fails validation")
	
	var bad_mission = valid_payload.duplicate(true)
	bad_mission["mission_id"] = "IR-2026-001"
	assert_true(not store.validate(bad_mission), "Invalid mission_id fails validation")
	
	var bad_schema = valid_payload.duplicate(true)
	bad_schema["schema_version"] = 99
	assert_true(not store.validate(bad_schema), "Invalid schema_version fails validation")
	
	# Finite and ranged player values validation
	var bad_health = valid_payload.duplicate(true)
	bad_health["player_state"]["health"] = 250.0 # Exceeds max_health 100.0
	assert_true(not store.validate(bad_health), "Health > max_health fails validation")
	
	var neg_health = valid_payload.duplicate(true)
	neg_health["player_state"]["health"] = -10.0
	assert_true(not store.validate(neg_health), "Negative health fails validation")
	
	var inf_health = valid_payload.duplicate(true)
	inf_health["player_state"]["health"] = INF
	assert_true(not store.validate(inf_health), "Infinite health fails validation")
	
	var bad_pos = valid_payload.duplicate(true)
	bad_pos["player_state"]["position"] = [0.0, NAN, 0.0]
	assert_true(not store.validate(bad_pos), "NaN position fails validation")
	
	# Quest and inventory validation
	var bad_scrap = valid_payload.duplicate(true)
	bad_scrap["inventory"]["items"]["scrap"] = -5
	assert_true(not store.validate(bad_scrap), "Negative scrap count fails validation")
	
	var bad_step = valid_payload.duplicate(true)
	bad_step["objectives"]["current_step_index"] = 999
	assert_true(not store.validate(bad_step), "Out-of-range step index fails validation")
	
	# Write valid checkpoint
	var written: bool = bool(store.write_save(valid_payload))
	assert_true(written, "Wrote valid checkpoint successfully")
	assert_true(store.has_save(), "Save file exists after write")
	
	# Read checkpoint
	var read_back: Dictionary = store.read_save()
	assert_true(read_back.get("mode_id") == "zombie_rpg", "Mode ID is zombie_rpg")
	assert_true(read_back.get("mission_id") == "ZB-2026-001", "Mission ID is ZB-2026-001")
	assert_true(read_back.get("checkpoint_id") == "test_cp_01", "Checkpoint ID restored")
	assert_true(float(read_back.get("player_state", {}).get("health")) == 85.0, "Player health restored")
	
	# Summary validation
	var summ: Dictionary = store.summary(read_back)
	assert_true(bool(summ.get("valid")), "Save summary is valid")
	assert_true(str(summ.get("checkpoint_name")) == "Test Checkpoint", "Summary contains checkpoint name")
	assert_true(summ.has("label"), "Summary contains formatted label")
	assert_true(summ.has("scrap"), "Summary contains scrap count")
	
	var empty_summ: Dictionary = store.summary({})
	assert_true(empty_summ.is_empty(), "Empty payload summary returns empty dictionary")
	
	# Atomic commit: invalid save rejection preserves the existing valid file untouched
	var invalid_payload := valid_payload.duplicate(true)
	invalid_payload["mode_id"] = "corrupted_mode"
	var write_invalid = store.write_save(invalid_payload)
	assert_true(not write_invalid, "Writing invalid payload rejected")
	var preserved = store.read_save()
	assert_true(preserved.get("mode_id") == "zombie_rpg", "Last valid save was preserved untouched")
	assert_true(float(preserved.get("player_state", {}).get("health")) == 85.0, "Preserved save state unchanged")
	
	# Clean up test save
	store.delete_save()
	assert_true(not store.has_save(), "Test save cleaned up")

func test_mission_state() -> void:
	print("Testing MissionState...")
	var m_script: Script = load("res://scripts/antigravity/zombie/mission_state.gd")
	var mission: RefCounted = m_script.new()
	mission.start()
	
	# Step 0: Explore
	assert_true(mission.get_current_step().get("id") == "obj_explore", "Initial objective is explore")
	
	# Event: pickup ammo advances to fuse
	mission.on_event("pickup_item", {"item_id": "ammo_plaza_1"})
	assert_true(mission.get_current_step().get("id") == "obj_fuse", "Advanced to obj_fuse")
	
	# Event: pickup fuse advances to relay
	mission.on_event("pickup_item", {"item_id": "item_power_fuse"})
	assert_true(mission.get_current_step().get("id") == "obj_relay", "Advanced to obj_relay")
	
	# Event: pickup relay advances to restore power
	mission.on_event("pickup_item", {"item_id": "item_power_relay"})
	assert_true(mission.get_current_step().get("id") == "obj_power", "Advanced to obj_power")
	
	# Event: power restored advances to survivor
	mission.on_event("power_restored")
	assert_true(mission.get_current_step().get("id") == "obj_survivor", "Advanced to obj_survivor")
	assert_true(bool(mission.get("power_restored")), "Power restored flag is true")
	
	# Event: talk to survivor advances to boss
	mission.on_event("talk_survivor")
	assert_true(mission.get_current_step().get("id") == "obj_boss", "Advanced to obj_boss")
	
	# Event: kill boss advances to extraction
	mission.on_event("boss_killed")
	assert_true(mission.get_current_step().get("id") == "obj_extract", "Advanced to obj_extract")
	
	# Event: reach extraction triggers mission completion
	var state_tracker := {"completed": false}
	mission.mission_completed.connect(func(stats: Dictionary):
		state_tracker["completed"] = true
		assert_true(bool(stats.get("completed")), "Stats show mission completed")
	)
	mission.on_event("reach_extraction")
	assert_true(bool(state_tracker["completed"]), "Mission completed signal fired")
	
	# Test mission reset restores state cleanly
	mission.reset()
	assert_true(mission.get_current_step().get("id") == "obj_explore", "Mission reset restored step to obj_explore")
	assert_true(mission.total_kills == 0, "Mission reset cleared kills")
	assert_true(not bool(mission.get("power_restored")), "Mission reset cleared power_restored")
	assert_true(not bool(mission.get("extracted")), "Mission reset cleared extracted flag")
	
	# Out-of-order test (Relay collected BEFORE Fuse - softlock bug prevention)
	var mission_ooo: RefCounted = m_script.new()
	mission_ooo.start()
	mission_ooo.on_event("pickup_item", {"item_id": "ammo_plaza_1"})
	assert_true(mission_ooo.get_current_step().get("id") == "obj_fuse", "OOO: on obj_fuse")
	mission_ooo.on_event("pickup_item", {"item_id": "item_power_relay"})
	assert_true(mission_ooo.get_current_step().get("id") == "obj_fuse", "OOO: still on obj_fuse because relay is step 2")
	mission_ooo.on_event("pickup_item", {"item_id": "item_power_fuse"})
	assert_true(mission_ooo.get_current_step().get("id") == "obj_power", "OOO: cleanly advanced to obj_power without softlock")

func test_weapon_system() -> void:
	print("Testing Weapon System...")
	var w_script: Script = load("res://scripts/antigravity/zombie/weapon_controller.gd")
	var wc: Node3D = w_script.new()
	
	# Initial configuration
	assert_true(wc.current_weapon_id == "pistol", "Initial weapon is pistol")
	assert_true(wc.mag_ammo == 12, "Pistol mag is 12")
	assert_true(wc.reserve_ammo == 36, "Pistol reserve is 36")
	assert_true(wc.get_current_weapon_name() != "", "Weapon name helper works")
	
	# Switch to scorpion
	var switched: bool = wc.switch_to_slot("scorpion")
	assert_true(switched, "Switched to scorpion successfully")
	assert_true(wc.current_weapon_id == "scorpion", "Current weapon is scorpion")
	assert_true(wc.mag_ammo == 20, "Scorpion initial mag is 20")
	assert_true(wc.reserve_ammo == 60, "Scorpion initial reserve is 60")
	assert_true(wc.is_automatic(), "Scorpion has automatic capability")
	
	# Switch back to pistol
	wc.switch_to_slot("pistol")
	assert_true(wc.current_weapon_id == "pistol", "Switched back to pistol")
	assert_true(wc.mag_ammo == 12, "Pistol ammo retained")
	
	# Switch to melee barbed bat
	var switched_bat: bool = wc.switch_to_slot("bat")
	assert_true(switched_bat, "Switched to bat successfully")
	assert_true(wc.current_weapon_id == "bat", "Current weapon is bat")
	assert_true(bool(wc.call("is_melee")), "Bat has melee attribute")
	assert_true(wc.call("quick_melee"), "Quick melee executes successfully")
	wc.switch_to_slot("pistol")
	
	# Reload cancellation
	wc.mag_ammo = 0
	wc.start_reload()
	assert_true(wc.is_reloading, "Weapon is reloading")
	wc.cancel_reload()
	assert_true(not wc.is_reloading, "Weapon reload successfully cancelled")
	
	# Test reset_state
	wc.mag_ammo = 2
	wc.reserve_ammo = 5
	wc.apply_extended_mag(18, "pistol")
	wc.reset_state()
	assert_true(wc.mag_ammo == 12, "Reset restored mag to 12")
	assert_true(wc.mag_capacity == 12, "Reset restored mag capacity to 12")
	assert_true(wc.reserve_ammo == 36, "Reset restored reserve to 36")
	
	# Block firing when player input disabled
	var p_ctrl = CharacterBody3D.new()
	p_ctrl.set_script(load("res://scripts/antigravity/zombie/player_controller.gd"))
	p_ctrl.input_enabled = false
	wc.player = p_ctrl
	assert_true(not wc.trigger_fire(), "Weapon fire blocked when player input disabled")
	assert_true(not wc.switch_to_slot("scorpion"), "Weapon switch blocked when player input disabled")
	p_ctrl.free()
	wc.player = null
	
	wc.free()

func test_mode_adapter() -> void:
	print("Testing Mode Adapter...")
	var adapter_script: Script = load("res://scripts/antigravity/zombie/zombie_mode_adapter.gd")
	var adapter: RefCounted = adapter_script.new()
	
	assert_true(adapter.entry_scene() == "res://scenes/antigravity/zombie/zombie_game.tscn", "Adapter entry scene path")
	var reqs: Array[String] = adapter.required_resources()
	assert_true(reqs.has("res://scenes/antigravity/zombie/zombie_game.tscn"), "Required resources has entry scene")
	assert_true(reqs.has("res://assets/antigravity/zombie/route_navmesh.res"), "Required resources has navmesh")
	
	# Adapter shares single authoritative save service instance
	var svc = adapter.save_service()
	assert_true(svc != null, "Adapter exposes save service")
	assert_true(svc == adapter.saves, "save_service() returns identical authoritative instance")
	assert_true(svc.path.begins_with("user://"), "Save service path is valid user path")
	
	# Invalid restore rejection
	var invalid_restore = adapter.restore(null, {})
	assert_true(not invalid_restore, "Restoring with null game returns false")
	assert_true(adapter.last_error != "", "Adapter sets last_error on invalid restore")
	assert_true(adapter.save_service().last_error != "", "Adapter sets saves.last_error on invalid restore")

func test_metadata_contract() -> void:
	print("Testing Metadata Contract...")
	var reg_path := "res://antigravity/zombie/MODE-REGISTRATION.json"
	assert_true(FileAccess.file_exists(reg_path), "MODE-REGISTRATION.json exists")
	
	var text := FileAccess.get_file_as_string(reg_path)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "MODE-REGISTRATION parses as Dictionary")
	
	var data: Dictionary = parsed as Dictionary
	assert_true(data.get("id") == "zombie_rpg", "Mode id is zombie_rpg")
	assert_true(data.get("availability") == "available", "Availability is available")
	assert_true(FileAccess.file_exists(data.get("artwork_path", "")), "Artwork file exists on disk")
	
	var missions: Array = data.get("missions", [])
	assert_true(not missions.is_empty(), "Missions array not empty")
	
	var m0: Dictionary = missions[0]
	assert_true(m0.get("id") == "ZB-2026-001", "Mission ID is ZB-2026-001")
	assert_true(m0.get("title") == "After Hours", "Mission title is After Hours")
	
	# Requirement 7: Controls must be Array of {"action": "...", "binding": "..."}
	var controls: Variant = m0.get("controls")
	assert_true(controls is Array, "Controls is an Array, not prose String")
	var controls_arr: Array = controls as Array
	assert_true(controls_arr.size() >= 10, "Controls contains all required bindings")
	var valid_hints := true
	for hint in controls_arr:
		if not hint is Dictionary or not hint.has("action") or not hint.has("binding"):
			valid_hints = false
			break
	assert_true(valid_hints, "Each control hint is a dictionary with action and binding")
	
	# Checkpoints metadata
	var cps: Variant = m0.get("checkpoints")
	assert_true(cps is Array and cps.size() == 6, "Metadata contains 6 authored checkpoints")
	if cps is Array:
		var has_start := false
		for cp in cps:
			if cp.get("id") == "cp_start":
				has_start = true
		assert_true(has_start, "Checkpoints metadata includes cp_start")
