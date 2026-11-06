extends SceneTree

const Reader = preload("res://scripts/assets/humanoid_animation.gd")
const Defaults = preload("res://scripts/assets/default_animations.gd")
const Animator = preload("res://scripts/assets/avatar_animator.gd")
var passed := 0
var failed := 0

class Coordinator extends Node:
	var peer
	var current_session_id := "test"
	var session_busy := false

class Remote extends Node3D:
	var avatar: Node3D

class LocalPlayer extends CharacterBody3D:
	var avatar_size := 1.0
	var avatar_model: Node3D

class ModelValidationLoader extends Node:
	var animation_calls := 0
	var model_calls := 0
	var avatar_valid := true
	var model_loads := true
	var animation_import_error := "Animation file has no clips or exceeds the 64-clip limit."
	var cache
	func get_asset_cache(): return cache
	func _validate_avatar(_path, require_humanoid: bool = false):
		if require_humanoid: model_calls += 1
		return avatar_valid and (model_loads or not require_humanoid)
	func _load_model_from_file(_path):
		model_calls += 1
		if not model_loads: return null
		var model = Node3D.new()
		model.add_child(Skeleton3D.new())
		model.set_meta("humanoid_bones", {"head": "Head"})
		return model
	func read_animation(_path):
		animation_calls += 1
		return {}

class ValidationCache extends RefCounted:
	var last_error := ""
	func import_file(path, _kind, validator):
		await validator.call(path)
		return {}

func _initialize():
	call_deferred("run")

func check(value: bool, title: String):
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func fixture() -> PackedByteArray:
	var binary = PackedFloat32Array([0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.3826834, 0.0, 0.9238795]).to_byte_array()
	var json = {"asset": {"version": "2.0"}, "nodes": [{"name": "Hips"}],
		"extensions": {"VRMC_vrm_animation": {"specVersion": "1.0", "humanoid": {"humanBones": {"hips": {"node": 0}}}}},
		"buffers": [{"byteLength": binary.size()}],
		"bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 8}, {"buffer": 0, "byteOffset": 8, "byteLength": 32}],
		"accessors": [{"bufferView": 0, "componentType": 5126, "count": 2, "type": "SCALAR"},
			{"bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC4"}],
		"animations": [{"name": "Turn", "samplers": [{"input": 0, "output": 1}],
			"channels": [{"sampler": 0, "target": {"node": 0, "path": "rotation"}}]}]}
	return pack(json, binary)

func pack(json: Dictionary, binary: PackedByteArray) -> PackedByteArray:
	var text = JSON.stringify(json).to_utf8_buffer()
	while text.size() % 4:
		text.append(32)
	var bytes = PackedByteArray()
	bytes.resize(20)
	bytes.encode_u32(0, 0x46546c67)
	bytes.encode_u32(4, 2)
	bytes.encode_u32(8, 28 + text.size() + binary.size())
	bytes.encode_u32(12, text.size())
	bytes.encode_u32(16, 0x4e4f534a)
	bytes.append_array(text)
	var chunk = PackedByteArray()
	chunk.resize(8)
	chunk.encode_u32(0, binary.size())
	chunk.encode_u32(4, 0x004e4942)
	bytes.append_array(chunk)
	bytes.append_array(binary)
	return bytes

