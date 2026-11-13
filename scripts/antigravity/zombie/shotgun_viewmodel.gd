extends RefCounted
## Mechanical animation for the rigged Benelli. Positions use the imported model's local units.

const Geometry = preload("res://scripts/antigravity/zombie/prop_geometry.gd")
const LOAD_PORT := Vector3(0, -0.19, -0.23)
const EJECTION_PORT := Vector3(0.086, 0.054, -0.41)
const FIRE_TIME := 0.24
const DRAW_TIME := 0.30
const VIEWMODEL_LAYER := 1 << 19
const SUPPORT_GRIP := Vector3(-0.12, -0.12, -0.99)
const FIRING_GRIP := Vector3(0.12, -0.26, 0.17)
const ARMS_PATH := "res://assets/antigravity/zombie/models/pistol_hands.scn"

var _model: Node3D
var _skeleton: Skeleton3D
var _bolt := -1
var _bolt_rest: Vector3
var _bolt_travel: Vector3
var _loading_shell: Node3D
var _spent_shell: Node3D
var _shot_clock := FIRE_TIME
var _draw_clock := DRAW_TIME
var _bolt_locked := false
var _arms: Skeleton3D
var _support_bones: Array[int] = []
var _support_rest: Array[Transform3D] = []
var _support_weights: Array[float] = []
var _sleeve_bones: Array[int] = []
var _sleeve_rest: Array[Transform3D] = []
var _wrist_rest: Vector3

var offset := Vector3.ZERO
var angles := Vector3.ZERO

func setup(model: Node3D, skeleton: Skeleton3D, empty: bool) -> void:
	_model = model
	_skeleton = skeleton
	_bolt = skeleton.find_bone("Bone Gun Object_2") if skeleton else -1
	if _bolt >= 0:
		_bolt_rest = skeleton.get_bone_pose_position(_bolt)
		var parent := skeleton.get_bone_parent(_bolt)
		var parent_frame := skeleton.global_basis * skeleton.get_bone_global_rest(parent).basis
		_bolt_travel = parent_frame.inverse() * (model.global_basis * Vector3(0, 0, 0.135))
	_loading_shell = _make_shell(Color("9c3027"))
	_spent_shell = _make_shell(Color("5c2924"))
	_setup_arms()
	_add_fill_light()
	_bolt_locked = empty
	update(0.0, -1.0, -1.0)

func draw() -> void:
	_draw_clock = 0.0

func fire(last_round: bool) -> void:
	_shot_clock = 0.0
	_bolt_locked = last_round

func chamber_loaded() -> void:
	_bolt_locked = false

func muzzle_position() -> Vector3:
	return _model.to_global(Vector3(-0.006, 0.067, -1.545))

func update(delta: float, handling: float, insert_phase: float) -> void:
	_shot_clock = minf(_shot_clock + delta, FIRE_TIME)
	_draw_clock = minf(_draw_clock + delta, DRAW_TIME)
	var kick := smoothstep(0.0, 0.035, _shot_clock) * (1.0 - smoothstep(0.04, 0.22, _shot_clock))
	var raised := 1.0 - smoothstep(0.0, DRAW_TIME, _draw_clock)
	var loading := clampf(handling, 0.0, 1.0)
	offset = Vector3(0.05 * loading, 0.025 * loading - 0.22 * raised, 0.055 * kick + 0.03 * loading)
	angles = Vector3(0.11 * kick - 0.42 * raised - 0.06 * loading, -0.31 * loading, -0.61 * loading)

	var opened := smoothstep(0.012, 0.048, _shot_clock)
	if not _bolt_locked:
		opened *= 1.0 - smoothstep(0.072, 0.135, _shot_clock)
	if _bolt >= 0:
		_skeleton.set_bone_pose_position(_bolt, _bolt_rest + _bolt_travel * opened)

	_spent_shell.visible = _shot_clock >= 0.032 and _shot_clock < FIRE_TIME
	if _spent_shell.visible:
		var time := (_shot_clock - 0.032) / (FIRE_TIME - 0.032)
		_spent_shell.position = EJECTION_PORT + Vector3(1.15 * time, 0.52 * time - 0.8 * time * time, 0.3 * time)
		_spent_shell.rotation = Vector3(1.55 + time * 8.0, time * 5.0, time * 4.0)

	_loading_shell.visible = insert_phase >= 0.0 and insert_phase < 0.82
	if _loading_shell.visible:
		var approach := smoothstep(0.0, 0.55, insert_phase)
		var seat := smoothstep(0.55, 0.82, insert_phase)
		_loading_shell.position = LOAD_PORT + Vector3(0, -0.36 * (1.0 - approach), 0.48 * (1.0 - approach) - 0.19 * seat)
		_loading_shell.rotation = Vector3(1.57 - 0.40 * (1.0 - approach), 0, 0)

	var support := SUPPORT_GRIP
	var reach := 0.0
	if insert_phase >= 0.0:
		reach = smoothstep(0.0, 0.22, insert_phase) * (1.0 - smoothstep(0.82, 1.0, insert_phase))
		support = SUPPORT_GRIP.lerp(_loading_shell.position + Vector3(-0.10, -0.06, 0.22), reach)
	elif loading > 0.0:
		support += Vector3(-0.17, -0.21, 0.28) * loading
	_pose_support_hand(support, reach)

