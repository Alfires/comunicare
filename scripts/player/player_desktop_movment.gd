extends CharacterBody3D

# Movement variables
@export var acceleration = 20.0
@export var friction = 15.0
@export var jump_force = 9.0
@export var gravity = 20.0
@export var mouse_sensitivity: float = 0.003
@export var max_tilt: float = deg_to_rad(85.0)  # Wider look without flipping.
@export_range(0.0, 0.4, 0.01) var first_person_forward_offset := 0.15
# References
@onready var camera = $Camera3D

var update_interval = 0.5
var elapsed_time = 0.0
var last_state = {"position": position, "rotation": rotation}

var head_idx = null
var skeleton = null
var avatar_model: Node3D
var avatar_generation := 0
var avatar_url := ""
var world_grip: Node3D
var focused := true
var camera_rest_position := Vector3.ZERO
var camera_previous_position := Vector3.ZERO
var camera_current_position := Vector3.ZERO
var camera_motion_ready := false
var sprint = preload("res://scripts/player/sprint_policy.gd").new()
var air_control = preload("res://scripts/player/air_control.gd").new()

func get_walk_speed() -> float:
	return float(SaveData.store.get_value("vr.move_speed")) * sprint.MOVEMENT_SCALE

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		sprint.suppress()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true

func _ready() -> void:
	camera_rest_position = camera.position
	_reset_camera_motion()
	world_grip = Node3D.new()
	world_grip.name = "WorldItemGrip"
	camera.add_child(world_grip)
	world_grip.position = Vector3(0.25, -0.2, -0.9)
	if DataLoader.has_signal("asset_revision_available"):
		DataLoader.asset_revision_available.connect(_asset_updated)
	SaveData.profile.profile_changed.connect(_profile_changed)
	if DataLoader.has_method("get_avatar_configuration"):
		DataLoader.get_avatar_configuration().changed.connect(_avatar_configuration_changed)
	add_to_group("player")
	NetworkHandler.get_animation_controller()
	$menue.hide()
	load_player_model()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _process(delta):
	_update_camera_position(Engine.get_physics_interpolation_fraction())
	# when to update data
	elapsed_time += delta
	if elapsed_time >= 0.05 and (last_state != {"position": position, "rotation": rotation} or elapsed_time >= update_interval):
		update_player_data() 
		last_state = {"position": position, "rotation": rotation}
		elapsed_time = 0.0
	
func update_player_data():
	if NetworkHandler.peer == null or not NetworkHandler.peer.is_connected_to_relay \
		or NetworkHandler.current_session_id.is_empty() or NetworkHandler.session_busy:
		return
	PlayerData.create(1,position,rotation).sent(NetworkHandler.peer.peer)
	

func set_player_pos(pos: Vector3):
	position = pos
	velocity = Vector3.ZERO
	_reset_camera_motion()

func _reset_camera_motion():
	camera_previous_position = global_position
	camera_current_position = global_position
	camera_motion_ready = true
	if is_instance_valid(camera): _update_camera_position(1.0)

func _update_camera_position(fraction: float):
	if not is_instance_valid(camera) or not camera_motion_ready: return
	var rendered = camera_previous_position.lerp(camera_current_position, clampf(fraction, 0, 1))
	# Only translate; body yaw and camera pitch remain immediate mouse input.
	camera.position = camera_rest_position + global_basis.inverse() * (rendered - global_position)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		# Horizontal rotation (body rotates around Y-axis)
		rotate_y(-event.relative.x * float(SaveData.store.get_value("controls.mouse_sensitivity")))
		
		# Vertical rotation (camera rotates around X-axis)
		if not is_instance_valid(camera): return
		var sensitivity = SaveData.store.get_value("controls.mouse_sensitivity")
		var invert = -1.0 if SaveData.store.get_value("controls.invert_mouse_y") else 1.0
		var tilt = camera.rotation.x - (event.relative.y * float(sensitivity) * invert)
		camera.rotation.x = clamp(tilt, -max_tilt, max_tilt)
		if head_idx != null and head_idx > -1:
			skeleton.set_bone_pose_rotation(head_idx, Quaternion.from_euler(camera.rotation))

	#camara switch
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		if camera.current:
			$Camera3D2.current = true
			
		else:
			camera.current = true

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("world_grab") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and not SaveData.voice.input_blocked and not NetworkHandler.session_busy:
		var pickups = DataLoader.get_world_pickups()
		if pickups.held_by_local("virtual"):
			pickups.release_grip("virtual")
		else:
			pickups.grab_nearest(world_grip, "virtual", 1.5)
		get_viewport().set_input_as_handled()
			
	
func _movement_blocked() -> bool:
	return not focused or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE or SaveData.voice.input_blocked \
		or NetworkHandler.session_busy or not get_tree().get_nodes_in_group("emote_wheel_input").is_empty()

func _movement_grounded() -> bool:
	return is_on_floor()