func run():
	await test_model_validation_separation()
	test_document_structure_regressions()
	test_avatar_dimensions()
	test_remote_motion()
	await test_walk_to_standing()
	var standing_source = Defaults.clip("neutral")
	check(standing_source.get("standing_legs") == "A_TPose", "standing uses aligned reference legs instead of wide staggered idle legs")
	var aligned := true
	for track in standing_source.tracks:
		if track.bone in ["hips", "leftUpperLeg", "rightUpperLeg", "leftLowerLeg", "rightLowerLeg", "leftFoot", "rightFoot"]:
			aligned = aligned and track.keys.size() == 1 and track.keys[0].rotation.is_equal_approx(Quaternion.IDENTITY)
	check(aligned, "standing hips and legs have no staggered walk or idle rotations")
	check(standing_source.get("source_clip") == "Idle_Loop", "standing samples an authored standing pose, never a frozen forward-walk frame")
	var airborne = load("res://scripts/assets/animation_controller.gd").new()
	check(airborne.resolve_motion(false, Vector3(0, -3, 0), 0) == "neutral", "descending does not start a falling animation")
	check(not "fall" in Defaults.IDS, "falling clip is removed from default selection")
	airborne.free()
	var view_policy = load("res://scripts/assets/first_person_avatar.gd")
	check(view_policy.is_camera_interior_bone("chest") and view_policy.is_camera_interior_bone("hips") and not view_policy.is_camera_interior_bone("leftUpperArm"), "local camera hides interior torso but preserves arms")
	check(view_policy.has_method("is_camera_interior_bone"), "first-person filtering excludes camera-intersecting torso as well as head")
	var strafe_service = load("res://scripts/assets/animation_controller.gd").new()
	check(strafe_service.has_method("strafe_pose"), "sideways animation has a leg-only composition policy")
	if strafe_service.has_method("strafe_pose"):
		for role in ["strafe_left", "strafe_right"]:
			var composed = strafe_service.strafe_pose(Defaults.clip(role))
			var forward = Defaults.clip("walk")
			var stable := true
			for track in composed.tracks:
				if track.bone in ["leftUpperArm", "rightUpperArm", "leftLowerArm", "rightLowerArm", "leftShoulder", "rightShoulder", "chest", "hips"]:
					var reference = forward.tracks.filter(func(item): return item.bone == track.bone)
					stable = stable and not reference.is_empty() and track.keys.size() == reference[0].keys.size() and track.keys.size() > 1 and track.source_rest.is_equal_approx(reference[0].source_rest)
					if not reference.is_empty() and track.keys.size() == reference[0].keys.size():
						for index in track.keys.size():
							stable = stable and track.keys[index].rotation.is_equal_approx(reference[0].keys[index].rotation)
			check(stable, role + " uses identical forward-walk arm and torso motion without sideways twisting")
	var standing = Defaults.clip("neutral")
	check(standing.tracks.all(func(track): return track.keys.size() == 1), "standing idle is a fixed pose with no animated motion")
	strafe_service.free()
	await test_tracking_targets()
	var first_person_service = load("res://scripts/assets/first_person_avatar.gd")
	check(first_person_service.has_method("prepare"), "first-person geometry is prepared during detached import, not cut on camera attachment")
	var direction_controller = load("res://scripts/assets/animation_controller.gd").new()
	check(direction_controller.resolve_motion(true, Vector3(-2, 0, 0), 0) == "strafe_left", "leftward movement chooses left strafe")
	check(direction_controller.resolve_motion(true, Vector3(2, 0, 0), 0) == "strafe_right", "rightward movement chooses right strafe")
	check(direction_controller.resolve_motion(true, Vector3.ZERO, 0) == "neutral", "standing still has no idle animation")
	check("walk_reference_speed" in direction_controller, "locomotion supports player-relative run threshold")
	if "walk_reference_speed" in direction_controller:
		direction_controller.walk_reference_speed = 2.0
		check(direction_controller.resolve_motion(true, Vector3(0, 0, -2), 0) == "walk", "default VR walking remains walk")
		check(direction_controller.resolve_motion(true, Vector3(0, 0, -3), 0) == "run", "default VR sprint selects run below old 4 m/s threshold")
		check(direction_controller.resolve_motion(true, Vector3(0, 0, -2.4), 0) == "run", "run hysteresis retains run near boundary")
		check(direction_controller.resolve_motion(true, Vector3(0, 0, -2.1), 0) == "walk", "slowing down returns to walk")
		check(direction_controller.resolve_motion(true, Vector3(0, 0, -2.4), 0) == "walk", "walk hysteresis avoids threshold flicker")
		direction_controller.walk_reference_speed = 5.0
		check(direction_controller.resolve_motion(true, Vector3(0, 0, -5), 0) == "walk", "fast configured VR walking is not mistaken for sprint")
		check(direction_controller.resolve_motion(true, Vector3(0, 0, -7.5), 0) == "run", "configured VR sprint selects run")
		check(direction_controller.resolve_motion(true, Vector3(7.5, 0, 0), 0) == "strafe_right", "sprint preserves strafe precedence")
		check(direction_controller.resolve_motion(true, Vector3.ZERO, 0) == "neutral", "stationary sprint cannot select run")
		check(direction_controller.resolve_motion(false, Vector3(0, 2, -7.5), 0) == "jump", "sprint preserves airborne role")
	var masked = direction_controller.tracking_mask(Defaults.clip("walk"))
	var bones: Array = masked.tracks.map(func(track): return track.bone)
	check("leftUpperArm" in bones and "rightLowerArm" in bones and "chest" in bones, "VR tracking mask preserves untracked arms and torso animation")
	check(not "head" in bones and not "leftHand" in bones and not "rightHand" in bones, "VR tracking mask excludes only tracked head and hands")
	direction_controller.free()
	await test_transition_blending()
	var walk = Defaults.clip("walk")
	var upper_tracks: Dictionary = {}
	for track in walk.tracks:
		upper_tracks[track.bone] = track
	check(upper_tracks.has("leftLowerArm") and upper_tracks.has("rightLowerArm") and upper_tracks.has("chest"),
		"bundled walk includes elbows and chest, not only straight T-pose shoulder swings")
	check(walk.get("provenance", {}).get("author") == "Quaternius", "default walk uses licensed third-party animation data, not procedural recipes")
	await test_authored_upper_body()
	var reader = Reader.new()
	var bytes = fixture()
	var parsed = reader.read_bytes(bytes)
	check(not parsed.is_empty() and parsed.clips[0].name == "Turn", "runtime VRMA parser reads real GLB channels")
	if parsed.is_empty():
		quit(1)
		return
	check(parsed.clips[0].duration == 1.0 and parsed.clips[0].tracks[0].bone == "hips", "clip duration and humanoid mapping retained")
	check(reader.read_bytes(bytes.slice(0, 24)).is_empty(), "truncated binary rejected quietly")
	var doc = reader.document(bytes)
	doc.json.buffers[0].uri = "file:///etc/passwd"
	check(reader.read_bytes(pack(doc.json, doc.binary)).is_empty(), "external URI rejected")
	doc.json.buffers[0].erase("uri")
	doc.json.animations[0].channels[0].target.path = "translation"
	check(reader.read_bytes(pack(doc.json, doc.binary)).is_empty(), "unsupported root motion rejected explicitly")
	doc.json.animations[0].channels[0].target.path = "rotation"
	doc.json.accessors[1].count = 99999999
	check(reader.read_bytes(pack(doc.json, doc.binary)).is_empty(), "oversized accessor rejected before allocation")
	var avatar = Node3D.new()
	var skeleton = Skeleton3D.new()
	skeleton.name = "Rig"
	avatar.add_child(skeleton)
	skeleton.add_bone("MappedHips")
	skeleton.set_bone_rest(0, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3.ZERO))
	avatar.set_meta("humanoid_bones", {"hips": "MappedHips"})
	root.add_child(avatar)
	var bound = reader.bind_clip(parsed.clips[0], avatar)
	check(bound != null and bound.track_get_path(0) == NodePath("Rig:MappedHips"), "retarget uses validated metadata instead of source node name")
	check(bound.track_get_key_value(0, 0).is_equal_approx(skeleton.get_bone_rest(0).basis.get_rotation_quaternion()), "retarget preserves target rest rotation")
	var source = parsed.clips[0].duplicate(true)
	source.tracks[0].source_rest = Quaternion(Vector3.UP, 0.7)
	var converted = reader.bind_clip(source, avatar)
	var rest_rotation = skeleton.get_bone_rest(0).basis.get_rotation_quaternion()
	var axis_conversion = rest_rotation.inverse() * source.tracks[0].source_rest
	var expected = rest_rotation * axis_conversion * source.tracks[0].keys[1].rotation * axis_conversion.inverse()
	check(converted.track_get_key_value(0, 1).is_equal_approx(expected), "hierarchical rest-axis conversion applied to imported rotation deltas")
	var animator = Animator.new()
	avatar.add_child(animator)
	animator.attach(avatar)
	check(animator.play_clip(parsed.clips[0], true, 1.0, 0.5), "dedicated AnimationPlayer starts imported clip")
	animator.player.advance(0.1)
	check(animator.player.current_animation_position > 0.5, "playhead advances from requested offset")
	animator.set_paused(true)
	check(not animator.player.is_playing(), "pause freezes player")
	animator.stop()
	check(not animator.player.is_playing(), "stop applies reset and stops player")
	for id in Defaults.IDS:
		var clip = Defaults.clip(id)
		check(not clip.is_empty() and clip.duration > 0 and not clip.tracks.is_empty(), "offline CC0 default: " + id)
		check(absf(clip.duration - AnimationState.DURATIONS[id]) < 0.00001, "wire duration matches authored clip: " + id)
	avatar.free()
	await test_ui(bytes)
	await test_wheel()
	await test_controller(parsed)
	await test_automatic_playback()
	await test_network()
	print("\nAnimation contracts: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_walk_to_standing():
	var avatar = Node3D.new()
	var rig = Skeleton3D.new()
	rig.name = "Rig"
	avatar.add_child(rig)
	var mapping: Dictionary = {}
	for track in Defaults.clip("neutral").tracks:
		rig.add_bone(track.bone)
		mapping[track.bone] = track.bone
	avatar.set_meta("humanoid_bones", mapping)
	root.add_child(avatar)
	var animator = Animator.new()
	avatar.add_child(animator)
	animator.attach(avatar)
	var reference = Reader.new().bind_clip(Defaults.clip("neutral"), avatar)
	for phase in [0.1, 0.45, 0.9]:
		animator.play_clip(Defaults.clip("walk"), true, 1.0, phase)
		animator.player.advance(0.3)
		animator.play_clip(Defaults.clip("neutral"), false)
		animator.player.advance(0.4)
		var clean := true
		for track in reference.get_track_count():
			var bone = rig.find_bone(String(reference.track_get_path(track).get_subname(0)))
			clean = clean and rig.get_bone_pose_rotation(bone).angle_to(reference.track_get_key_value(track, 0)) < 0.002
		check(clean, "stopping walk at phase %s settles every bone to standing without leftover walk pose" % phase)
		var frozen = rig.get_bone_pose_rotation(rig.find_bone("leftUpperLeg"))
		animator.player.advance(1.5)
		check(frozen.angle_to(rig.get_bone_pose_rotation(rig.find_bone("leftUpperLeg"))) < 0.002, "standing remains motionless after transition")
	avatar.free()

func test_tracking_targets():
	var rig = Skeleton3D.new()
	root.add_child(rig)
	for name in ["Head", "Upper", "Lower", "Hand"]: rig.add_bone(name)
	rig.set_bone_parent(2, 1)
	rig.set_bone_parent(3, 2)
	rig.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)))
	rig.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0.2, 1.4, 0)))
	rig.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(0.3, 0, 0)))
	rig.set_bone_rest(3, Transform3D(Basis.IDENTITY, Vector3(0.3, 0, 0)))
	rig.reset_bone_poses()
	var head = Node3D.new()
	var hand = Node3D.new()
	root.add_child(head)
	root.add_child(hand)
	head.position = Vector3(0.05, 1.7, -0.1)
	hand.position = Vector3(0.55, 1.2, -0.2)
	var camera_before = head.global_transform
	var modifier = load("res://scripts/assets/avatar_tracking.gd").new()
	rig.add_child(modifier)
	modifier.configure({"head": "Head", "leftUpperArm": "Upper", "leftLowerArm": "Lower", "leftHand": "Hand"}, head, hand, null)
	modifier._process_modification()
	check(rig.get_bone_global_pose(3).origin.distance_to(hand.position) < 0.015, "final-pose arm IK places wrist at controller target")
	check(rig.get_bone_global_pose(0).origin.distance_to(head.position) < 0.001, "avatar head follows independent headset target")
	check(head.global_transform.is_equal_approx(camera_before), "tracking solver never moves headset/camera target")
	# Animation changes upstream arm rotations; final tracking must still win.
	rig.set_bone_pose_rotation(1, Quaternion(Vector3.UP, 0.8))
	modifier._process_modification()
	check(rig.get_bone_global_pose(3).origin.distance_to(hand.position) < 0.015, "arm IK corrects animated shoulder/elbow changes back to tracked wrist")
	rig.free()
	head.free()
	hand.free()

