extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var library = preload("res://scripts/campus_materials.gd").new()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset-manifest.json")) as Dictionary
	library.configure_manifest(manifest["materials"] as Array)
	var authored: StandardMaterial3D = StandardMaterial3D.new()
	authored.resource_name = "E9 satin dark cherry bent plywood"
	var image: Image = Image.create(4,4,false,Image.FORMAT_RGB8)
	image.fill(Color("8b613c"))
	authored.albedo_texture = ImageTexture.create_from_image(image)
	var mapped_preserved: bool = library.material_for(authored) == authored
	var unknown: StandardMaterial3D = StandardMaterial3D.new()
	unknown.resource_name = "User approved mapped prop"
	var unknown_preserved: bool = library.material_for(unknown) == unknown
	var frame: StandardMaterial3D = StandardMaterial3D.new()
	frame.resource_name = "E5 charcoal bronze aluminium entrance frames"
	frame.albedo_color = Color("303336")
	var frame_result: BaseMaterial3D = library.material_for(frame, "E5 dark full-height glazing mullion") as BaseMaterial3D
	var frame_opaque: bool = frame_result.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.resource_name = "D7 clear blue-grey entrance glass"
	glass.albedo_color = Color(0.75,0.86,0.88,0.24)
	var glass_result: BaseMaterial3D = library.material_for(glass) as BaseMaterial3D
	var clear_glass: bool = glass_result.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and glass_result.albedo_color.a < 0.2
	var shared_cache: bool = library.material_for(frame) == frame_result
	var passed: bool = mapped_preserved and unknown_preserved and frame_opaque and clear_glass and shared_cache
	var report: Dictionary = {"passed": passed, "mapped_asset_preserved": mapped_preserved, "unknown_asset_preserved": unknown_preserved, "glazing_frame_opaque": frame_opaque, "glass_transparent": clear_glass, "shared_material_cache": shared_cache}
	FileAccess.open("res://tools/polish_material_contract_test.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("POLISH_MATERIAL_CONTRACT ", JSON.stringify(report))
	quit(0 if passed else 1)
