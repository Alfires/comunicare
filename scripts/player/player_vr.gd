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
var jump_force: float = 9.0

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
var tracking_modifier: SkeletonModifier3D
var tracker_roles = preload("res://scripts/assets/tracker_role_provider.gd").new()
var tracking_calibration = preload("res://scripts/assets/tracking_calibration.gd").new()
var rig_report: Dictionary = {}
var virtual_keyboard: Control
var scroll_at := {"left": 0, "right": 0}
var room_scale = preload("res://scripts/player/vr_room_scale.gd").new()
var safety = preload("res://scripts/player/vr_safety.gd").new()
var teleport_held := false
var teleport_candidate: Dictionary = {}
var teleport_marker: MeshInstance3D
var role_offsets: Dictionary = {}
var tracking_sequence := 0
var tracking_elapsed := 0.0
var foot_grounding = preload("res://scripts/assets/foot_grounding.gd").new()
var grounded_body_targets: Dictionary = {}
var world_grip_pressed := {"left": false, "right": false}
var sprint = preload("res://scripts/player/sprint_policy.gd").new()
var air_control = preload("res://scripts/player/air_control.gd").new()

func get_walk_speed() -> float:
	return float(SaveData.store.get_value("vr.move_speed")) * sprint.MOVEMENT_SCALE

func _sprint_speed(blocked: bool, teleport_mode: bool) -> float:
	var active = left_controller.get_is_active()
	return sprint.target_speed(get_walk_speed(), active and left_controller.is_button_pressed("primary_click"),
		blocked or teleport_mode or not active)


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
	var collision = get_node_or_null("CollisionShape3D")
	if collision != null and collision.shape != null: collision.shape = collision.shape.duplicate()

func set_player_pos(pos: Vector3):
	position = pos
	velocity = Vector3.ZERO

func _process(delta: float):
	tracking_elapsed += delta
	if tracking_elapsed >= 0.05:
		tracking_elapsed = 0
		_publish_tracking()
	_update_runtime_trackers()
	if is_instance_valid(tracking_modifier) and is_instance_valid(skeleton):
		var targets = tracking_calibration.calibrated_targets(tracker_roles.targets(Time.get_ticks_msec()), role_offsets)
		var body_targets: Dictionary = {}
		for role in ["hips", "leftFoot", "rightFoot"]:
			if role in ["leftFoot", "rightFoot"] and targets.has(role) and grounded_body_targets.has(role):
				targets[role] = grounded_body_targets[role]
			if targets.has(role): body_targets[role] = skeleton.global_transform.affine_inverse() * targets[role]
		tracking_modifier.set_body_targets(body_targets)
	var menu_action = str(SaveData.store.get_value("input.xr_main_menu_action"))
	if _menu_open() and (not focused or not xr_camera.get_is_active()): _close_main_menu()
	var suppressed = not focused or SaveData.voice.input_blocked
	if input_router.menu_toggle(left_controller.is_button_pressed(menu_action), right_controller.is_button_pressed(menu_action), suppressed):
		_toggle_main_menu()
	_update_menu_pointer()
	_update_world_grips()
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
	if elapsed_time >= 0.05 and (last_state != {"position": position, "rotation": rotation} or elapsed_time >= update_interval):
		update_player_data() 
		last_state = {"position": position, "rotation": rotation}
		elapsed_time = 0.0
		
func _get_movement_input() -> Vector2:
	return left_controller.get_vector2("primary").limit_length(1.0)

func _update_world_grips():
	if not DataLoader.has_method("get_world_pickups"): return
	var pickups = DataLoader.get_world_pickups()
	var blocked = not focused or _menu_open() or SaveData.voice.input_blocked or NetworkHandler.session_busy \
		or not get_tree().get_nodes_in_group("emote_wheel_input").is_empty()
	for side in ["left", "right"]:
		var hand: XRController3D = left_controller if side == "left" else right_controller
		var pressed = not blocked and hand.get_is_active() and hand.get_float("grip") >= 0.6
		var mirror = NetworkHandler.get_animation_controller().get("local_mirror")
		if pressed and not world_grip_pressed[side]:
			if not is_instance_valid(mirror) or not mirror.visible or not mirror.try_grab(hand, side, 0.3): pickups.grab_nearest(hand, side, 0.3)
		if not pressed and world_grip_pressed[side]:
			if is_instance_valid(mirror): mirror.release(side)
			pickups.release_grip(side)
		world_grip_pressed[side] = pressed

