extends SceneTree
var failed := 0
class Loader extends Node:
	var world_runtime: Node
func _initialize(): call_deferred("run")
func check(value: bool, title: String):
	print("PASS: " if value else "FAIL: ", title)
	if not value: failed += 1
func run():
	var streamed = Node3D.new()
	root.add_child(streamed)
	var hidden_mesh: MeshInstance3D
	for index in 25:
		var mesh = MeshInstance3D.new()
		mesh.position.x = index
		mesh.layers = 3
		streamed.add_child(mesh)
		if index == 24:
			mesh.hide()
			hidden_mesh = mesh
	var reveal = load("res://scripts/worlds/world_visual_reveal.gd").new()
	streamed.add_child(reveal)
	reveal.configure(streamed, Vector3.ZERO)
	check(reveal.cursor <= 8 and reveal.cursor < 25, "world entry reveals bounded nearby batch without waiting for all visuals")
	while not reveal.pending.is_empty(): reveal.advance()
	check(not hidden_mesh.visible and hidden_mesh.layers == 3, "progressive reveal preserves authored visibility and render layers")
	check(not reveal.is_processing(), "finished visual scheduler stops per-frame work")
	streamed.free()
	var distance_world = Node3D.new()
	root.add_child(distance_world)
	var far = MeshInstance3D.new()
	far.mesh = BoxMesh.new()
	far.position.x = 100
	distance_world.add_child(far)
	var dynamic = load("res://scripts/worlds/world_visual_reveal.gd").new()
	distance_world.add_child(dynamic)
	dynamic.configure(distance_world, Vector3.ZERO)
	check(far.layers == 0 and dynamic.pending.size() == 1, "distant package visuals wait until player approaches")
	dynamic.priority_point = Vector3(100, 0, 0)
	dynamic.advance()
	check(far.layers != 0 and dynamic.pending.is_empty(), "approaching a map region reveals its validated visuals")
	distance_world.free()
	var built = load("res://scripts/worlds/world_builder.gd").new().build_package("res://packages/world_ui.zip")
	check(built.ok and built.document.ui.pages.has("credits"), "actual packaged menu passes reader and world builder")
	check(not load("res://scripts/worlds/world_builder.gd").new().build_package("res://packages/world_ui_bad.zip").ok, "invalid packaged UI root fails closed without runtime error")
	var schema = load("res://scripts/worlds/world_ui_schema.gd")
	var ui = {"version": 1, "pages": {"credits": {"title": "Credits / level", "widgets": [
		{"id": "credits", "type": "text", "text": "Created by test author"},
		{"id": "xp", "type": "progress", "max": 100, "bind": "state.xp"},
		{"id": "upgrade", "type": "button", "text": "Upgrade", "entity": "station", "actions": [{"op": "state_add", "key": "xp", "value": 10}]}]}}}
	var capabilities = ["ui.local", "state.local"]
	check(schema.validate(ui, ["station"], capabilities).ok, "reviewed menu schema accepts Credits/progress/action widgets")
	var hostile = ui.duplicate(true)
	hostile.pages.credits.widgets[0].type = "WebView"
	check(not schema.validate(hostile, ["station"], capabilities).ok, "arbitrary UI class rejected")
	hostile = ui.duplicate(true)
	hostile.pages.credits.widgets[2].actions = [{"op": "os.execute"}]
	check(not schema.validate(hostile, ["station"], capabilities).ok, "UI cannot bind executable callbacks")
	var world = Node3D.new()
	var station = Node3D.new()
	station.name = "Station"
	world.add_child(station)
	root.add_child(world)
	var runtime = load("res://scripts/worlds/world_runtime.gd").new()
	world.add_child(runtime)
	runtime.configure(world, {"ui": ui, "manifest": {"script_capabilities": capabilities}, "entities": {"station": {"path": "Station", "script": "station"}}, "programs": {"station": {"events": {"use": [{"op": "menu", "page": "credits"}]}}}})
	var loader = Loader.new()
	loader.world_runtime = runtime
	root.add_child(loader)
	var pickup = load("res://scripts/worlds/world_pickup_controller.gd").new()
	root.add_child(pickup)
	pickup.configure(null, loader)
	var hand = Node3D.new()
	world.add_child(hand)
	hand.position.x = 5
	check(not pickup.activate_nearest(hand, 0.3), "out of range scripted station cannot activate")
	hand.position.x = 0.1
	check(pickup.activate_nearest(hand, 0.3) and is_instance_valid(runtime.menu), "production pickup adapter dispatches use to bound world station")
	check(not pickup.activate_nearest(hand, 0.3), "open world menu suppresses repeated world interaction")
	runtime.menu.widgets.upgrade.control.pressed.emit()
	check(runtime.run_state.get("xp") == 10, "safe button dispatch updates scoped run state")
	runtime.menu.refresh()
	check(runtime.menu.widgets.xp.control.value == 10, "progress binding reflects state")
	var old_menu = runtime.menu
	runtime.close_menu()
	runtime.open_menu("credits")
	old_menu.widgets.upgrade.control.pressed.emit()
	check(runtime.run_state.get("xp") == 10, "retired page cannot dispatch actions into a newly opened menu")
	runtime.stop_scripts()
	check(not is_instance_valid(runtime.menu) and get_nodes_in_group("emote_wheel_input").is_empty(), "script stop releases world menu input ownership")
	check(not pickup.activate_nearest(hand, 0.3), "retired world runtime cannot activate station")
	pickup.free()
	loader.free()
	world.free()
	await process_frame
	print("World UI failures: ", failed)
	quit(1 if failed else 0)
