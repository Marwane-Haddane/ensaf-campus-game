extends OmniLight3D
## Animated light for the After Hours mood: "fire" flickers, "beacon" blinks
## like a warning lamp, "alarm" pulses slowly. Reduced motion holds a steady glow.

@export var mode := "fire"
@export var base_energy := 1.0
var reduced_motion := false
var _time := 0.0
var _seed := 0.0


func _ready() -> void:
	_seed = fmod(absf(global_position.x * 13.7 + global_position.z * 7.3), 10.0)
	light_energy = base_energy


func _process(delta: float) -> void:
	if reduced_motion:
		light_energy = base_energy * (0.85 if mode != "fire" else 0.95)
		return
	_time += delta
	var t := _time + _seed
	match mode:
		"fire":
			light_energy = base_energy * (0.78 + 0.14 * sin(t * 9.1) + 0.08 * sin(t * 23.7) + 0.06 * sin(t * 3.3))
		"beacon":
			light_energy = base_energy * (1.0 if fmod(t, 1.1) < 0.45 else 0.08)
		"alarm":
			light_energy = base_energy * (0.25 + 0.75 * pow(0.5 + 0.5 * sin(t * 2.4), 2.0))
