extends Node3D
## Bundled CC0 Quaternius RobotExpressive; no runtime network requests.
var material: StandardMaterial3D
var indicator: Label3D
var loading := true
var elapsed := 0.0

func _init():
	material = StandardMaterial3D.new()
	material.roughness = 0.85
	var robot = load("res://assets/avatars/placeholder/RobotExpressive.glb").instantiate() as Node3D
	robot.name = "RobotModel"
	add_child(robot)
	var bounds = AABB()
	var first := true
	for mesh in robot.find_children("*", "MeshInstance3D", true, false):
		var transform_to_robot = Transform3D.IDENTITY
		var cursor: Node3D = mesh
		while cursor != robot:
			transform_to_robot = cursor.transform * transform_to_robot
			cursor = cursor.get_parent()
		var box: AABB = transform_to_robot * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		mesh.material_override = material
	if bounds.size.y > 0:
		var factor = 1.75 / bounds.size.y
		robot.scale = Vector3.ONE * factor
		robot.position.y = -bounds.position.y * factor
	indicator = Label3D.new()
	indicator.position = Vector3(0, 1.12, -0.15)
	indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicator.font_size = 64
	indicator.pixel_size = 0.006
	add_child(indicator)
	set_state(false, false)

func set_state(blocked: bool, failed: bool):
	loading = not blocked and not failed
	material.albedo_color = Color("e8a849") if blocked else (Color("ca7070") if failed else Color("62b5e5"))
	indicator.text = "X" if blocked else ("!" if failed else "...")
	indicator.modulate = Color.WHITE

func _process(delta: float):
	if not loading: return
	elapsed += delta
	indicator.text = ".".repeat(1 + int(elapsed * 3) % 3)
