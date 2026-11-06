extends Node
## Trusted event broker for declarative .worldscript data, not attached GDScript.
const Data = preload("res://scripts/worlds/world_data.gd")
const VM = preload("res://scripts/worlds/world_script_vm.gd")
var entities: Dictionary = {}
var programs: Dictionary = {}
var bindings: Dictionary = {}
var capabilities: Array = []
var enabled := false
var world: WeakRef
var tick_elapsed := 0.0
var last_error := ""
var local_store: RefCounted
var checkpoint: WeakRef
var run_state: Dictionary = {}
var ui: Dictionary = {}
var menu: Control
var menu_layer: CanvasLayer
var menu_player: Node
var old_mouse_mode := Input.MOUSE_MODE_VISIBLE
var old_focus: WeakRef
var ui_dispatching := false
var vr_panel: Node3D
var vr_pressed := false

func configure(root_node: Node, document: Dictionary) -> Dictionary:
	stop_scripts()
	checkpoint = null
	run_state.clear()
	ui = document.get("ui", {}).duplicate(true)
	entities.clear()
	bindings.clear()
	programs = document.get("programs", {}).duplicate(true)
	capabilities = document.get("manifest", {}).get("script_capabilities", []).duplicate()
	world = weakref(root_node)
	for id in document.get("entities", {}):
		var entry: Dictionary = document.entities[id]
		var node = root_node if entry.path == "." else root_node.get_node_or_null(NodePath(entry.path))
		if node == null: return Data.failure("Missing runtime entity")
		entities[id] = weakref(node)
		if not str(entry.get("script", "")).is_empty(): bindings[id] = entry.script
	enabled = true
	last_error = ""
	return {"ok": true}

func binding_value(key: String) -> Variant:
	if key.begins_with("saved."): return local_store.values.get(key.trim_prefix("saved.")) if local_store != null else null
	return run_state.get(key.trim_prefix("state.")) if key.begins_with("state.") else null

func dispatch_ui(entity: String, actions: Array, source_menu: Control = null) -> Dictionary:
	if not enabled or world == null or world.get_ref() == null or not is_instance_valid(menu) or source_menu != menu or not entities.has(entity) or entities[entity].get_ref() == null or ui_dispatching: return Data.failure("World menu unavailable")
	ui_dispatching = true
	var result = _run(actions)
	ui_dispatching = false
	return result

func dispatch(event: String, entity: String) -> Dictionary:
	if not enabled or world == null or world.get_ref() == null: return Data.failure("World scripts stopped")
	if not event in ["start", "tick", "use", "grab", "release"] or (not entity.is_empty() and not entities.has(entity)):
		return Data.failure("Invalid world event")
	if not entity.is_empty() and entities[entity].get_ref() == null:
		return Data.failure("World event target is unavailable")
	var commands: Array = []
	# One aggregate event invocation and budget across all modules. Replication
	# must order shared callbacks before using this for multiplayer game logic.
	var operations: Array = []
	for id in bindings:
		if not entity.is_empty() and id != entity: continue
		if entities[id].get_ref() == null: continue
		operations.append_array(programs[bindings[id]].events.get(event, []))
	return _run(operations)

func _counter_sum(previous: Variant, increment: Variant) -> Variant:
	if not (previous is int or previous is float): return null
	if previous is int and increment is int:
		if increment > 0 and previous > 9223372036854775807 - increment: return null
		if increment < 0 and previous < (-9223372036854775807 - 1) - increment: return null
	var result = previous + increment
	return result if is_finite(float(result)) else null

func _run(operations: Array) -> Dictionary:
	var commands: Array = []
	var next_state = run_state.duplicate(true)
	var saved = local_store.values.duplicate(true) if local_store != null else {}
	var result = VM.new().run_event(operations, {"capabilities": capabilities, "entities": entities.keys(), "saved": saved}, {})
	if not result.ok:
		last_error = result.error
		stop_scripts()
		return result
	commands = result.commands
	# Resolve the whole transaction before mutating any scene state.
	for command in commands:
		if command.op == "menu":
			if not command.page.is_empty() and not ui.get("pages", {}).has(command.page): return Data.failure("Unknown world menu page")
			continue
		if command.op in ["state_set", "state_add"]:
			if command.op == "state_set": next_state[command.key] = command.get("value")
			else:
				var previous = next_state.get(command.key, 0)
				var sum = _counter_sum(previous, command.value)
				if sum == null: return Data.failure("Run counter is not numeric or exceeds its range")
				next_state[command.key] = sum
			if next_state.size() > 128 or not Data.bounded(next_state, 0, [2048]) or JSON.stringify(next_state).to_utf8_buffer().size() > 16384: return Data.failure("Run state budget exceeded")
			continue
		if command.op == "checkpoint":
			var marker = entities.get(command.entity)
			if marker == null or not marker.get_ref() is Marker3D: return Data.failure("Checkpoint must target a world marker")
			continue
		if command.op in ["save_set", "save_add", "save_delete"]:
			if local_store == null: return Data.failure("Local storage unavailable")
			if command.op == "save_set": saved[command.key] = command.get("value")
			elif command.op == "save_delete": saved.erase(command.key)
			else:
				var previous = saved.get(command.key, 0)
				var sum = _counter_sum(previous, command.value)
				if sum == null: return Data.failure("Saved counter is not numeric or exceeds its range")
				saved[command.key] = sum
			continue
		var target = entities.get(command.entity)
		if target == null or not target.get_ref() is Node3D:
			stop_scripts()
			return Data.failure("Visual target is unavailable")
	if saved != (local_store.values if local_store != null else {}) and not local_store.commit(saved): return Data.failure("Local save failed or exceeded quota")
	run_state = next_state
	for command in commands:
		if command.op == "command": entities[command.entity].get_ref().visible = command.value
		elif command.op == "checkpoint": checkpoint = entities[command.entity]
		elif command.op == "menu":
			if command.page.is_empty(): close_menu()
			else: open_menu(command.page)
	return {"ok": true, "commands": commands.size()}