func test_transition_blending():
	var avatar = Node3D.new()
	var rig = Skeleton3D.new()
	rig.name = "Rig"
	rig.add_bone("Arm")
	avatar.add_child(rig)
	avatar.set_meta("humanoid_bones", {"leftUpperArm": "Arm"})
	root.add_child(avatar)
	var animator = Animator.new()
	avatar.add_child(animator)
	animator.attach(avatar)
	var first = {"duration": 1.0, "tracks": [{"bone": "leftUpperArm", "keys": [{"time": 0.0, "rotation": Quaternion(Vector3.FORWARD, 0.8)}, {"time": 1.0, "rotation": Quaternion(Vector3.FORWARD, 0.8)}]}]}
	var second = first.duplicate(true)
	for key in second.tracks[0].keys: key.rotation = Quaternion(Vector3.FORWARD, -0.8)
	animator.play_clip(first)
	animator.player.advance(0.5)
	var before = rig.get_bone_pose_rotation(0)
	animator.play_clip(second)
	check(before.angle_to(rig.get_bone_pose_rotation(0)) < 0.02, "changing clips preserves current pose instead of snapping")
	animator.player.advance(0.1)
	var middle = rig.get_bone_pose_rotation(0)
	check(before.angle_to(middle) > 0.1 and middle.angle_to(Quaternion(Vector3.FORWARD, -0.8)) > 0.1, "transition passes through an intermediate blended pose")
	animator.play_clip(first)
	check(middle.angle_to(rig.get_bone_pose_rotation(0)) < 0.02, "interrupting a blend starts from the currently visible pose")
	animator.player.advance(0.4)
	check(rig.get_bone_pose_rotation(0).angle_to(before) < 0.02, "blend converges to the requested animation")
	var jump_pose = first.duplicate(true)
	jump_pose.motion_role = "jump"
	var standing_pose = second.duplicate(true)
	standing_pose.motion_role = "neutral"
	animator.play_clip(jump_pose)
	animator.player.advance(0.4)
	animator.play_clip(standing_pose)
	animator.player.advance(0.25)
	check(rig.get_bone_pose_rotation(0).angle_to(Quaternion(Vector3.FORWARD, -0.8)) > 0.1, "jump to standing remains blended beyond ordinary transition duration")
	animator.player.advance(0.35)
	check(rig.get_bone_pose_rotation(0).angle_to(Quaternion(Vector3.FORWARD, -0.8)) < 0.02, "jump to standing settles within six tenths of a second")
	var desktop_camera = Camera3D.new()
	var xr_origin = XROrigin3D.new()
	var xr_camera = XRCamera3D.new()
	var body = Node3D.new()
	root.add_child(body)
	body.add_child(desktop_camera)
	body.add_child(xr_origin)
	xr_origin.add_child(xr_camera)
	desktop_camera.position = Vector3(0, 1.6, 0)
	xr_camera.position = Vector3(0.1, 1.7, 0.2)
	var desktop_before = desktop_camera.global_transform
	var xr_before = xr_camera.global_transform
	animator.play_clip(second)
	animator.player.advance(0.3)
	check(desktop_camera.global_transform.is_equal_approx(desktop_before) and xr_camera.global_transform.is_equal_approx(xr_before),
		"avatar transition leaves independent desktop and tracked XR camera transforms unchanged")
	body.free()
	avatar.free()

func test_authored_upper_body():
	var walk = Defaults.clip("walk")
	for bone in ["leftUpperArm", "rightUpperArm", "leftLowerArm", "rightLowerArm", "leftHand", "rightHand", "chest"]:
		var tracks = walk.tracks.filter(func(track): return track.bone == bone)
		check(tracks.size() == 1 and tracks[0].keys.size() > 20, "authored full-body walk has sampled " + bone + " motion")
		if tracks.is_empty(): continue
		var first: Quaternion = tracks[0].keys[0].rotation
		var maximum := 0.0
		for key in tracks[0].keys:
			maximum = maxf(maximum, first.angle_to(key.rotation))
		check(maximum > 0.01, "walk changes " + bone + " rather than holding the rest pose")
	if not FileAccess.file_exists("res://real-avatar.vrm"):
		print("SKIP: optional real VRM fixture; set AVATAR_FIXTURE to a permitted local avatar")
		return
	var avatar = await root.get_node("DataLoader")._load_model_from_file("res://real-avatar.vrm")
	check(avatar != null, "production loader imports real VRM regression fixture")
	if avatar == null: return
	root.add_child(avatar)
	var camera = Camera3D.new()
	root.add_child(camera)
	var other_camera = Camera3D.new()
	root.add_child(other_camera)
	var first_person = load("res://scripts/assets/first_person_avatar.gd")
	var original_meshes: Dictionary = {}
	for mesh in avatar.find_children("*", "MeshInstance3D", true, false):
		if not mesh.get_meta("first_person_derivative", false): original_meshes[mesh] = mesh.mesh
	check(first_person.apply(avatar, camera), "real combined VRM mesh splits head triangles for first-person rendering")
	var unchanged := true
	for mesh in original_meshes: unchanged = unchanged and mesh.mesh == original_meshes[mesh]
	check(unchanged, "first-person activation leaves every original third-person mesh unchanged")
	check(other_camera.cull_mask & first_person.BODY_LAYER == 0, "other cameras exclude local first-person derivative layer")
	var count_before = avatar.find_children("*", "MeshInstance3D", true, false).size()
	first_person.apply(avatar, camera)
	check(avatar.find_children("*", "MeshInstance3D", true, false).size() == count_before, "repeated first-person activation never creates more geometry")
	check(camera.cull_mask & first_person.HEAD_LAYER == 0 and other_camera.cull_mask & first_person.HEAD_LAYER != 0,
		"only player camera excludes head layer; other cameras keep head visible")
	camera.queue_free()
	other_camera.queue_free()
	var animator = Animator.new()
	avatar.add_child(animator)
	animator.attach(avatar)
	check(animator.play_clip(walk, true, 1.0, 0.25), "third-party full-body walk binds to real VRM metadata")
	var skeleton = Reader.new()._skeleton(avatar)
	var mapping: Dictionary = avatar.get_meta("humanoid_bones")
	for side in ["left", "right"]:
		var arm = skeleton.find_bone(mapping[side + "UpperArm"])
		var hand = skeleton.find_bone(mapping[side + "Hand"])
		animator.player.advance(0)
		var offset = skeleton.get_bone_global_pose(hand).origin - skeleton.get_bone_global_pose(arm).origin
		check(offset.y < -0.15, "real VRM " + side + " hand drops below shoulder instead of T-posing")
		var initial_hand = skeleton.get_bone_global_pose(hand).origin
		animator.player.seek(0.7, true)
		animator.player.advance(0)
		check(initial_hand.distance_to(skeleton.get_bone_global_pose(hand).origin) > 0.02,
			"real VRM " + side + " hand moves through the walking cycle")
		animator.player.seek(0.25, true)
	avatar.queue_free()
	await process_frame