func _physics_process(delta):
	grounded_body_targets = tracking_calibration.calibrated_targets(tracker_roles.targets(Time.get_ticks_msec()), role_offsets)
	for role in ["leftFoot", "rightFoot"]:
		if grounded_body_targets.has(role):
			grounded_body_targets[role] = foot_grounding.resolve(role, grounded_body_targets[role], get_world_3d().direct_space_state, [get_rid()], collision_mask)
	if focused and xr_camera.get_is_active(): room_scale.reconcile(self, origin_node, xr_camera)
	var movement_input = _get_movement_input()
	var turn_axis = right_controller.get_vector2("primary").x
	var blocked = not focused or not xr_camera.get_is_active() or _menu_open() or SaveData.voice.input_blocked or not get_tree().get_nodes_in_group("emote_wheel_input").is_empty() or NetworkHandler.session_busy
	if not left_controller.get_is_active(): movement_input = Vector2.ZERO
	if not right_controller.get_is_active(): turn_axis = 0
	if blocked:
		motion_rearm = true
		turning.reset()
	if motion_rearm and not blocked and movement_input.length() < 0.1 and absf(turn_axis) < 0.2:
		motion_rearm = false
	if blocked or motion_rearm:
		movement_input = Vector2.ZERO
		turn_axis = 0
	var teleport_mode = SaveData.store.get_value("vr.locomotion_mode") == "teleport"
	if teleport_mode:
		_update_teleport(not blocked and not motion_rearm, movement_input)
		movement_input = Vector2.ZERO
	else:
		teleport_held = false
		if is_instance_valid(teleport_marker): teleport_marker.hide()
	movement_speed = _sprint_speed(blocked or motion_rearm, teleport_mode)
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
	if not is_on_floor() and not blocked and not motion_rearm and not teleport_mode:
		velocity = air_control.steer(velocity, desired, acceleration, delta)
	else:
		velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	move_and_slide()
	blink_remaining = maxf(0, blink_remaining - delta)
	var strength = comfort.update_vignette(Vector2(velocity.x, velocity.z).length(), rad_to_deg(yaw) / maxf(delta, 0.001), delta, SaveData.store.get_value("vr.comfort_vignette"))
	if comfort_material != null:
		comfort_material.set_shader_parameter("strength", strength)
		var clipped = SaveData.store.get_value("vr.head_clip_fade") and safety.head_obstructed(self, xr_camera.global_position)
		comfort_material.set_shader_parameter("blink", 1.0 if blink_remaining > 0 or clipped else 0.0)
	var shape_node = get_node_or_null("CollisionShape3D")
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var height = 1.2 if SaveData.store.get_value("vr.seated_mode") else clampf(xr_camera.position.y + 0.15, 1.0, 2.4)
		safety.resize_capsule(self, shape_node, height)

func _update_teleport(enabled: bool, stick: Vector2):
	if not is_instance_valid(teleport_marker):
		teleport_marker = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.04
		teleport_marker.mesh = sphere
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.1, 0.9, 0.6)
		teleport_marker.material_override = material
		get_tree().root.add_child(teleport_marker)
	var aiming = enabled and stick.y < -0.6
	if aiming:
		var collision = get_node_or_null("CollisionShape3D")
		var height: float = collision.shape.height if collision != null else 1.8
		var radius: float = collision.shape.radius if collision != null else 0.4
		teleport_candidate = safety.destination(self, left_controller.global_position, -left_controller.global_basis.z, height, radius)
		teleport_marker.visible = not teleport_candidate.is_empty()
		if teleport_marker.visible: teleport_marker.global_position = teleport_candidate.position + Vector3.UP * 0.03
	elif teleport_held:
		if enabled and stick.length() < 0.3 and not teleport_candidate.is_empty():
			var collision = get_node_or_null("CollisionShape3D")
			if collision != null and safety.clearance(self, teleport_candidate.position + Vector3.UP * 0.02, collision.shape.height, collision.shape.radius):
				safety.commit_teleport(self, origin_node, xr_camera, teleport_candidate.position + Vector3.UP * 0.02)
				blink_remaining = 0.1
		teleport_candidate.clear()
		teleport_marker.hide()
	teleport_held = aiming

func _menu_open() -> bool:
	return is_instance_valid(main_panel) and main_panel.visible

