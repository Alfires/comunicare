extends Node3D
const Home = preload("res://scripts/worlds/welcome_island/home_contract.gd")
var recoverable_homes: Dictionary = {}

func _ready():
	# Direct startup and scene re-entry share DataLoader's built-in spawn contract.
	call_deferred("_spawn_players")

func _spawn_players():
	for player in get_tree().get_nodes_in_group("player"):
		return_player_to_spawn(player)

func return_player_to_spawn(player: Node3D):
	if is_instance_valid(player) and player.is_in_group("player"):
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
			body.global_transform = record.home
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			body.sleeping = true
		else:
			# Unregistered lost objects cannot pile up in the spawn/head space.
			body.queue_free()