func test_automatic_playback():
	var rate_controller = load("res://scripts/assets/animation_controller.gd").new()
	check(rate_controller.has_method("locomotion_rate"), "locomotion playback adapts to real movement speed")
	if rate_controller.has_method("locomotion_rate"):
		check(is_equal_approx(rate_controller.locomotion_rate("walk", 2.0, 1.0), 1.0), "authored walking reference uses natural cadence")
		check(is_equal_approx(rate_controller.locomotion_rate("walk", 4.0, 1.0), 2.0), "faster walking speeds up step cadence")
		check(is_equal_approx(rate_controller.locomotion_rate("run", 6.0, 1.0), 1.5), "sprinting scales running cadence to horizontal speed")
		check(is_equal_approx(rate_controller.locomotion_rate("strafe_left", 1.0, 1.0), 0.5), "slow analog strafing slows leg cadence")
		check(is_equal_approx(rate_controller.locomotion_rate("walk", 4.0, 2.0), 1.0), "larger avatars account for longer strides")
		check(is_equal_approx(rate_controller.locomotion_rate("jump", 6.0, 1.0), 1.0), "jump playback speed is independent of horizontal movement")
	rate_controller.free()
	var network = Coordinator.new()
	root.add_child(network)
	var body = LocalPlayer.new()
	var avatar = Node3D.new()
	var skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	var mapping: Dictionary = {}
	for bone in ["hips", "head", "spine", "leftHand", "rightHand", "leftFoot", "rightFoot", "leftUpperArm", "rightUpperArm", "leftLowerArm", "rightLowerArm", "leftUpperLeg", "rightUpperLeg", "leftLowerLeg", "rightLowerLeg"]:
		skeleton.add_bone(bone)
		mapping[bone] = bone
	avatar.add_child(skeleton)
	avatar.set_meta("humanoid_bones", mapping)
	body.avatar_model = avatar
	body.add_child(avatar)
	root.add_child(body)
	body.add_to_group("player")
	var controller = load("res://scripts/assets/animation_controller.gd").new()
	root.add_child(controller)
	controller.configure(network, null)
	controller._update_locomotion()
	check(controller.local_state.get("kind") == "locomotion" and controller.local_state.get("action") == "resolved", "actual equipped synthetic avatar receives automatic resolved playback without menu")
	check(controller.request_emote("builtin:dance") and controller.local_state.kind == "emote", "emote request uses same actual avatar animation layer")
	var layer = controller.local_animator
	check(controller.has_method("_update_locomotion_rate"), "cadence updates preserve active layer and playhead")
	if controller.has_method("_update_locomotion_rate"):
		controller.local_state.kind = "locomotion"
		controller.local_state.loop = true
		controller.local_state.share = false
		layer.player.advance(0.25)
		var phase = layer.player.current_animation_position
		controller._update_locomotion_rate(1.5)
		check(is_equal_approx(layer.player.speed_scale, 1.5) and absf(layer.player.current_animation_position - phase) < 0.001, "cadence change does not restart stride or recreate animator")
		var sequence_before = controller.sequence
		controller._update_locomotion_rate(1.5)
		check(controller.sequence == sequence_before, "unchanged cadence produces no repeated state updates")
	body.velocity = Vector3(1, 0, 0)
	controller._update_locomotion()
	check(controller.active_emote.is_empty() and controller.local_state.kind == "locomotion" and controller.local_animator == layer, "movement interrupts emote and restores automatic state on same layer")
	controller.queue_free()
	body.queue_free()
	network.queue_free()
	await process_frame

func test_wheel():
	var layout = load("res://scripts/assets/emote_layout.gd").new()
	layout.configure("res://wheel.json")
	var group = layout.add_group("root", "Many dances")
	var catalog: Dictionary = {}
	for i in 17:
		layout.add_emote(group, "dance:%s" % i, "Dance %s" % i)
		catalog["dance:%s" % i] = {"name": "Dance %s" % i}
	check(layout.page_count(group) == 4, "17 entries paginate into four five-content pages")
	var sectors = layout.sectors(group, 0)
	check(sectors.size() == 8 and sectors[3].type == "next" and sectors[4].type == "indicator" and sectors[5].type == "previous", "paging replaces three in-wheel sectors, never adds footer buttons")
	check(sectors[5].disabled and not sectors[3].disabled, "first-page Previous disabled, Next enabled")
	check(layout.sectors(group, 3)[3].disabled, "last-page Next disabled")
	var wheel = load("res://scripts/GUI/emote_wheel.gd").new()
	root.add_child(wheel)
	wheel.open(layout, catalog, false)
	var changes: Array = []
	wheel.emote_selected.connect(func(id): changes.append(id))
	var group_sector = layout.groups.root.entries.size() - 1
	wheel.activate_sector(group_sector)
	check(wheel.group == group and changes.is_empty(), "entering a group navigates without choosing an emote")
	wheel.activate_sector(3)
	check(wheel.page == 1 and wheel.hovered == -1 and changes.is_empty(), "Next pages inside circle and clears selection without animation")
	wheel.activate_sector(4)
	check(changes.is_empty() and wheel.page == 1, "page indicator is non-activating")
	wheel.activate_sector(0)
	check(changes == ["dance:5"], "content wedge selects correct stable action on page two")
	wheel.back()
	check(wheel.group == "root" and wheel.page == 0, "Back restores parent page")
	var nested = layout.add_group(group, "Nested")
	check(not nested.is_empty(), "groups can contain more groups")
	var candidate = layout.groups.duplicate(true)
	candidate[nested].entries.append({"type": "group", "id": "root", "name": "Cycle"})
	check(not layout.commit(candidate), "cyclic nested group graph rejected")
	var restored = load("res://scripts/assets/emote_layout.gd").new()
	restored.configure("res://wheel.json")
	check(restored.groups.has(nested) and restored.groups[group].entries.size() == 18, "nested layout and ordered entries persist")
	for count in [0, 1, 5, 8, 9, 10, 11, 17]:
		var candidate_layout = load("res://scripts/assets/emote_layout.gd").new()
		candidate_layout.groups.root.entries.clear()
		for i in count:
			candidate_layout.groups.root.entries.append({"type": "emote", "id": str(i), "name": str(i)})
		var expected = int(ceil(count / 5.0)) if count > 8 else 1
		check(candidate_layout.page_count("root") == expected and candidate_layout.sectors("root", 0).size() == 8,
			"eight-sector pagination boundary: %s entries" % count)
	var broken_file = FileAccess.open("res://broken-wheel.json", FileAccess.WRITE)
	broken_file.store_string("not json")
	broken_file.close()
	var broken = load("res://scripts/assets/emote_layout.gd").new()
	broken.configure("res://broken-wheel.json")
	check(not broken.writable and FileAccess.get_file_as_string("res://broken-wheel.json") == "not json", "corrupt wheel preserved while default layout remains usable")
	wheel.dismiss()
	wheel.queue_free()
	await process_frame

