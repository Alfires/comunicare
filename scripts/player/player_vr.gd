extends CharacterBody3D

@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var origin_node = $XROrigin3D
@onready var right_controller: XRController3D = $XROrigin3D/RightHand
@onready var left_controller: XRController3D = $XROrigin3D/LeftHand

var vrm_model: Node3D
var skeleton: Skeleton3D


var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var movement_speed: float = 2.0
var turn_speed: float = 2.0
var acceleration = 20.0
var jump_force: float = 7.0

var update_interval = 0.5
var elapsed_time = 0.0
var last_state = {"position": position, "rotation": rotation}

var head_bone_names := ["Armature.Head","Head","Skeleton3D:Head","face","mixamorig:Head"]

var right_arm_names := ["RightHand", "J_Bip_R_Hand", "mixamorig:RightHand"]

var left_arme_names :=  ["LeftHand", "J_Bip_L_Hand", "mixamorig:LeftHand"]


var head_forward_offset: float = 0.08

var debug_timer: float = 0.0


func _ready():
	load_vrm_model()

func _process(delta: float):
	debug_timer += delta
	if debug_timer >= 2.0:
		debug_timer = 0.0
	
	elapsed_time += delta
	if elapsed_time >= update_interval or last_state != {"position": position, "rotation": rotation}:  
		update_player_data() 
		elapsed_time = 0.0
		
func _get_movement_input() -> Vector2:
	var input = left_controller.get_vector2("primary")
	if input.length() < 0.1:
		input = Vector2.ZERO
	return input * movement_speed

func _physics_process(delta):
	var movement_input = _get_movement_input()
	var direction = xr_camera.global_transform.basis * Vector3(movement_input.x, 0, movement_input.y)
	
	velocity.y -= gravity * delta
	
	if right_controller.is_button_pressed("ax_button") and is_on_floor():
		velocity.y = jump_force

	
	if direction:
		velocity.x = lerp(velocity.x, direction.x * movement_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, -direction.z * movement_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x/4, 0, delta)
		velocity.z = move_toward(velocity.z/4, 0, delta)
	
	move_and_slide()


func update_player_data():
	PlayerData.create(1,position,rotation).sent(NetworkHandler.peer.peer)

func load_vrm_model():
	print("Loading VRM model...")
	var model = await DataLoader.load_vrm_from_url(SaveData.data["avatar_url"])

	if model == null:
		print("ERROR: Failed to load VRM model")
		return

	vrm_model = model
	add_child(vrm_model)
	vrm_model.position = Vector3.ZERO

	skeleton = _find_skeleton(vrm_model)
	if skeleton == null:
		print("ERROR: Skeleton not found")
		return
	
	var xrbm := XRBodyModifier3D.new()
	skeleton.add_child(xrbm)
	var head_bone_name = get_bone_by_array(head_bone_names,skeleton)
	if head_bone_name != "":
		print("head bone found: ", head_bone_name)
		var ba := BoneAttachment3D.new()
		#ba.override_pose = true
		ba.bone_name = head_bone_name
		xr_camera.reparent(ba,false)
		xr_camera.position = Vector3(0, 0.15, 0.08)
		skeleton.add_child(ba)
	else: print("head bone not found")
	var TBID := _create_TwoBoneIK3D()
	skeleton.add_child(TBID)

	
func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result != null:
			return result
	return null

func _create_TwoBoneIK3D() -> TwoBoneIK3D:
	var TBID = TwoBoneIK3D.new()
	return TBID

## Gives you the bone name from a list of names
func get_bone_by_array(bone_array: Array,_skeleton: Skeleton3D) -> String:
	for i in bone_array:
		if _skeleton.find_bone(i) != -1:
			return i
	return ""
		
