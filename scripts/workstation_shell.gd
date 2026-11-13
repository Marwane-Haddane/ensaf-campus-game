extends RefCounted
## Virtual Linux home and stateful local training commands.
const BlackoutLab = preload("res://scripts/cyber/blackout_lab.gd")
const HOME := "/home/analyst"
const FOLDERS := ["Desktop", "Documents", "Evidence", "Help", "Reports"]
var training: Node
var cyber: RefCounted
var cwd: String = HOME
var files: Dictionary = {}
var aliases: Dictionary = {}

func configure(owner_ui: Node) -> void:
	training = owner_ui
	cyber = BlackoutLab.new()
	cyber.configure(self)
	cwd = HOME
	files.clear()
	aliases.clear()
	var steps: Array = training.mission.get("steps", [])
	var plan := "# Incident response field guide\n## " + str(training.mission.title) + "\n\n## Start with the basics\n`ls`   List files\n`cd`   Change folder\n`cat`  Read a file\n\n## Your recovery plan\n"
	for i: int in range(steps.size()):
		var step: Dictionary = steps[i]
		var name: String = "%02d-%s.md" % [i+1, str(step.id)]
		if step.id == "preserve": name = "02-preserve-evidence.md"
		var short_command := "ir " + str(step.id)
		aliases[short_command] = str(step.terminal.command)
		plan += "%02d  %s\n" % [i+1, str(step.title)]
		files[HOME+"/Help/"+name] = "# Step %02d — %s\n\nRun: `%s`\n\n%s\n\nRead the result before continuing.\n" % [i+1,str(step.title),short_command,str(step.get("feedback", ""))]
	plan += "\n## Step 01 — Inspect\nRun: `ir inspect`\nRead the result before continuing.\n\n## Terminal shortcuts\nTab: complete a command or path\nUp / Down: command history\nCtrl+L: clear the display\n\nCase actions use the ir prefix. Run `ir help` for the full command list.\n\nAdvanced scenario: `mission start blackout`"
	files[HOME+"/Help/START_HERE.md"] = plan
	files[HOME+"/Documents/briefing.md"] = "# Case briefing\n\n" + str(training.mission.briefing.objective) + "\n\n" + str(training.mission.briefing.priority_note)
	files[HOME+"/Evidence/case-notes.txt"] = "CASE " + str(training.mission.entities.case_id) + "\nThe borrowed session\n\nAffected workstation: " + str(training.mission.entities.workstation.id) + "\nReview the authentication timeline and endpoint observation.\nPreserve source records before changing the workstation.\n\nAll timestamps in the case files use UTC."
	files[HOME+"/Evidence/session.log"] = "\n".join(training.mission.evidence[0].lines)
	files[HOME+"/Evidence/endpoint.log"] = "\n".join(training.mission.evidence[1].lines)
	files[HOME+"/Evidence/resource-audit.log"] = "\n".join(training.mission.evidence[2].lines)
	files[HOME+"/Evidence/workstation.json"] = JSON.stringify(training.mission.entities.workstation,"  ")
	files[HOME+"/Reports/incident-report.md"] = "# Incident report\n\nOpen this file to prepare the incident handover.\nThe source evidence, response actions and recovery checks remain available in the case journal."

func resolve(path: String) -> String:
	var raw := path.strip_edges().trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	if raw == "~": raw = HOME
	elif raw.begins_with("~/"): raw = HOME + raw.substr(1)
	elif not raw.begins_with("/"): raw = cwd.path_join(raw)
	var parts: Array[String] = []
	for part: String in raw.split("/",false):
		if part == ".": continue
		if part == "..":
			if not parts.is_empty(): parts.pop_back()
		else: parts.append(part)
	return "/" + "/".join(parts)

func display_path() -> String:
	return cwd.replace(HOME,"~") if cwd.begins_with(HOME) else cwd

func is_directory(path: String) -> bool:
	if path in ["/", "/home", HOME]: return true
	for folder: String in FOLDERS:
		if path == HOME+"/"+folder: return true
	return false

func list_directory(path: String = "") -> Array[Dictionary]:
	var target := resolve(path)
	var result: Array[Dictionary] = []
	var directories: Array[String] = []
	if target == "/": directories.assign(["home"])
	elif target == "/home": directories.assign(["analyst"])
	elif target == HOME: directories.assign(FOLDERS)
	for name: String in directories:
		result.append({"name":name,"path":target.path_join(name),"type":"Folder","size":"—","directory":true,"modified":"Oct 31  09:15"})
	var names: Array = files.keys()
	names.sort()
	for path_key: String in names:
		if path_key.get_base_dir() != target: continue
		var content: String = _content(path_key)
		result.append({"name":path_key.get_file(),"path":path_key,"type":"Markdown document" if path_key.ends_with(".md") else "Text document","size":"%.1f KB" % maxf(0.1, content.length()/1024.0),"directory":false,"modified":"Oct 31  09:15"})
	return result

func _content(path: String) -> String:
	if path == HOME+"/Reports/incident-report.md" and bool(training.state.get("report_submitted",false)):
		return str(training.submitted_report_text)
	if path == HOME+"/Help/START_HERE.md":
		var content: String = files[path]
		for i: int in range(training.mission.steps.size()):
			var step: Dictionary = training.mission.steps[i]
			var row := "%02d  %s" % [i+1,str(step.title)]
			if bool(training.state.get(str(step.completion_flag),false)): content = content.replace(row,row+"  ✓")
		return content
	return str(files.get(path,""))

func read_file(path: String) -> Dictionary:
	var target := resolve(path)
	return {"ok":files.has(target),"path":target,"text":_content(target) if files.has(target) else "cat: %s: No such file" % path}

