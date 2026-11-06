extends Node
## Scene-owned visual scheduling; does not alter script visibility or collision.
signal completed
var pending: Array = []
var cursor := 0
const BATCH = 8

func configure(world: Node3D, center: Vector3):
	var meshes = world.find_children("*", "MeshInstance3D", true, false)
	meshes.sort_custom(func(a, b): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	for mesh in meshes:
		pending.append({"node": weakref(mesh), "layers": mesh.layers})
		mesh.layers = 0
	# First nearby batch is available before movement is released.
	advance()

func advance():
	var deadline = Time.get_ticks_usec() + 1500
	var count := 0
	while cursor < pending.size() and count < BATCH:
		var entry: Dictionary = pending[cursor]
		var mesh = entry.node.get_ref()
		if is_instance_valid(mesh): mesh.layers = entry.layers
		cursor += 1
		count += 1
		if Time.get_ticks_usec() >= deadline: break
	if cursor == pending.size():
		pending.clear()
		completed.emit()
		set_process(false)

func _process(_delta: float): advance()