func test_ui(bytes: PackedByteArray):
	var loader = root.get_node("DataLoader")
	loader.get_asset_cache().initialize("res://cache")
	var configuration = loader.get_avatar_configuration()
	configuration.configure("test-account", "res://avatar.json", loader)
	var menu = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	root.add_child(menu)
	check(menu.draft_sources.is_empty() and not menu.has_method("play"), "source-only avatar editor has no manual player")
	check(menu.get("url") == null, "avatar editor has no manual URL input")
	check(menu.has_method("choose_model_file") and menu.has_method("choose_animation_files"), "avatar and animation imports have dedicated file picker actions")
	await menu.add_source("https://example.test/avatar.vrm", true)
	check(menu.draft_model.is_empty() and "file" in menu.status.text.to_lower(), "manual source entry refuses URL models with file guidance")
	var file = FileAccess.open("res://motion.vrma", FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	await menu.add_source("res://motion.vrma", false)
	check(menu.draft_sources.size() == 1, "actual file import adds external source to draft")
	check(not menu.draft_sources[0].share, "newly imported file never silently grants redistribution consent")
	check(not loader.animation_import_busy and loader.animation_thread == null, "runtime animation worker is joined without blocking main loop")
	await menu.apply()
	check(configuration.emotes.size() == 3 and configuration.sources.size() == 1, "Apply resolves non-basic clip without changing locomotion defaults")
	check(configuration.has_method("active_avatar"), "active avatar exposes one source descriptor for account UI")
	if configuration.has_method("active_avatar"):
		var original_model = configuration.model.duplicate(true)
		configuration.model = {"hash": "a".repeat(64), "name": "Local robot", "url": "", "share": true}
		var active: Dictionary = configuration.active_avatar("https://example.test/old.vrm")
		check(active.url == "" and active.key == "cache:" + "a".repeat(64), "local active avatar never reports stale profile URL")
		configuration.model.url = "https://example.test/new.vrm"
		check(configuration.active_avatar("https://example.test/old.vrm").url == "https://example.test/new.vrm", "active public URL follows applied model")
		configuration.model = {}
		check(configuration.active_avatar("https://example.test/profile.vrm").url == "https://example.test/profile.vrm", "profile URL remains fallback only when no model is applied")
		configuration.model = original_model
	check(configuration.active_avatar("https://example.test/profile.vrm").key == configuration.model_key("https://example.test/profile.vrm"), "account descriptor and player model cache key stay linked")
	menu.queue_free()
	await process_frame
	menu = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	root.add_child(menu)
	check(menu.draft_sources.size() == 1, "applied source configuration restores when page reopens")
	var disk = load("res://scripts/assets/avatar_configuration.gd").new()
	root.add_child(disk)
	disk.configure("test-account", "res://avatar.json", loader)
	for i in 100:
		if disk.emotes.size() == 3: break
		await process_frame
	check(disk.sources.size() == 1 and disk.emotes.size() == 3, "account-scoped sources and role catalog restore from disk")
	var imported_ids = configuration.emotes.keys().filter(func(id): return not id.begins_with("builtin:"))
	var customized = configuration.layout.groups.duplicate(true)
	customized.imports.entries.clear()
	customized.imports.known_ids = [] # Model a saved layout that has never seen this import.
	configuration.layout.commit(customized)
	await configuration._restore()
	check(configuration.layout.groups.imports.entries.any(func(entry): return entry.id == imported_ids[0]), "new available emotes remain discoverable with an existing customized layout")
	var removed = configuration.layout.groups.duplicate(true)
	removed.imports.entries.clear()
	configuration.layout.commit(removed)
	await configuration._restore()
	check(configuration.layout.groups.imports.entries.is_empty(), "intentionally removed shortcuts are not re-added on restore")
	var placed = configuration.layout.groups.duplicate(true)
	placed.dances.entries.append({"type": "emote", "id": imported_ids[0], "name": "My turn"})
	configuration.layout.commit(placed)
	await configuration._restore()
	check(configuration.layout.groups.dances.entries.size() == 1 and configuration.layout.groups.imports.entries.is_empty(), "custom emote placements are preserved without duplicate imported shortcuts")
	disk.queue_free()
	var editor = load("res://scripts/GUI/emote_layout_editor.gd").new()
	menu.add_child(editor)
	editor.configure(configuration)
	check(editor.has_method("filter_library"), "wheel organizer offers searchable emote library")
	if editor.has_method("filter_library"):
		editor.filter_library("dance")
		check(editor.library_rows.get_child_count() == 1, "library search finds Dance without scanning source hashes")
		editor.filter_library("")
		check(editor.library_rows.get_child_count() == configuration.emotes.size(), "library shows all applied emotes as direct add rows")
	check(editor.group_choice.item_count == 3, "actual wheel editor exposes root, Dances and applied imported actions group")
	editor.group = "root"
	editor._render()
	editor.entries.select(0)
	var moved_id = configuration.layout.groups.root.entries[0].id
	editor._move(1)
	check(editor.entries.get_selected_items() == PackedInt32Array([1]) and configuration.layout.groups.root.entries[1].id == moved_id, "moving shortcut preserves selection for repeated moves")
	editor.queue_free()
	menu.queue_free()
	await process_frame
	var batch_menu = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	root.add_child(batch_menu)
	batch_menu.draft_sources.clear()
	check(batch_menu.has_method("import_animation_files"), "multi-file import snapshots mode and consent for whole selection")
	if batch_menu.has_method("import_animation_files"):
		var document = Reader.new().document(bytes)
		document.json.animations[0].name = "Another turn"
		var second_file = FileAccess.open("res://second-motion.vrma", FileAccess.WRITE)
		second_file.store_buffer(pack(document.json, document.binary))
		second_file.close()
		batch_menu.permission.set_pressed_no_signal(true)
		await batch_menu.import_animation_files(PackedStringArray())
		check(batch_menu.permission.button_pressed, "empty file selection does not consume redistribution consent")
		await batch_menu.import_animation_files(PackedStringArray(["res://motion.vrma", "res://second-motion.vrma"]))
		check(batch_menu.draft_sources.size() == 2 and batch_menu.draft_sources.all(func(source): return source.share), "explicit batch redistribution consent applies consistently to every selected animation")
		check(not batch_menu.permission.button_pressed and not batch_menu.busy, "batch clears consent and busy state after all files complete")
		batch_menu.draft_sources.clear()
		await batch_menu.import_animation_files(PackedStringArray(["res://motion.vrma", "res://second-motion.vrma"]))
		check(batch_menu.draft_sources.size() == 2 and batch_menu.draft_sources.all(func(source): return not source.share), "batch without consent never inherits previous selection permission")
	batch_menu.queue_free()
	await process_frame

func test_model_validation_separation():
	var configuration = load("res://scripts/assets/avatar_configuration.gd").new()
	var loader = ModelValidationLoader.new()
	root.add_child(loader)
	root.add_child(configuration)
	configuration.loader = loader
	var file = FileAccess.open("res://model-with-extra-motion.glb", FileAccess.WRITE)
	var doc = Reader.new().document(fixture())
	doc.json.animations[0].channels[0].target.path = "translation"
	file.store_buffer(pack(doc.json, doc.binary)); file.close()
	check(await configuration._validate_model("res://model-with-extra-motion.glb"), "valid avatar is not rejected because optional embedded animation is unsupported")
	check(loader.model_calls == 1, "model compatibility validation constructs one scene rather than importing twice")
	check(loader.animation_calls == 0, "model validation never applies standalone animation byte/clip limits")
	loader.avatar_valid = false
	loader.cache = ValidationCache.new()
	configuration.account_owner = "test"
	var rejected: Dictionary = await configuration.import_source("res://bad-model.glb", true, true)
	check(rejected.is_empty() and not "64-clip" in configuration.last_error and "model" in configuration.last_error.to_lower(), "model rejection cannot reuse stale standalone animation error")
	loader.avatar_valid = true
	loader.model_loads = false
	configuration.last_error = ""
	check(not await configuration._validate_model("res://bad-model.glb") and not configuration.last_error.is_empty(), "model scene-import failure has an actionable model diagnostic")
	configuration.free(); loader.free()
	if FileAccess.file_exists("res://real-avatar.vrm"):
		var real_configuration = load("res://scripts/assets/avatar_configuration.gd").new()
		root.add_child(real_configuration)
		real_configuration.loader = root.get_node("DataLoader")
		check(await real_configuration._validate_model("res://real-avatar.vrm"), "real downloaded avatar passes model validation independently of embedded clips")
		real_configuration.free()

func test_document_structure_regressions():
	check(load("res://scripts/assets/asset_cache.gd").LIMITS.avatar == 256 * 1024 * 1024, "avatar cache/import ceiling is 256 MiB")
	check(load("res://relay_protocol/animation_state.gd").get_script_constant_map().get("MAX_AVATAR_BYTES", 0) == 256 * 1024 * 1024, "relay avatar transfer ceiling matches client imports")
	check(AnimationState.transfer_timeout_msec(256 * 1024 * 1024) >= 4096000, "maximum model has enough bounded transfer time at conservative bandwidth")
	check(AnimationState.transfer_timeout_msec(1024) == 900000, "small transfer timeout remains compatible")
	var reader = Reader.new()
	var doc = reader.document(fixture())
	var bin = doc.binary.duplicate()
	var duplicate = fixture()
	var header = PackedByteArray(); header.resize(8)
	header.encode_u32(0, bin.size()); header.encode_u32(4, 0x004e4942)
	duplicate.append_array(header); duplicate.append_array(bin); duplicate.encode_u32(8, duplicate.size())
	check(reader.document(duplicate).is_empty(), "duplicate binary chunks are rejected rather than replacing animation bytes")
	var reordered = PackedByteArray(); reordered.resize(12)
	reordered.encode_u32(0, 0x46546c67); reordered.encode_u32(4, 2)
	reordered.append_array(header); reordered.append_array(bin)
	var text = JSON.stringify(doc.json).to_utf8_buffer()
	while text.size() % 4: text.append(32)
	header.encode_u32(0, text.size()); header.encode_u32(4, 0x4e4f534a)
	reordered.append_array(header); reordered.append_array(text); reordered.encode_u32(8, reordered.size())
	check(reader.document(reordered).is_empty(), "binary-before-JSON container is rejected")
	doc.json.buffers.append({"byteLength": 4})
	check(reader.document(pack(doc.json, bin)).is_empty(), "multiple buffers cannot alias one binary payload")
	doc.json.buffers = [{"byteLength": bin.size() + 100}]
	check(reader.document(pack(doc.json, bin)).is_empty(), "declared buffer beyond actual payload is rejected")
	doc = reader.document(fixture())
	doc.json.buffers[0].byteLength = bin.size() - 4
	check(reader.read_bytes(pack(doc.json, bin)).is_empty(), "animation accessors cannot read beyond declared buffer into extra BIN bytes")
	doc = reader.document(fixture())
	doc.json.asset.version = "1.0"
	check(reader.document(pack(doc.json, bin)).is_empty(), "GLB2 header cannot conceal unsupported glTF asset version")
	doc = reader.document(fixture())
	doc.json.buffers[0].byteLength = bin.size() - 1
	check(reader.document(pack(doc.json, bin)).binary.size() == bin.size() - 1, "legal one-byte BIN padding is excluded from accessor-visible payload")
	doc = reader.document(fixture())
	doc.json.accessors[0].byteOffset = 1
	check(reader.read_bytes(pack(doc.json, bin)).is_empty(), "misaligned float accessor is rejected before reading")
	doc = reader.document(fixture())
	doc.json.accessors[0].normalized = true
	check(reader.read_bytes(pack(doc.json, bin)).is_empty(), "normalized float accessor is rejected")
	doc = reader.document(fixture())
	doc.json.nodes.append({"name": "Unused cycle", "children": [1]})
	check(reader.read_bytes(pack(doc.json, bin)).is_empty(), "hierarchy cycle is rejected even outside animated bone chain")
	var source = Reader.new().read_bytes(fixture())
	var model = Node3D.new()
	var rig = Skeleton3D.new(); model.add_child(rig); rig.add_bone("Hips")
	model.set_meta("humanoid_bones", {"hips": "Hips"})
	reader.bind_clip(source.clips[0], model)
	model.set_meta("humanoid_bones", {"hips": "MissingBone"})
	reader.last_error = "stale unrelated error"
	check(reader.bind_clip(source.clips[0], model) == null and "MissingBone" in reader.last_error, "missing mapped bone supplies current actionable error")
	model.set_meta("humanoid_bones", {"hips": "Hips"})
	check(reader.bind_clip(source.clips[0], model) != null and reader.last_error.is_empty(), "successful animation binding clears previous error")
	model.free()

func test_avatar_dimensions():
	var layout = load("res://scripts/assets/emote_layout.gd").new()
	check(not layout.add_emote("root", "builtin:dance", "Duplicate Dance"), "layout service rejects duplicate emote in same group")
	var custom = layout.add_group("root", "Custom")
	layout.add_emote(custom, "builtin:dance", "Dance")
	var original = layout.groups.duplicate(true)
	check(not layout.move_entry(custom, 0, "root", 0) and layout.groups == original, "moving emote into group that already contains it preserves source")
	var child = layout.add_group(custom, "Nested")
	layout.add_emote(child, "builtin:interact", "Interact")
	layout.delete_group(custom)
	check(not layout.groups.has(child), "deleting parent group removes orphaned descendant groups")
	var parent_a = layout.add_group("root", "Parent A")
	var parent_b = layout.add_group("root", "Parent B")
	var shared = layout.add_group(parent_a, "Shared child")
	var linked = layout.groups.duplicate(true)
	linked[parent_b].entries.append({"type": "group", "id": shared, "name": "Shared child"})
	layout.commit(linked)
	layout.delete_group(parent_a)
	check(layout.groups.has(shared) and layout.groups[parent_b].entries[0].id == shared, "group deletion preserves descendants reachable from another parent")
	var dimensions = load("res://scripts/assets/avatar_dimensions.gd")
	var model = Node3D.new()
	model.scale = Vector3.ONE * 2
	var container = Node3D.new()
	container.position.y = 0.25
	model.add_child(container)
	var rig = Skeleton3D.new()
	container.add_child(rig)
	rig.add_bone("custom_head")
	rig.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.75, 0)))
	model.set_meta("humanoid_bones", {"head": "custom_head"})
	check(dimensions.eye_position(model).is_equal_approx(Vector3(0, 2, 0)), "camera uses mapped head through nested scaled skeleton transforms")
	rig.set_bone_pose_position(0, Vector3(0, 10, 0))
	check(dimensions.eye_position(model).is_equal_approx(Vector3(0, 2, 0)), "animated head pose never changes calibrated camera height")
	container.free()
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1, 3, 1)
	mesh.mesh = box
	mesh.position.y = 1.5
	model.add_child(mesh)
	check(is_equal_approx(dimensions.eye_position(model).y, 5.52), "headless model camera falls back near transformed mesh top")
	model.free()

