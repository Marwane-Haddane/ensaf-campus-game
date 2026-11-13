extends RefCounted
## Survival & RPG Inventory System for Zombie RPG

signal inventory_changed
signal upgrade_purchased(upgrade_id: String)
signal medkit_used(amount: float)
signal progression_changed(summary: Dictionary)
signal reward_claimed(reward_id: String, experience: int, scrap: int)

const RANK_THRESHOLDS := [0, 60, 150, 300]
const RANK_TITLES := ["New arrival", "Field responder", "Campus defender", "Survivor"]
const UPGRADE_CATALOG := {
	"upgrade_armor":{"id":"upgrade_armor","title":"Kevlar reinforcement","cost":25,"benefit":"+50 max health and +50 healing","description":"+50 maximum health and 50 immediate healing. Best for close encounters."},
	"upgrade_extended_mag":{"id":"upgrade_extended_mag","title":"Extended magazines","cost":25,"benefit":"Pistol 12 to 18  ·  Scorpion 20 to 30","description":"Pistol 12→18; Scorpion 20→30. Fewer reloads, without creating free ammunition."}
}
var experience: int = 0
var claimed_rewards: Array[String] = []

var items: Dictionary = {
	"ammo": 36,
	"medkit": 1,
	"scrap": 0,
	"item_power_fuse": 0,
	"item_power_relay": 0
}

var upgrades: Array[String] = []

var weapon_slots: Array[Dictionary] = [
	{"slot": 1, "id": "pistol", "name": "9mm Tactical Pistol", "unlocked": true},
	{"slot": 2, "id": "scorpion", "name": "CZ Scorpion EVO 3", "unlocked": true}
]
var active_slot_index: int = 0

func reset() -> void:
	items = {
		"ammo": 36,
		"medkit": 1,
		"scrap": 0,
		"item_power_fuse": 0,
		"item_power_relay": 0
	}
	upgrades.clear()
	experience = 0
	claimed_rewards.clear()
	weapon_slots = [
		{"slot": 1, "id": "pistol", "name": "9mm Tactical Pistol", "unlocked": true},
		{"slot": 2, "id": "scorpion", "name": "Scorpion Machine Pistol", "unlocked": true}
	]
	active_slot_index = 0
	inventory_changed.emit()
	progression_changed.emit(get_progression_summary())

