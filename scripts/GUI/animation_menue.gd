extends Control
## Source-only owner configuration, deliberately not a playback console.

signal closed
var configuration: Node
var draft_model: Dictionary = {}
var draft_sources: Array = []
var rows: VBoxContainer
var status: Label
var model_label: Label
var url: LineEdit
var model_mode: CheckButton
var permission: CheckButton
var picker: FileDialog
var busy := false
var generation := 0
var profile_service
var profile_owner := ""
var apply_button: Button

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	configuration = DataLoader.get_avatar_configuration()
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("profile") != null:
		profile_service = save.profile
		profile_owner = profile_service.get_local_fingerprint()
		profile_service.profile_changed.connect(_owner_changed)
	set_meta("blocks_global_shortcuts", true)
	draft_model = configuration.model.duplicate(true)
	draft_sources = configuration.sources.duplicate(true)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var scroll = ScrollContainer.new()
	panel.add_child(scroll)
	var layout = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	scroll.add_child(layout)
	var title = Label.new()
	title.text = "My avatar & animations"
	layout.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Basic animations apply automatically. Other compatible clips appear in the B emote wheel after Apply."
	layout.add_child(status)
	model_label = Label.new()
	model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(model_label)
	var advanced_toggle = CheckButton.new()
	advanced_toggle.text = "Import from file or URL (advanced)"
	layout.add_child(advanced_toggle)
	var imports = VBoxContainer.new()
	imports.visible = false
	layout.add_child(imports)
	advanced_toggle.toggled.connect(func(enabled): imports.visible = enabled)
	model_mode = CheckButton.new()
	model_mode.text = "This file is an avatar model (off = animation)"
	imports.add_child(model_mode)
	permission = CheckButton.new()
	permission.text = "I have permission to redistribute these selected assets to instance participants"
	permission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	imports.add_child(permission)
	url = LineEdit.new()
	url.max_length = 4096
	url.placeholder_text = "HTTPS URL or local file path (headset file-picker fallback)"
	imports.add_child(url)
	_button(imports, "Validate file / URL", func(): add_source(url.text.strip_edges(), model_mode.button_pressed))
	picker = FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.vrm,*.vrma,*.glb ; Avatar / humanoid animation"])
	picker.files_selected.connect(func(paths):
		for path in paths:
			await add_source(path, model_mode.button_pressed))
	add_child(picker)
	_button(imports, "Choose file(s)…", func(): picker.popup_centered_ratio(0.8))
	_button(layout, "Use profile avatar / defaults", func():
		draft_model = {}
		_render())
	rows = VBoxContainer.new()
	layout.add_child(rows)
	_button(layout, "Organize emotes / wheel shortcuts", func():
		var editor = preload("res://scripts/GUI/emote_layout_editor.gd").new()
		add_child(editor)
		editor.configure(configuration))
	apply_button = _button(layout, "Apply avatar & animations", apply)
	_button(layout, "Cancel / Back", func(): closed.emit(); queue_free())
	_render()

func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _render():
	model_label.text = "Model: " + str(draft_model.get("name", "Current profile avatar"))
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for index in draft_sources.size():
		var row = HBoxContainer.new()
		var label = Label.new()
		label.text = str(draft_sources[index].name)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 100
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_button(row, "Remove", func(): draft_sources.remove_at(index); _render())
		if index > 0:
			_button(row, "Earlier", func():
				var item = draft_sources.pop_at(index)
				draft_sources.insert(index - 1, item)
				_render())
		rows.add_child(row)

func add_source(source: String, is_model: bool):
	if busy or source.is_empty(): return
	if not is_model and draft_sources.size() >= 32:
		status.text = "At most 32 external sources can be applied."
		return
	busy = true
	apply_button.disabled = true
	var ticket = generation
	status.text = "Validating source…"
	var result = await configuration.import_source(source, is_model, permission.button_pressed)
	if ticket != generation or not is_inside_tree(): return
	busy = false
	apply_button.disabled = false
	if result.is_empty():
		status.text = configuration.last_error
		return
	if is_model: draft_model = result
	else:
		var duplicate := false
		for entry in draft_sources:
			if entry.hash == result.hash: duplicate = true
		if not duplicate: draft_sources.append(result)
	permission.set_pressed_no_signal(false)
	status.text = "Ready to add. Press Apply; new emotes will appear in the Imported emotes wheel group. Cancel leaves your setup unchanged."
	_render()

func apply():
	if busy: return
	if profile_service != null and (profile_service.get_local_fingerprint() != profile_owner or not profile_service.can_edit(profile_owner)):
		status.text = "Avatar owner changed; close and reopen this editor."
		return
	busy = true
	apply_button.disabled = true
	var saved = await configuration.apply(draft_model, draft_sources)
	if not is_inside_tree(): return
	busy = false
	apply_button.disabled = false
	status.text = "Applied. Basic movement animations are automatic; press B or Home → Emotes for other actions." if saved else configuration.last_error
	if saved and not configuration.emotes.is_empty():
		var organizer = preload("res://scripts/GUI/emote_layout_editor.gd").new()
		add_child(organizer)
		organizer.configure(configuration)

func _exit_tree():
	generation += 1
	if profile_service != null and profile_service.profile_changed.is_connected(_owner_changed):
		profile_service.profile_changed.disconnect(_owner_changed)

func _owner_changed(_fingerprint: String):
	if profile_service.get_local_fingerprint() != profile_owner:
		generation += 1
		queue_free()
