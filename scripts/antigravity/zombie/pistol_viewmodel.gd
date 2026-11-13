extends RefCounted
## Calibrates the imported pistol meshes to the hand rig and keeps them on the
## firing hand through the authored poses. Coordinates are in skeleton space.

const SOURCE_GRIP := Vector3(-2.6111, -8.0837, 1.9909)
const HAND_GRIP := Vector3(-0.4466, -1.4557, 1.044)
const SOURCE_MUZZLE := Vector3(-2.7882, -13.4373, 2.4832)
const SOURCE_MAGWELL := Vector3(-2.5953, -7.6310, -0.6479)
const MODEL_SCALE := 0.135
const SLIDE_TRAVEL := 0.073
const VIEWMODEL_LAYER := 1 << 19

var _skeleton: Skeleton3D
var _gun: int
var _slide: int
var _right_wrist: int
var _left_wrist: int
var _left_palm: int
var _shoulders: Array[int] = []
var _elbows: Array[int] = []
var _sleeve_anchors: Array[Vector3] = []
var _gun_from_wrist: Transform3D
var _slide_from_gun: Transform3D
var _muzzle: Vector3
var _magwell: Vector3
var _magazine: Node3D
var _slide_kick := 0.0
var _reload_entry: Array[Transform3D] = []

func setup(skeleton: Skeleton3D) -> bool:
	_skeleton = skeleton
	_gun = skeleton.find_bone("weapon_050")
	_slide = skeleton.find_bone("slider_051")
	_right_wrist = skeleton.find_bone("Bone.028_027")
	_left_wrist = skeleton.find_bone("Bone.005_04")
	_left_palm = skeleton.find_bone("Bone.006_05")
	var body := skeleton.get_node_or_null("Object_82") as MeshInstance3D
	var slide := skeleton.get_node_or_null("Object_83") as MeshInstance3D
	if mini(mini(_gun, _slide), mini(_right_wrist, mini(_left_wrist, _left_palm))) < 0 \
			or body == null or slide == null:
		return false

	var gun_pose := skeleton.get_bone_global_pose(_gun)
	var slide_pose := skeleton.get_bone_global_pose(_slide)
	var correction := Transform3D(Basis.from_scale(Vector3.ONE * MODEL_SCALE),
		HAND_GRIP - SOURCE_GRIP * MODEL_SCALE)
	_calibrate_skin(body, _gun, gun_pose.affine_inverse() * correction * gun_pose)
	_calibrate_skin(slide, _slide, slide_pose.affine_inverse() * correction * slide_pose)
	var authored_finish := slide.get_active_material(0) as StandardMaterial3D
	if authored_finish:
		var slide_finish := authored_finish.duplicate() as StandardMaterial3D
		slide_finish.emission_enabled = true
		slide_finish.emission = Color("212832")
		slide_finish.emission_energy_multiplier = 0.36
		slide.set_surface_override_material(0, slide_finish)
	_gun_from_wrist = skeleton.get_bone_global_pose(_right_wrist).affine_inverse() * gun_pose
	_slide_from_gun = gun_pose.affine_inverse() * slide_pose
	_muzzle = gun_pose.affine_inverse() * (correction * SOURCE_MUZZLE)
	_magwell = gun_pose.affine_inverse() * (correction * SOURCE_MAGWELL)
	_frame_sleeve("Bone.002_01", "Bone.003_02", Vector3(0.24, 0.24, -0.55))
	_frame_sleeve("Bone.025_024", "Bone.026_025", Vector3(-0.24, 0.24, -0.55))
	_build_magazine()
	_add_fill_light()
	return true

func _calibrate_skin(mesh: MeshInstance3D, bone: int, correction: Transform3D) -> void:
	var skin := mesh.skin.duplicate() as Skin
	for i in range(skin.get_bind_count()):
		if skin.get_bind_bone(i) == bone:
			skin.set_bind_pose(i, correction * skin.get_bind_pose(i))
	mesh.skin = skin

func _build_magazine() -> void:
	_magazine = Node3D.new()
	_magazine.name = "PistolMagazine"
	_skeleton.add_child(_magazine)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("555d6b")
	steel.metallic = 0.68
	steel.roughness = 0.5
	var base := StandardMaterial3D.new()
	base.albedo_color = Color("22262c")
	var cartridge := StandardMaterial3D.new()
	cartridge.albedo_color = Color("b69854")
	cartridge.metallic = 0.55
	_add_magazine_part(Vector3(0.079, 0.135, 0.234), Vector3(0, 0, -0.066), steel)
	_add_magazine_part(Vector3(0.104, 0.153, 0.029), Vector3(0, 0, 0.065), base)
	_add_magazine_part(Vector3(0.041, 0.089, 0.021), Vector3(0, 0.009, -0.183), cartridge)

