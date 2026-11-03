extends RefCounted
var path := "user://ensagames/tests/fixture-default.json"
var mode_id := "zombie_rpg"
var mission_id := "ZB-FIXTURE-001"
var last_error := ""
func read_save() -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary and value.get("mode_id")==mode_id and value.get("mission_id")==mission_id and value.get("score") is float else {}
func write_save(payload: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		last_error = "Cannot write isolated fixture checkpoint"
		return false
	file.store_string(JSON.stringify(payload))
	return true
func summary(payload: Dictionary) -> Dictionary:
	return {"checkpoint_name":"Fixture checkpoint %d" % int(payload.get("score",0))}
func capture(game: Node3D) -> Dictionary:
	return {"mode_id":mode_id,"mission_id":mission_id,"score":game.score}
func restore(game: Node3D,checkpoint: Dictionary) -> bool:
	if checkpoint.get("mode_id") != mode_id or checkpoint.get("mission_id") != mission_id: return false
	game.score = int(checkpoint.get("score",0))
	return true