func _setup_arms() -> void:
	var arms_scene := load(ARMS_PATH) as PackedScene
	var model := arms_scene.instantiate() as Node3D
	_model.add_child(model)
	model.rotation.y = PI
	model.scale = Vector3.ONE * 0.39
	_arms = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var animation := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.play("Armature|A_Origin")
	animation.advance(0.0)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == &"Object_12":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mesh.free()
	var firing_wrist := _arms.find_bone("Bone.028_027")
	var support_wrist := _arms.find_bone("Bone.005_04")
	if firing_wrist < 0 or support_wrist < 0:
		return
	var wrist_in_model := _model.to_local(_arms.to_global(_arms.get_bone_global_pose(firing_wrist).origin))
	model.position += FIRING_GRIP - wrist_in_model
	_wrist_rest = _arms.get_bone_global_pose(support_wrist).origin
	# Preserve the exact pistol cloth/glove materials and complete finger chains.
	# The first three bones form each sleeve; keep the wrists at their grips.
	for index in range(1, 29):
		_support_bones.append(index)
		_support_rest.append(_arms.get_bone_global_pose(index))
		_support_weights.append(1.0 if index >= 4 else float(index - 1) / 3.0)
	for index in [1, 29]:
		_sleeve_bones.append(index)
		_sleeve_rest.append(_arms.get_bone_global_pose(index))

func _pose_support_hand(grip: Vector3, reach: float) -> void:
	if _support_bones.is_empty():
		return
	var displacement := _arms.to_local(_model.to_global(grip)) - _wrist_rest
	var roll_axis := (_arms.global_basis.inverse() * _model.global_basis.z).normalized()
	var roll := Basis(roll_axis, 0.32 * reach)
	for i in _support_bones.size():
		var pose := _support_rest[i]
		var weight := _support_weights[i]
		if weight == 1.0:
			pose.origin = _wrist_rest + roll * (pose.origin - _wrist_rest)
			pose.basis = roll * pose.basis
		pose.origin += displacement * weight
		_arms.set_bone_global_pose_override(_support_bones[i], pose, 1.0, true)

	# Anchor both jacket openings below the view, rather than stretching a bare cuff.
	for i in _sleeve_bones.size():
		var pose := _sleeve_rest[i]
		var anchor := Vector3(-0.45, -0.85, -0.12) if i == 0 else Vector3(0.55, -0.85, -0.10)
		pose.origin = _arms.to_local((_model.get_parent() as Node3D).to_global(anchor))
		_arms.set_bone_global_pose_override(_sleeve_bones[i], pose, 1.0, true)

func _add_fill_light() -> void:
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers |= VIEWMODEL_LAYER
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.6, 0.7, -0.65)
	fill.light_cull_mask = VIEWMODEL_LAYER
	fill.light_color = Color("e6ecff")
	fill.light_energy = 0.45
	fill.omni_range = 1.5
	_model.add_child(fill)

func _make_shell(tint: Color) -> Node3D:
	var shell := Node3D.new()
	_model.add_child(shell)
	Geometry.cylinder(shell, 0.024, 0.125, Vector3.ZERO, Geometry.metal(tint, 0.0))
	Geometry.cylinder(shell, 0.025, 0.028, Vector3(0, -0.064, 0), Geometry.metal(Color("bd8742"), 0.5))
	for mesh: Node in shell.get_children():
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shell
