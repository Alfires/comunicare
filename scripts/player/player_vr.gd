extends CharacterBody3D

@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var origin_node = $XROrigin3D
@onready var right_controller: XRController3D = $XROrigin3D/RightHand
@onready var left_controller: XRController3D = $XROrigin3D/LeftHand
@export_range(0.0, 0.4, 0.01) var first_person_forward_offset := 0.15

var vrm_model: Node3D
var avatar_generation := 0
var avatar_url := ""
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
var emote_pressed := {"left": false, "right": false}
var locomotion = preload("res://scripts/player/vr_locomotion.gd").new()
var turning = preload("res://scripts/player/vr_turn_controller.gd").new()
var input_router = preload("res://scripts/player/vr_input_router.gd").new()
var comfort = preload("res://scripts/player/vr_comfort.gd").new()
var pointer = preload("res://scripts/GUI/vr_pointer_router.gd").new()
var main_panel: Node3D
var main_ui: Control
var trigger_before := {"left": false, "right": false}
var motion_rearm := false
var focused := true
var blink_remaining := 0.0
var comfort_material: ShaderMaterial


func _ready():
	if DataLoader.has_signal("asset_revision_available"):
		DataLoader.asset_revision_available.connect(_asset_updated)
	SaveData.profile.profile_changed.connect(_profile_changed)
	if DataLoader.has_method("get_avatar_configuration"):
		DataLoader.get_avatar_configuration().changed.connect(_avatar_configuration_changed)
	add_to_group("player")
	NetworkHandler.get_animation_controller()
	load_vrm_model()
	_create_comfort_overlay()

func set_player_pos(pos: Vector3):
	position = pos
	velocity = Vector3.ZERO

func _process(delta: float):
	var menu_action = str(SaveData.store.get_value("input.xr_main_menu_action"))
	var suppressed = not focused or SaveData.voice.input_blocked
	if input_router.menu_toggle(left_controller.is_button_pressed(menu_action), right_controller.is_button_pressed(menu_action), suppressed):
		_toggle_main_menu()
	_update_menu_pointer()
	var action = str(SaveData.store.get_value("input.xr_emote_action"))
	for side in ["left", "right"]:
		var controller = left_controller if side == "left" else right_controller
		var pressed = controller.is_button_pressed(action)
		if pressed and not emote_pressed[side] and get_tree().get_nodes_in_group("emote_wheel_input").is_empty() and not SaveData.voice.input_blocked and not _menu_open() and focused:
			NetworkHandler.get_animation_controller().open_xr_menu(controller, xr_camera, true)
		emote_pressed[side] = pressed
	debug_timer += delta
	if debug_timer >= 2.0:
		debug_timer = 0.0
	
	elapsed_time += delta
	if elapsed_time >= update_interval or last_state != {"position": position, "rotation": rotation}:  
		update_player_data() 
		elapsed_time = 0.0
		
func _get_movement_input() -> Vector2:
	return left_controller.get_vector2("primary").limit_length(1.0)

func _physics_process(delta):
	var movement_input = _get_movement_input()
	var turn_axis = right_controller.get_vector2("primary").x
	var blocked = not focused or _menu_open() or not get_tree().get_nodes_in_group("emote_wheel_input").is_empty() or NetworkHandler.session_busy
	if blocked:
		motion_rearm = true
		turning.reset()
	if motion_rearm and not blocked and movement_input.length() < 0.1 and absf(turn_axis) < 0.2:
		motion_rearm = false
	if blocked or motion_rearm:
		movement_input = Vector2.ZERO
		turn_axis = 0
	movement_speed = float(SaveData.store.get_value("vr.move_speed"))
	var desired = locomotion.desired_velocity(movement_input, xr_camera.global_basis, movement_speed, float(SaveData.store.get_value("vr.move_dead_zone")))
	turning.dead_zone = float(SaveData.store.get_value("vr.turn_dead_zone"))
	var mode = str(SaveData.store.get_value("vr.turn_mode"))
	var yaw = turning.step(turn_axis, delta, mode, float(SaveData.store.get_value("vr.snap_angle")), float(SaveData.store.get_value("vr.smooth_turn_rate")))
	if not is_zero_approx(yaw):
		var pivot = xr_camera.global_position
		pivot.y = global_position.y
		global_transform = turning.pivot_transform(global_transform, pivot, yaw)
		if mode == "snap" and SaveData.store.get_value("vr.snap_blink"): blink_remaining = 0.08
	velocity.y -= gravity * delta
	if not blocked and not motion_rearm and SaveData.store.get_value("vr.jump_enabled") and right_controller.is_button_pressed("primary_click") and is_on_floor():
		velocity.y = jump_force
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	move_and_slide()
	blink_remaining = maxf(0, blink_remaining - delta)
	var strength = comfort.update_vignette(Vector2(velocity.x, velocity.z).length(), rad_to_deg(yaw) / maxf(delta, 0.001), delta, SaveData.store.get_value("vr.comfort_vignette"))
	if comfort_material != null:
		comfort_material.set_shader_parameter("strength", strength)
		comfort_material.set_shader_parameter("blink", 1.0 if blink_remaining > 0 else 0.0)
	var shape_node = get_node_or_null("CollisionShape3D")
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var height = 1.2 if SaveData.store.get_value("vr.seated_mode") else clampf(xr_camera.position.y + 0.15, 1.0, 2.4)
		shape_node.shape.height = height
		shape_node.position.y = height * 0.5

func _menu_open() -> bool:
	return is_instance_valid(main_panel) and main_panel.visible

