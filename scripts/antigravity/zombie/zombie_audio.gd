extends RefCounted
## Procedural sound library for After Hours. Every sound is synthesised here at
## first use (no external files), so all of it is original work released as
## CC0. See assets/antigravity/zombie/audio/AUDIO_SOURCES.md.

const RATE := 22050
const VARIANTS := {"step": 4, "step_run": 4, "groan": 3, "alert": 2, "attack": 3, "hurt": 3, "death": 2, "enemy_step": 3}
static var _cache: Dictionary = {}

static func sfx_bus() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"

static func variant_count(kind: String) -> int:
	return int(VARIANTS.get(kind, 1))

static func stream(kind: String, variant: int = -1) -> AudioStreamWAV:
	if variant < 0:
		variant = randi() % variant_count(kind)
	var key := "%s#%d" % [kind, variant]
	if not _cache.has(key):
		_cache[key] = _bake(_synth(kind, variant))
	return _cache[key]

## One-shot non-positional sound (UI, player foley, pickups).
static func play_ui(parent: Node, kind: String, volume_db: float = -10.0, pitch_jitter: float = 0.04) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = stream(kind)
	voice.bus = sfx_bus()
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	voice.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

## Positional voice owned by an actor (reuse one per channel to bound nodes).
static func make_voice(parent: Node3D, voice_name: String, height: float, max_distance: float = 32.0) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = voice_name
	voice.position.y = height
	voice.bus = sfx_bus()
	voice.max_distance = max_distance
	voice.unit_size = 5.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(voice)
	return voice

static func play_voice(voice: AudioStreamPlayer3D, kind: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if voice == null or not voice.is_inside_tree():
		return
	voice.stream = stream(kind)
	voice.volume_db = volume_db
	voice.pitch_scale = pitch * (1.0 + randf_range(-0.05, 0.05))
	voice.play()

static func _bake(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, clampi(int(samples[i] * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav

static func _synth(kind: String, variant: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(("%s%d" % [kind, variant]).hash())
	match kind:
		"step": return _footstep(rng, 0.11, 900.0 + variant * 120.0, 0.55)
		"step_run": return _footstep(rng, 0.13, 1300.0 + variant * 150.0, 0.75)
		"enemy_step": return _footstep(rng, 0.16, 520.0 + variant * 90.0, 0.6)
		"land": return _footstep(rng, 0.22, 420.0, 0.9)
		"groan": return _voice(rng, 1.25, 82.0 + variant * 11.0, 70.0 + variant * 6.0, 0.08, 0.45)
		"alert": return _voice(rng, 0.85, 150.0 + variant * 20.0, 230.0 + variant * 25.0, 0.35, 0.8)
		"attack": return _voice(rng, 0.42, 120.0 + variant * 15.0, 165.0, 0.45, 0.85)
		"hurt": return _voice(rng, 0.32, 210.0 + variant * 25.0, 120.0, 0.3, 0.75)
		"death": return _voice(rng, 1.4, 115.0 + variant * 12.0, 48.0, 0.25, 0.7)
		"brute_roar": return _voice(rng, 1.7, 58.0, 74.0, 0.55, 1.0)
		"brute_step": return _footstep(rng, 0.3, 260.0, 1.0)
		"player_hurt": return _voice(rng, 0.28, 180.0, 130.0, 0.15, 0.6)
		"pickup": return _chime([880.0, 1320.0], 0.09, 0.4)
		"pickup_ammo": return _clack(rng)
		"medkit": return _chime([523.25, 659.25, 783.99], 0.07, 0.35)
		"ui_click": return _tick(1700.0, 0.035, 0.32)
		"ui_hover": return _tick(2400.0, 0.02, 0.14)
		"dry_fire": return _tick(3100.0, 0.05, 0.4)
		"level_start": return _drone(1.3)
		"level_clear": return _chime([392.0, 493.88, 587.33, 783.99], 0.11, 0.38)
		"checkpoint": return _chime([659.25, 987.77], 0.12, 0.3)
	return _tick(1000.0, 0.05, 0.2)

static func _footstep(rng: RandomNumberGenerator, length: float, brightness: float, gain: float) -> PackedFloat32Array:
	# Filtered noise grit on top of a short low heel thump.
	var out := PackedFloat32Array()
	var n := int(length * RATE)
	out.resize(n)
	var low := 0.0
	var coef := clampf(brightness / RATE * TAU, 0.01, 0.9)
	for i: int in n:
		var t := float(i) / RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * coef
		var grit := low * exp(-t * 38.0)
		var thump := sin(TAU * (95.0 - t * 160.0) * t) * exp(-t * 30.0) * 0.8
		out[i] = (grit * 1.6 + thump) * gain * 0.5
	return out

static func _voice(rng: RandomNumberGenerator, length: float, f_start: float, f_end: float, roughness: float, gain: float) -> PackedFloat32Array:
	# Growl: glottal pulse train through two crude formants, amplitude-modulated
	# for a wet, broken throat, plus breath noise.
	var out := PackedFloat32Array()
	var n := int(length * RATE)
	out.resize(n)
	var phase := 0.0
	var f1 := 0.0
	var f2 := 0.0
	var breath := 0.0
	var wobble := rng.randf_range(4.0, 7.0)
	for i: int in n:
		var t := float(i) / RATE
		var k := t / length
		var freq := lerpf(f_start, f_end, k) * (1.0 + 0.05 * sin(TAU * wobble * t) + rng.randf_range(-0.02, 0.02) * roughness)
		phase = fmod(phase + freq / RATE, 1.0)
		var pulse := 1.0 - 2.0 * phase
		f1 += (pulse - f1) * 0.18
		f2 += (pulse - f2 - f1 * 0.3) * 0.45
		breath += (rng.randf_range(-1.0, 1.0) - breath) * 0.3
		var rasp := 1.0 - roughness * 0.5 * (1.0 + sin(TAU * 31.0 * t + rng.randf() * 0.3))
		var env := minf(1.0, t / 0.06) * pow(1.0 - k, 1.4)
		out[i] = (f1 * 0.9 + f2 * 0.35 + breath * 0.18) * rasp * env * gain * 0.55
	return out

static func _chime(notes: Array, spacing: float, gain: float) -> PackedFloat32Array:
	var length := spacing * notes.size() + 0.35
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	for idx: int in notes.size():
		var start := int(idx * spacing * RATE)
		var f := float(notes[idx])
		for i: int in range(start, out.size()):
			var t := float(i - start) / RATE
			out[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * exp(-t * 9.0) * gain * 0.5
	return out

static func _clack(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.22 * RATE))
	for hit: float in [0.0, 0.09]:
		var start := int(hit * RATE)
		for i: int in range(start, out.size()):
			var t := float(i - start) / RATE
			out[i] += (sin(TAU * 2300.0 * t) * 0.5 + rng.randf_range(-0.5, 0.5)) * exp(-t * 70.0) * 0.4
	return out

static func _tick(freq: float, length: float, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	for i: int in out.size():
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * exp(-t * 6.0 / length) * gain
	return out

static func _drone(length: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(length * RATE))
	for i: int in out.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.15) * exp(-t * 2.2)
		out[i] = (sin(TAU * 55.0 * t) + 0.6 * sin(TAU * 82.4 * t) + 0.25 * sin(TAU * 110.7 * t)) * env * 0.3
	return out
