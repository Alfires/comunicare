extends Control

@onready var rows: VBoxContainer = $Layout/Content/ScrollContainer/Rows
@onready var categories: VBoxContainer = $Layout/Content/Side/CategoryScroll/Categories
@onready var status: Label = $Layout/Status
## Rows are built per category on demand (the shown one first, the others one per
## frame). Reading controls/errors/resets completes the build first, so callers
## always see every setting.
var controls: Dictionary:
	get:
		_complete_rows()
		return _controls
var errors: Dictionary:
	get:
		_complete_rows()
		return _errors
var _controls: Dictionary = {}
var _errors: Dictionary = {}
var _resets: Dictionary = {}
var _pending_rows: Dictionary = {}
var binding_id := ""
var selected_category := ""
var category_pages: Dictionary = {}
var category_buttons: Dictionary = {}
var resets: Dictionary:
	get:
		_complete_rows()
		return _resets
var searching := false
@onready var search: LineEdit = %Search
@onready var no_results: Label = %NoResults
const RESET_ICON = preload("res://themes/icons/reset.svg")

func _ready():
	search.set_meta("blocks_global_shortcuts", true)
	search.text_changed.connect(_search_changed)
	SaveData.registry.definitions_changed.connect(_render)
	SaveData.store.setting_changed.connect(_update_value)
	SaveData.store.persistence_error.connect(_show_error)
	SaveData.store.saved.connect(_on_saved)
	_render()
	if not SaveData.store.last_error.is_empty():
		_show_error(SaveData.store.last_error)

func _render():
	_cancel_binding()
	for child in categories.get_children():
		categories.remove_child(child)
		child.queue_free()
	for child in rows.get_children():
		if child == no_results:
			continue
		rows.remove_child(child)
		child.queue_free()
	_controls.clear()
	_errors.clear()
	_resets.clear()
	_pending_rows.clear()
	category_pages.clear()
	category_buttons.clear()
	var group = ButtonGroup.new()
	var category := ""
	var page: VBoxContainer
	for definition in SaveData.registry.get_definitions():
		if not definition.get("visible", true):
			continue
		if category != definition.category:
			category = definition.category
			page = VBoxContainer.new()
			page.theme_type_variation = "SectionVBox"
			rows.add_child(page)
			category_pages[category] = page
			categories.add_child(_category_button(category, group))
			var header = HBoxContainer.new()
			var title = Label.new()
			title.text = category
			title.theme_type_variation = "HeaderLabel"
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header.add_child(title)
			var reset = Button.new()
			reset.text = "Reset category"
			reset.pressed.connect(_reset_category.bind(category))
			header.add_child(reset)
			page.add_child(header)
			# Rows are inserted before this hidden marker, after header/help items.
			var marker = Control.new()
			marker.visible = false
			marker.set_meta("row_marker", true)
			page.add_child(marker)
			_pending_rows[category] = []
		_pending_rows[category].append(definition)
	if category_pages.has("Assets") and DataLoader.has_method("get_asset_cache"):
		_add_cache_actions(category_pages.Assets)
	if category_pages.has("Controls"):
		var help = preload("res://scripts/GUI/home_help.gd").new()
		category_pages.Controls.add_child(help)
		category_pages.Controls.move_child(help, 1)
		var local_notice = Label.new()
		local_notice.text = "Home objects are local to this client; changes are not synchronized with other players."
		local_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		category_pages.Controls.add_child(local_notice)
		for lighting in get_tree().get_nodes_in_group("home_lighting"):
			category_pages.Controls.add_child(lighting.make_controls())
		for house in get_tree().get_nodes_in_group("home_resting"):
			category_pages.Controls.add_child(house.make_rest_controls())
		for kitchen in get_tree().get_nodes_in_group("home_kitchen"):
			category_pages.Controls.add_child(kitchen.make_controls())
		for ship in get_tree().get_nodes_in_group("home_ship"):
			var board = Button.new()
			board.text = "Board pond boat (near dock)…"
			board.custom_minimum_size.y = 44
			board.pressed.connect(func():
				var world = get_tree().current_scene
				if world != null and world.has_method("_confirm_ship_boarding"): world._confirm_ship_boarding(ship))
			category_pages.Controls.add_child(board)
			for action in [["Stop pond boat", ship.stop], ["Leave boat at dock", ship.disembark], ["Return boat to dock", ship.return_to_dock]]:
				var button = Button.new()
				button.text = action[0]; button.custom_minimum_size.y = 44
				button.pressed.connect(action[1])
				category_pages.Controls.add_child(button)
	if category_pages.has("VR Comfort"):
		_add_vr_actions(category_pages["VR Comfort"])
	var credits = preload("res://scripts/GUI/credits_page.gd").new()
	credits.visible = false # Builds its notices when Credits is first selected.
	credits.source_requested.connect(func(url): OS.shell_open(url))
	rows.add_child(credits)
	category_pages["Credits"] = credits
	categories.add_child(_category_button("Credits", group))
	if not category_pages.has(selected_category):
		selected_category = "" if category_pages.is_empty() else str(category_pages.keys()[0])
	select_category(selected_category)
	set_process(not _pending_rows.is_empty())

