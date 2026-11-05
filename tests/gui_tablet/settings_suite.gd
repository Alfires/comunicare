extends "res://common.gd"
## Part 9 settings page rewrite, plus Part 8's move of VR tracker/comfort actions
## into Settings. Uses the production settings scene with the real registry/store.

const ROW_PARTS = ["Title", "Caption", "Value", "Reset", "Error"]

var menu: Control

func suite_name() -> String:
	return "settings (parts 8-9)"

func run():
	menu = load("res://scenes/GUI/settings_menue.tscn").instantiate()
	root.size = Vector2i(1400, 1000)
	root.add_child(menu)
	await frames(3)
	await test_vr_actions()
	await test_rows()
	await test_reset_visibility()
	await test_errors()
	await test_search()
	test_categories()
	menu.free()

func rows() -> Array:
	return find_by_meta(menu, "setting_id")

func row(id: String) -> Node:
	for node in rows():
		if node.get_meta("setting_id") == id: return node
	return null

func part_of(node: Node, name: String) -> Node:
	return node.find_child(name, true, false) if node != null else null

func visible_ids() -> Array:
	return rows().filter(func(node): return node.is_visible_in_tree()).map(func(node): return node.get_meta("setting_id"))

func test_vr_actions():
	if not begin(8): return
	var tracker = menu.find_child("TrackerSetupButton", true, false)
	var comfort = menu.find_child("ComfortPresetButton", true, false)
	check(tracker is BaseButton, "Settings → VR has a VR tracker setup row")
	check(comfort is BaseButton, "Settings → VR has a Comfort preset row")
	if comfort is BaseButton:
		var store = autoload("SaveData").store
		activate(comfort)
		await frames()
		check(store.get_value("vr.turn_mode") == "snap" and is_equal_approx(store.get_value("vr.move_speed"), 1.5)
			and store.get_value("vr.comfort_vignette") and store.get_value("vr.snap_blink") and not store.get_value("vr.jump_enabled"),
			"Comfort preset applies the same six values as before")
		for id in ["vr.turn_mode", "vr.snap_angle", "vr.move_speed", "vr.comfort_vignette", "vr.snap_blink", "vr.jump_enabled"]:
			store.reset_value(id)

func test_rows():
	if not begin(9): return
	var all = rows()
	check(not all.is_empty(), "settings rows keep their setting_id meta")
	var incomplete: Array = []
	for node in all:
		for name in ["Title", "Value", "Reset", "Error"]:
			if part_of(node, name) == null:
				incomplete.append("%s.%s" % [node.get_meta("setting_id"), name])
	check(incomplete.is_empty(), "every row has Title, Value, Reset and Error parts %s" % [incomplete.slice(0, 4)])
	menu.select_category("Controls")
	await frames(2)
	var target = row("controls.invert_mouse_y")
	var title = part_of(target, "Title")
	var value = part_of(target, "Value")
	if title is Control and value is Control:
		var a: Rect2 = title.get_global_rect()
		var b: Rect2 = value.get_global_rect()
		check(b.position.x >= a.end.x - 1 and b.position.y < a.end.y and a.position.y < b.end.y,
			"label on the left, control on the right in the same line")
	else:
		check(false, "row layout parts are Controls")
	var described = row("controls.mouse_sensitivity")
	var plain = row("controls.invert_mouse_y")
	var described_caption = part_of(row("input.toggle_microphone"), "Caption")
	check(described_caption is Label and described_caption.visible and described_caption.theme_type_variation in ["CaptionLabel", "MutedLabel"],
		"descriptions render as muted captions")
	var plain_caption = part_of(plain, "Caption")
	check(plain_caption == null or not plain_caption.visible, "rows without description take no caption space")
	check(described != null, "number settings still render")

func test_reset_visibility():
	if not begin(9): return
	var store = autoload("SaveData").store
	var reset = part_of(row("controls.invert_mouse_y"), "Reset")
	if not reset is BaseButton:
		check(false, "Reset is a button")
		return
	check(reset.theme_type_variation == "IconButton" and reset.text.is_empty() and reset.icon != null and not reset.tooltip_text.is_empty(),
		"Reset is a small icon button with a tooltip")
	store.reset_value("controls.invert_mouse_y")
	await frames()
	check(not reset.visible, "Reset is hidden while the value is default")
	store.set_value("controls.invert_mouse_y", true)
	await frames()
	check(reset.visible, "Reset appears once the value differs from default")
	activate(reset)
	await frames()
	check(store.get_value("controls.invert_mouse_y") == false and not reset.visible, "Reset restores the default and hides again")

func test_errors():
	if not begin(9): return
	var hidden = rows().all(func(node):
		var error = part_of(node, "Error")
		return error is Label and not error.visible)
	check(hidden, "error labels take no space while empty")
	var binding = row("input.toggle_microphone")
	var button = part_of(binding, "Value")
	var error = part_of(binding, "Error")
	if not button is BaseButton or error == null:
		check(false, "key binding row exposes Value button and Error label")
		return
	menu.select_category("Controls")
	activate(button)
	await frames()
	root.push_input(key_event(KEY_B))
	await frames()
	check(error.visible and not error.text.is_empty(), "a conflicting key shows the inline error")
	root.push_input(key_event(KEY_ESCAPE))
	await frames()
	check(not error.visible, "Escape cancels binding and clears the error")

func test_search():
	if not begin(9): return
	var search = menu.find_child("Search", true, false)
	check(search is LineEdit, "settings page has a search field")
	if not search is LineEdit: return
	check(search.get_meta("blocks_global_shortcuts", false), "typing in search never toggles the menu")
	search.text = "mouse"
	search.text_changed.emit("mouse")
	await frames()
	var shown = visible_ids()
	check("controls.mouse_sensitivity" in shown and "controls.invert_mouse_y" in shown and "audio.master_volume" not in shown,
		"search filters by label and description")
	search.text = "volume"
	search.text_changed.emit("volume")
	await frames()
	shown = visible_ids()
	check("audio.master_volume" in shown and "audio.voice_volume" in shown, "search spans categories")
	var registry = autoload("SaveData").registry
	var matches = shown.all(func(id):
		var definition = registry.get_definition(id)
		return (definition.label + " " + definition.get("description", "")).to_lower().contains("volume"))
	check(matches, "only matching rows are shown")
	search.text = "zzzz-no-match"
	search.text_changed.emit(search.text)
	await frames()
	var empty = menu.find_child("NoResults", true, false)
	check(visible_ids().is_empty() and empty is Control and empty.is_visible_in_tree(), "no matches shows a one-line empty state")
	search.text = ""
	search.text_changed.emit("")
	menu.select_category("Audio")
	await frames()
	shown = visible_ids()
	check(not shown.is_empty() and shown.all(func(id): return registry.get_definition(id).category == "Audio"),
		"clearing search restores the selected category")

func test_categories():
	if not begin(9): return
	var categories = menu.get("category_buttons")
	check(categories is Dictionary and not categories.is_empty()
		and categories.values().all(func(button): return button.theme_type_variation == "NavButton"), "categories use NavButton")
