extends Node
## A dedicated animation layer; never touches camera, body or unrelated tracks.

const Reader = preload("res://scripts/assets/humanoid_animation.gd")
const Defaults = preload("res://scripts/assets/default_animations.gd")
var player: AnimationPlayer
var avatar: Node3D
var descriptor: Dictionary = {}
var reader = Reader.new()
var last_error := ""
const BLEND_SECONDS = 0.22
const JUMP_RETURN_SECONDS = 0.55
var blend_seconds := BLEND_SECONDS
var motion_role := ""
var owned_bones: Dictionary = {}
var blend_from: Dictionary = {}
var blend_elapsed := 0.0
var blend_position := 0.0

func attach(model: Node3D):
	avatar = model
	player = AnimationPlayer.new()
	player.name = "HumanoidMotion"
	model.add_child(player)
	player.root_node = NodePath("..")
	player.mixer_applied.connect(_blend_pose)
	var library = AnimationLibrary.new()
	library.add_animation("RESET", Animation.new())
	player.add_animation_library("", library)

func play_clip(clip: Dictionary, looping: bool = true, speed: float = 1.0, offset: float = 0.0) -> bool:
	if not is_instance_valid(avatar) or not is_instance_valid(player):
		return false
	var animation = reader.bind_clip(clip, avatar)
	if animation == null:
		last_error = reader.last_error
		return false
	var transitioning = player.is_playing()
	var next_role = str(clip.get("motion_role", ""))
	blend_seconds = JUMP_RETURN_SECONDS if motion_role == "jump" and next_role == "neutral" else BLEND_SECONDS
	motion_role = next_role
	blend_from.clear()
	# Reset only bones owned by this motion layer, never tracked XR head/hands.
	var reset = Animation.new()
	var skeleton = reader._skeleton(avatar)
	var mapping: Dictionary = avatar.get_meta("humanoid_bones", {})
	for source in clip.tracks:
		if not mapping.has(source.bone): continue
		owned_bones[source.bone] = true
	# Include previous channels so an arm-only action blends unused bones back
	# to rest instead of leaving the old pose stuck. Never include unowned XR bones.
	for bone in owned_bones:
		if not mapping.has(bone): continue
		var index = skeleton.find_bone(mapping[bone])
		if index < 0: continue
		if transitioning: blend_from[index] = skeleton.get_bone_pose_rotation(index)
		var track = reset.add_track(Animation.TYPE_ROTATION_3D)
		reset.track_set_path(track, NodePath(str(avatar.get_path_to(skeleton)) + ":" + skeleton.get_bone_name(index)))
		reset.rotation_track_insert_key(track, 0, skeleton.get_bone_rest(index).basis.get_rotation_quaternion())
		var path = reset.track_get_path(track)
		if animation.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			var resting = animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(resting, path)
			animation.rotation_track_insert_key(resting, 0, skeleton.get_bone_rest(index).basis.get_rotation_quaternion())
	player.stop(true)
	var reset_library = player.get_animation_library("")
	reset_library.remove_animation("RESET")
	reset_library.add_animation("RESET", reset)
	if player.has_animation_library("motion"):
		player.remove_animation_library("motion")
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	var library = AnimationLibrary.new()
	library.add_animation("clip", animation)
	player.add_animation_library("motion", library)
	player.speed_scale = clampf(speed, 0.25, 2.0)
	blend_elapsed = 0.0
	blend_position = fposmod(offset, animation.length) if looping else clampf(offset, 0, animation.length)
	player.play("motion/clip")
	# mixer_applied blends the evaluated target back from the captured visible
	# pose, including interrupted transitions and nonzero network playheads.
	player.seek(blend_position, true)
	last_error = ""
	return true

func _blend_pose():
	if blend_from.is_empty(): return
	var position = player.current_animation_position
	var elapsed = position - blend_position
	if elapsed < 0: elapsed += player.current_animation_length
	blend_position = position
	blend_elapsed += maxf(0, elapsed) / maxf(absf(player.speed_scale), 0.001)
	var weight = smoothstep(0.0, blend_seconds, blend_elapsed)
	var skeleton = reader._skeleton(avatar)
	for index in blend_from:
		skeleton.set_bone_pose_rotation(index, blend_from[index].slerp(skeleton.get_bone_pose_rotation(index), weight))
	if blend_elapsed >= blend_seconds: blend_from.clear()

func stop():
	blend_from.clear()
	motion_role = ""
	if is_instance_valid(player):
		player.play("RESET")
		player.advance(0)
		player.stop()
	descriptor.clear()

func set_paused(value: bool):
	if not is_instance_valid(player):
		return
	if value:
		player.pause()
	else:
		player.play()