func _add_magazine_part(dimensions: Vector3, position: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	part.mesh = box
	part.material_override = material
	part.position = position
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_magazine.add_child(part)

func _add_fill_light() -> void:
	for mesh: Node in _skeleton.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers |= VIEWMODEL_LAYER
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 0.40, 0.45)
	fill.light_cull_mask = VIEWMODEL_LAYER
	fill.light_color = Color("d1dfff")
	fill.light_energy = 0.29
	fill.omni_range = 1.6
	_skeleton.add_child(fill)

func _frame_sleeve(shoulder_name: String, elbow_name: String, offset: Vector3) -> void:
	var shoulder := _skeleton.find_bone(shoulder_name)
	var elbow := _skeleton.find_bone(elbow_name)
	if shoulder >= 0 and elbow >= 0:
		_shoulders.append(shoulder)
		_elbows.append(elbow)
		_sleeve_anchors.append(_skeleton.get_bone_global_pose(shoulder).origin + offset)

func _position_sleeves() -> void:
	# Extend the open end of each sleeve below the camera while preserving the
	# authored elbow and hand transforms.
	for i in range(_shoulders.size()):
		var shoulder := _skeleton.get_bone_global_pose(_shoulders[i])
		var elbow := _skeleton.get_bone_global_pose(_elbows[i])
		shoulder.origin = _sleeve_anchors[i]
		_skeleton.set_bone_global_pose(_shoulders[i], shoulder)
		_skeleton.set_bone_global_pose(_elbows[i], elbow)

func fire() -> void:
	_slide_kick = 1.0

func begin_reload() -> void:
	_reload_entry.clear()
	for i in range(_skeleton.get_bone_count()):
		_reload_entry.append(_skeleton.get_bone_pose(i))

func apply(delta: float, reload_progress: float, empty: bool) -> void:
	if reload_progress >= 0.0 and reload_progress < 0.12:
		var weight := smoothstep(0.0, 0.12, reload_progress)
		for i in range(_reload_entry.size()):
			var pose := _reload_entry[i].interpolate_with(_skeleton.get_bone_pose(i), weight)
			_skeleton.set_bone_pose_position(i, pose.origin)
			_skeleton.set_bone_pose_rotation(i, pose.basis.get_rotation_quaternion())
	_position_sleeves()
	_slide_kick = move_toward(_slide_kick, 0.0, delta * 12.0)
	var gun_pose := _skeleton.get_bone_global_pose(_right_wrist) * _gun_from_wrist
	var slide_pose := gun_pose * _slide_from_gun
	var seated := reload_progress >= 0.76
	var locked := empty and not seated
	slide_pose.origin -= gun_pose.basis.y.normalized() * SLIDE_TRAVEL * maxf(_slide_kick, float(locked))
	_skeleton.set_bone_global_pose(_gun, gun_pose)
	_skeleton.set_bone_global_pose(_slide, slide_pose)

	var distance := smoothstep(0.22, 0.46, reload_progress) * (1.0 - smoothstep(0.52, 0.76, reload_progress))
	var magazine_pose := gun_pose.orthonormalized()
	magazine_pose.origin = gun_pose * _magwell
	magazine_pose.origin += magazine_pose.basis * Vector3(0.11 * distance, 0.0, 0.27 * distance)
	_magazine.transform = magazine_pose
	_magazine.visible = reload_progress >= 0.21 and reload_progress < 0.77

	if reload_progress >= 0.0:
		var contact := smoothstep(0.15, 0.30, reload_progress) * (1.0 - smoothstep(0.76, 0.91, reload_progress))
		var palm := _skeleton.get_bone_global_pose(_left_palm).origin
		var wrist := _skeleton.get_bone_global_pose(_left_wrist)
		var grip_point := magazine_pose * Vector3(0.076, 0.0, 0.008)
		wrist.origin += (grip_point - palm).limit_length(0.25) * contact
		_skeleton.set_bone_global_pose(_left_wrist, wrist)

func muzzle_position() -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(_gun) * _muzzle)
