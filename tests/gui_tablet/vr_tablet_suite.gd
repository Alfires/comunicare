extends "res://common.gd"
## Part 8: floating, movable VR tablet. Synthetic transforms only; no XR runtime,
## headset or physical controllers. The screen faces local +Z (VRViewport2D convention).

const METHODS = ["configure", "place_initial", "raycast_to_pixel", "grab_zone_contains", "begin_grab",
	"update_grab", "end_grab", "remember_placement", "restore_placement", "summon", "update_follow",
	"world_grab_blocked", "touch_pixel", "effective_smoothing"]
var HEAD := Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0))

var tablet: Node3D

func suite_name() -> String:
	return "vr tablet (part 8)"

func run():
	if not begin(8): return
	test_settings()
	test_wiring()
	tablet = scene_component("res://scenes/GUI/vr_tablet.tscn", METHODS)
	if tablet == null: return
	root.add_child(tablet)
	tablet.set("smoothing", 0.0)
	tablet.set("reduce_motion", false)
	await frames()
	test_screen()
	test_placement()
	test_raycast()
	test_grab()
	test_two_hand_scale()
	test_relative_placement()
	test_follow()
	test_touch()
	test_store_binding()
	tablet.free()

func screen_size() -> Vector2:
	var size = tablet.get("screen_size_m")
	var factor = tablet.get("scale_factor")
	if not size is Vector2 or not (factor is float or factor is int): return Vector2.ZERO
	return size * float(factor)

func world(local: Vector3) -> Vector3:
	return tablet.global_transform * local

func normal() -> Vector3:
	return tablet.global_basis.z.normalized()

func expected_pixel(local: Vector2) -> Vector2:
	var size = screen_size()
	return Vector2((local.x / size.x + 0.5) * 1600.0, (0.5 - local.y / size.y) * 1200.0)

func pixel_at(local: Vector2) -> Vector2:
	var point = world(Vector3(local.x, local.y, 0))
	return tablet.raycast_to_pixel(point + normal() * 0.3, -normal())

func transforms_equal(a: Transform3D, b: Transform3D, tolerance := 0.001) -> bool:
	return a.origin.distance_to(b.origin) < tolerance and a.basis.x.distance_to(b.basis.x) < tolerance \
		and a.basis.y.distance_to(b.basis.y) < tolerance and a.basis.z.distance_to(b.basis.z) < tolerance

func faces(head: Transform3D) -> bool:
	return normal().dot((head.origin - tablet.global_position).normalized()) > cos(deg_to_rad(10))

func test_settings():
	var save = autoload("SaveData")
	var expected = {
		"vr.menu_pin_mode": {"type": "enum", "default": "pinned", "options": ["pinned", "follow"]},
		"vr.menu_scale": {"type": "number", "default": 1.0, "min": 0.6, "max": 1.6},
		"vr.menu_direct_touch": {"type": "boolean", "default": false},
		"vr.menu_hand": {"type": "enum", "default": "either", "options": ["left", "right", "either"]},
	}
	for id in expected:
		var definition: Dictionary = save.registry.get_definition(id)
		var spec: Dictionary = expected[id]
		var valid = definition.get("category") == "VR Menu" and definition.get("type") == spec.type and definition.get("default") == spec.default
		if spec.has("options"): valid = valid and definition.get("options") is Dictionary and definition.options.keys() == spec.options
		if spec.has("min"): valid = valid and is_equal_approx(float(definition.get("min", -1)), spec.min) and is_equal_approx(float(definition.get("max", -1)), spec.max)
		check(valid, "VR Menu setting registered: " + id)

func test_wiring():
	var player = source("res://scripts/player/player_vr.gd")
	check(player.contains("vr_tablet.tscn") and not player.contains("vr_gui.tscn"), "player_vr opens the tablet instead of the flat panel (wiring check)")
	check(not player.contains("tracking_button.position") and not player.contains("comfort_button.position"),
		"tracker/comfort buttons no longer float over the menu at pixel positions (wiring check)")
	check(player.contains("world_grab_blocked"), "world pickup consults the tablet grab zone (wiring check)")