## Builds the rows of one category if they are still pending.
func _build_rows(category: String):
	if not _pending_rows.has(category):
		return
	var definitions: Array = _pending_rows[category]
	_pending_rows.erase(category)
	var page: Control = category_pages[category]
	var marker: Node = page.get_children().filter(func(child): return child.has_meta("row_marker"))[0]
	for definition in definitions:
		var row = _setting_row(definition)
		page.add_child(row)
		page.move_child(row, marker.get_index())
		_update_value(definition.id, SaveData.store.get_value(definition.id))

func _complete_rows():
	for category in _pending_rows.keys():
		_build_rows(category)

## One pending category per frame keeps opening Settings smooth.
func _process(_delta: float):
	if _pending_rows.is_empty():
		set_process(false)
		return
	_build_rows(_pending_rows.keys()[0])

func _category_button(category: String, group: ButtonGroup) -> Button:
	var tab = Button.new()
	tab.text = category
	tab.theme_type_variation = "NavButton"
	tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tab.custom_minimum_size = Vector2(150, 48)
	tab.toggle_mode = true
	tab.button_group = group
	tab.pressed.connect(select_category.bind(category))
	category_buttons[category] = tab
	return tab

## Row: Title (+ Caption) on the left, Value on the right, Reset only when changed, Error only when set.
func _setting_row(definition: Dictionary) -> Control:
	var row = VBoxContainer.new()
	row.theme_type_variation = "FlushVBox"
	row.set_meta("setting_id", definition.id)
	row.set_meta("search_text", (str(definition.label) + " " + str(definition.get("description", ""))).to_lower())
	var line = HBoxContainer.new()
	line.theme_type_variation = "WideHBox"
	row.add_child(line)
	var info = VBoxContainer.new()
	info.theme_type_variation = "FlushVBox"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_stretch_ratio = 0.82
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(info)
	var title = Label.new()
	title.name = "Title"
	title.text = definition.label
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)
	if not str(definition.get("description", "")).is_empty():
		var caption = Label.new()
		caption.name = "Caption"
		caption.text = definition.description
		caption.theme_type_variation = "CaptionLabel"
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(caption)
	var control = _create_control(definition)
	control.name = "Value"
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 40)
	line.add_child(control)
	_controls[definition.id] = control
	var reset = Button.new()
	reset.name = "Reset"
	reset.theme_type_variation = "IconButton"
	reset.icon = RESET_ICON
	reset.tooltip_text = "Reset to default"
	reset.custom_minimum_size = Vector2(40, 40)
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_reset_value.bind(definition.id))
	line.add_child(reset)
	_resets[definition.id] = reset
	var error = Label.new()
	error.name = "Error"
	error.theme_type_variation = "ErrorLabel"
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.visible = false
	row.add_child(error)
	_errors[definition.id] = error
	return row

func _set_error(id: String, message: String):
	if _errors.has(id):
		_errors[id].text = message
		_errors[id].visible = not message.is_empty()

func _search_changed(query: String):
	var text = query.strip_edges().to_lower()
	searching = not text.is_empty()
	if searching:
		_complete_rows()
	var any := false
	for name in category_pages:
		var page: Control = category_pages[name]
		var page_match := false
		for child in page.get_children():
			if child.has_meta("setting_id"):
				var hit = not searching or str(child.get_meta("search_text")).contains(text)
				child.visible = hit
				page_match = page_match or hit
			elif child.get_index() > 0 and not child.has_meta("row_marker"):
				child.visible = not searching
		page.visible = (page_match and searching) or (not searching and name == selected_category)
		any = any or (page_match and searching)
	no_results.text = "No settings match \"%s\"." % query.strip_edges()
	no_results.visible = searching and not any
	for name in category_buttons:
		category_buttons[name].set_pressed_no_signal(not searching and name == selected_category)

