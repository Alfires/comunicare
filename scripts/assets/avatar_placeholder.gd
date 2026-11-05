extends Node3D
## Original offline stand-in; all geometry is generated from bundled primitives.
var material: StandardMaterial3D
var indicator: Label3D
var loading := true
var elapsed := 0.0

func _init():
	material = StandardMaterial3D.new()
	material.roughness = 0.85
	for part in [
		[Vector3(0, 1.55, 0), Vector3(0.32, 0.32, 0.32)],
		[Vector3(0, 1.08, 0), Vector3(0.46, 0.55, 0.25)],
		[Vector3(-0.34, 1.05, 0), Vector3(0.16, 0.6, 0.18)],
		[Vector3(0.34, 1.05, 0), Vector3(0.16, 0.6, 0.18)],
		[Vector3(-0.14, 0.4, 0), Vector3(0.19, 0.8, 0.22)],
		[Vector3(0.14, 0.4, 0), Vector3(0.19, 0.8, 0.22)]]:
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = part[1]
		mesh.mesh = box
		mesh.position = part[0]
		mesh.material_override = material
		add_child(mesh)
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
