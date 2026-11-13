extends RefCounted
## Stateful fictional network. No socket or host network commands are invoked.
const HOME := "/home/analyst"
const TARGET := "10.77.20.15"
const FLAGS := ["linked", "addressed", "routed", "discovered", "enumerated", "clues", "generated", "recovered", "evidence", "rotated", "disabled", "firewall", "verified"]
var _shell_ref: WeakRef
var shell: RefCounted:
	get: return _shell_ref.get_ref() if _shell_ref != null else null
var active := false
var remote := false
var flags: Dictionary = {}
var address := "192.168.56.44/24"
var gateway := "192.168.56.1"
var attempts := 0
var locked := false
var allow_ssh := false
var deny_incoming := false
var hint_count := 0
var generated_text := ""
var transcript: Array[String] = []

func configure(backend: RefCounted) -> void:
	_shell_ref = weakref(backend)

func start() -> String:
	active = true
	remote = false
	flags.clear()
	for flag in FLAGS: flags[flag] = false
	address = "192.168.56.44/24"
	gateway = "192.168.56.1"
	attempts = 0
	locked = false
	allow_ssh = false
	deny_incoming = false
	hint_count = 0
	generated_text = ""
	transcript.clear()
	for file: String in ["Documents/candidates.txt", "Evidence/maintenance-notice.txt", "Evidence/archive-auth.log", "Reports/blackout-report.md"]:
		shell.files.erase(HOME+"/"+file)
	_seed_files()
	return "OPERATION BLACKOUT / CY-2026-002\n02:10 — Research submission closes at 03:00. The campus gateway has drifted from its approved configuration. A maintenance account was used to change the archive service. Restore access without taking the archive offline.\n\nRead: cat ~/Documents/blackout-briefing.md\nTrack: lab status   Reference: lab help   Hints: lab hint\nThis is a stateful simulated network; Python candidate generation uses a restricted local Python runtime."

func _seed_files() -> void:
	shell.files[HOME+"/Documents/blackout-briefing.md"] = """# Operation Blackout
You are the on-call analyst. Researchers cannot submit to archive.campus.test.
The last shift left your workstation disconnected and configured for the wrong subnet.
A vendor's maintenance endpoint may still expose a weak credential. Determine what happened, collect evidence, and restore the approved service boundary.

## Rules of engagement
Only the fictional 10.77.20.0/24 lab segment is in scope. No real network requests are made.
Use the temporary maintenance account 'maint' to validate the weakness. Do not interrupt HTTPS (443): submissions must stay available.
The audit service locks for a simulated 30 seconds after a burst faster than one attempt/second. Use evidence to narrow your search.

## Objectives
1. Repair eth0 using the handover network plan.
2. Discover hosts, enumerate services, and inspect the HTTP maintenance notice.
3. Write Python that combines clue tokens with permutations, case variants, and separators. Print candidates, one per line; do not paste a wordlist.
4. Validate the account using audit-auth with a one-second delay, then connect with ssh.
5. Read and preserve the remote authentication log BEFORE remediation.
6. Lock the exposed account, stop the legacy service, restrict SSH to the analyst subnet, enable the firewall, and verify HTTPS from your workstation.
7. Submit your findings with lab submit.

Your progress and script are included when you save the game. 'lab restart' resets this case.
"""
	shell.files[HOME+"/Documents/network-handover.txt"] = "Approved analyst NIC: eth0\nAnalyst address: 10.77.10.44/24\nGateway: 10.77.10.1\nResearch segment: 10.77.20.0/24\nArchive DNS name: archive.campus.test\nDNS server: 10.77.10.53 (already provisioned)\nKeep archive HTTPS available throughout the response.\n"
	shell.files[HOME+"/Documents/candidates.py"] = "# Read the maintenance notice first. Replace these example tokens with your evidence.\nfrom itertools import permutations\n\ntokens = [\"example\", \"2000\"]\nseparators = [\"@\", \"-\", \"\"]\nseen = set()\nfor pair in permutations(tokens, 2):\n    for separator in separators:\n        candidate = separator.join(pair)\n        if candidate not in seen:\n            seen.add(candidate)\n            print(candidate)\n"
	shell.files[HOME+"/Help/BLACKOUT.md"] = help_text()