func test_screen():
	var viewport = tablet.get("viewport")
	check(viewport is SubViewport and viewport.size == Vector2i(1600, 1200), "tablet renders a 1600×1200 SubViewport")
	check(viewport is SubViewport and viewport.get_meta("vr_menu", false), "tablet viewport keeps the vr_menu meta")
	check(viewport is SubViewport and viewport.size_2d_override == Vector2i(1000, 750) and viewport.size_2d_override_stretch,
		"layout is 1000×750 logical px stretched to 1600×1200 so body text is about 1° tall")
	var pin = find_by_script(viewport, "res://scripts/GUI/tablet_shell.gd") if viewport is SubViewport else null
	pin = pin.get_node_or_null("%PinButton") if pin != null else null
	check(pin is BaseButton and pin.visible, "pin button is shown on the VR tablet")
	var size = tablet.get("screen_size_m")
	check(size is Vector2 and size.is_equal_approx(Vector2(0.55, 0.4125)), "default screen is 0.55 × 0.41 m (4:3)")
	check(size is Vector2 and 1600.0 / size.x >= 2800.0, "about 2900 px/m keeps text sharp at arm's length")
	check(viewport is SubViewport and find_by_script(viewport, "res://scripts/GUI/tablet_shell.gd") != null, "tablet hosts the shared shell")
	var anchor = named(tablet, "KeyboardAnchor")
	check(anchor is Node3D and tablet.is_ancestor_of(anchor) and tablet.to_local(anchor.global_position).y < -size.y / 2,
		"virtual keyboard docks below the screen and moves with it")

func test_placement():
	tablet.place_initial(HEAD)
	var offset = tablet.global_position - HEAD.origin
	var flat = Vector2(offset.x, offset.z)
	check(absf(flat.length() - 0.55) < 0.05 and offset.z < 0, "first open: about 0.55 m in front")
	check(offset.y <= -0.10 and offset.y >= -0.30, "first open: slightly below eye height")
	check(faces(HEAD) and normal().y > 0.05, "screen is tilted toward the face like a held tablet")
	check(absf(tablet.global_basis.x.normalized().y) < 0.01, "no roll")
	var turned = Transform3D(Basis(Vector3.UP, PI / 2), HEAD.origin)
	tablet.place_initial(turned)
	check((tablet.global_position - turned.origin).x < -0.4 and faces(turned), "placement follows head yaw")
	tablet.summon(HEAD)
	check((tablet.global_position - HEAD.origin).z < -0.4 and faces(HEAD), "summon brings the tablet back in front")

func test_raycast():
	tablet.place_initial(HEAD)
	check(pixel_at(Vector2.ZERO).distance_to(Vector2(800, 600)) < 2, "ray at the screen center hits pixel (800, 600)")
	var size = screen_size()
	var corner = Vector2(size.x / 2 - 0.01, size.y / 2 - 0.01)
	check(pixel_at(corner).distance_to(expected_pixel(corner)) < 2, "upper-right maps to the top-right pixels (Y inverted)")
	var center = world(Vector3.ZERO)
	check(tablet.raycast_to_pixel(center - normal() * 0.3, normal()) == Vector2(-1, -1), "back-face rays miss")
	check(tablet.raycast_to_pixel(world(Vector3(size.x, 0, 0)) + normal() * 0.3, -normal()) == Vector2(-1, -1), "rays beside the screen miss")
	check(tablet.raycast_to_pixel(center + normal() * 0.3, tablet.global_basis.x) == Vector2(-1, -1), "parallel rays miss")

