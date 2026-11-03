## slide_registry.gd — Data-driven slide registry for AAA Cinematic Loading Screen System
## Manages slide manifests, tip libraries, and mode-specific artwork for Zombie RPG & Incident Response
class_name SlideRegistry
extends RefCounted

const ZOMBIE_DIR := "res://assets/loading/zombie"
const CYBER_DIR := "res://assets/loading/cyber"

static var _zombie_slides: Array[Dictionary] = []
static var _cyber_slides: Array[Dictionary] = []
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_init_zombie_slides()
	_init_cyber_slides()
	_initialized = true

static func get_slides_for_mode(mode_id: String) -> Array[Dictionary]:
	_ensure_initialized()
	if mode_id == "incident_response" or mode_id == "cyber":
		return _cyber_slides
	# Default to zombie_rpg
	return _zombie_slides

static func get_slide_by_id(slide_id: String) -> Dictionary:
	_ensure_initialized()
	for s in _zombie_slides:
		if s.id == slide_id:
			return s
	for s in _cyber_slides:
		if s.id == slide_id:
			return s
	return {}

static func get_fallback_slide(mode_id: String) -> Dictionary:
	_ensure_initialized()
	var list := get_slides_for_mode(mode_id)
	if not list.is_empty():
		return list[0]
	return {
		"id": "fallback_atrium",
		"mode_id": mode_id,
		"image_path": "res://assets/launcher/campus-dusk-reference.png",
		"title": "ENSA FÈS CAMPUS",
		"subtitle": "University Infrastructure",
		"tip": "Stay alert and monitor your surroundings at all times.",
		"category": "environment",
		"enemy_type": "",
		"is_implemented": true
	}