func help_text() -> String:
	return """Operation Blackout — command reference
mission start blackout       Start the case
lab status | hint | submit    Objectives, optional hint, final validation
lab restart                  Reset this case and its files
lab wait 30                  Advance the simulated lockout timer
ip link show / ip addr show / ip route show
sudo ip link set eth0 up
sudo ip addr replace <CIDR> dev eth0
sudo ip route replace default via <gateway>
ping -c 3 <IP>               Connectivity diagnosis
dig archive.campus.test       Resolve the archive after routing works
nmap -sn 10.77.20.0/24        Discover the lab segment
nmap -sV <IP>                Enumerate a discovered host
curl http://<IP>:8080/notice  Read maintenance clues
nano ~/Documents/candidates.py  Open the Python editor (Save / Run)
python3 ~/Documents/candidates.py > ~/Documents/candidates.txt
audit-auth --target <IP> --user maint --candidates ~/Documents/candidates.txt --delay 1
ssh maint@<IP>               Use the recovered credential in the lab keyring
cat /var/log/auth.log        Read remote evidence
scp maint@10.77.20.15:/var/log/auth.log ~/Evidence/archive-auth.log
sudo usermod -L maint        Lock the compromised account
sudo systemctl disable --now legacy-maint
sudo ufw allow from 10.77.10.0/24 to any port 22
sudo ufw default deny incoming
sudo ufw enable
exit                        Leave the remote session
curl https://archive.campus.test/health
lab submit

Python teaching subset: assignments, lists, tuples, sets, for/if, comparisons,
string concatenation, lower/title/upper/join/replace, print, len, str, sorted,
set/add, list/append, range, and from itertools import permutations, product.
No host file/network access. Print output is redirected to the virtual file.
Limits: 12 KB source; 4096 candidates; 128 characters per line; bounded steps.
Requires Python 3 installed on the computer; no heavy runtime is bundled.
"""

func status() -> String:
	var labels := ["Connect eth0", "Assign approved address", "Repair default route", "Discover hosts", "Enumerate archive", "Collect maintenance clues", "Generate Python permutations", "Recover maintenance credential", "Preserve authentication evidence", "Lock compromised account", "Disable legacy service", "Apply restricted firewall", "Verify healthy archive"]
	var text := "OPERATION BLACKOUT\n"
	for i in FLAGS.size(): text += ("[OK] " if flags.get(FLAGS[i],false) else "[  ] ") + labels[i] + "\n"
	return text + "\nAttempts: %d | Hints: %d | Session: %s" % [attempts,hint_count,"archive" if remote else "analyst"]

func _reachable() -> bool:
	return flags.get("linked",false) and flags.get("addressed",false) and flags.get("routed",false)

func execute(command: String) -> Dictionary:
	var text := _execute(command)
	transcript.append(command)
	if transcript.size() > 150: transcript.pop_front()
	return {"text":text.replace("[","[lb]"),"action":"","clear":false,"cwd":shell.cwd}

