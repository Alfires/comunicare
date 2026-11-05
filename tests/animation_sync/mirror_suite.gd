extends SceneTree
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ", title)
	if not ok: failed += 1
func run():
	var path = "res://scripts/assets/local_mirror.gd"
	check(ResourceLoader.exists(path), "local mirror component exists")
	if not ResourceLoader.exists(path): quit(1); return
	var mirror = load(path).new()
	root.add_child(mirror)
	var camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1.5, 2)
	mirror.source_camera = camera
	mirror._process(0.016)
	check(is_equal_approx(mirror.reflection_camera.global_position.z, -2), "mirror reflects camera position across plane")
	check(mirror.viewport.world_3d == root.world_3d, "mirror renders the real local world")
	check(mirror.find_children("*", "CollisionObject3D", true, false).is_empty(), "mirror creates no physics bodies or areas")
	mirror.resize_by(10)
	check(mirror.dimensions.x <= 3.0, "mirror resizing stays bounded")
	var hand = Node3D.new()
	root.add_child(hand)
	hand.global_position = mirror.handle.global_position
	check(mirror.try_grab(hand, "virtual", 0.3), "local mirror handle can be grabbed")
	var before = mirror.global_position
	hand.global_position += Vector3(1, 0, 0)
	mirror._process(0.016)
	check(mirror.global_position.distance_to(before + Vector3.RIGHT) < 0.001, "grab moves mirror without physics simulation")
	check(mirror.release("virtual"), "handle releases without throw or network state")
	var controller = load("res://scripts/assets/animation_controller.gd").new()
	var layout = controller._wheel_layout()
	check(layout.groups.root.entries.any(func(entry): return entry.type == "group" and entry.name == "Mirror"), "emote wheel includes Mirror subgroup")
	check(layout.groups["__local_mirror_tools__"].entries.size() == 4, "Mirror subgroup offers toggle resize and reposition actions")
	controller.free()
	mirror.free(); hand.free(); camera.free()
	print("Mirror failures: ", failed)
	quit(1 if failed else 0)
