extends RefCounted
## Explicit state ownership; panel navigation is separate from world lifecycle.
const TRANSITIONS := {
	"STARTUP":["INITIALIZING","ERROR"], "INITIALIZING":["MAIN_MENU","ERROR"],
	"MAIN_MENU":["SELECT_MODE","ERROR"], "SELECT_MODE":["MAIN_MENU","LOADING_GAME","ERROR"],
	"LOADING_GAME":["READY","ERROR","CANCELLED"], "READY":["PLAYING","CANCELLED","ERROR"],
	"PLAYING":["MAIN_MENU","ERROR"], "ERROR":["MAIN_MENU","SELECT_MODE","CANCELLED"],
	"CANCELLED":["MAIN_MENU","ERROR"]}
var value := "STARTUP"
var history: Array[String] = ["STARTUP"]
func change(next: String) -> bool:
	if next == value: return true
	if not next in TRANSITIONS.get(value,[]): return false
	value = next
	history.append(next)
	return true
