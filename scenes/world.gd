extends Node3D
const Home = preload("res://scripts/worlds/welcome_island/home_contract.gd")
var recoverable_homes: Dictionary = {}
var local_pickups: Node

func _ready():
	# Direct startup and scene re-entry share DataLoader's built-in spawn contract.
	call_deferred("_spawn_players")
	call_deferred("_setup_local_objects")

func _setup_local_objects():
	var loader = get_node_or_null("/root/DataLoader")
	local_pickups = loader.get_world_pickups() if loader != null and loader.has_method("get_world_pickups") else null
	if local_pickups == null:
		local_pickups = preload("res://scripts/worlds/world_pickup_controller.gd").new()
		add_child(local_pickups)
	var objects := {}
	for index in 2:
		var item = RigidBody3D.new()
		item.name = "GardenBelonging" + str(index)
		add_child(item)
		item.position = Vector3(-24 + index * 0.7, 0.4, 17)
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.25, 0.2, 0.25)
		mesh.mesh = box
		item.add_child(mesh)
		var shape = CollisionShape3D.new()
		var collision = BoxShape3D.new()
		collision.size = box.size
		shape.shape = collision
		item.add_child(shape)
		objects[item.name] = item
		register_recoverable(item, item.global_transform)
	var lamp = OmniLight3D.new()
	lamp.name = "GardenLamp"
	lamp.position = Vector3(-24, 1, 18)
	lamp.light_color = Color(1, 0.76, 0.45)
	lamp.omni_range = 5
	add_child(lamp)
	var switch = StaticBody3D.new()
	switch.name = "GardenLampSwitch"
	add_child(switch)
	switch.position = Vector3(-24, 0.65, 18)
	var switch_mesh = MeshInstance3D.new()
	switch_mesh.mesh = BoxMesh.new()
	switch_mesh.scale = Vector3(0.15, 0.3, 0.15)
	switch.add_child(switch_mesh)
	var switch_collision = CollisionShape3D.new()
	var switch_shape = BoxShape3D.new()
	switch_shape.size = Vector3(0.15, 0.3, 0.15)
	switch_collision.shape = switch_shape
	switch.add_child(switch_collision)
	local_pickups.activate_local(self, objects, {"lamp": {"node": switch, "action": func(): lamp.visible = not lamp.visible}})

func _spawn_players():
	for player in get_tree().get_nodes_in_group("player"):
		return_player_to_spawn(player)

func return_player_to_spawn(player: Node3D):
	if is_instance_valid(player) and player.is_in_group("player"):
		if is_instance_valid(local_pickups): local_pickups.cancel_local_input()
		Home.reset_player(player)

func register_recoverable(body: RigidBody3D, home: Transform3D) -> bool:
	if not is_instance_valid(body) or not home.is_finite(): return false
	# Weak keys do not retain disconnected/deleted items after scene teardown.
	var id = body.get_instance_id()
	if not recoverable_homes.has(id):
		body.tree_exiting.connect(func(): recoverable_homes.erase(id), CONNECT_ONE_SHOT)
	recoverable_homes[id] = {"body": weakref(body), "home": home}
	return true

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Physics callbacks cannot safely mutate body transforms immediately.
	call_deferred("_recover_body", weakref(body))

func _recover_body(reference: WeakRef):
	var body = reference.get_ref()
	if not is_instance_valid(body): return
	if body.is_in_group("player"):
		return_player_to_spawn(body)
	elif body is RigidBody3D:
		var record = recoverable_homes.get(body.get_instance_id(), {})
		if not record.is_empty() and record.body.get_ref() == body:
			if is_instance_valid(local_pickups): local_pickups.cancel_local_input()
			body.global_transform = record.home
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			body.sleeping = true
		else:
			# Unregistered lost objects cannot pile up in the spawn/head space.
			body.queue_free()

func _exit_tree():
	if is_instance_valid(local_pickups): local_pickups.reset()