func test_grab():
	tablet.place_initial(HEAD)
	var size = screen_size()
	var edge = Transform3D(Basis.IDENTITY, world(Vector3(size.x / 2 + 0.015, 0, 0.01)))
	check(tablet.grab_zone_contains(edge.origin), "frame edge is a grab zone")
	check(tablet.grab_zone_contains(world(Vector3(0, size.y / 2 - 0.01, 0.01))), "status bar is a grab zone")
	check(not tablet.grab_zone_contains(world(Vector3(0, 0, 0.01))), "screen content is not a grab zone")
	check(not tablet.grab_zone_contains(world(Vector3(0, 0, 0.2))), "points away from the tablet are not grab zones")
	check(not tablet.begin_grab("left", Transform3D(Basis.IDENTITY, world(Vector3(0, 0, 0.01)))), "grip over content does not grab")
	tablet.visible = true
	check(tablet.world_grab_blocked(edge.origin), "tablet grab zone has priority over world pickup")
	check(not tablet.world_grab_blocked(world(Vector3(0, 0, 0.5))), "world pickup works away from the tablet")
	var before = tablet.global_transform
	check(tablet.begin_grab("right", edge), "grip on the frame grabs the tablet")
	var moved = Transform3D(Basis(Vector3.UP, deg_to_rad(30)), edge.origin + Vector3(0.2, 0, -0.1))
	tablet.update_grab("right", moved)
	var expected = moved * edge.affine_inverse() * before
	check(transforms_equal(tablet.global_transform, expected), "grabbed tablet follows the hand with its relative offset and rotation")
	tablet.end_grab("right")
	var released = tablet.global_transform
	tablet.update_grab("right", Transform3D(Basis.IDENTITY, Vector3(5, 5, 5)))
	check(transforms_equal(tablet.global_transform, released), "release leaves the tablet floating in place")
	check(pixel_at(Vector2.ZERO).distance_to(Vector2(800, 600)) < 2, "pointer mapping stays correct after moving")
	tablet.visible = false
	check(not tablet.world_grab_blocked(edge.origin), "hidden tablet never blocks world pickup")
	tablet.visible = true
	tablet.set("smoothing", 0.3)
	check(is_equal_approx(tablet.effective_smoothing(), 0.3), "smoothing is used by default")
	tablet.set("reduce_motion", true)
	check(tablet.effective_smoothing() == 0.0, "reduce motion disables smoothing")
	tablet.set("reduce_motion", false)
	tablet.place_initial(HEAD)
	before = tablet.global_transform
	edge = Transform3D(Basis.IDENTITY, world(Vector3(size.x / 2 + 0.015, 0, 0.01)))
	tablet.begin_grab("right", edge)
	moved = Transform3D(Basis.IDENTITY, edge.origin + Vector3(0.3, 0, 0))
	tablet.update_grab("right", moved)
	var target = (moved * edge.affine_inverse() * before).origin
	var remaining = tablet.global_position.distance_to(target)
	check(remaining > 0.001 and remaining < 0.3, "smoothed grab moves part of the way per update")
	tablet.end_grab("right")
	tablet.set("smoothing", 0.0)

func test_two_hand_scale():
	tablet.place_initial(HEAD)
	tablet.set("scale_factor", 1.0)
	var size = screen_size()
	var left = Transform3D(Basis.IDENTITY, world(Vector3(-size.x / 2 - 0.015, 0, 0.01)))
	var right = Transform3D(Basis.IDENTITY, world(Vector3(size.x / 2 + 0.015, 0, 0.01)))
	check(tablet.begin_grab("left", left) and tablet.begin_grab("right", right), "both hands can grab the frame")
	var span = right.origin - left.origin
	tablet.update_grab("right", Transform3D(Basis.IDENTITY, left.origin + span * 2.0))
	check(is_equal_approx(float(tablet.get("scale_factor")), 1.6), "spreading hands scales up, clamped to 1.6×")
	tablet.update_grab("right", Transform3D(Basis.IDENTITY, left.origin + span * 0.25))
	check(is_equal_approx(float(tablet.get("scale_factor")), 0.6), "closing hands scales down, clamped to 0.6×")
	tablet.end_grab("left")
	tablet.end_grab("right")
	var corner = Vector2(screen_size().x / 2 - 0.01, 0)
	check(pixel_at(corner).distance_to(expected_pixel(corner)) < 2, "pointer mapping uses the scaled screen size")
	tablet.set("scale_factor", 1.0)

