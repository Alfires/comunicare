extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)
func run():
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame; await process_frame
	var house = current_scene.get_node("Island/House")
	var lighting = house.get_node_or_null("RoomLighting")
	check(lighting != null, "house has three-zone lighting owner")
	if lighting == null:
		current_scene.queue_free(); await process_frame; finish(); return
	check(lighting.zones.size() == 3, "exactly lounge bedroom kitchen zones")
	for name in ["Lounge", "Bedroom", "Kitchen"]:
		var light = lighting.zones[name].light
		check(light is OmniLight3D and not light.shadow_enabled, "bounded nonshadowed real light: " + name)
		check(lighting.set_zone(name, false, 0.5, "warm") and light.light_energy == 0, "off changes actual illumination: " + name)
		check(lighting.set_zone(name, true, 0.5, "neutral") and light.light_energy > 0 and light.light_energy <= 2, "on changes actual illumination: " + name)
		check(not lighting.set_zone(name, true, NAN, "warm"), "NaN brightness rejected: " + name)
		check(not lighting.set_zone(name, true, 4, "warm"), "excessive brightness rejected: " + name)
		check(not lighting.set_zone(name, true, 0.5, "strobe"), "unknown temperature rejected: " + name)
	var bedroom_energy = lighting.zones.Bedroom.light.light_energy
	lighting.set_zone("Lounge", true, 0.1, "warm")
	check(lighting.zones.Bedroom.light.light_energy == bedroom_energy, "changing lounge leaves bedroom unchanged")
	check(not lighting.set_zone("Missing", true, 1, "warm"), "unknown zone rejected")
	var panel = lighting.make_controls()
	root.add_child(panel)
	check(panel.find_children("*", "HSlider", true, false).size() == 3, "all zones have adjustable UI brightness")
	check(panel.find_children("*", "CheckButton", true, false).size() == 3, "all zones have UI on/off")
	var toggles = panel.find_children("*", "CheckButton", true, false)
	toggles[0].button_pressed = false
	check(lighting.zones.Lounge.light.light_energy == 0, "real UI toggle updates zone")
	panel.queue_free()
	if OS.get_environment("ISLAND_LAYOUT_RENDERED") == "1":
		var camera = Camera3D.new(); current_scene.add_child(camera)
		camera.look_at_from_position(Vector3(24, 1.7, -14), Vector3(21, 0.8, -23))
		for state in ["off", "dim", "bright"]:
			for zone in lighting.zones: lighting.set_zone(zone, state != "off", 0.1 if state == "dim" else 1.0, "warm")
			await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/opencode/island-lighting-" + state + ".png") == OK, "rendered light comparison: " + state)
		print("LIGHTING METRICS: draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " process_seconds=", Performance.get_monitor(Performance.TIME_PROCESS))
	lighting.set_zone("Lounge", false, 0.1, "neutral")
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame; await process_frame
	var fresh = current_scene.get_node("Island/House/RoomLighting")
	check(fresh.zones.Lounge.enabled and fresh.zones.Lounge.brightness == 0.6, "home reload restores session-local defaults")
	current_scene.queue_free(); await process_frame; await process_frame
	finish()
func finish():
	print("Welcome layout: %s passed, %s failed (lighting)" % [passed, failed])
	quit(1 if failed else 0)
