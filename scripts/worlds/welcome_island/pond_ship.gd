extends Node3D
## Trusted local-only constrained watercraft; never reparents/rotates tracked players.
const BERTH := Vector3(19, -0.3, 23)
var rider: WeakRef
var speed := 0.0
var steering := 0.0
var input_rearm := false
var controls: CanvasLayer

func _ready():
	position = BERTH
	var hull = load("res://assets/welcome_island/models/ship/boat-row-large.glb").instantiate()
	hull.name = "Hull"
	hull.scale = Vector3.ONE * 1.6
	add_child(hull)
	for mesh in hull.find_children("*", "MeshInstance3D", true, false):
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.7, 0.55, 0.38)
		material.albedo_texture = load("res://assets/welcome_island/textures/weathered_planks/weathered_planks_diff_1k.jpg")
		material.normal_enabled = true
		material.normal_texture = load("res://assets/welcome_island/textures/weathered_planks/weathered_planks_nor_gl_1k.jpg")
		material.roughness = 0.7
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.7
		mesh.material_override = material
	var deck = StaticBody3D.new()
	deck.name = "RiderSupport"
	add_child(deck)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new(); box.size = Vector3(1.4, 0.2, 2.8)
	shape.shape = box; shape.position.y = 0.6
	deck.add_child(shape)
	add_to_group("home_ship")

func board(player: CharacterBody3D) -> bool:
	if rider != null or not is_instance_valid(player) or not player.is_in_group("player") or player.global_position.distance_to(global_position) > 3.5: return false
	if not _exit_clear(player): return false
	rider = weakref(player)
	player.set_meta("home_ship", weakref(self))
	player.velocity = Vector3.ZERO
	input_rearm = true
	player.global_position = global_position + Vector3(0, 0.8, 0)
	_show_controls()
	return true

func drive(input: Vector2, blocked: bool):
	if blocked or not input.is_finite():
		speed = 0; steering = 0; input_rearm = true; return
	if input_rearm:
		if input.length() < 0.1: input_rearm = false
		speed = 0; steering = 0; return
	speed = clampf(input.y, -1, 1) * 1.5
	steering = clampf(input.x, -1, 1) * 0.45

func step(delta: float):
	if rider == null: return
	var player = rider.get_ref()
	if not is_instance_valid(player): rider = null; speed = 0; return
	var turn = clampf(delta, 0, 0.05) * steering
	var target = global_position + -global_basis.z * speed * clampf(delta, 0, 0.05)
	var distance = Vector2((target.x - 23) / 1.15, target.z - 23).length()
	var proposed_yaw = rotation.y + turn
	if distance <= 8.0 and _hull_clear(target, proposed_yaw):
		global_position = target
		rotation.y = proposed_yaw
	else: speed = 0
	player.global_position = global_position + Vector3(0, 0.8, 0)
	player.velocity = Vector3.ZERO

func _physics_process(delta: float): step(delta)

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: stop()

func stop():
	speed = 0; steering = 0; input_rearm = true

func disembark() -> bool:
	if rider == null or global_position.distance_to(BERTH) > 1.0: return false
	var player = rider.get_ref()
	if not is_instance_valid(player): rider = null; return false
	if not _exit_clear(player): return false
	_release(player, Vector3(9, 1, 23))
	return true

func _exit_clear(player: CharacterBody3D) -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	var capsule = CapsuleShape3D.new(); capsule.radius = 0.35; capsule.height = 1.9
	query.shape = capsule; query.transform.origin = Vector3(9, 1.05, 23); query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func _hull_clear(target: Vector3, target_yaw: float = rotation.y) -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	var hull = BoxShape3D.new(); hull.size = Vector3(2.4, 0.7, 3.6)
	query.shape = hull
	query.transform = Transform3D(Basis.from_euler(Vector3(0, rotation.y, 0)), global_position + Vector3(0, 0.6, 0))
	query.motion = target - global_position
	var excluded: Array[RID] = [get_node("RiderSupport").get_rid()]
	if rider != null and is_instance_valid(rider.get_ref()): excluded.append(rider.get_ref().get_rid())
	query.exclude = excluded
	var space = get_world_3d().direct_space_state
	if query.motion.length_squared() > 0.000001 and space.cast_motion(query)[0] < 1: return false
	# Sample rotation as well as translation so long bow/stern corners cannot
	# swing through dock posts while the craft's center remains unobstructed.
	var start = query.transform
	query.motion = Vector3.ZERO
	for index in range(1, 5):
		var fraction = index / 4.0
		query.transform = Transform3D(Basis.from_euler(Vector3(0, lerpf(rotation.y, target_yaw, fraction), 0)), start.origin.lerp(target + Vector3(0, 0.6, 0), fraction))
		if not space.intersect_shape(query).is_empty(): return false
	return true

func return_to_dock():
	stop(); position = BERTH; rotation = Vector3.ZERO
	if rider != null:
		var player = rider.get_ref()
		if is_instance_valid(player):
			if not disembark(): _release(player, Vector3(0, 1, 0))
		else: rider = null

func _release(player: CharacterBody3D, target: Vector3):
	player.remove_meta("home_ship")
	preload("res://scripts/worlds/welcome_island/home_contract.gd").reset_player(player, target)
	rider = null; stop()
	if is_instance_valid(controls): controls.queue_free()

func _show_controls():
	controls = CanvasLayer.new(); add_child(controls)
	var panel = HBoxContainer.new(); panel.position = Vector2(20, 100); controls.add_child(panel)
	for action in [["Stop", stop], ["Disembark at dock", disembark], ["Return to dock", return_to_dock]]:
		var button = Button.new(); button.text = action[0]; button.custom_minimum_size.y = 44
		button.pressed.connect(action[1]); panel.add_child(button)
	# These controls are also exposed through the player's shared Settings menu.

func _exit_tree():
	if rider != null:
		var player = rider.get_ref()
		if is_instance_valid(player):
			player.remove_meta("home_ship")
			player.velocity = Vector3.ZERO