func test_remote_motion():
	check(PlayerData.create(1, Vector3.ZERO, Vector3.ZERO).flag == 0,
		"movement uses sequenced unreliable delivery rather than reordered unsequenced packets")
	if not ResourceLoader.exists("res://scripts/player/remote_motion.gd"):
		check(false, "remote movement has a buffered interpolation policy")
		return
	var motion = load("res://scripts/player/remote_motion.gd").new()
	motion.push(Vector3.ZERO, Vector3(0, deg_to_rad(179), 0), 0.0)
	motion.push(Vector3(0.5, 0, 0), Vector3(0, deg_to_rad(-179), 0), 0.05)
	motion.push(Vector3(1, 0, 0), Vector3(0, deg_to_rad(-177), 0), 0.10)
	var middle = motion.sample(0.125)
	check(is_equal_approx(middle.origin.x, 0.25), "20 Hz movement interpolates between packets rather than snapping to latest")
	check(absf(middle.basis.get_euler().y) > 3.0, "rotation interpolates across wrap using shortest quaternion arc")
	var next = motion.sample(0.135)
	check(next.origin.x > middle.origin.x and next.origin.x - middle.origin.x < 0.2,
		"remote movement advances smoothly between network arrivals")
	check(motion.sample(2.0).origin.x <= 2.01, "packet loss extrapolation is bounded and stops instead of drifting indefinitely")
	motion.push(Vector3(30, 0, 0), Vector3.ZERO, 2.0)
	check(is_equal_approx(motion.sample(2.0).origin.x, 30), "teleport resets old movement samples immediately")
	motion.push(Vector3(INF, 0, 0), Vector3.ZERO, 2.1)
	check(motion.sample(2.1).origin.is_finite(), "invalid movement cannot poison interpolation")
	var jitter = load("res://scripts/player/remote_motion.gd").new()
	var previous := 0.0
	var largest_step := 0.0
	for frame in 120:
		var time = frame / 60.0
		# Alternate 33/67 ms packet spacing with one missing update.
		if frame % 6 in [0, 2] and frame != 60:
			jitter.push(Vector3(time * 3.0, 0, 0), Vector3.ZERO, time)
		var pose = jitter.sample(time)
		largest_step = maxf(largest_step, absf(pose.origin.x - previous))
		previous = pose.origin.x
	check(largest_step < 0.11, "jittery arrivals and a dropped packet remain smooth at render-frame cadence")
	check(jitter.samples.size() <= 32, "movement history remains bounded")

