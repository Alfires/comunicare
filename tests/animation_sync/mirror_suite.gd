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
	check(mirror.has_method("set_dimensions"), "mirror supports independent X and Y sizing")
	if mirror.has_method("set_dimensions"):
		mirror.set_dimensions(Vector2(2.5, 0.8))
		check(mirror.dimensions.is_equal_approx(Vector2(2.5, 0.8)), "mirror may be wide and short rather than uniform scale")
		check(absf(float(mirror.viewport.size.x) / mirror.viewport.size.y - 2.5 / 0.8) < 0.03, "reflection render target preserves resized aspect ratio")
	check(mirror.has_method("set_quality"), "mirror exposes bounded render quality")
	if mirror.has_method("set_quality"):
		mirror.set_quality("low")
		var low: Vector2i = mirror.viewport.size
		mirror.set_quality("high")
		check(mirror.viewport.size.x > low.x and mirror.viewport.size.y > low.y, "higher quality increases reflection resolution")
		mirror.set_quality("invalid")
		check(maxi(mirror.viewport.size.x, mirror.viewport.size.y) <= 1536, "invalid quality cannot create unbounded viewport")
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
	check(controller._mirror_actions().has("__mirror_size__"), "Mirror subgroup opens circular size popup")
	var wheel = load("res://scripts/GUI/emote_wheel.gd").new()
	root.add_child(wheel)
	wheel.open(layout, controller.emote_catalog())
	check(wheel.has_method("open_size_popup"), "wheel has draggable circular size popup")
	if wheel.has_method("open_size_popup"):
		wheel.open_size_popup(Vector2(1, 1.5))
		wheel.set_size_angle(0.5)
		check(is_equal_approx(wheel.size_values.x, 1.7), "circular control maps half-turn to width midpoint")
		wheel.size_axis = 1
		wheel.set_size_angle(1.0)
		check(is_equal_approx(wheel.size_values.y, 4.5), "Y dial changes height independently")
		check(wheel.visible and wheel.size_popup, "size interaction keeps emote menu open")
		wheel.pointer_direction = Vector2(0.5, 0)
		wheel.size_pointer(true)
		wheel.select_direction(Vector2(0, 0.8))
		wheel.size_pointer(false)
		check(not wheel.size_dragging and wheel.visible, "release ends circular drag without dismissing menu")
		wheel.back()
		check(not wheel.size_popup and wheel.visible, "popup Back returns to wheel without closing it")
	controller.wheel = wheel
	controller._choose_emote("__cancel_emote__")
	check(wheel.visible, "return to movement does not close emote menu")
	controller.local_mirror = mirror
	controller._choose_emote("__mirror_toggle__")
	check(wheel.visible, "mirror toggle does not close emote menu")
	controller.local_mirror = null
	wheel.queue_free()
	controller.free()
	mirror.free(); hand.free(); camera.free()
	print("Mirror failures: ", failed)
	quit(1 if failed else 0)