func execute(line: String) -> Dictionary:
	var command := line.strip_edges()
	var words := command.split(" ",false)
	var output := ""
	var action := ""
	var clear := false
	if words.is_empty(): return {"text":"","cwd":cwd,"action":"","clear":false}
	if command == "mission start blackout": return {"text":cyber.start(),"cwd":cwd,"action":"","clear":false}
	if cyber.active and words[0] in ["lab","ip","sudo","ping","dig","nmap","curl","python3","audit-auth","ssh","scp","exit"]: return cyber.execute(command)
	if cyber.active and command == "cat /var/log/auth.log": return cyber.execute(command)
	if cyber.active and words[0] in ["nano", "edit"]:
		var target := resolve(command.substr(words[0].length()).strip_edges())
		if target.get_base_dir() != HOME+"/Documents" or not target.ends_with(".py"):
			return {"text":"Edit a .py file in ~/Documents.","cwd":cwd,"action":"","clear":false}
		if not files.has(target): files[target] = "# Python candidate generator\n"
		return {"text":"Opening " + target,"cwd":cwd,"action":"editor","path":target,"clear":false}
	var verb: String = words[0]
	var argument: String = command.substr(verb.length()).strip_edges()
	match verb:
		"pwd": output = cwd
		"whoami": output = "analyst"
		"hostname": output = "campus-lab"
		"uname": output = "Linux campus-lab 6.8.0-campus x86_64"
		"clear": clear = true
		"ls":
			if argument in ["-la", "-l", "-a"]: argument = ""
			if not is_directory(resolve(argument)): output = "ls: cannot access '%s': No such directory" % argument
			else:
				var names: Array[String] = []
				for entry: Dictionary in list_directory(argument):
					names.append("[color=#58aeef]"+entry.name+"[/color]" if entry.directory else entry.name)
				output = "   ".join(names)
		"cd":
			var target := HOME if argument.is_empty() else resolve(argument)
			if is_directory(target): cwd = target
			else: output = "cd: %s: No such directory" % argument
		"cat": output = "cat: provide a file name" if argument.is_empty() else str(read_file(argument).text)
		"help": output = _help()
		"ir":
			if argument in ["", "help"]: output = _help()
			elif argument == "report": action = "report"; output = "Opening ~/Reports/incident-report.md"
			elif argument == "journal": action = "journal"; output = training._evidence_content()
			elif argument == "status": output = training._status_text()
			elif argument == "reconnect": output = training.run_command(str(aliases.get("ir verify","")))
			elif aliases.has(command):
				output = training.run_command(aliases[command])
				var next: int = training.get_completion_count()
				if next < training.mission.steps.size():
					var step: Dictionary = training.mission.steps[next]
					output += "\n\nNext: " + str(step.title) + "\nGuide: ~/Help/" + _guide_for(next)
			else: output = "ir: unknown action '%s'\nRun ir help for available case commands." % argument
		"status", "evidence", "report", "reset":
			if verb == "report": action = "report"; output = "Opening incident report."
			else: output = training.run_command(verb)
		"sim": output = training.run_command(command)
		_: output = "%s: command not found\nType help for available commands." % verb
	return {"text":output,"cwd":cwd,"action":action,"clear":clear}

func _guide_for(index: int) -> String:
	var id: String = str(training.mission.steps[index].id)
	return "02-preserve-evidence.md" if id == "preserve" else "%02d-%s.md" % [index+1,id]

func _help() -> String:
	return "Advanced scenario: mission start blackout\n\nCampus lab shell\n\nls                 List files\ncd <folder>        Change directory\npwd                Print working directory\ncat <file>         Read a local file\nclear              Clear the terminal\n\nIncident response\nir inspect         Inspect workstation and timeline\nir preserve        Preserve the source evidence\nir isolate         Isolate the affected workstation\nir revoke          Revoke the reused session\nir restore         Restore the approved baseline\nir verify          Verify recovery and reconnect\nir report          Write and review the handover\nir status          Check the current case state\nir journal         Review unlocked evidence\n\nStart here: cat ~/Help/START_HERE.md"

func complete(line: String) -> Array[String]:
	var options: Array[String] = []
	var space := line.rfind(" ")
	var prefix := line.substr(0,space+1) if space >= 0 else ""
	var token := line.substr(space+1)
	if space < 0:
		for verb: String in ["ls","cd","cat","pwd","whoami","hostname","uname","clear","help","ir","mission","lab","ip","sudo","ping","dig","nmap","curl","python3","nano","audit-auth","ssh","scp","exit"]:
			if verb.begins_with(token): options.append(verb+" ")
	elif prefix == "ir ":
		for verb: String in ["help","inspect","preserve","isolate","revoke","restore","verify","report","status","journal"]:
			if verb.begins_with(token): options.append(prefix+verb)
	elif prefix == "mission ": options.append("mission start blackout")
	elif prefix == "lab ":
		for verb: String in ["status","help","hint","submit","restart","wait 30"]:
			if verb.begins_with(token): options.append(prefix+verb)
	else:
		var slash := token.rfind("/")
		var directory := token.substr(0,slash+1) if slash >= 0 else ""
		var partial := token.substr(slash+1)
		for entry: Dictionary in list_directory(directory):
			if str(entry.name).begins_with(partial): options.append(prefix+directory+str(entry.name)+("/" if entry.directory else ""))
	return options

func save_script(path: String, source: String) -> bool:
	if path.get_base_dir() != HOME+"/Documents" or not path.ends_with(".py") or source.length()>12000: return false
	files[path] = source
	return true