func test_controller(parsed: Dictionary):
	var network = Coordinator.new()
	network.peer = RelayPeer.new()
	network.peer.session_peers = [7]
	root.add_child(network)
	var remote = Remote.new()
	remote.name = "7"
	remote.avatar = Node3D.new()
	var skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	skeleton.add_bone("Hips")
	remote.avatar.add_child(skeleton)
	remote.avatar.set_meta("humanoid_bones", {"hips": "Hips"})
	for track in Defaults.clip("neutral").tracks:
		if track.bone == "hips": continue
		skeleton.add_bone(track.bone)
		remote.avatar.get_meta("humanoid_bones")[track.bone] = track.bone
	remote.add_child(remote.avatar)
	network.add_child(remote)
	var controller = load("res://scripts/assets/animation_controller.gd").new()
	root.add_child(controller)
	controller.configure(network, null)
	controller.transport = network.peer
	check(controller.resolve_motion(true, Vector3.ZERO, 1000) == "neutral", "automatic state starts neutral without opening a menu")
	check(controller.resolve_motion(true, Vector3(0, 0, -2), 1100) == "walk", "movement resolves automatic walk")
	check(controller.resolve_motion(false, Vector3(0, 2, 0), 1200) == "jump", "upward airborne state resolves jump")
	check(controller.resolve_motion(false, Vector3(0, -2, 0), 1300) == "neutral", "descending airborne state stays neutral without fall playback")
	check(controller.resolve_motion(true, Vector3.ZERO, 1400) == "neutral" and controller.resolve_motion(true, Vector3.ZERO, 1800) == "neutral", "ground contact selects static neutral with no landing playback")
	controller.assets[parsed.hash] = {"parsed": parsed}
	var value = {"op": "state", "session_id": "test", "version": 2, "peer_id": 7,
		"generation": "a".repeat(32), "sequence": 1, "action": "resolved", "kind": "emote", "role": "turn", "mask": "full", "avatar_revision": "", "configuration_revision": 0, "offset": 0.5,
		"speed": 1.0, "loop": true, "duration": 1.0, "builtin": "", "hash": parsed.hash,
		"size": 1024, "clip": 0, "started": controller.now()}
	controller.receive(value)
	check(controller.remote_animators.has(7), "production client controller attaches remote animation layer")
	check(controller.remote_animators[7].player.current_animation_position >= 0.5, "production receiver seeks late-loaded motion to current playhead")
	value.sequence = 2
	value.action = "pause"
	controller.receive(value)
	check(controller.remote_states[7].sequence == 1, "production receiver rejects legacy manual pause")
	value.session_id = "other"
	value.sequence = 3
	value.action = "resolved"
	controller.receive(value)
	check(controller.remote_states[7].sequence == 1, "production receiver rejects another instance's state")
	check(not controller.has_method("pause") and not controller.has_method("play"), "controller exposes no parallel manual player API")
	controller.clear()
	check(controller.remote_states.is_empty() and controller.assets.is_empty(), "client transition removes motion and asset session state")
	var neutral = {"op": "state", "session_id": "test", "version": 2, "peer_id": 7,
		"generation": "a".repeat(32), "sequence": 4, "action": "resolved", "kind": "locomotion", "role": "neutral", "mask": "full", "avatar_revision": "", "configuration_revision": 0,
		"offset": 0.0, "speed": 1.0, "loop": true, "duration": 1.0, "builtin": "neutral", "library": AnimationState.LIBRARY, "hash": "", "started": controller.now()}
	controller.receive(neutral)
	var scaled_state = neutral.duplicate(true)
	var local_size_player = LocalPlayer.new()
	root.add_child(local_size_player)
	local_size_player.add_to_group("player")
	local_size_player.avatar_size = 2.5
	controller.local_state = neutral.duplicate(true)
	controller.sequence = 10
	controller._refresh_local_scale()
	check(controller.local_state.avatar_scale == 2.5 and controller.local_state.sequence == 11,
		"stationary avatar scale change republishes fresh state without changing motion")
	controller._refresh_local_scale()
	check(controller.local_state.sequence == 11, "unchanged avatar size does not flood relay with states")
	local_size_player.free()
	scaled_state.sequence += 1
	scaled_state.avatar_scale = 2.0
	controller.receive(scaled_state)
	check(remote.scale == Vector3.ONE * 2, "remote avatar receives validated size from animation state")
	scaled_state.avatar_scale = 100.0
	check(not AnimationState.valid(scaled_state), "wire rejects out of bounds avatar sizes")
	check(not controller.incoming.has(7), "newly joined standing player never requests nonexistent remote animation size")
	check(controller.remote_animators.has(7), "standing remote player gets built-in neutral animation without downloadable payload")
	var completed_standing = neutral.duplicate(true)
	completed_standing.loop = false
	completed_standing.offset = 1.0
	completed_standing.sequence = 5
	controller.receive(completed_standing)
	check(controller.remote_animators[7].descriptor.get("sequence") == 5,
		"completed nonlooping standing state retains authored pose instead of resetting remote rig to T-pose")
	var standing_animator = controller.remote_animators[7]
	standing_animator.player.advance(2.0)
	controller.receive(completed_standing)
	check(standing_animator.descriptor.get("sequence") == 5 and standing_animator.player.has_animation("motion/clip"),
		"repeated expired standing snapshots keep the animation layer instead of applying RESET")
	var replacement = Node3D.new()
	replacement.add_child(skeleton.duplicate())
	replacement.set_meta("humanoid_bones", remote.avatar.get_meta("humanoid_bones").duplicate())
	remote.remove_child(remote.avatar)
	remote.avatar.free()
	remote.avatar = replacement
	remote.add_child(replacement)
	controller.receive(completed_standing)
	check(controller.remote_animators[7].avatar == replacement and controller.remote_animators[7].descriptor.get("sequence") == 5,
		"late-loaded replacement avatar receives completed standing pose instead of remaining in T-pose")
	neutral.sequence = 6
	controller.receive(neutral)
	var animator = controller.remote_animators[7]
	check(animator.has_method("synchronize"), "animation drift supports continuous correction without periodic playhead jumps")
	if animator.has_method("synchronize"):
		animator.player.seek(0.95, true)
		animator.synchronize(0.05, 1.0, true, 1.0)
		check(is_equal_approx(animator.player.current_animation_position, 0.95), "loop-boundary drift correction never jumps to the other end of the clip")
		check(animator.player.speed_scale > 1.0 and animator.player.speed_scale <= 1.1, "small animation drift catches up using bounded playback speed")
	for builtin in AnimationState.BUILTINS:
		for mask in ["full", "tracked_head_hands"]:
			var state = neutral.duplicate(true)
			state.builtin = builtin
			state.role = builtin
			state.duration = AnimationState.DURATIONS[builtin]
			state.mask = mask
			state.sequence = controller.remote_states[7].sequence + 1
			controller.receive(state)
			check(controller.remote_animators[7].descriptor.get("sequence") == state.sequence and controller.incoming.is_empty(),
				"remote builtin %s with %s mask plays without custom asset fields" % [builtin, mask])
	var malformed = neutral.duplicate(true)
	malformed.sequence = controller.remote_states[7].sequence + 1
	malformed.builtin = ""
	malformed.hash = "b".repeat(64)
	malformed.clip = 0
	controller.receive(malformed)
	check(controller.remote_states[7].sequence < malformed.sequence and controller.incoming.is_empty(),
		"custom animation without size is rejected before remote dispatch")
	controller.clear()
	controller.queue_free()
	network.queue_free()
	await process_frame

func pump(server: Node, clients: Array, seconds: float = 0.25):
	var deadline = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		server.handle_events()
		for client in clients:
			client.handle_events()
		await create_timer(0.003).timeout