func _toggle_main_menu():
	if main_panel == null:
		main_panel = load("res://scenes/GUI/vr_gui.tscn").instantiate()
		main_panel.size = Vector2(1.2, 0.9)
		main_panel.pixel_per_unit = 800
		get_tree().root.add_child(main_panel)
		main_panel.viewport.set_meta("vr_menu", true)
		main_ui = load("res://scenes/GUI/menue.tscn").instantiate()
		main_panel.viewport.add_child(main_ui)
		main_panel.hide()
	if main_panel.visible:
		_close_main_menu()
	else:
		var animation = NetworkHandler.get_animation_controller()
		if is_instance_valid(animation.wheel) and animation.wheel.visible: animation.wheel.dismiss()
		main_panel.global_position = xr_camera.global_position - xr_camera.global_basis.z * 1.2
		main_panel.look_at(xr_camera.global_position, Vector3.UP, true)
		main_panel.show()
		motion_rearm = true

func _close_main_menu():
	if pointer == null: return
	pointer.cancel()
	_flush_pointer_events()
	if is_instance_valid(main_panel): main_panel.hide()
	motion_rearm = true
	trigger_before = {"left": false, "right": false}

func _flush_pointer_events():
	var events = pointer.drain_events()
	if not is_instance_valid(main_panel): return
	for value in events:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = value.pressed
		main_panel.inject_input(event, value.position)

func _update_menu_pointer():
	if not _menu_open(): return
	for side in ["left", "right"]:
		var controller = left_controller if side == "left" else right_controller
		var valid = focused and controller.get_is_active()
		var hit = main_panel.raycast_to_viewport_point(controller.global_position, -controller.global_basis.z) if valid else Vector2(-1, -1)
		pointer.hover(side, hit, hit.x >= 0)
		var pressed = valid and controller.is_button_pressed("trigger_click")
		if pressed and not trigger_before[side]: pointer.press(side)
		if not pressed and trigger_before[side]: pointer.release(side)
		trigger_before[side] = pressed
		if hit.x >= 0:
			main_panel.inject_input(InputEventMouseMotion.new(), hit)
	_flush_pointer_events()

func _create_comfort_overlay():
	var mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh.mesh = quad
	mesh.position.z = -0.2
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader = Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, depth_test_disabled, cull_disabled, fog_disabled; uniform float strength=0.0; uniform float blink=0.0; void vertex(){ POSITION=vec4(VERTEX.xy,0.0,1.0); } void fragment(){ float edge=smoothstep(0.2,0.7,length(UV-vec2(0.5))); ALBEDO=vec3(0.0); ALPHA=max(blink,edge*strength); }"
	comfort_material = ShaderMaterial.new()
	comfort_material.shader = shader
	mesh.material_override = comfort_material
	xr_camera.add_child(mesh)

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		_close_main_menu()
		comfort.reset()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		motion_rearm = true


func update_player_data():
	if NetworkHandler.peer == null or not NetworkHandler.peer.is_connected_to_relay \
		or NetworkHandler.current_session_id.is_empty() or NetworkHandler.session_busy:
		return
	PlayerData.create(1,position,rotation).sent(NetworkHandler.peer.peer)

func load_vrm_model():
	var url: String = SaveData.data["avatar_url"]
	var configuration = DataLoader.get_avatar_configuration() if DataLoader.has_method("get_avatar_configuration") else null
	if configuration != null: url = configuration.model_key(url)
	if url == avatar_url:
		return
	avatar_url = url
	avatar_generation += 1
	var generation = avatar_generation
	print("Loading VRM model...")
	var model = await configuration.load_model(SaveData.data["avatar_url"]) if configuration != null else await DataLoader.load_vrm_from_url(url)

	if model == null:
		if generation == avatar_generation:
			avatar_url = ""
		print("ERROR: Failed to load VRM model")
		return
	if generation != avatar_generation:
		model.queue_free()
		return
	var new_skeleton = _find_skeleton(model)
	if new_skeleton == null:
		model.queue_free()
		return
	if xr_camera.get_parent() != origin_node:
		xr_camera.reparent(origin_node)
	if is_instance_valid(vrm_model):
		vrm_model.queue_free()

	vrm_model = model
	add_child(vrm_model)
	preload("res://scripts/assets/first_person_avatar.gd").apply(vrm_model, xr_camera)
	# Keep the headset's real tracked pose. Move the avatar shell behind it
	# to provide the same forward clearance as desktop without camera motion.
	vrm_model.position = Vector3.BACK * first_person_forward_offset

	skeleton = _find_skeleton(vrm_model)
	if skeleton == null:
		print("ERROR: Skeleton not found")
		return
	
	var tracking = preload("res://scripts/assets/avatar_tracking.gd").new()
	skeleton.add_child(tracking)
	tracking.configure(vrm_model.get_meta("humanoid_bones", {}), xr_camera, left_controller, right_controller)
	# The tracked camera stays under XROrigin3D. Avatar animation/IK must
	# follow the headset, never make the headset follow an animated bone.

	
func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result != null:
			return result
	return null

func _profile_changed(owner: String):
	if owner == SaveData.profile.get_local_fingerprint():
		load_vrm_model()

func _asset_updated(source: String, _previous: String, _revision: String):
	if source == avatar_url:
		avatar_url = ""
		load_vrm_model()

func _avatar_configuration_changed():
	load_vrm_model()

func _exit_tree():
	_close_main_menu()
	if is_instance_valid(main_panel): main_panel.queue_free()
	if DataLoader.has_signal("asset_revision_available") and DataLoader.asset_revision_available.is_connected(_asset_updated):
		DataLoader.asset_revision_available.disconnect(_asset_updated)
	avatar_generation += 1
	SaveData.profile.profile_changed.disconnect(_profile_changed)

## Gives you the bone name from a list of names
func get_bone_by_array(bone_array: Array,_skeleton: Skeleton3D) -> String:
	for i in bone_array:
		if _skeleton.find_bone(i) != -1:
			return i
	return ""
		
