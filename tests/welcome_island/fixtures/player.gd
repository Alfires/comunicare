extends Node3D
## No capture, avatar downloads or physical XR. A small operable menu probe.
var clicks := 0

func _ready():
	var menu = Button.new()
	menu.name = "MenuProbe"
	menu.text = "Offline menu probe"
	menu.position = Vector2(24, 24)
	menu.size = Vector2(240, 64)
	menu.pressed.connect(func(): clicks += 1)
	add_child(menu)
	var camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 4, 8)
	camera.look_at_from_position(camera.position, Vector3.ZERO)