func open_menu(page: String):
	if not enabled or not ui.get("pages", {}).has(page): return
	close_menu()
	for player in get_tree().get_nodes_in_group("player"):
		if player.get("xr_camera") != null:
			if player.has_method("_menu_open") and player._menu_open(): return
			menu_player = player
			break
		if player.has_method("_movement_blocked") and player._movement_blocked(): return
		menu_player = player
		break
	old_mouse_mode = Input.mouse_mode
	var focus = get_viewport().gui_get_focus_owner()
	old_focus = weakref(focus) if focus != null else null
	menu = preload("res://scripts/worlds/world_menu.gd").new()
	if is_instance_valid(menu_player) and menu_player.get("xr_camera") != null:
		vr_panel = load("res://scenes/GUI/vr_gui.tscn").instantiate()
		vr_panel.size = Vector2(1.0, 0.75)
		vr_panel.pixel_per_unit = 800
		add_child(vr_panel)
		vr_panel.viewport.add_child(menu)
		var camera = menu_player.xr_camera
		vr_panel.global_position = camera.global_position - camera.global_basis.z * 1.2
		vr_panel.look_at(camera.global_position, Vector3.UP, true)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		menu_layer = CanvasLayer.new()
		menu_layer.layer = 25
		add_child(menu_layer)
		menu_layer.add_child(menu)
	menu.add_to_group("emote_wheel_input") # Existing production movement/input suppression.
	menu.build(self, ui.pages[page])
	menu.closed.connect(close_menu)

func close_menu():
	if is_instance_valid(menu):
		menu.remove_from_group("emote_wheel_input")
		menu.queue_free()
		# Do not steal mouse ownership back from an application menu opened
		# while this world page was active.
		if not is_instance_valid(menu_player) or not menu_player.has_method("_menu_open") or not menu_player._menu_open(): Input.mouse_mode = old_mouse_mode
		if old_focus != null and is_instance_valid(old_focus.get_ref()): old_focus.get_ref().grab_focus()
	menu = null
	if is_instance_valid(menu_layer): menu_layer.queue_free()
	menu_layer = null
	if is_instance_valid(vr_panel): vr_panel.queue_free()
	vr_panel = null
	vr_pressed = false
	menu_player = null

func _unhandled_input(event: InputEvent):
	if is_instance_valid(menu) and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

func _exit_tree(): close_menu()

func respawn_local_player(player: Node3D) -> bool:
	# Trusted callers only. Scripts can select a marker but cannot move players.
	if not enabled or checkpoint == null or not checkpoint.get_ref() is Marker3D or not player.has_method("set_player_pos"): return false
	player.set_player_pos(checkpoint.get_ref().global_position)
	return true

func stop_scripts():
	close_menu()
	enabled = false
	tick_elapsed = 0.0

func _process(delta: float):
	if not enabled: return
	if is_instance_valid(menu):
		if is_instance_valid(menu_player) and (menu_player.get("focused") == false or (menu_player.has_method("_menu_open") and menu_player._menu_open())):
			close_menu()
			return
		if is_instance_valid(vr_panel) and is_instance_valid(menu_player):
			var hand = menu_player.right_controller
			var hit = vr_panel.raycast_to_viewport_point(hand.global_position, -hand.global_basis.z) if hand.get_is_active() else Vector2(-1, -1)
			var pressed = hit.x >= 0 and hand.is_button_pressed("trigger_click")
			if hit.x >= 0: vr_panel.inject_input(InputEventMouseMotion.new(), hit)
			if pressed != vr_pressed:
				var event = InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				vr_panel.inject_input(event, hit if hit.x >= 0 else Vector2.ZERO)
			vr_pressed = pressed
		return # Local script tick pause only; never pauses shared SceneTree.
	tick_elapsed += minf(delta, 0.1)
	while tick_elapsed + 0.000000001 >= 0.05:
		tick_elapsed = maxf(0.0, tick_elapsed - 0.05)
		dispatch("tick", "")
		if not enabled or is_instance_valid(menu): break
