extends SceneTree
## Engine-level XR emulator: actual tracker/controller nodes, production player/menu.
## Not an OpenXR compositor/runtime or physical-device certification.
var passed := 0
var failed := 0
var trackers: Array = []

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func controller(name: String, hand: int, position: Vector3):
	var tracker = XRControllerTracker.new()
	tracker.name = name
	tracker.type = XRServer.TRACKER_CONTROLLER
	tracker.hand = hand
	tracker.set_pose("default", Transform3D(Basis.IDENTITY, position), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_input("primary", Vector2.ZERO)
	tracker.set_input("grip", 0.0)
	tracker.set_input("ax_button", false)
	tracker.set_input("trigger_click", false)
	XRServer.add_tracker(tracker)
	trackers.append(tracker)
	return tracker

## Clicks the tablet at a logical-layout point through the production ray mapping.
func tablet_tap(player: Node, logical: Vector2):
	var dimensions: Vector2 = player.main_panel.viewport.size
	var pixels = logical * dimensions / Vector2(player.main_panel.viewport.size_2d_override)
	var screen: Vector2 = player.main_panel.size_m()
	var hit = player.main_panel.global_transform * Vector3((pixels.x / dimensions.x - 0.5) * screen.x, (0.5 - pixels.y / dimensions.y) * screen.y, 0)
	var mapped = player.main_panel.raycast_to_viewport_point(hit + player.main_panel.global_basis.z * 0.5, -player.main_panel.global_basis.z)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		player.main_panel.inject_input(event, mapped)
		await process_frame

func save_tablet(player: Node, filename: String):
	var directory = OS.get_environment("COMUNICARE_UI_ARTIFACTS")
	if DisplayServer.get_name() == "headless" or directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	player.main_panel.viewport.get_texture().get_image().save_png(directory.path_join(filename))
	print("Screenshot: ", directory.path_join(filename))

## Friends on the narrowest tablet layout (interface size 1.5): long names and
## friend cards with Invite, Join friend and the shared "more" menu must fit.
func test_friends_tablet(player: Node):
	var save = root.get_node("SaveData")
	var network = root.get_node("NetworkHandler")
	var real_service = save.friends
	var previous_session = network.current_session_id
	save.store.set_value("interface.ui_scale", 1.5)
	network.current_session_id = "vr-test-session"
	player.main_ui.open_page("friends")
	var page: Control = player.main_ui.page("friends")
	save.friends = load("res://fake_friends.gd").new(30, true)
	page._bind_service()
	for frame in 6:
		await process_frame
	var logical := Vector2(player.main_panel.viewport.size_2d_override)
	var page_rect: Rect2 = page.get_global_rect()
	check(player.main_ui.shell.compact, "narrow VR tablet switches the shell to the compact icon rail")
	check(Rect2(Vector2.ZERO, logical).grow(0.5).encloses(player.main_ui.shell.get_global_rect()), "whole tablet shell fits the narrow VR viewport")
	check(logical.x < 700 and Rect2(Vector2.ZERO, logical).grow(0.5).encloses(page_rect), "Friends page fits the narrowest VR tablet layout (%s in %s)" % [page_rect, logical])
	check(page.rows.size() == page.view.size() and page.rows.size() > 20, "VR Friends builds every card within a few frames (%d/%d)" % [page.rows.size(), page.view.size()])
	var outside: Array = []
	var narrow: Array = []
	var controls: Array = page.layout.find_children("*", "Button", true, false) + page.layout.find_children("*", "LineEdit", true, false) + page.layout.find_children("*", "OptionButton", true, false)
	for control in controls:
		if not control.is_visible_in_tree(): continue
		var rect: Rect2 = control.get_global_rect()
		if rect.position.x < page_rect.position.x - 0.5 or rect.end.x > page_rect.end.x + 0.5:
			outside.append("%s '%s' %s" % [control.get_class(), control.get("text"), rect])
	for card in page.rows.values():
		if card.get_meta("title").size.x < 120:
			narrow.append("%s %.0f px" % [card.get_meta("title").text.left(20), card.get_meta("title").size.x])
	check(outside.is_empty(), "every visible Friends control stays inside the tablet page horizontally " + str(outside.slice(0, 4)))
	check(narrow.is_empty(), "names keep at least 120 px next to Invite/Join/more " + str(narrow.slice(0, 4)))
	var long_titles: Array = page.rows.values().map(func(card): return card.get_meta("title")).filter(func(title): return title.text.length() > 40)
	check(not long_titles.is_empty() and long_titles.all(func(title): return title.clip_text and title.get_combined_minimum_size().x < 200),
		"long names are truncated instead of widening the card")
	await save_tablet(player, "vr-friends.png")
	var first: Control = page.rows.values().filter(func(card): return card.visible).reduce(func(a, b): return a if a.get_index() < b.get_index() else b)
	var more: Button
	for button in first.find_children("*", "Button", true, false):
		if button.tooltip_text == "More actions": more = button
	var anchor: Vector2 = more.get_global_rect().position + Vector2(0, more.size.y)
	await tablet_tap(player, more.get_global_rect().get_center())
	await process_frame
	var popup: Control = page.more_menu
	var popup_rect: Rect2 = popup.get_global_rect()
	print("VR more menu: anchor=", anchor, " popup=", popup_rect, " logical=", logical, " physical=", player.main_panel.viewport.size)
	check(popup.visible and page.more_items().size() >= 2, "controller ray tap on a card's more button opens its menu")
	check(Rect2(Vector2.ZERO, logical).grow(1).encloses(popup_rect), "more menu stays inside the tablet")
	var button_rect: Rect2 = more.get_global_rect()
	check((absf(popup_rect.position.y - button_rect.end.y) < 2 or absf(popup_rect.end.y - button_rect.position.y) < 2)
		and popup_rect.position.x <= button_rect.end.x and popup_rect.end.x >= button_rect.position.x, "more menu opens directly below or above its button")
	await save_tablet(player, "vr-friends-more.png")
	popup.hide()
	save.friends = real_service
	page._bind_service()
	network.current_session_id = previous_session
	save.store.reset_value("interface.ui_scale")
	await process_frame
	check(not player.main_ui.shell.compact, "default VR tablet size restores the full navigation rail")

func run():
	root.size = Vector2i(1000, 700)
	var save = root.get_node("SaveData")
	root.get_node("DataLoader").get_asset_cache().enabled = false
	save.load_acount()
	save.data.avatar_url = ""
	save.data.default_avatar = ""
	var head = XRPositionalTracker.new()
	head.name = "head"
	head.type = XRServer.TRACKER_HEAD
	head.set_pose("default", Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	XRServer.add_tracker(head)
	trackers.append(head)
	var left = controller("left_hand", XRPositionalTracker.TRACKER_HAND_LEFT, Vector3(-0.3, 1.2, -0.4))
	var right = controller("right_hand", XRPositionalTracker.TRACKER_HAND_RIGHT, Vector3(0.3, 1.2, -0.4))
	var player = load("res://scenes/player/player_vr.tscn").instantiate()
	# Start with the real rig but prevent normal polling until deterministic poses
	# and camera are installed. Invoke production input paths explicitly below.
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	await process_frame
	check(player.left_controller.get_is_active() and player.right_controller.get_is_active(), "emulated XRControllerTracker poses activate production hand nodes")
	check(player.left_controller.position.distance_to(Vector3(-0.3, 1.2, -0.4)) < 0.01, "production left hand follows emulated tracked pose")
	left.set_input("primary", Vector2(0, -1))
	check(player._get_movement_input().is_equal_approx(Vector2(0, -1)), "emulated joystick reaches actual VR locomotion input")
	left.set_input("primary", Vector2.ZERO)
	player._toggle_main_menu()
	await process_frame
	check(player._menu_open() and player.main_ui.get_script().resource_path == "res://scripts/GUI/menue.gd" and player.main_ui.shell != null,
		"production VR rig opens actual shared tablet menu in 3D viewport")
	check(player.main_panel.viewport.get_meta("vr_menu", false), "VR viewport owns input mode independently from desktop mouse capture")
	var settings = player.main_ui.page("settings")
	player.main_ui.current_tab = 3
	settings.select_category("Network")
	check(settings.selected_category == "Network", "actual Network preferences are mounted in emulated VR menu")
	var target = Button.new()
	target.text = "Emulator ray target"
	target.position = Vector2(400, 300)
	target.size = Vector2(200, 80)
	player.main_panel.viewport.add_child(target)
	var clicks: Array = []
	target.pressed.connect(func(): clicks.append(true))
	# The tablet lays out at size_2d_override (logical) and renders at viewport.size (physical).
	var dimensions: Vector2 = player.main_panel.viewport.size
	var stretch = dimensions / Vector2(player.main_panel.viewport.size_2d_override)
	var pixels = target.get_rect().get_center() * stretch
	var screen: Vector2 = player.main_panel.size_m()
	var local_hit = Vector3((pixels.x / dimensions.x - 0.5) * screen.x, (0.5 - pixels.y / dimensions.y) * screen.y, 0)
	var hit = player.main_panel.global_transform * local_hit
	var origin = hit + player.main_panel.global_basis.z * 0.5
	var mapped = player.main_panel.raycast_to_viewport_point(origin, -player.main_panel.global_basis.z)
	check(mapped.distance_to(pixels) < 1.0, "emulated controller ray maps actual VR panel geometry to UI pixels")
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		player.main_panel.inject_input(event, mapped)
		await process_frame
	check(clicks.size() == 1, "VR tablet injects physical pixels that hit the logical-layout button exactly once")
	target.free()
	await test_friends_tablet(player)
	player._close_main_menu()
	check(not player._menu_open() and player.motion_rearm, "emulated menu close suppresses immediate accidental locomotion")
	left.set_input("ax_button", true)
	check(player.input_router.menu_toggle(true, false, false), "emulated left X supplies rising-edge menu intent")
	check(not player.input_router.menu_toggle(true, false, false), "held emulated face button never repeats menu toggle")
	player.input_router.menu_toggle(false, false, false)
	check(player.input_router.menu_toggle(false, true, false), "emulated right A supplies equivalent menu intent")
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not player.focused and not player._menu_open(), "focus loss closes production VR menu and clears interaction ownership")
	var old_position = player.left_controller.position
	left.set_pose("default", Transform3D(Basis.IDENTITY, Vector3(-0.5, 1.3, -0.6)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	check(player.left_controller.position.distance_to(old_position) > 0.1, "emulator motion updates production tracked hand after rig initialization")
	player.focused = true
	left.set_input("grip", 1.0)
	player._update_world_grips()
	check(player.world_grip_pressed.left, "emulated analog grip reaches actual world pickup input adapter")
	left.set_input("grip", 0.0)
	player._update_world_grips()
	check(not player.world_grip_pressed.left, "emulated grip release clears pickup input latch")
	# Exercise the actual frame/physics paths, not only input helpers. A broad
	# synthetic floor isolates locomotion from downloaded-world geometry.
	var floor = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(200, 0.2, 200)
	collision.shape = box
	floor.add_child(collision)
	floor.position.y = -0.1
	root.add_child(floor)
	player.position = Vector3(0, 1.4, 0)
	player.focused = true
	player._process(0.016)
	for frame in 90:
		await physics_frame
		player.focused = true # Emulated XR focus, independent of desktop window focus.
		player._physics_process(1.0 / 60.0)
	var start = player.position
	left.set_input("primary", Vector2(0, -1))
	for frame in 90:
		await physics_frame
		player.focused = true
		player._physics_process(1.0 / 60.0)
	check(player.position.distance_to(start) > 2.0 and player.position.is_finite(), "production VR physics moves tracked rig across collidable floor")
	left.set_input("primary", Vector2.ZERO)
	for frame in 60:
		await physics_frame
		player._physics_process(1.0 / 60.0)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.05, "production VR physics brakes after joystick release")
	var network = root.get_node("NetworkHandler")
	network.session_busy = true
	left.set_input("primary", Vector2(0, -1))
	for frame in 20:
		await physics_frame
		player._physics_process(1.0 / 60.0)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.05, "world transition suppresses actual VR body movement")
	network.session_busy = false
	left.set_input("primary", Vector2.ZERO)
	floor.queue_free()
	player.queue_free()
	for tracker in trackers: XRServer.remove_tracker(tracker)
	if is_instance_valid(network.animation_controller): network.animation_controller.queue_free(); network.animation_controller = null
	if network.directory_browser != null: network.directory_browser.stop()
	if network.lan_discovery != null: network.lan_discovery.stop()
	await process_frame
	await process_frame
	print("\nVR emulator acceptance: %s passed, %s failed" % [passed, failed])
	print("Godot XR tracker emulation only; OpenXR runtime unavailable, compositor/optics/comfort remain unverified.")
	quit(1 if failed else 0)