func _execute(command: String) -> String:
	var words := command.split(" ", false)
	if words.is_empty(): return ""
	if command == "lab help": return help_text()
	if command == "lab status": return status()
	if command == "lab restart": return start()
	if command == "lab hint":
		hint_count += 1
		if not _reachable(): return "Compare ip addr and ip route with ~/Documents/network-handover.txt. Bring eth0 up, replace its address, then replace the default gateway."
		if not flags.clues: return "Discover the research /24, enumerate the archive's service versions, then request its HTTP /notice endpoint."
		if not flags.recovered: return "The notice gives a first name and birth year. Include lower/title case, both token orders, and @ / - / empty separators. Use permutations(tokens, 2)."
		if not flags.evidence: return "Connect with ssh, inspect /var/log/auth.log, then preserve it with scp before changing anything."
		return "Keep 443 open. Lock maint, disable legacy-maint, allow SSH from the analyst /24, set the default incoming policy, and enable the firewall. Exit and check /health."
	if command == "lab wait 30":
		locked = false
		return "Simulated lockout elapsed. No wall-clock waiting required."
	if command == "lab submit":
		for flag in FLAGS:
			if not flags.get(flag,false): return "Case incomplete: " + flag + ". Run lab status."
		var score := maxi(40,100-hint_count*3-int(attempts/100))
		shell.files[HOME+"/Reports/blackout-report.md"] = "# Operation Blackout — resolved\nScore: %d/100\nRoot cause: leaked identity clues and a predictable maintenance credential exposed through legacy-maint.\nEvidence: ~/Evidence/archive-auth.log\nContainment: account locked, legacy service disabled, SSH restricted to analyst subnet.\nRecovery: archive HTTPS healthy.\nCandidates tested: %d\n\nCommand trail:\n%s" % [score,attempts,"\n".join(transcript)]
		return "CASE RESOLVED — %d/100\nArchive submissions are healthy; the maintenance route is closed. Report saved to ~/Reports/blackout-report.md." % score
	if command in ["ip link", "ip link show"]: return "2: eth0: <BROADCAST,MULTICAST%s> state %s" % [",UP" if flags.linked else "", "UP" if flags.linked else "DOWN"]
	if command in ["ip addr", "ip addr show", "ip a"]: return "eth0 inet " + address + (" UP" if flags.linked else " DOWN")
	if command in ["ip route", "ip route show"]: return "default via " + gateway + " dev eth0\n" + address + " dev eth0"
	if command == "sudo ip link set eth0 up": flags.linked = true; return ""
	if words.size() == 7 and command.begins_with("sudo ip addr replace ") and words[5] == "dev" and words[6] == "eth0":
		address = words[4]; flags.addressed = address == "10.77.10.44/24"; flags.verified = false
		return ""
	if words.size() == 7 and command.begins_with("sudo ip route replace default via "):
		gateway = words[6]; flags.routed = gateway == "10.77.10.1"; flags.verified = false
		return ""
	if command.begins_with("python3 "): return _python(command)
	if command.begins_with("audit-auth "): return _audit(words)
	if command == "exit": remote = false; return "Connection to archive closed."
	if not _reachable(): return "Network unreachable. Inspect ip link, ip addr, ip route and the handover plan."
	if command.begins_with("ping "):
		var target: String = words[-1]
		if target in ["10.77.10.1","10.77.10.53",TARGET,"10.77.20.53"]: return "3 packets transmitted, 3 received, 0% packet loss; time 2.1 ms"
		return "Destination unreachable (target outside the responding lab hosts)."
	if command == "dig archive.campus.test": return "archive.campus.test. 60 IN A " + TARGET
	if command == "nmap -sn 10.77.20.0/24":
		flags.discovered = true
		return "Nmap scan report for archive.campus.test (10.77.20.15) — Host is up\nNmap scan report for resolver.campus.test (10.77.20.53) — Host is up\n256 IP addresses scanned; 2 hosts up."
	if command == "nmap -sV " + TARGET:
		if not flags.discovered: return "Discover the authorized segment first: nmap -sn <CIDR>."
		flags.enumerated = true
		return "PORT     STATE SERVICE VERSION\n22/tcp   %s ssh     OpenSSH 9.6\n443/tcp  open  https   Campus Archive 2.4\n8080/tcp %s http    Legacy Maintenance 1.2" % ["open" if not flags.firewall or allow_ssh else "filtered", "closed" if flags.disabled else "open"]
	if command == "nmap -sV 10.77.20.53": return "53/tcp open domain Campus DNS\nNo maintenance service."
	if command == "curl http://"+TARGET+":8080/notice":
		if flags.disabled: return "curl: connection refused"
		if not flags.enumerated: return "Identify service versions before collecting the maintenance notice."
		flags.clues = true
		var notice := "Maintenance notice / cached staff profile\nOwner: Nora El Amrani\nBirthday: 14 September 1998\nAccount: maint\nTicket M-184: temporary passwords used first name plus birth year. Older deployments used punctuation separators and reversed token order.\n02:01 — urgent archive routing change approved by maint (approval reference missing)."
		shell.files[HOME+"/Evidence/maintenance-notice.txt"] = notice
		return notice
	if command == "ssh maint@"+TARGET:
		if flags.rotated: return "Permission denied: maintenance account is locked."
		if not flags.recovered: return "Permission denied. Recover the lab credential through the candidate audit first."
		remote = true
		return "Authenticated using recovered lab credential. archive$\nInspect /var/log/auth.log. Preserve evidence before remediation."
	if command == "cat /var/log/auth.log":
		if not remote: return "Read this path from the archive session."
		return _auth_log()
	if command == "scp maint@"+TARGET+":/var/log/auth.log ~/Evidence/archive-auth.log":
		if not remote or flags.rotated: return "Preserve evidence from an authenticated session before locking maint."
		flags.evidence = true
		shell.files[HOME+"/Evidence/archive-auth.log"] = _auth_log()
		return "archive-auth.log 100% — evidence copy preserved in analyst workspace"
	if command.begins_with("sudo "):
		if not remote: return "This change requires an authenticated archive session."
		if not flags.evidence: return "Change blocked by incident procedure: preserve /var/log/auth.log first."
		match command:
			"sudo usermod -L maint": flags.rotated = true; return "Maintenance password locked; the current response session remains open."
			"sudo systemctl disable --now legacy-maint": flags.disabled = true; return "legacy-maint stopped and disabled. HTTPS remains running."
			"sudo ufw allow from 10.77.10.0/24 to any port 22": allow_ssh = true; return "Rule added: analyst subnet -> SSH"
			"sudo ufw default deny incoming": deny_incoming = true; return "Default incoming policy: deny"
			"sudo ufw enable":
				if not allow_ssh or not deny_incoming: return "Preflight failed: preserve analyst SSH access and set default deny first. Existing 443 allow rule retained."
				flags.firewall = true; return "Firewall enabled. Allowed: analyst subnet/22, any/443."
	if command == "curl https://archive.campus.test/health":
		if remote: return "Run the recovery probe from the analyst workstation after exit."
		flags.verified = flags.rotated and flags.disabled and flags.firewall
		return "HTTP/1.1 200 OK\narchive=healthy; submissions=accepting\n" + ("Security baseline verified." if flags.verified else "Availability is healthy, but the security baseline is incomplete.")
	return "Unsupported lab command or target. Run lab help for syntax."