func test_relative_placement():
	var fresh = load("res://scenes/GUI/vr_tablet.tscn").instantiate()
	root.add_child(fresh)
	check(not fresh.restore_placement(Transform3D.IDENTITY), "restore without a remembered placement returns false")
	fresh.free()
	tablet.place_initial(HEAD)
	var before = tablet.global_transform
	tablet.remember_placement(Transform3D.IDENTITY)
	var player = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(3, 0, 2))
	check(tablet.restore_placement(player) and transforms_equal(tablet.global_transform, player * before),
		"reopen restores placement relative to player yaw and position")
	var pitched = Transform3D(Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, 0.35), Vector3(3, 0, 2))
	tablet.restore_placement(pitched)
	check(transforms_equal(tablet.global_transform, player * before), "only player yaw is used, never pitch")

func test_follow():
	tablet.set("pin_mode", "pinned")
	tablet.place_initial(HEAD)
	var pinned = tablet.global_transform
	var right = Transform3D(Basis(Vector3.UP, -PI / 2), HEAD.origin)
	tablet.update_follow(right, 0.1)
	check(transforms_equal(tablet.global_transform, pinned), "pinned tablet stays in the world")
	tablet.set("pin_mode", "follow")
	var small = Transform3D(Basis(Vector3.UP, deg_to_rad(30)), HEAD.origin)
	tablet.update_follow(small, 0.1)
	check(transforms_equal(tablet.global_transform, pinned), "follow mode ignores small head turns (< 45°)")
	tablet.update_follow(right, 0.1)
	var direction = tablet.global_position - right.origin
	var forward = -right.basis.z
	check(Vector2(direction.x, direction.z).normalized().dot(Vector2(forward.x, forward.z)) > 0.95 and faces(right),
		"follow mode lazily re-centers after a large head turn")
	tablet.set("pin_mode", "pinned")

func test_touch():
	tablet.place_initial(HEAD)
	tablet.set("direct_touch_enabled", true)
	var center = world(Vector3.ZERO)
	var hover = tablet.touch_pixel(center + normal() * 0.02)
	check(hover is Dictionary and hover.get("hover", false) and not hover.get("pressed", true)
		and hover.get("pixel", Vector2(-1, -1)).distance_to(Vector2(800, 600)) < 2, "fingertip within 3 cm hovers")
	check(tablet.touch_pixel(center + normal() * 0.005).get("pressed", false), "fingertip at the surface presses")
	check(tablet.touch_pixel(center - normal() * 0.01).get("pressed", false), "slightly pushing through still presses")
	check(tablet.touch_pixel(center - normal() * 0.05).is_empty(), "far behind the screen is ignored")
	check(tablet.touch_pixel(center + normal() * 0.05).is_empty(), "beyond 3 cm is ignored")
	tablet.set("direct_touch_enabled", false)
	check(tablet.touch_pixel(center + normal() * 0.005).is_empty(), "direct touch is off unless enabled")

func test_store_binding():
	var save = autoload("SaveData")
	if save.registry.get_definition("vr.menu_pin_mode").is_empty(): return
	tablet.configure(save.store)
	save.store.set_value("vr.menu_pin_mode", "follow")
	save.store.set_value("vr.menu_scale", 1.2)
	save.store.set_value("vr.menu_direct_touch", true)
	check(tablet.get("pin_mode") == "follow" and is_equal_approx(float(tablet.get("scale_factor")), 1.2)
		and tablet.get("direct_touch_enabled") == true, "tablet applies VR Menu settings live")
	for id in ["vr.menu_pin_mode", "vr.menu_scale", "vr.menu_direct_touch"]:
		save.store.reset_value(id)
