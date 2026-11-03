extends SceneTree
## Tests the virtual shell against the real training engine; no GPU or host shell.

var training
var shell
var checks: int = 0
var failures: Array[String] = []
var evidence_files: Dictionary = {"session.log": "EV-01", "endpoint.log": "EV-02", "resource-audit.log": "EV-03"}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		print("WORKSTATION_SHELL_FAIL " + description)


func _text(command: String) -> String:
	var result: Dictionary = shell.execute(command)
	return str(result.get("text", ""))


func _count() -> int:
	return training.get_completion_count()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var training_script: Script = load("res://scripts/training_ui.gd")
	training = training_script.new()
	root.add_child(training)
	await process_frame
	var shell_script: Script = load("res://scripts/workstation_shell.gd")
	shell = shell_script.new()
	shell.configure(training)
	_test_filesystem()
	_test_completion()
	_test_mission()
	var result := {
		"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"completion_count": _count(), "points": training.points,
		"host_reconnected": bool(training.state.get("host_reconnected", false)),
		"submitted_report_available": bool(shell.read_file("~/Reports/incident-report.md").ok)
	}
	var report := FileAccess.open("res://tools/workstation_shell_test.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	print("WORKSTATION_SHELL_TEST " + JSON.stringify(result))
	training.queue_free()
	quit(0 if failures.is_empty() else 1)


func _test_filesystem() -> void:
	_check(_text("pwd") == "/home/analyst" and shell.display_path() == "~", "pwd and prompt start in the virtual analyst home")
	var home_entries: Array[Dictionary] = shell.list_directory()
	var folders: Array[String] = []
	for entry: Dictionary in home_entries:
		if entry.directory:
			folders.append(str(entry.name))
	_check(folders == ["Desktop", "Documents", "Evidence", "Help", "Reports"], "Home lists exactly the intended virtual folders")
	_check(_text("ls").contains("Evidence") and _text("ls -la").contains("Help"), "ls and ls -la list virtual home folders")
	_check(_text("cd Evidence").is_empty() and _text("pwd") == "/home/analyst/Evidence", "cd Evidence changes the virtual working directory")
	_check(shell.display_path() == "~/Evidence", "Prompt shortens only the virtual home prefix")
	for filename: String in evidence_files:
		var expected := ""
		for raw_evidence in training.mission.evidence:
			var evidence: Dictionary = raw_evidence
			if str(evidence.id) == evidence_files[filename]:
				expected = "\n".join(evidence.lines)
		_check(not expected.is_empty() and _text("cat " + filename) == expected, filename + " exactly matches its authored mission log")
	var workstation: Variant = JSON.parse_string(_text("cat workstation.json"))
	_check(workstation is Dictionary and workstation == training.mission.entities.workstation, "Workstation JSON exposes the actual fictional hostname and TEST-NET IP")
	_check(_text("cat 'session.log'") == _text("cat session.log"), "Quoted file paths read the same virtual record")
	_check(_text("cat ../Documents/briefing.md").contains(str(training.mission.briefing.priority_note)), "Relative briefing includes the scenario-specific evidence/containment priority")
	_check(_text("cat ~/Evidence/case-notes.txt").contains(str(training.mission.entities.case_id)), "Case notes use the current case ID")
	_check(_text("cat missing.log").contains("No such file"), "Missing files produce a useful error")
	var before_cwd: String = shell.cwd
	_check(_text("cd missing-folder").contains("No such directory") and shell.cwd == before_cwd, "Invalid cd leaves the current directory unchanged")
	for host_path: String in ["C:\\Windows\\win.ini", "C:/Windows/win.ini", "/etc/passwd", "res://project.godot", "user://settings.cfg", "../../../../Windows/win.ini"]:
		var file_result: Dictionary = shell.read_file(host_path)
		_check(not file_result.ok and str(file_result.text).contains("No such file"), "Host path is absent from virtual storage: " + host_path)
	_check(not shell.is_directory("C:/Windows") and not shell.is_directory("/etc"), "Host directories cannot be listed or entered")
	_check(shell.resolve("./../Help/../Evidence/session.log") == "/home/analyst/Evidence/session.log", "Dot segments resolve consistently inside the virtual tree")
	_text("cd /")
	_check(_text("ls").contains("home") and shell.list_directory().size() == 1, "Virtual root exposes only home")
	_text("cd ../../../../")
	_check(shell.cwd == "/", "Parent traversal clamps at the virtual root")
	_text("cd")
	_check(shell.cwd == "/home/analyst", "Bare cd returns to the virtual analyst home")
	_check(_text("whoami") == "analyst" and _text("hostname") == "campus-lab", "Identity commands return authored virtual identity")
	_check(_text("curl https://example.com").contains("command not found"), "Unrecognized host-like command is rejected")
	var clear_result: Dictionary = shell.execute("clear")
	_check(clear_result.clear and str(clear_result.text).is_empty(), "clear requests a display clear rather than changing the case")
	_check(_count() == 0 and training.points == 0, "Filesystem exploration does not advance the mission")


func _test_completion() -> void:
	_check(shell.complete("pw").has("pwd "), "Command completion offers pwd")
	_check(shell.complete("ir pre").has("ir preserve"), "Action completion offers the preservation alias")
	_check(shell.complete("cd E").has("cd Evidence/"), "Directory completion adds a trailing slash")
	_check(shell.complete("cat ~/Help/02-").has("cat ~/Help/02-preserve-evidence.md"), "Guide completion returns the real preservation guide path")
	_text("cd Evidence")
	_check(shell.complete("cat ses").has("cat session.log"), "File completion respects the current virtual directory")
	_check(shell.complete("cat /etc/pass").is_empty(), "Completion cannot reveal host paths")
	_text("cd")


func _test_mission() -> void:
	for raw_step in training.mission.steps:
		var step: Dictionary = raw_step
		_check(str(shell.aliases.get("ir " + str(step.id), "")) == str(step.terminal.command), "Alias targets exact authored command: " + str(step.id))
	_check(_text("ir help").contains("ir preserve") and _text("cat ~/Help/START_HERE.md").contains("ir inspect"), "Help and start guide explain the available case actions")
	var original_state: Dictionary = training.state.duplicate(true)
	_check(_text("ir preserve").contains("ACTION LOCKED") and training.state == original_state, "Preservation alias enforces inspection prerequisite")
	_check(_text("ir reconnect").contains("ACTION LOCKED") and training.state == original_state, "Reconnect alias enforces recovery prerequisites")
	_check(_text("ir restore").contains("ACTION LOCKED") and training.state == original_state, "Restore cannot bypass evidence and containment")
	_check(_text("ir not-a-case-action").contains("unknown action") and training.state == original_state, "Unknown IR action changes no state")
	_check(_text("sim execute-anything").contains("Unknown training action") and training.state == original_state, "Direct sim syntax still passes through the mission whitelist")
	var inspect_result := _text("ir inspect")
	_check(_count() == 1 and inspect_result.contains(str(training.mission.entities.workstation.hostname)), "Inspect alias advances once and reports the actual affected hostname")
	_check(inspect_result.contains("~/Help/02-preserve-evidence.md"), "Successful inspection points to the real next guide")
	_check(_text("cat ~/Help/START_HERE.md").contains("01  Inspect the case  ✓"), "Start guide marks completed actions dynamically")
	var score_after_inspect: int = training.points
	_text("ir inspect")
	_check(_count() == 1 and training.points == score_after_inspect, "Repeated aliases do not duplicate progress or points")
	var journal_result: Dictionary = shell.execute("ir journal")
	_check(journal_result.action == "journal" and str(journal_result.text).contains("EV-01") and not str(journal_result.text).contains("EV-ARCHIVE /"), "Journal opens unlocked source evidence without inventing a preserved archive")
	_check(_text("ir status").contains("1 / 7"), "Status reflects actual engine progress")
	for id: String in ["preserve", "isolate", "revoke", "restore"]:
		_text("ir " + id)
	_check(_count() == 5 and bool(training.state.host_isolated) and bool(training.state.session_revoked) and not bool(training.state.host_reconnected), "Preserve, isolate, revoke and restore leave the host isolated until verified")
	_text("ir verify")
	_check(_count() == 6 and bool(training.state.recovery_verified) and bool(training.state.host_reconnected) and not bool(training.state.host_isolated), "Verify alias completes checks before controlled reconnection")
	var report_action: Dictionary = shell.execute("ir report")
	_check(report_action.action == "report" and _count() == 6, "Report alias requests the form without submitting it")
	var submit_command: String = training.mission.steps.back().terminal.command
	_check(_text(submit_command).contains("REPORT NEEDS REVIEW") and _count() == 6, "Report cannot submit before valid answers and preview")
	training.report_answers = {"summary": "   ", "finding": "session_reuse", "evidence_ids": ["EV-ARCHIVE", "EV-VERIFY"], "follow_up": "monitor_review"}
	training.call("_preview_report")
	_check(not training.report_preview_valid and _text(submit_command).contains("REPORT NEEDS REVIEW"), "Whitespace summary fails real report validation")
	training.report_answers.summary = "The demo workstation showed suspicious session reuse. I preserved the logs, contained endpoint and identity access, and verified the approved recovery baseline."
	training.call("_preview_report")
	_check(training.report_preview_valid, "Supported answers and factual summary produce a valid report preview")
	_text(submit_command)
	_check(_count() == 7 and training.points == 100 and bool(training.state.mission_complete), "Exact authored report submission completes all seven actions for 100 points")
	var report_text := _text("cat ~/Reports/incident-report.md")
	_check(report_text == str(training.submitted_report_text) and report_text.contains(str(training.mission.entities.workstation.hostname)), "Reports file returns the submitted factual handover")
	_text("ir verify")
	_check(_count() == 7 and training.points == 100 and training.journal.size() == 7, "Completed verification remains idempotent after reconnection")
	shell.configure(training)
	_check(shell.cwd == "/home/analyst" and _count() == 7 and training.points == 100, "Reconfiguring a desktop shell preserves mission progress")
	_check(_text("cat ~/Reports/incident-report.md") == report_text, "Reconfiguring preserves access to the immutable submitted report")
	var engine_check: Dictionary = training.run_self_test()
	_check(bool(engine_check.passed) and _count() == 7 and training.submitted_report_text == report_text, "Existing engine self-test passes without overwriting this completed session")
