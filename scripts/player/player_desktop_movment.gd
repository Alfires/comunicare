extends CharacterBody3D

# Movement variables
@export var speed = 3.0
@export var acceleration = 20.0
@export var friction = 15.0
@export var jump_force = 7.0
@export var gravity = 20.0
@export var mouse_sensitivity: float = 0.003
@export var max_tilt: float = PI / 3.7  # Limit vertical rotation
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

func _ready() -> void:
	SaveData.profile.profile_changed.connect(_profile_changed)
	add_to_group("player")
	$menue.hide()
	load_player_model()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _process(delta):
	position += velocity * delta  # Move immediately
	var packet = PackedByteArray()
	packet.append_array(var_to_bytes(position))
	# when to update data
	elapsed_time += delta
	if elapsed_time >= update_interval or last_state != {"position": position, "rotation": rotation}:  
		update_player_data() 
		elapsed_time = 0.0
	
func update_player_data():
	if NetworkHandler.peer == null or not NetworkHandler.peer.is_connected_to_relay \
		or NetworkHandler.current_session_id.is_empty() or NetworkHandler.session_busy:
		return
	PlayerData.create(1,position,rotation).sent(NetworkHandler.peer.peer)
	

func set_player_pos(pos: Vector3):
	position = pos

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
			
	
func _physics_process(delta):
	# Get input
	var input_direction = Vector3(0,0,0)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		input_direction = Input.get_vector("left", "right", "back", "forward")
	var forward = -global_transform.basis.z  # Camera forward direction
	var right = global_transform.basis.x     # Camera right direction
	
	# Calculate movement direction relative to camera
	var direction = (forward * input_direction.y + right * input_direction.x).normalized()
	
	# Apply movement
	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)
	
	# Apply gravity
	velocity.y -= gravity * delta
	
	# Handle jumping
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		velocity.y = jump_force
	
	# Move the character
	move_and_slide()


func load_player_model():
	var url: String = SaveData.data["avatar_url"]
	if url == avatar_url:
		return
	avatar_url = url
	avatar_generation += 1
	var generation = avatar_generation
	var vrm_model = await DataLoader.load_vrm_from_url(url)
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
	await get_tree().process_frame
	
	skeleton = vrm_model.find_child("Skeleton3D")
	if skeleton:
		head_idx = skeleton.find_bone("Head")
		var eye_bone_idx = _find_eye_bone()
		if eye_bone_idx != -1:
			# Create a BoneAttachment3D to attach camera to the bone
			var bone_attachment = BoneAttachment3D.new()
			bone_attachment.bone_idx = eye_bone_idx
			skeleton.add_child(bone_attachment)
			# Move camera as child of the bone attachment
			var head_offset = _calculate_head_offset()
			camera.reparent(bone_attachment)
			camera.position = head_offset


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

func _exit_tree():
	avatar_generation += 1
	SaveData.profile.profile_changed.disconnect(_profile_changed)