func _add_cache_actions(page: VBoxContainer):
	var cache = DataLoader.get_asset_cache()
	cache.initialize()
	var summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(summary)
	var update = func():
		if is_instance_valid(summary):
			summary.text = "Managed assets: %.1f MiB\n%s" % [cache.usage_bytes() / 1048576.0, cache.last_error]
	update.call()
	var open = Button.new()
	open.text = "Open cache folder"
	open.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path(cache.directory)))
	page.add_child(open)
	var refresh = Button.new()
	refresh.text = "Check loaded avatars and world for updates now"
	refresh.pressed.connect(func():
		refresh.disabled = true
		await DataLoader.call("refresh_loaded_assets")
		if is_instance_valid(refresh):
			refresh.disabled = false
		update.call())
	page.add_child(refresh)
	var clear = Button.new()
	clear.text = "Clear unused downloads (keep active assets and imports)"
	page.add_child(clear)
	# The confirmation dialog is created on first click, not with the page.
	clear.pressed.connect(func():
		var confirm: ConfirmationDialog = clear.get_node_or_null("Confirm")
		if confirm == null:
			confirm = ConfirmationDialog.new()
			confirm.name = "Confirm"
			confirm.dialog_text = "Remove unused cached downloads? Active assets and imported originals will be kept."
			clear.add_child(confirm)
			confirm.confirmed.connect(func():
				cache.clear_unused()
				update.call())
		confirm.popup_centered())

const COMFORT_PRESET = [["vr.turn_mode", "snap"], ["vr.snap_angle", 30.0], ["vr.move_speed", 1.5],
	["vr.comfort_vignette", true], ["vr.snap_blink", true], ["vr.jump_enabled", false]]

func _add_vr_actions(page: VBoxContainer):
	var comfort = Button.new()
	comfort.name = "ComfortPresetButton"
	comfort.text = "Apply comfort preset"
	comfort.tooltip_text = "Snap turning, slower movement, vignette and blink, no jump"
	comfort.custom_minimum_size.y = 48
	comfort.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	comfort.pressed.connect(apply_comfort_preset)
	page.add_child(comfort)
	var tracker = Button.new()
	tracker.name = "TrackerSetupButton"
	tracker.text = "Set up VR trackers…"
	tracker.custom_minimum_size.y = 48
	tracker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tracker.visible = get_viewport() != null and get_viewport().get_meta("vr_menu", false)
	tracker.pressed.connect(_open_tracker_setup)
	page.add_child(tracker)

func apply_comfort_preset():
	for pair in COMFORT_PRESET:
		SaveData.store.set_value(pair[0], pair[1])

func _open_tracker_setup():
	for player in get_tree().get_nodes_in_group("player"):
		if player.get("tracker_roles") != null:
			var setup = preload("res://scripts/GUI/vr_tracking_setup.gd").new()
			get_viewport().add_child(setup)
			setup.configure(player)
			return

## The relay panel builds dialogs and lists (~20 ms); create it when Network is first shown.
func _ensure_relay_panel():
	var page: Control = category_pages.get("Network")
	if page == null or page.has_meta("relay_panel") or not NetworkHandler.has_method("get_relay_preferences"):
		return
	var panel = load("res://scripts/multiplayer/federation/relay_preferences_panel.gd").new()
	page.add_child(panel)
	page.set_meta("relay_panel", panel)
	panel.configure(NetworkHandler.get_relay_preferences())

func select_category(category: String):
	if not category_pages.has(category):
		return
	_cancel_binding()
	selected_category = category
	_build_rows(category)
	if category == "Network":
		_ensure_relay_panel()
	if searching:
		search.text = ""
		_search_changed("")
	for name in category_pages:
		category_pages[name].visible = name == category
		category_buttons[name].set_pressed_no_signal(name == category)
	$Layout/Content/ScrollContainer.scroll_vertical = 0

const SWATCH_SETTINGS = ["interface.theme_preset", "interface.accent"]

func _swatch_colors(id: String) -> Dictionary:
	var palette = load("res://scripts/GUI/theme/palette.gd").new()
	var preset = str(SaveData.store.get_value("interface.theme_preset"))
	var accent = str(SaveData.store.get_value("interface.accent"))
	var highlight = str(SaveData.store.get_value("interface.hover_color"))
	var result := {}
	for key in SaveData.registry.get_definition(id).options:
		if id == "interface.theme_preset":
			var tokens = palette.tokens(key, accent, highlight)
			result[key] = [tokens.background, tokens.surface_raised, tokens.accent, tokens.text]
		else:
			result[key] = [palette.tokens(preset, key, highlight).accent]
	return result

