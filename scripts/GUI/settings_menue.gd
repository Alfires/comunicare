extends Control

@onready var rows: VBoxContainer = $Layout/Content/ScrollContainer/Rows
@onready var categories: VBoxContainer = $Layout/Content/CategoryScroll/Categories
@onready var status: Label = $Layout/Status
var controls: Dictionary = {}
var errors: Dictionary = {}
var binding_id := ""
var selected_category := ""
var category_pages: Dictionary = {}
var category_buttons: Dictionary = {}

func _ready():
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
		rows.remove_child(child)
		child.queue_free()
	controls.clear()
	errors.clear()
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
			page.add_theme_constant_override("separation", 16)
			rows.add_child(page)
			category_pages[category] = page
			var tab = Button.new()
			tab.text = category
			tab.custom_minimum_size = Vector2(140, 44)
			tab.toggle_mode = true
			tab.button_group = group
			tab.pressed.connect(select_category.bind(category))
			categories.add_child(tab)
			category_buttons[category] = tab
			var header = HBoxContainer.new()
			var title = Label.new()
			title.text = category
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header.add_child(title)
			var reset = Button.new()
			reset.text = "Reset category"
			reset.pressed.connect(_reset_category.bind(category))
			header.add_child(reset)
			page.add_child(header)
		var row = VBoxContainer.new()
		row.set_meta("setting_id", definition.id)
		var label = Label.new()
		label.text = definition.label
		row.add_child(label)
		if not definition.get("description", "").is_empty():
			var description = Label.new()
			description.text = definition.description
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(description)
		var line = HBoxContainer.new()
		var control = _create_control(definition)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.y = 40
		line.add_child(control)
		controls[definition.id] = control
		var reset = Button.new()
		reset.text = "Reset"
		reset.pressed.connect(_reset_value.bind(definition.id))
		line.add_child(reset)
		row.add_child(line)
		var error = Label.new()
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(error)
		errors[definition.id] = error
		page.add_child(row)
		_update_value(definition.id, SaveData.store.get_value(definition.id))
	if category_pages.has("Assets") and DataLoader.has_method("get_asset_cache"):
		_add_cache_actions(category_pages.Assets)
	if category_pages.has("Network") and NetworkHandler.has_method("get_relay_preferences"):
		var panel = load("res://scripts/multiplayer/federation/relay_preferences_panel.gd").new()
		category_pages.Network.add_child(panel)
		panel.configure(NetworkHandler.get_relay_preferences())
	if category_pages.has("Controls"):
		var local_notice = Label.new()
		local_notice.text = "Home objects are local to this client; changes are not synchronized with other players."
		local_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		category_pages.Controls.add_child(local_notice)
	var credits = preload("res://scripts/GUI/credits_page.gd").new()
	credits.source_requested.connect(func(url): OS.shell_open(url))
	rows.add_child(credits)
	category_pages["Credits"] = credits
	var credits_tab = Button.new()
	credits_tab.text = "Credits"
	credits_tab.custom_minimum_size = Vector2(140, 44)
	credits_tab.toggle_mode = true
	credits_tab.button_group = group
	credits_tab.pressed.connect(select_category.bind("Credits"))
	categories.add_child(credits_tab)
	category_buttons["Credits"] = credits_tab
	if not category_pages.has(selected_category):
		selected_category = "" if category_pages.is_empty() else str(category_pages.keys()[0])
	select_category(selected_category)

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
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Remove unused cached downloads? Active assets and imported originals will be kept."
	clear.add_child(confirm)
	clear.pressed.connect(func(): confirm.popup_centered())
	confirm.confirmed.connect(func():
		cache.clear_unused()
		update.call())

func select_category(category: String):
	if not category_pages.has(category):
		return
	_cancel_binding()
	selected_category = category
	for name in category_pages:
		category_pages[name].visible = name == category
		category_buttons[name].set_pressed_no_signal(name == category)
	$Layout/Content/ScrollContainer.scroll_vertical = 0

func _create_control(definition: Dictionary) -> Control:
	var id: String = definition.id
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
		errors[id].text = "Invalid value; change was not applied."
		_show_error(errors[id].text)
	else:
		errors[id].text = ""

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
	if not controls.has(id):
		return
	var control: Control = controls[id]
	if control is CheckButton:
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
	if errors.has(id):
		errors[id].text = ""

func _begin_binding(id: String):
	_cancel_binding()
	binding_id = id
	SaveData.voice.input_blocked = true
	controls[id].text = "Press a key (Esc cancels)"

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
			errors[binding_id].text = "Key already used by " + action + ". Choose another key or Escape."
			return
	var definition = SaveData.registry.get_definition(binding_id)
	if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] and code not in definition.get("allowed_modifier_keys", []):
		errors[binding_id].text = "Choose a non-modifier key."
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