static func _init_zombie_slides() -> void:
	_zombie_slides = [
		# --- Anchor slide: Canonical Visual Reference 2 ---
		{
			"id": "atrium_after_dark",
			"mode_id": "zombie_rpg",
			"image_path": "%s/atrium_after_dark.webp" % ZOMBIE_DIR,
			"title": "Atrium After Dark",
			"subtitle": "Main Reception & Central Concourse",
			"tip": "Go for headshots to take down zombies faster and conserve ammo.",
			"category": "environment",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Canonical visual reference. Dark atrium, floor-to-ceiling glass, red emergency illumination."
		},

		# --- 12 Enemy introductions ---
		{
			"id": "enemy_wanderer",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_wanderer.webp" % ZOMBIE_DIR,
			"title": "The Wanderer",
			"subtitle": "Basic Infected Student",
			"tip": "Keep your distance and avoid becoming surrounded.",
			"category": "enemy",
			"enemy_type": "walker",
			"is_implemented": true,
			"gameplay_note": "Implemented enemy archetype (Infected Walker). Shambles slowly but deals 15 melee damage in close quarters."
		},
		{
			"id": "enemy_runner",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_runner.webp" % ZOMBIE_DIR,
			"title": "The Runner",
			"subtitle": "Tactical Concept Preview",
			"tip": "Runners close distances quickly. Stay alert and keep your weapon drawn.",
			"category": "enemy",
			"enemy_type": "runner",
			"is_implemented": false,
			"gameplay_note": "Proposed enemy concept. Agile sprinter targeting survivors caught in open areas."
		},
		{
			"id": "enemy_screamer",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_screamer.webp" % ZOMBIE_DIR,
			"title": "The Screamer",
			"subtitle": "Wide-Angle Infected",
			"tip": "The Screamer spots targets across a wide angle. Break line of sight before reloading.",
			"category": "enemy",
			"enemy_type": "screamer",
			"is_implemented": true,
			"gameplay_note": "Uses the shared chase and melee controller with a 180-degree field of view."
		},
		{
			"id": "enemy_brute",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_brute.webp" % ZOMBIE_DIR,
			"title": "The Brute",
			"subtitle": "Heavy Infected",
			"tip": "Move when the Brute draws back, then fire while it recovers.",
			"category": "enemy",
			"enemy_type": "brute",
			"is_implemented": true,
			"gameplay_note": "The Brute has 240 HP and a committed swing. Headshots can interrupt the wind-up."
		},
		{
			"id": "enemy_stalker",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_stalker.webp" % ZOMBIE_DIR,
			"title": "The Stalker",
			"subtitle": "Long-Reach Infected",
			"tip": "The Stalker closes quickly and reaches farther than a Walker. Leave room to back away.",
			"category": "enemy",
			"enemy_type": "stalker",
			"is_implemented": true,
			"gameplay_note": "Uses the shared chase and melee controller with an extended reach."
		},
		{
			"id": "enemy_crawler",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_crawler.webp" % ZOMBIE_DIR,
			"title": "The Crawling Infected",
			"subtitle": "Low-Profile Ambush Threat",
			"tip": "Threats may be closer to the floor than expected. Scan low angles.",
			"category": "enemy",
			"enemy_type": "crawler",
			"is_implemented": true,
			"gameplay_note": "Implemented enemy archetype (Infected Crawler). Low 1.1m profile makes headshots tricky."
		},
		{
			"id": "enemy_guard",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_guard.webp" % ZOMBIE_DIR,
			"title": "The Guard",
			"subtitle": "Tactical Concept Preview",
			"tip": "Not every enemy is equally vulnerable. Armored campus security requires tactical spacing.",
			"category": "enemy",
			"enemy_type": "guard",
			"is_implemented": false,
			"gameplay_note": "Proposed enemy concept. Reinforced body armor deflects frontal small-arms fire."
		},
		{
			"id": "enemy_lurker",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_lurker.webp" % ZOMBIE_DIR,
			"title": "The Lurker",
			"subtitle": "Tactical Concept Preview",
			"tip": "Pay attention to silhouettes and movement through glass partitions.",
			"category": "enemy",
			"enemy_type": "lurker",
			"is_implemented": false,
			"gameplay_note": "Proposed enemy concept. Uses architectural glazing to shadow survivors before breaching."
		},
		{
			"id": "enemy_swarm",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_swarm.webp" % ZOMBIE_DIR,
			"title": "The Swarm",
			"subtitle": "Tactical Concept Preview",
			"tip": "Avoid attracting large groups of infected in open lecture halls.",
			"category": "enemy",
			"enemy_type": "swarm",
			"is_implemented": false,
			"gameplay_note": "Proposed enemy concept. Clustered pack behavior overwhelms barricaded chokepoints."
		},
		{
			"id": "enemy_lab_infected",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_lab_infected.webp" % ZOMBIE_DIR,
			"title": "The Lab Infected",
			"subtitle": "Tactical Concept Preview",
			"tip": "Investigate unfamiliar threats carefully. Hazmat suits resist standard attacks.",
			"category": "enemy",
			"enemy_type": "lab_infected",
			"is_implemented": false,
			"gameplay_note": "Proposed enemy concept. Contaminated lab attire provides environmental insulation."
		},
		{
			"id": "enemy_night_hunter",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_night_hunter.webp" % ZOMBIE_DIR,
			"title": "The Night Hunter",
			"subtitle": "Tactical Concept Preview",
			"tip": "Visibility can be your greatest disadvantage outdoors after dusk.",
			"category": "enemy",
			"enemy_type": "night_hunter",
			"is_implemented": false,
			"gameplay_note": "Proposed enemy concept. Nighttime campus predator with extreme detection radius."
		},
		{
			"id": "enemy_apex",
			"mode_id": "zombie_rpg",
			"image_path": "%s/enemy_apex.webp" % ZOMBIE_DIR,
			"title": "The Apex Infected",
			"subtitle": "Tactical Concept Preview",
			"tip": "Some encounters require preparation, traps, and supplies rather than direct confrontation.",
			"category": "enemy",
			"enemy_type": "apex",
			"is_implemented": false,
			"gameplay_note": "Proposed late-game boss concept. Mutated powerhouse requiring coordinated fire and traps."
		},

		# --- 5 Additional campus environments ---
		{
			"id": "env_computer_lab",
			"mode_id": "zombie_rpg",
			"image_path": "%s/env_computer_lab.webp" % ZOMBIE_DIR,
			"title": "Abandoned Computer Laboratory",
			"subtitle": "Department of Computer Engineering",
			"tip": "Emergency power keeps certain workstations online. Check them for campus maps and security logs.",
			"category": "environment",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Campus computer laboratory with powered workstations and keycard terminals."
		},
		{
			"id": "env_library",
			"mode_id": "zombie_rpg",
			"image_path": "%s/env_library.webp" % ZOMBIE_DIR,
			"title": "The Central Library",
			"subtitle": "Quiet Study & Archives Wing",
			"tip": "Tall bookshelves provide stealth cover, but narrow aisles can trap unwary survivors.",
			"category": "environment",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Multi-aisle campus library offering vertical sightlines and stealth opportunities."
		},
		{
			"id": "env_rooftop",
			"mode_id": "zombie_rpg",
			"image_path": "%s/env_rooftop.webp" % ZOMBIE_DIR,
			"title": "Campus Rooftop",
			"subtitle": "Observation & Radio Relay Outpost",
			"tip": "Elevated vantage points offer a clear view of patrol routes across courtyard paths.",
			"category": "environment",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Rooftop terrace overlooking Fès skyline, ideal for reconnaissance and scouting."
		},
		{
			"id": "env_underground",
			"mode_id": "zombie_rpg",
			"image_path": "%s/env_underground.webp" % ZOMBIE_DIR,
			"title": "Underground Service Tunnel",
			"subtitle": "Substation & Utility Infrastructure",
			"tip": "Maintenance tunnels connect buildings safely, but light sources are strictly limited.",
			"category": "environment",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Power substation and pipe utility trenches connecting campus buildings."
		},
		{
			"id": "campus_courtyard",
			"mode_id": "zombie_rpg",
			"image_path": "%s/campus_courtyard.webp" % ZOMBIE_DIR,
			"title": "The Campus Courtyard",
			"subtitle": "Central Plaza & Exterior Grounds",
			"tip": "Cross open plazas swiftly. Lingering in open spaces invites flanking threats.",
			"category": "environment",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Open exterior plaza linking Building E and Building D with perimeter cover."
		},

		# --- 4 Survival and gameplay ---
		{
			"id": "survival_stealth",
			"mode_id": "zombie_rpg",
			"image_path": "%s/survival_stealth.webp" % ZOMBIE_DIR,
			"title": "Stealth & Evasion",
			"subtitle": "Acoustic Detection Avoidance",
			"tip": "Break enemy line of sight behind solid cover. Gunshots can draw nearby infected.",
			"category": "survival",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Enemy perception checks line of sight and responds to gunshot noise."
		},
		{
			"id": "survival_scavenging",
			"mode_id": "zombie_rpg",
			"image_path": "%s/survival_scavenging.webp" % ZOMBIE_DIR,
			"title": "Supply Scavenging",
			"subtitle": "Resource Management & Crafting",
			"tip": "Medical kits, ammunition, and scrap parts are critical for surviving prolonged incursions.",
			"category": "survival",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Implemented inventory system supporting ammunition, bandages, and craftable weapon upgrades."
		},
		{
			"id": "survival_barricade",
			"mode_id": "zombie_rpg",
			"image_path": "%s/survival_barricade.webp" % ZOMBIE_DIR,
			"title": "Defensive Preparation",
			"subtitle": "Chokepoints & Fortification",
			"tip": "Classroom doors and barricades buy precious seconds to reload and regroup.",
			"category": "survival",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Interactive physical doors and obstacle placement block infected navigation paths."
		},
		{
			"id": "survival_escape",
			"mode_id": "zombie_rpg",
			"image_path": "%s/survival_escape.webp" % ZOMBIE_DIR,
			"title": "Emergency Escape",
			"subtitle": "Extraction Zone Defense",
			"tip": "Keep an extraction route planned before initiating combat inside unfamiliar corridors.",
			"category": "survival",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Restore power, check in with Shaun, and defeat the Brute before boarding the extraction truck."
		},

		# --- 2 Narrative artwork ---
		{
			"id": "story_first_night",
			"mode_id": "zombie_rpg",
			"image_path": "%s/story_first_night.webp" % ZOMBIE_DIR,
			"title": "The First Night",
			"subtitle": "Incident Chronology: 21:14 Lockdown",
			"tip": "When campus communications failed at 21:00, security protocol Alpha triggered full building isolation.",
			"category": "story",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Lore backstory detailing the outbreak timeline at ENSA Fès."
		},
		{
			"id": "story_unknown_signal",
			"mode_id": "zombie_rpg",
			"image_path": "%s/story_unknown_signal.webp" % ZOMBIE_DIR,
			"title": "The Unknown Signal",
			"subtitle": "Automated SOS Frequency",
			"tip": "A looped radio transmission from the engineering block repeats coordinates every 15 minutes.",
			"category": "story",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Secondary narrative objective hinting at survivor beacon frequencies across campus."
		}
	]

