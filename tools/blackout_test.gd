extends SceneTree
class SaveGame extends Node3D:
	var training: Node
	var player := Node3D.new()
	var pitch := 0.0
	func restore_safe_pose(pose: Dictionary) -> void:
		player.position = Vector3(pose.position[0],pose.position[1],pose.position[2])
var shell: RefCounted
var checks := 0
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL ",label)
func cmd(line: String) -> String: return str(shell.execute(line).text)
func run() -> void:
	var training = load("res://scripts/training_ui.gd").new()
	root.add_child(training)
	await process_frame
	shell = training.workstation_shell
	check(cmd("mission start blackout").contains("BLACKOUT"),"Case starts")
	check(cmd("lab submit").contains("incomplete"),"Cannot skip mission")
	check(cmd("ping -c 3 10.77.20.15").contains("unreachable"),"Broken network blocks probes")
	cmd("sudo ip link set eth0 up")
	cmd("sudo ip addr replace 10.77.10.44/24 dev eth0")
	check(cmd("ping -c 3 10.77.20.15").contains("unreachable"),"Route required")
	cmd("sudo ip route replace default via 10.77.10.1")
	check(cmd("ping -c 3 10.77.20.15").contains("0% packet loss"),"Network fixed")
	check(cmd("nmap -sV 10.77.20.15").contains("Discover"),"Discovery required")
	check(cmd("nmap -sn 10.77.20.0/24").contains("2 hosts"),"Discovery returns hosts")
	check(cmd("nmap -sV 10.77.20.15").contains("8080"),"Service enumeration")
	check(cmd("curl http://10.77.20.15:8080/notice").contains("Nora"),"Evidence unlocks clues")
	check(shell.execute("nano ~/Documents/candidates.py").action == "editor","Editor action")
	check(cmd("python3 ~/Documents/candidates.py > ~/Documents/candidates.txt").contains("6 candidates"),"Real Python example runs")
	var audit := "audit-auth --target 10.77.20.15 --user maint --candidates ~/Documents/candidates.txt --delay "
	check(cmd(audit+"1").contains("No match"),"Example tokens cannot solve case")
	check(cmd(audit+"0").contains("locked"),"Burst causes lockout")
	check(cmd(audit+"1").contains("temporarily"),"Lockout persists")
	cmd("lab wait 30")
	var path := "/home/analyst/Documents/candidates.py"
	var source: String = shell.files[path]
	source = source.replace("[\"example\", \"2000\"]","[\"nora\", \"Nora\", \"1998\"]")
	check(shell.save_script(path,source),"Player can save Python")
	check(cmd("python3 ~/Documents/candidates.py > ~/Documents/candidates.txt").contains("18 candidates"),"Permutations produce actual combinations")
	check(cmd(audit+"1").contains("Credential validated"),"Evidence-derived candidate succeeds")
	check(cmd("ssh maint@10.77.20.15").contains("Authenticated"),"Recovered credential enables session")
	check(cmd("sudo usermod -L maint").contains("preserve"),"Cannot destroy evidence first")
	check(cmd("cat /var/log/auth.log").contains("10.77.20.88"),"Remote timeline available")
	cmd("scp maint@10.77.20.15:/var/log/auth.log ~/Evidence/archive-auth.log")
	cmd("sudo usermod -L maint")
	cmd("sudo systemctl disable --now legacy-maint")
	check(cmd("sudo ufw enable").contains("Preflight failed"),"Prevent responder lockout")
	cmd("sudo ufw allow from 10.77.10.0/24 to any port 22")
	cmd("sudo ufw default deny incoming")
	cmd("sudo ufw enable")
	cmd("exit")
	check(cmd("curl https://archive.campus.test/health").contains("verified"),"Baseline and availability verified")
	check(cmd("lab submit").contains("CASE RESOLVED"),"Full mission completable")
	var store = load("res://scripts/launcher/save_store.gd").new()
	store.path = "user://ensagames/tests/blackout-save.json"
	var save_game := SaveGame.new()
	save_game.training = training
	var checkpoint: Dictionary = store.capture(save_game)
	check(store.validate(checkpoint), "Normal checkpoint accepts cyber state")
	check(store.write_save(checkpoint), "Cyber checkpoint writes")
	check(not store.read_save().is_empty(), "Cyber checkpoint reads")
	var corrupt := checkpoint.duplicate(true)
	corrupt.cyber_lab.flags.verified = "yes"
	check(not store.validate(corrupt), "Corrupt cyber flags rejected")
	cmd("lab restart")
	check(store.restore(save_game,checkpoint) and shell.cyber.flags.verified, "Normal game restore restores cyber progress")
	save_game.player.free()
	save_game.free()
	var saved: Dictionary = shell.cyber.snapshot()
	cmd("lab restart")
	check(not shell.cyber.flags.verified,"Restart resets progress")
	check(shell.cyber.restore(saved) and shell.cyber.flags.verified,"Restore preserves progress")
	check(shell.files[path] == source,"Restore preserves player code")
	check(shell.read_file("~/Reports/blackout-report.md").ok,"Final report persisted")
	var blocked: String = source.replace("from itertools import permutations","import os")
	shell.save_script(path,blocked)
	check(cmd("python3 ~/Documents/candidates.py > ~/Documents/candidates.txt").contains("Unsupported statement"),"Host imports blocked")
	print("BLACKOUT_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	training.free()
	quit(0 if failures.is_empty() else 1)
