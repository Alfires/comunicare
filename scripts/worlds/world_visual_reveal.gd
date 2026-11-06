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
	for mesh in meshes:
		pending.append({"node": weakref(mesh), "layers": mesh.layers, "bounds": mesh.global_transform * mesh.get_aabb()})
		mesh.layers = 0
	pending.sort_custom(func(a, b): return _distance_squared(a) < _distance_squared(b))
	# First nearby batch is available before movement is released.
	advance()

func _exit_tree():
	for entry in pending:
		var mesh = entry.node.get_ref()
		if is_instance_valid(mesh): mesh.layers = entry.layers
	pending.clear()

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
		var dirty := false
		for player in get_tree().get_nodes_in_group("player"):
			if player is Node3D:
				if player.global_position.distance_squared_to(priority_point) > 0.25:
					priority_point = player.global_position
					dirty = true
				break
		for index in range(pending.size() - 1, -1, -1):
			var entry: Dictionary = pending[index]
			var mesh = entry.node.get_ref()
			if not is_instance_valid(mesh):
				pending.remove_at(index)
				dirty = true
				continue
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			if not bounds.is_equal_approx(entry.bounds):
				entry.bounds = bounds
				dirty = true
		if dirty: pending.sort_custom(func(a, b): return _distance_squared(a) < _distance_squared(b))
	elif not pending.is_empty() and _distance_squared(pending.front()) > RANGE * RANGE:
		return # Distant-only work is reconsidered at 10 Hz, not render cadence.
	advance()
