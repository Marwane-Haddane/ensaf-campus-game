extends "res://scripts/launcher/zombie_storyboard.gd"
## Opening adapted from design/incident.json: a paused, fictional response case.

func _init() -> void:
	heading = "THE BORROWED SESSION    /    OPENING STORY"
	art_directory = "res://assets/launcher/cyber-story/"
	story_note = "FICTIONAL TRAINING  /  5 SECONDS PER PANEL"
	panels = [
		["01-signout.webp", "Campus computer lab · Before the alert", "JUST SIGNED OUT", "AT THE LAB DESK", "Student: I signed out of the demo portal.\nLab support: Thanks. I’ll check the workstation.", Color("ffbe45")],
		["02-alert.webp", "lab-ws-07 · An unexpected source", "THE SESSION RETURNS", "CASE IR-2026-001", "The same demo session appears from another source after sign-out. An unrecognized app was seen earlier. What happened?", Color("ff7b95")],
		["03-evidence.webp", "Response console · Paused evidence snapshot", "LOOK BEFORE YOU ACT", "YOUR ROLE / RESPONSE TRAINEE", "No active spread is observed in this exercise. Inspect the timeline, then preserve the snapshot before recovery changes the evidence.", Color("5af5d1")],
		["04-contain.webp", "Workstation + identity service", "CLOSE BOTH DOORS", "CONTAIN THE INCIDENT", "Isolate lab-ws-07. Then revoke the reused session: isolation alone cannot cancel access from another source.", Color("ffae59")],
		["05-recover.webp", "Approved baseline · Controlled recovery", "RESTORE. TEST. RECONNECT.", "BRING THE LAB BACK SAFELY", "Restore the approved lab image while isolated. Verify recovery and old-session rejection, then reconnect under observation.", Color("78d8ff")],
		["06-handover.webp", "First move · Find the marked training PC", "YOUR CASE STARTS HERE", "PRESS E / OPEN THE HELP FOLDER", "Finish with a factual incident report. First, find a marked PC, press E, and open Help for step-by-step guidance.", Color("defb55")],
	]
