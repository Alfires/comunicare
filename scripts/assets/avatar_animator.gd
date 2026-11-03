extends Node
## A dedicated animation layer; never touches camera, body or unrelated tracks.

const Reader = preload("res://scripts/assets/humanoid_animation.gd")
const Defaults = preload("res://scripts/assets/default_animations.gd")
var player: AnimationPlayer
var avatar: Node3D
var descriptor: Dictionary = {}
var reader = Reader.new()
var last_error := ""

func attach(model: Node3D):
	avatar = model
	player = AnimationPlayer.new()
	player.name = "HumanoidMotion"
	model.add_child(player)
	player.root_node = NodePath("..")
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
	stop()
	# Reset only bones owned by this motion layer, never tracked XR head/hands.
	var reset = Animation.new()
	var skeleton = reader._skeleton(avatar)
	var mapping: Dictionary = avatar.get_meta("humanoid_bones", {})
	for source in clip.tracks:
		if not mapping.has(source.bone): continue
		var index = skeleton.find_bone(mapping[source.bone])
		var track = reset.add_track(Animation.TYPE_ROTATION_3D)
		reset.track_set_path(track, NodePath(str(avatar.get_path_to(skeleton)) + ":" + skeleton.get_bone_name(index)))
		reset.rotation_track_insert_key(track, 0, skeleton.get_bone_rest(index).basis.get_rotation_quaternion())
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
	player.play("motion/clip")
	player.seek(fposmod(offset, animation.length) if looping else clampf(offset, 0, animation.length), true)
	last_error = ""
	return true

func stop():
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
