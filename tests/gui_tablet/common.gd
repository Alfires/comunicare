extends SceneTree
## Shared helpers for the RED GUI tablet acceptance suites. Proposed component
## interfaces are product contracts from docs/roadmaps/gui-theme-and-avatar-preview-roadmap.md;
## missing components fail assertions instead of breaking compilation.

const PRESETS = ["graphite", "paper", "forest", "sand", "night", "high_contrast"]
const ACCENTS = ["teal", "blue", "amber", "green", "rose", "violet", "match_highlight"]
const HIGHLIGHTS = ["cyan", "yellow", "green", "magenta", "white"]
const TOKENS = ["background", "surface", "surface_raised", "border", "text", "text_muted",
	"accent", "accent_text", "focus", "success", "warning", "danger", "preview_stage", "overlay_dim"]
const PAGES = ["quick", "friends", "worlds", "avatars", "instance", "settings"]

var passed := 0
var failed := 0
var part := 0

func _initialize():
	call_deferred("_main")

func _main():
	await run()
	print("\nGUI tablet %s: %s passed, %s failed" % [suite_name(), passed, failed])
	quit(1 if failed else 0)

func suite_name() -> String:
	return "suite"

func run():
	pass

## Selects the roadmap part for following checks; false when filtered out by GUI_PARTS.
func begin(number: int) -> bool:
	part = number
	var selected = OS.get_environment("GUI_PARTS")
	if selected.is_empty():
		return true
	return str(number) in selected.split(",")

func check(value: bool, title: String):
	var line = "[P%d] %s" % [part, title]
	if value:
		passed += 1
		print("PASS: ", line)
	else:
		failed += 1
		print("FAIL: ", line)

func autoload(name: String) -> Node:
	return root.get_node_or_null(name)

func script_component(path: String, methods: Array) -> Object:
	if not ResourceLoader.exists(path):
		check(false, "roadmap component exists: " + path)
		return null
	var object = load(path).new()
	return _require_methods(object, path, methods)

func scene_component(path: String, methods: Array) -> Node:
	if not ResourceLoader.exists(path):
		check(false, "roadmap scene exists: " + path)
		return null
	var node = load(path).instantiate()
	return _require_methods(node, path, methods)

func _require_methods(object: Object, path: String, methods: Array) -> Object:
	var missing: Array = []
	for method in methods:
		if not object.has_method(method):
			missing.append(method)
	if not missing.is_empty():
		check(false, path + " implements " + ", ".join(missing))
		if object is Node:
			object.free()
		return null
	check(true, "component interface: " + path)
	return object

func require(object: Object, method: String, context: String) -> bool:
	var present = object != null and object.has_method(method)
	if not present:
		check(false, context + " implements " + method)
	return present

func source(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)

func evidence(name: String) -> String:
	return source("res://evidence/" + name + ".txt")

func descendants(node: Node) -> Array:
	var result: Array = []
	if node == null:
		return result
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func find_by_meta(node: Node, key: String, value: Variant = null) -> Array:
	var result: Array = []
	for child in descendants(node):
		if child.has_meta(key) and (value == null or child.get_meta(key) == value):
			result.append(child)
	return result

func find_by_script(node: Node, path: String) -> Node:
	for child in descendants(node):
		var script = child.get_script()
		if script != null and script.resource_path == path:
			return child
	return null

func named(node: Node, name: String) -> Node:
	if node == null:
		return null
	var unique = node.get_node_or_null("%" + name)
	return unique if unique != null else node.find_child(name, true, false)

## Emulates a real click: toggle buttons emit toggled and then pressed.
func activate(button: BaseButton):
	if button == null:
		return
	if button.toggle_mode:
		button.set_pressed_no_signal(not button.button_pressed)
		button.toggled.emit(button.button_pressed)
	button.pressed.emit()

func frames(count := 2):
	for i in count:
		await process_frame

func colors_equal(a: Variant, b: Variant) -> bool:
	return a is Color and b is Color and a.is_equal_approx(b)

func luminance(color: Color) -> float:
	var channel = func(value: float) -> float:
		return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
	return 0.2126 * channel.call(color.r) + 0.7152 * channel.call(color.g) + 0.0722 * channel.call(color.b)

## WCAG 2.x contrast ratio, computed independently of the implementation.
func contrast(a: Color, b: Color) -> float:
	var first = luminance(a)
	var second = luminance(b)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)

func key_event(keycode: Key, pressed := true) -> InputEventKey:
	var event = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event

func action_event(action: String) -> InputEvent:
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var copy: InputEventKey = event.duplicate()
				copy.pressed = true
				if copy.keycode == KEY_NONE:
					copy.keycode = copy.physical_keycode
				return copy
	return key_event(KEY_ESCAPE)

func project_theme() -> Theme:
	return ThemeDB.get_project_theme()

func palette() -> Object:
	if not ResourceLoader.exists("res://scripts/GUI/theme/palette.gd"):
		return null
	var object = load("res://scripts/GUI/theme/palette.gd").new()
	return object if object.has_method("tokens") else null