func _auth_log() -> String:
	return "02:01:12 archive legacy-maint: Accepted password for maint from 10.77.20.88\n02:01:15 archive sudo: maint changed archive upstream to 10.77.20.88:8443\n02:02:03 archive watchdog: upstream reverted to approved pool; HTTPS restored\n02:04:18 archive legacy-maint: 37 failed passwords from 10.77.20.88\n02:05:00 archive SOC: legacy service remains exposed; temporary account unrotated\n"

func _audit(words: PackedStringArray) -> String:
	if not _reachable() or not flags.clues: return "Collect service and identity evidence before auditing authentication."
	if locked: return "429 burst limit: account temporarily locked. Use lab wait 30 and retry with --delay 1."
	var options: Dictionary = {}
	if words.size() != 9: return "Usage: audit-auth --target <IP> --user maint --candidates <file> --delay 1"
	for i in range(1,words.size(),2): options[words[i]] = words[i+1]
	if options.get("--target") != TARGET or options.get("--user") != "maint": return "Target/account outside this exercise's scope."
	if flags.rotated or flags.disabled: return "Authentication endpoint is closed."
	if not str(options.get("--delay","")).is_valid_float(): return "Delay must be a number in seconds."
	if float(options["--delay"]) < 1.0:
		attempts += 5; locked = true; return "429 burst limit after 5 attempts. Account locked for 30 simulated seconds."
	var data: Dictionary = shell.read_file(str(options.get("--candidates","")))
	if not data.ok: return data.text
	if not flags.generated or str(data.text) != generated_text: return "Use the output of your Python permutation script; a pasted/static list does not satisfy this challenge."
	for candidate: String in str(data.text).split("\n",false):
		attempts += 1
		if candidate == "1998@Nora":
			flags.recovered = true
			return "Credential validated after %d total attempts. Stored in the lab keyring.\nConnect: ssh maint@%s\nThe weakness was a predictable personal-data pattern, not a software exploit." % [attempts,TARGET]
	return "No match. Revisit case variants, token order and separators. No progress awarded."