func _physics_process(delta):
	# Get input
	var input_direction = Vector3(0,0,0)
	var blocked = _movement_blocked()
	var target_speed = sprint.target_speed(get_walk_speed(), Input.is_action_pressed("sprint"), blocked)
	if not blocked:
		input_direction = Input.get_vector("left", "right", "back", "forward")
	var forward = -global_transform.basis.z  # Camera forward direction
	var right = global_transform.basis.x     # Camera right direction
	
	# Calculate movement direction relative to camera
	var direction = (forward * input_direction.y + right * input_direction.x).normalized()
	
	# Apply movement
	if not _movement_grounded() and not blocked:
		velocity = air_control.steer(velocity, direction * target_speed, acceleration, delta)
	elif direction:
		velocity.x = lerp(velocity.x, direction.x * target_speed, minf(acceleration * delta, 1.0))
		velocity.z = lerp(velocity.z, direction.z * target_speed, minf(acceleration * delta, 1.0))
	else:
		velocity.x = lerp(velocity.x, 0.0, minf(friction * delta, 1.0))
		velocity.z = lerp(velocity.z, 0.0, minf(friction * delta, 1.0))
	
	# Apply gravity
	velocity.y -= gravity * delta
	
	# Handle jumping
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not blocked:
		velocity.y = jump_force
	
	# Move the character
	if not camera_motion_ready: _reset_camera_motion()
	camera_previous_position = global_position
	move_and_slide()
	camera_current_position = global_position


func load_player_model():
	var url: String = SaveData.data["avatar_url"]
	var configuration = DataLoader.get_avatar_configuration() if DataLoader.has_method("get_avatar_configuration") else null
	if configuration != null:
		url = configuration.model_key(url)
	if url == avatar_url:
		return
	avatar_url = url
	avatar_generation += 1
	var generation = avatar_generation
	var vrm_model = await configuration.load_model(SaveData.data["avatar_url"]) if configuration != null else await DataLoader.load_vrm_from_url(url)
	if vrm_model == null:
		if generation == avatar_generation:
			avatar_url = ""
		return
	if generation != avatar_generation:
		vrm_model.queue_free()
		return
	if camera.get_parent() != self:
		camera.reparent(self)
	if is_instance_valid(avatar_model):
		avatar_model.queue_free()
	avatar_model = vrm_model
	skeleton = null
	head_idx = -1
	add_child(vrm_model)
	preload("res://scripts/assets/first_person_avatar.gd").apply(vrm_model, camera)
	await get_tree().process_frame
	
	skeleton = vrm_model.find_child("Skeleton3D")
	if skeleton:
		head_idx = skeleton.find_bone("Head")
		# Calibrate once from REST geometry, never follow animated head poses.
		var eye_bone_idx = _find_eye_bone()
		if eye_bone_idx >= 0:
			camera.position = vrm_model.transform * skeleton.transform * skeleton.get_bone_global_rest(eye_bone_idx).origin
			camera.position += Vector3.FORWARD * first_person_forward_offset
	camera_rest_position = camera.position
	_reset_camera_motion()


func _find_eye_bone() -> int:
	var eye_names = PackedStringArray(["LeftEye", "Left_Eye", "left_eye", "Eye.L", "Eye", "eye", "CenterEye", "center_eye"])
	for bone_name in eye_names:
		var idx = skeleton.find_bone(bone_name)
		if idx != -1:
			print("Found eye bone: %s" % bone_name)
			return idx
	print("No eye bone found, using head")
	return skeleton.find_bone("Head")
	
func _calculate_head_offset() -> Vector3:
	if head_idx == -1:
		return Vector3(0, 0, 0.1)  # Fallback small offset
		
	# Get the head bone's node
	var head_size = Vector3.ONE * -0.1  # Default fallback
	
	# Search for mesh instances under the head to get dimensions
	for child in skeleton.get_children():
		if child is MeshInstance3D and child.name.to_lower().contains("head"):
			var aabb = child.get_aabb()
			head_size = aabb.size
			break
			
	var meshes = []
	for child in skeleton.get_children():
		meshes.append(child)
	
	# If no direct mesh found, search the skeleton tree
	if head_size == Vector3.ONE * -0.1:
		if meshes.size() > 0:
			for mesh in meshes:
				if mesh is MeshInstance3D:
					head_size = mesh.get_aabb().size
					break
	
	# Offset forward by half the head width (Z-axis)
	var offset = Vector3(0, 0.1, head_size.z * -0.5)
	print("Head size: %s, Camera offset: %s" % [head_size, offset])
	
	return offset

func _profile_changed(owner: String):
	if owner == SaveData.profile.get_local_fingerprint():
		load_player_model()

func _asset_updated(source: String, _previous: String, _revision: String):
	if source == avatar_url:
		avatar_url = ""
		load_player_model()

func _avatar_configuration_changed():
	load_player_model()

func _exit_tree():
	if DataLoader.has_signal("asset_revision_available") and DataLoader.asset_revision_available.is_connected(_asset_updated):
		DataLoader.asset_revision_available.disconnect(_asset_updated)
	avatar_generation += 1
	SaveData.profile.profile_changed.disconnect(_profile_changed)