func _create_control(definition: Dictionary) -> Control:
	var id: String = definition.id
	if id in SWATCH_SETTINGS and ResourceLoader.exists("res://scripts/GUI/theme/swatch_picker.gd"):
		var picker = load("res://scripts/GUI/theme/swatch_picker.gd").new()
		picker.set_options(definition.options, _swatch_colors(id))
		picker.value_selected.connect(_commit.bind(id))
		return picker
	match definition.type:
		"boolean":
			var control = CheckButton.new()
			control.toggled.connect(_commit.bind(id))
			return control
		"number":
			var control = SpinBox.new()
			control.min_value = definition.min
			control.max_value = definition.max
			control.step = definition.get("step", 1)
			control.suffix = definition.get("unit", "")
			control.value_changed.connect(_commit.bind(id))
			return control
		"text":
			var control = LineEdit.new()
			control.max_length = definition.get("max_length", 4096)
			control.text_submitted.connect(_commit.bind(id))
			control.focus_exited.connect(func(): _commit(control.text, id))
			return control
		"enum":
			var control = OptionButton.new()
			for value in definition.options:
				control.add_item(str(definition.options[value]))
				control.set_item_metadata(control.item_count - 1, value)
			control.item_selected.connect(func(index): _commit(control.get_item_metadata(index), id))
			return control
		"key_binding":
			var control = Button.new()
			control.pressed.connect(_begin_binding.bind(id))
			return control
	var unsupported = Label.new()
	unsupported.text = "Unsupported setting type"
	return unsupported

func _commit(value: Variant, id: String):
	if not SaveData.store.set_value(id, value):
		_set_error(id, "Invalid value; change was not applied.")
		_show_error(_errors[id].text)
	else:
		_set_error(id, "")

func _reset_value(id: String):
	SaveData.store.reset_value(id)
	# Invalid uncommitted text may differ from the store even when its default
	# already matches. Refresh explicitly instead of relying on a change signal.
	_update_value(id, SaveData.store.get_value(id))

func _reset_category(category: String):
	for definition in SaveData.registry.get_definitions():
		if definition.category == category:
			_reset_value(definition.id)

func _update_value(id: String, value: Variant):
	if not _controls.has(id):
		return
	var control: Control = _controls[id]
	if id in ["interface.theme_preset", "interface.hover_color"] and _controls.has("interface.accent") \
		and _controls["interface.accent"].has_method("set_options"):
		_controls["interface.accent"].set_options(SaveData.registry.get_definition("interface.accent").options, _swatch_colors("interface.accent"))
	if control.has_method("swatch_buttons"):
		control.value = str(value)
	elif control is CheckButton:
		control.set_pressed_no_signal(value)
	elif control is SpinBox:
		control.set_value_no_signal(value)
	elif control is LineEdit:
		control.text = str(value)
	elif control is OptionButton:
		for index in control.item_count:
			if control.get_item_metadata(index) == value:
				control.select(index)
	elif control is Button:
		control.text = OS.get_keycode_string(value)
	_set_error(id, "")
	if _resets.has(id):
		_resets[id].visible = value != SaveData.registry.get_definition(id).get("default")

func _begin_binding(id: String):
	if not _controls.has(id):
		_complete_rows()
	_cancel_binding()
	binding_id = id
	SaveData.voice.input_blocked = true
	_controls[id].text = "Press a key (Esc cancels)"

func _input(event: InputEvent):
	if binding_id.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		_cancel_binding()
		return
	var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var candidate = InputEventKey.new()
	candidate.physical_keycode = code
	for action in InputMap.get_actions():
		if action != binding_id.trim_prefix("input.") and InputMap.event_is_action(candidate, action):
			_set_error(binding_id, "Key already used by " + action + ". Choose another key or Escape.")
			return
	var definition = SaveData.registry.get_definition(binding_id)
	if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] and code not in definition.get("allowed_modifier_keys", []):
		_set_error(binding_id, "Choose a non-modifier key.")
		return
	_commit(code, binding_id)
	_cancel_binding()

func _cancel_binding():
	if not binding_id.is_empty():
		var id = binding_id
		binding_id = ""
		_update_value(id, SaveData.store.get_value(id))
		SaveData.voice.input_blocked = false

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel_binding()

func _show_error(message: String):
	status.text = message
	preload("res://scripts/GUI/error_popup.gd").show_error(self, message)

func _on_saved():
	status.text = ""

func _exit_tree():
	_cancel_binding()
	SaveData.registry.definitions_changed.disconnect(_render)
	SaveData.store.setting_changed.disconnect(_update_value)
	SaveData.store.persistence_error.disconnect(_show_error)
	SaveData.store.saved.disconnect(_on_saved)