static func _init_cyber_slides() -> void:
	_cyber_slides = [
		{
			"id": "cyber_workstation",
			"mode_id": "incident_response",
			"image_path": "%s/cyber_workstation.webp" % CYBER_DIR,
			"title": "Forensic Workstation Analysis",
			"subtitle": "Digital Evidence Preservation",
			"tip": "Verify system logs and hash signatures before modifying running processes.",
			"category": "forensics",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Active investigation mechanic: workstation command shell, hash calculation, and artifact analysis."
		},
		{
			"id": "cyber_server_room",
			"mode_id": "incident_response",
			"image_path": "%s/cyber_server_room.webp" % CYBER_DIR,
			"title": "Campus Datacenter Infrastructure",
			"subtitle": "Core Switch & Blade Enclosures",
			"tip": "Check network switches and patch panels for unauthorized physical taps.",
			"category": "network",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Server rack inspection and network port identification gameplay."
		},
		{
			"id": "cyber_incident_triage",
			"mode_id": "incident_response",
			"image_path": "%s/cyber_incident_triage.webp" % CYBER_DIR,
			"title": "Incident Response Triage",
			"subtitle": "Containment & Quarantine Protocol",
			"tip": "Isolate compromised hosts from the subnet immediately to prevent lateral movement.",
			"category": "response",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Incident triage protocol: containing compromised workstations and evidence preservation."
		},
		{
			"id": "cyber_network_monitoring",
			"mode_id": "incident_response",
			"image_path": "%s/cyber_network_monitoring.webp" % CYBER_DIR,
			"title": "Campus Network Gateway",
			"subtitle": "Intrusion Detection System",
			"tip": "Look for anomalous outbound beaconing intervals in border gateway traffic.",
			"category": "monitoring",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Packet capture and border firewall monitoring mechanics."
		},
		{
			"id": "cyber_evidence_collection",
			"mode_id": "incident_response",
			"image_path": "%s/cyber_evidence_collection.webp" % CYBER_DIR,
			"title": "Chain of Custody",
			"subtitle": "Incident Documentation Protocol",
			"tip": "Document forensic timestamps and memory dumps in strict compliance with protocol.",
			"category": "evidence",
			"enemy_type": "",
			"is_implemented": true,
			"gameplay_note": "Formal evidence report submission and chain-of-custody verification."
		}
	]

