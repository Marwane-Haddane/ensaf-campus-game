extends SceneTree
func _init() -> void: call_deferred("run_test")
func run_test() -> void:
	var path := "res://assets/launcher/ensa-emblem-white.svg"
	var text := FileAccess.get_file_as_string(path)
	var texture := load(path) as Texture2D
	var valid := texture != null and "<path" in text and not "<image" in text and not "<text" in text
	var white := true
	var transparent := false
	if texture != null:
		var pixels := texture.get_image()
		for y: int in range(pixels.get_height()):
			for x: int in range(pixels.get_width()):
				var pixel := pixels.get_pixel(x,y)
				if pixel.a<.01: transparent = true
				elif pixel.a>.1 and minf(pixel.r,minf(pixel.g,pixel.b))<.98: white = false
	var result := {"passed":valid and white and transparent,"real_svg_paths":valid,"white_only":white,"transparent_background":transparent}
	FileAccess.open("res://tools/launcher/brand-assets-test.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("ENSA_BRAND_ASSETS ",JSON.stringify(result))
	quit(0 if result.passed else 1)