func test_network():
	var server = load("res://scripts/multiplayer/relay.gd").new()
	server.connection = ENetConnection.new()
	check(server.connection.create_host_bound("127.0.0.1", 0) == OK, "animation relay binds isolated loopback")
	var clients: Array = []
	var messages: Array = [[], [], []]
	var movements: Array = [[], [], []]
	for i in 3:
		var client = RelayPeer.new()
		client.account_key = Crypto.new().generate_rsa(2048)
		client.animation_data.connect(func(value): messages[i].append(value))
		client.player_data.connect(func(value): movements[i].append(value))
		client.connect_to_relay("127.0.0.1", server.connection.get_local_port())
		clients.append(client)
	await pump(server, clients, 0.8)
	check(clients.all(func(client): return client.is_authenticated and client.animation_supported), "three real clients negotiate authenticated animation capability")
	check(clients.all(func(client): return client.get("world_supported") == true), "real peers negotiate shared world item capability")
	clients[0].create_session(0, "Room", "", "default_wold")
	clients[2].create_session(0, "Other", "", "default_wold")
	await pump(server, clients)
	clients[1].join_session(clients[0].current_session_id, "default_wold")
	await pump(server, clients)
	if clients[0].has_method("send_world"):
		var world_received: Array = [[], [], []]
		for index in clients.size(): clients[index].world_data.connect(func(value): world_received[index].append(value))
		clients[0].send_world({"op": "grab", "session_id": clients[0].current_session_id, "revision": "", "entity": "cup", "grip": "left", "sequence": 1, "epoch": 0})
		await pump(server, clients)
		var grips: Array = world_received[1].filter(func(value): return value.get("op") == "item")
		check(grips.size() == 1 and grips[0].get("holder") == 0 and grips[0].get("grip") == "left", "real relay sends authenticated item holder/grip to same-instance peer")
		check(world_received[2].is_empty(), "same world in another instance receives no item state")
		if not grips.is_empty():
			var lease_epoch = grips[0].epoch
			clients[1].send_world({"op": "grab", "session_id": clients[1].current_session_id, "revision": "", "entity": "cup", "grip": "virtual", "sequence": 1, "epoch": lease_epoch})
			await pump(server, clients)
			check(world_received[1].any(func(value): return value.get("op") == "result" and value.get("ok") == false), "real concurrent desktop grab cannot steal VR lease")
			clients[0].send_world({"op": "pose", "session_id": clients[0].current_session_id, "revision": "", "entity": "cup", "epoch": lease_epoch, "sequence": 2, "position": [1, 1, 1], "rotation": [0, 0, 0, 1]})
			await pump(server, clients)
			check(world_received[1].any(func(value): return value.get("op") == "pose" and value.get("position") == [1.0, 1.0, 1.0]), "real held-object pose reaches remote participant")
			clients[1].send_world({"op": "pose", "session_id": clients[1].current_session_id, "revision": "", "entity": "cup", "epoch": lease_epoch, "sequence": 2, "position": [2, 2, 2], "rotation": [0, 0, 0, 1]})
			await pump(server, clients)
			check(world_received[1].filter(func(value): return value.get("op") == "pose").size() == 1, "nonholder pose rejected instead of forging held-object movement")
			clients[1].send_world({"op": "snapshot", "session_id": clients[1].current_session_id, "revision": ""})
			await pump(server, clients)
			check(world_received[1].any(func(value): return value.get("op") == "snapshot" and value.get("items", {}).has("cup")), "real late-item snapshot supplies current live lease")
	var state = {"op": "state", "version": 2, "sequence": 1, "action": "resolved", "kind": "emote", "role": "dance", "mask": "full", "avatar_revision": "", "configuration_revision": 0, "offset": 0.25,
		"speed": 1.0, "loop": true, "duration": 1.0, "builtin": "dance", "hash": "",
		"library": Defaults.LIBRARY, "session_id": clients[0].current_session_id, "peer_id": 254}
	clients[0].send_animation(state)
	await pump(server, clients)
	var received = messages[1].filter(func(value): return value.get("op") == "state")
	check(received.size() == 1, "reliable animation reaches exact-instance participant")
	check(messages[2].filter(func(value): return value.get("op") == "state").is_empty(), "same-world different instance receives no animation")
	var owner = int(received[0].peer_id) if not received.is_empty() else -1
	check(owner != 254 and server.animations.states.has(owner), "relay derives actor from authenticated transport, not claimed ID")
	for distance in [3.0, 4.5]:
		PlayerData.create(1, Vector3(0, 0, -distance), Vector3.ZERO).sent(clients[0].peer)
		await pump(server, clients)
		check(not movements[1].is_empty() and movements[1].back().position.is_equal_approx(Vector3(0, 0, -distance)), "ordinary movement transport delivers sprint displacement %s to instance peer" % distance)
	check(movements[2].is_empty(), "sprint displacement stays isolated from other instances")
	check(clients[0].get("tracking_supported") == true, "authenticated peers negotiate tracked-pose capability separately from animation")
	if clients[0].get("tracking_supported") == true:
		var pose = {"op": "pose", "version": 1, "session_id": clients[0].current_session_id, "sequence": 1,
			"avatar_revision": "a".repeat(64), "calibration_revision": 0, "targets": {"head": [0, 1.6, 0, 0, 0, 0, 1]}}
		clients[0].send_animation(pose)
		await pump(server, clients)
		check(messages[1].filter(func(value): return value.get("op") == "pose").size() == 1, "tracked head pose reaches only exact-instance peer")
		check(messages[2].filter(func(value): return value.get("op") == "pose").is_empty(), "another instance cannot receive tracker poses")
		pose.sequence = 2
		pose.targets.head[0] = 1000
		clients[0].send_animation(pose)
		await pump(server, clients)
		check(messages[1].filter(func(value): return value.get("op") == "pose").size() == 1, "out-of-range tracker position is rejected at relay")
	clients[0].send_animation(state)
	await pump(server, clients)
	check(messages[1].filter(func(value): return value.get("op") == "state").size() == 1, "duplicate sequence rejected")
	clients[1].send_animation({"op": "snapshot", "session_id": clients[1].current_session_id})
	await pump(server, clients)
	check(messages[1].filter(func(value): return value.get("op") == "state").size() == 2, "late-load snapshot preserves latest state")
	clients[1].send_animation({"op": "clock", "nonce": Time.get_ticks_msec()})
	await pump(server, clients)
	check(not messages[1].filter(func(value): return value.get("op") == "clock" and value.has("time")).is_empty(), "monotonic relay clock sampling available")
	var data = fixture()
	var digest = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	var hash = digest.finish().hex_encode()
	state.sequence = 2
	state.builtin = ""
	state.hash = hash
	state.size = data.size()
	state.clip = 0
	state.duration = 1.0
	clients[0].send_animation(state)
	await pump(server, clients)
	clients[1].send_animation({"op": "request", "session_id": clients[1].current_session_id, "owner": owner, "hash": hash})
	await pump(server, clients)
	var requests = messages[0].filter(func(value): return value.get("op") == "request")
	check(requests.size() == 1, "local asset bytes require explicit receiver request")
	var recipient = int(requests[0].requester) if not requests.is_empty() else -1
	clients[0].send_animation({"op": "chunk", "session_id": clients[0].current_session_id, "target": recipient,
		"hash": hash, "offset": 0, "bytes": Marshalls.raw_to_base64(data)})
	await pump(server, clients)
	var chunks = messages[1].filter(func(value): return value.get("op") == "chunk")
	check(chunks.size() == 1 and Marshalls.base64_to_raw(chunks[0].bytes) == data, "requested bounded animation bytes forwarded without relay persistence")
	check(server.animations.requests.is_empty(), "completed transfer leaves no relay queue")
	state.sequence = 3
	state.model_hash = "d".repeat(64)
	state.model_size = data.size()
	var large_model = state.duplicate(true)
	large_model.model_size = 256 * 1024 * 1024
	check(AnimationState.valid(large_model), "wire descriptor accepts 256 MiB avatar without allocating model bytes")
	large_model.model_size += 1
	check(not AnimationState.valid(large_model), "wire descriptor rejects avatars above new maximum")
	clients[0].send_animation(state)
	await pump(server, clients)
	clients[1].send_animation({"op": "request", "asset_kind": "avatar", "session_id": clients[1].current_session_id, "owner": owner, "hash": state.model_hash})
	await pump(server, clients)
	var model_requests = messages[0].filter(func(value): return value.get("op") == "request" and value.get("asset_kind") == "avatar")
	check(model_requests.size() == 1, "same resolved state authorizes separately bounded custom model delivery")
	clients[0].send_animation({"op": "chunk", "asset_kind": "avatar", "session_id": clients[0].current_session_id, "target": recipient,
		"hash": state.model_hash, "offset": 0, "bytes": Marshalls.raw_to_base64(data)})
	await pump(server, clients)
	check(messages[1].filter(func(value): return value.get("op") == "chunk" and value.get("asset_kind") == "avatar").size() == 1, "model chunks retain asset kind through ephemeral relay")
	state.sequence = 4
	state.action = "pause"
	clients[0].send_animation(state)
	await pump(server, clients)
	check(server.animations.states[owner].action == "resolved" and server.animations.states[owner].sequence == 3, "relay rejects manual pause rather than creating another animation stream")
	var old_session: String = clients[2].current_session_id
	var target_index = server.get_session_index(clients[0].current_session_id)
	server.sessions[target_index][0].world_revision = "b".repeat(64)
	clients[2].expected_world_revision = "c".repeat(64)
	clients[2].join_session(clients[0].current_session_id, "default_wold")
	await pump(server, clients)
	check(clients[2].current_session_id == old_session, "world revision mismatch preserves previous membership")
	clients[2].expected_world_revision = "b".repeat(64)
	clients[2].join_session(clients[0].current_session_id, "default_wold")
	await pump(server, clients)
	check(clients[2].current_session_id == clients[0].current_session_id, "matching pinned revision permits ordinary admission")
	clients[0].peer.peer_disconnect()
	await pump(server, clients)
	check(not server.animations.states.has(owner) and not server.animations.supported.has(owner)
		and not server.animations.generations.has(owner), "disconnect erases actor state, capability and generation")
	check(not server.animations.poses.has(owner) and not server.animations.pose_supported.has(owner) and not server.animations.pose_rates.has(owner), "disconnect removes live tracker pose and capability/rate references")
	check(not server.world_items.supported.has(owner) and not server.world_items.generations.has(owner) and not server.world_items.rates.has(owner), "disconnect deletes world capability/generation/rate state")
	var retained_holder = false
	for instance in server.world_items.instances.values():
		if instance.senders.has(owner): retained_holder = true
		for item in instance.items.values():
			if item.holder == owner: retained_holder = true
	check(not retained_holder, "disconnect clears indirect item holder and sequence references")
	for client in clients:
		if client.peer.get_state() == ENetPacketPeer.STATE_CONNECTED: client.peer.peer_disconnect()
	await pump(server, clients, 0.4)
	check(server.world_items.instances.is_empty(), "empty instances leave no relay world-item state")
	for client in clients: client.connection.destroy()
	server.connection.destroy()
	server.free()