func _python(command: String) -> String:
	var halves := command.split(" > ")
	if halves.size() != 2: return "Use python3 <script.py> > <candidates.txt> to save printed candidates."
	var data: Dictionary = shell.read_file(halves[0].trim_prefix("python3 "))
	if not data.ok: return data.text
	var destination: String = shell.resolve(halves[1])
	if not destination.begins_with(HOME+"/Documents/") or destination.get_base_dir() != HOME+"/Documents" or not destination.ends_with(".txt"): return "Write candidate output into ~/Documents/<name>.txt."
	var worker_source := preload("res://scripts/cyber/python_lab_source.gd").SOURCE
	if worker_source.is_empty(): return "Python lab runner missing from this build."
	var dir := "user://cyber_runtime"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var worker := FileAccess.open(dir+"/worker.py",FileAccess.WRITE)
	worker.store_string(worker_source); worker.close()
	var request := FileAccess.open(dir+"/request.json",FileAccess.WRITE)
	request.store_string(JSON.stringify({"source":data.text})); request.close()
	var output: Array = []
	var args := PackedStringArray(["-I","-S",ProjectSettings.globalize_path(dir+"/worker.py"),ProjectSettings.globalize_path(dir+"/request.json")])
	var code := OS.execute("python",args,output,true,false)
	if code != 0: return "Python 3 could not run. Install Python 3 on PATH to use this exercise. Details: " + str(output).left(300)
	var result: Variant = JSON.parse_string("\n".join(output))
	if not result is Dictionary: return "Python runner returned invalid output."
	if not result.get("ok",false): return "Python: " + str(result.get("error","Execution failed"))
	generated_text = str(result.text)
	shell.files[destination] = generated_text
	flags.generated = bool(result.get("permutations",false)) and generated_text.split("\n",false).size() > 1
	return "Python finished: %d candidates written to %s.\n%s" % [generated_text.split("\n",false).size(),destination,"Permutation requirement satisfied." if flags.generated else "Use itertools.permutations and print more than one candidate."]
func snapshot() -> Dictionary:
	var lab_files: Dictionary = {}
	for path: String in shell.files:
		if path.ends_with(".py") or path in [HOME+"/Documents/candidates.txt",HOME+"/Evidence/maintenance-notice.txt",HOME+"/Evidence/archive-auth.log",HOME+"/Reports/blackout-report.md"]:
			lab_files[path] = shell.files[path]
	return {"active":active,"remote":remote,"flags":flags.duplicate(),"address":address,"gateway":gateway,"attempts":attempts,"locked":locked,"allow_ssh":allow_ssh,"deny_incoming":deny_incoming,"hint_count":hint_count,"generated_text":generated_text,"transcript":transcript.duplicate(),"files":lab_files}

static func valid_snapshot(data: Dictionary) -> bool:
	if not data.get("active",false): return true
	if not data.get("flags") is Dictionary or not data.get("files") is Dictionary or not data.get("transcript") is Array: return false
	if JSON.stringify(data).length() > 1200000: return false
	for flag: String in FLAGS:
		if not data.flags.get(flag) is bool: return false
	for path: Variant in data.files:
		if not path is String or not data.files[path] is String or not path.begins_with(HOME+"/") or path.contains("..") or str(data.files[path]).length()>530000: return false
	for key: String in ["remote", "locked", "allow_ssh", "deny_incoming"]:
		if not data.get(key) is bool: return false
	for key: String in ["address", "gateway", "generated_text"]:
		if not data.get(key) is String: return false
	for key: String in ["attempts", "hint_count"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])) or float(data[key]) < 0 or float(data[key]) > 10000000: return false
	return true

func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data): return false
	if not data.get("active",false):
		active = false
		remote = false
		return true
	start()
	flags = data.flags.duplicate()
	remote = bool(data.get("remote",false))
	address = str(data.get("address",""))
	gateway = str(data.get("gateway",""))
	attempts = maxi(0,int(data.get("attempts",0)))
	locked = bool(data.get("locked",false))
	allow_ssh = bool(data.get("allow_ssh",false))
	deny_incoming = bool(data.get("deny_incoming",false))
	hint_count = maxi(0,int(data.get("hint_count",0)))
	generated_text = str(data.get("generated_text",""))
	for line: Variant in data.transcript:
		if line is String and transcript.size()<150: transcript.append(line.left(12000))
	for path: String in data.files: shell.files[path] = data.files[path]
	return true
