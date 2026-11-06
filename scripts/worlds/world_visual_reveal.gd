extends Node
## Scene-owned visual scheduling; does not alter script visibility or collision.
signal completed
var pending: Array = []
var cursor := 0
const BATCH = 8
const RANGE = 38.0
var priority_point := Vector3.ZERO
var refresh_elapsed := 0.0

func configure(world: Node3D, center: Vector3):
	priority_point = center
	var meshes = world.find_children("*", "MeshInstance3D", true, false)
	meshes.sort_custom(func(a, b): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	for mesh in meshes:
		pending.append({"node": weakref(mesh), "layers": mesh.layers, "bounds": mesh.global_transform * mesh.get_aabb()})
		mesh.layers = 0
	pending.sort_custom(func(a, b): return _distance_squared(a) < _distance_squared(b))
	# First nearby batch is available before movement is released.
	advance()

func _distance_squared(entry: Dictionary) -> float:
	var box: AABB = entry.bounds
	var nearest = priority_point.clamp(box.position, box.end)
	return nearest.distance_squared_to(priority_point)

func advance():
	var deadline = Time.get_ticks_usec() + 1500
	var count := 0
	while not pending.is_empty() and count < BATCH:
		var entry: Dictionary = pending.front()
		if _distance_squared(entry) > RANGE * RANGE: break
		pending.pop_front()
		var mesh = entry.node.get_ref()
		if is_instance_valid(mesh): mesh.layers = entry.layers
		cursor += 1
		count += 1
		if Time.get_ticks_usec() >= deadline: break
	if pending.is_empty():
		pending.clear()
		completed.emit()
		set_process(false)

func _process(delta: float):
	refresh_elapsed += delta
	if refresh_elapsed >= 0.1:
		refresh_elapsed = 0
		for player in get_tree().get_nodes_in_group("player"):
			if player is Node3D:
				if player.global_position.distance_squared_to(priority_point) > 0.25:
					priority_point = player.global_position
					pending.sort_custom(func(a, b): return _distance_squared(a) < _distance_squared(b))
				break
	advance()