func add_item(id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	items[id] = mini(9999, get_item_count(id) + amount)
	if id.begins_with("item_power_"): items[id] = mini(1,items[id])
	inventory_changed.emit()

func remove_item(id: String, amount: int = 1) -> bool:
	if amount < 0: return false
	if amount == 0: return true
	var current: int = items.get(id, 0)
	if current < amount:
		return false
	items[id] = current - amount
	inventory_changed.emit()
	return true

func has_item(id: String, amount: int = 1) -> bool:
	return items.get(id, 0) >= amount

func get_item_count(id: String) -> int:
	return maxi(0,int(items.get(id, 0)))

func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in upgrades

func can_afford_upgrade(cost: int) -> bool:
	return cost > 0 and get_item_count("scrap") >= cost

func buy_upgrade(upgrade_id: String, cost: int = -1) -> bool:
	if not UPGRADE_CATALOG.has(upgrade_id) or has_upgrade(upgrade_id):
		return false
	var authored_cost: int = UPGRADE_CATALOG[upgrade_id].cost
	if cost != -1 and cost != authored_cost: return false
	cost = authored_cost
	if not remove_item("scrap", cost):
		return false
	upgrades.append(upgrade_id)
	upgrade_purchased.emit(upgrade_id)
	inventory_changed.emit()
	return true

func get_upgrade_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for id: String in ["upgrade_armor","upgrade_extended_mag"]:
		var option: Dictionary = UPGRADE_CATALOG[id].duplicate(true)
		option["owned"] = has_upgrade(id)
		option["can_buy"] = not option.owned and can_afford_upgrade(option.cost)
		option["reason"] = "Installed" if option.owned else ("Ready to install" if option.can_buy else "Need %d more scrap" % maxi(0,int(option.cost)-get_item_count("scrap")))
		options.append(option)
	return options

func claim_reward(reward_id: String, xp: int, scrap: int = 0, bonus_items: Dictionary = {}) -> bool:
	# Stable event IDs make objective, kill and cache rewards survive retries.
	if reward_id.is_empty() or reward_id.length()>160 or reward_id in claimed_rewards or claimed_rewards.size()>=1000 or xp<0 or scrap<0: return false
	for id: Variant in bonus_items:
		if not id is String or not bonus_items[id] is int or bonus_items[id]<0: return false
	claimed_rewards.append(reward_id)
	experience = mini(999999,experience+xp)
	items["scrap"] = mini(9999,get_item_count("scrap")+scrap)
	for id: String in bonus_items:
		items[id] = mini(9999,get_item_count(id)+int(bonus_items[id]))
	inventory_changed.emit()
	progression_changed.emit(get_progression_summary())
	reward_claimed.emit(reward_id,xp,scrap)
	return true

func has_claimed_reward(reward_id: String) -> bool:
	return reward_id in claimed_rewards

func award_enemy_reward(enemy_id: String, is_boss: bool = false) -> bool:
	if enemy_id.is_empty(): return false
	return claim_reward("enemy:"+enemy_id,70 if is_boss else 12,15 if is_boss else 3)

func get_rank() -> int:
	var result := 1
	for threshold: int in RANK_THRESHOLDS:
		if experience>=threshold: result += 1
	return mini(RANK_THRESHOLDS.size(),result-1)

func get_medkit_healing() -> float:
	return 40.0+10.0*minf(2.0,float(get_rank()-1))

func get_progression_summary() -> Dictionary:
	var rank: int = get_rank()
	var start_xp: int = RANK_THRESHOLDS[rank-1]
	var next_xp: int = RANK_THRESHOLDS[rank] if rank<RANK_THRESHOLDS.size() else 0
	return {"xp":experience,"rank":rank,"rank_title":RANK_TITLES[rank-1],"rank_start_xp":start_xp,"next_rank_xp":next_xp,
		"progress":clampf(float(experience-start_xp)/float(next_xp-start_xp),0,1) if next_xp>start_xp else 1.0,"medkit_healing":get_medkit_healing()}

func use_medkit(player: Node) -> bool:
	if not has_item("medkit", 1):
		return false
	if player == null or not is_instance_valid(player):
		return false
	if not player.has_method("heal"): return false
	var cur_health: float = float(player.get("health"))
	var max_health: float = float(player.get("max_health"))
	if not is_finite(cur_health) or not is_finite(max_health) or cur_health<=0 or cur_health >= max_health:
		return false # Already at full health
	
	remove_item("medkit", 1)
	var heal_val: float = minf(get_medkit_healing(),max_health-cur_health)
	player.call("heal", heal_val)
	medkit_used.emit(heal_val)
	return true

func get_equipped_weapon() -> Dictionary:
	if active_slot_index >= 0 and active_slot_index < weapon_slots.size():
		return weapon_slots[active_slot_index]
	return {}

func get_weapon_slots() -> Array[Dictionary]:
	return weapon_slots

func switch_slot(index: int) -> Dictionary:
	if index >= 0 and index < weapon_slots.size():
		var slot_info = weapon_slots[index]
		if bool(slot_info.get("unlocked", false)):
			active_slot_index = index
			inventory_changed.emit()
			return slot_info
	return {}

func unlock_weapon(id: String) -> void:
	for slot_info in weapon_slots:
		if slot_info.get("id") == id:
			slot_info["unlocked"] = true
			inventory_changed.emit()
			return
	
	if id == "shotgun":
		weapon_slots.append({"slot": 3, "id": "shotgun", "name": "Benelli M4 Shotgun", "unlocked": true})
		inventory_changed.emit()

func capture_state() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"upgrades": upgrades.duplicate(),
		"weapon_slots": weapon_slots.duplicate(true),
		"active_slot_index": active_slot_index,
		"experience":experience,"claimed_rewards":claimed_rewards.duplicate()
	}

func restore_state(data: Dictionary) -> void:
	if data.has("items") and data["items"] is Dictionary:
		items = {}
		for key: Variant in data["items"]:
			var value: Variant = data["items"][key]
			if key is String and (value is int or value is float) and is_finite(float(value)):
				items[key] = clampi(int(value),0,9999)
	if data.has("upgrades") and data["upgrades"] is Array:
		upgrades.clear()
		for u in data["upgrades"]:
			if str(u) in UPGRADE_CATALOG and not str(u) in upgrades: upgrades.append(str(u))
	if data.has("weapon_slots") and data["weapon_slots"] is Array:
		weapon_slots.clear()
		for s in data["weapon_slots"]:
			if s is Dictionary:
				weapon_slots.append(s.duplicate(true))
	if data.has("active_slot_index"):
		active_slot_index = clampi(int(data["active_slot_index"]),0,maxi(0,weapon_slots.size()-1))
	experience = clampi(int(data.get("experience",0)),0,999999)
	claimed_rewards.clear()
	if data.get("claimed_rewards",[]) is Array:
		for reward: Variant in data.get("claimed_rewards",[]):
			if reward is String and not reward.is_empty() and reward.length()<=160 and not reward in claimed_rewards and claimed_rewards.size()<1000: claimed_rewards.append(reward)
	inventory_changed.emit()
	progression_changed.emit(get_progression_summary())