func _toggle_main_menu():
	if not is_instance_valid(main_panel):
		main_panel = load("res://scenes/GUI/vr_gui.tscn").instantiate()
		main_panel.size = Vector2(1.2, 0.9)
		main_panel.pixel_per_unit = 800
		get_tree().root.add_child(main_panel)
		main_panel.viewport.set_meta("vr_menu", true)
		main_ui = load("res://scenes/GUI/menue.tscn").instantiate()
		main_panel.viewport.add_child(main_ui)
		var tracking_button = Button.new()
		tracking_button.text = "VR tracker setup"
		tracking_button.position = Vector2(12, 45)
		tracking_button.custom_minimum_size = Vector2(180, 40)
		main_panel.viewport.add_child(tracking_button)
		tracking_button.pressed.connect(func():
			var setup = preload("res://scripts/GUI/vr_tracking_setup.gd").new()
			main_panel.viewport.add_child(setup)
			setup.configure(self))
		var comfort_button = Button.new()
		comfort_button.text = "Comfort preset"
		comfort_button.position = Vector2(200, 45)
		comfort_button.custom_minimum_size = Vector2(160, 40)
		main_panel.viewport.add_child(comfort_button)
		comfort_button.pressed.connect(func():
			for pair in [["vr.turn_mode", "snap"], ["vr.snap_angle", 30.0], ["vr.move_speed", 1.5], ["vr.comfort_vignette", true], ["vr.snap_blink", true], ["vr.jump_enabled", false]]:
				SaveData.store.set_value(pair[0], pair[1]))
		virtual_keyboard = preload("res://scripts/GUI/vr_keyboard.gd").new()
		main_panel.viewport.add_child(virtual_keyboard)
		main_panel.viewport.gui_focus_changed.connect(func(control):
			if control is LineEdit or control is TextEdit: virtual_keyboard.edit(control))
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
	if is_instance_valid(virtual_keyboard): virtual_keyboard.close()
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
			var scroll = controller.get_vector2("primary").y
			if absf(scroll) > 0.5 and Time.get_ticks_msec() >= scroll_at[side]:
				scroll_at[side] = Time.get_ticks_msec() + 100
				var event = InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_WHEEL_DOWN if scroll > 0 else MOUSE_BUTTON_WHEEL_UP
				event.pressed = true
				main_panel.inject_input(event, hit)
				event.pressed = false
				main_panel.inject_input(event, hit)
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

func _update_runtime_trackers():
	var trackers = XRServer.get_trackers(XRServer.TRACKER_ANY)
	for id in trackers:
		var tracker = trackers[id]
		if not tracker is XRPositionalTracker or tracker is XRControllerTracker: continue
		if str(id) in ["head", "/user/head"]: continue
		var pose = tracker.get_pose("default")
		if pose == null: continue
		tracker_roles.update_sample(str(id), origin_node.global_transform * pose.transform,
			pose.has_tracking_data and pose.tracking_confidence != XRPose.XR_TRACKING_CONFIDENCE_NONE, Time.get_ticks_msec())

func _publish_tracking():
	var peer = NetworkHandler.peer
	if not focused or peer == null or not peer.tracking_supported or NetworkHandler.session_busy or NetworkHandler.current_session_id.is_empty(): return
	if not SaveData.store.get_value("vr.share_tracking") or not is_instance_valid(vrm_model): return
	var revision: String = vrm_model.get_meta("asset_revision", "")
	if not InstanceState.valid_fingerprint(revision): return
	var targets: Dictionary = {}
	for pair in [["head", xr_camera], ["leftHand", left_controller], ["rightHand", right_controller]]:
		if pair[1].get_is_active(): targets[pair[0]] = TrackingPose.encode_target(global_transform.affine_inverse() * pair[1].global_transform)
	var body = grounded_body_targets
	for role in body: targets[role] = TrackingPose.encode_target(global_transform.affine_inverse() * body[role])
	tracking_sequence += 1
	peer.send_animation({"op": "pose", "version": 1, "session_id": NetworkHandler.current_session_id,
		"sequence": tracking_sequence, "avatar_revision": revision, "calibration_revision": 0, "targets": targets})

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		sprint.suppress()
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
	tracking_modifier = tracking
	rig_report = preload("res://scripts/assets/humanoid_rig_adapter.gd").new().validate_mapping(skeleton, vrm_model.get_meta("humanoid_bones", {}))
	var owner: String = SaveData.profile.get_local_fingerprint()
	var revision: String = vrm_model.get_meta("asset_revision", "")
	if not owner.is_empty() and not revision.is_empty():
		tracking_calibration.configure("user://tracking/" + owner + "-" + revision + ".json", owner, revision)
		var saved_calibration = tracking_calibration.load_calibration()
		tracking.set_calibration(saved_calibration)
		role_offsets = saved_calibration.get("role_offsets", {})
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
	foot_grounding.clear()
	if is_instance_valid(teleport_marker): teleport_marker.queue_free()
	tracker_roles.clear()
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
		
