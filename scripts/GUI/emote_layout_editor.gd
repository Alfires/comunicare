extends PanelContainer
## Local layout editing is separate from source selection and never plays clips.

var configuration
var group := "root"
var group_choice: OptionButton
var destination: OptionButton
var actions: OptionButton
var entries: ItemList
var name_input: LineEdit
var status: Label
var initial_owner := ""
var library_rows: VBoxContainer
var library_query := ""

func _process(_delta: float):
	if configuration != null and configuration.account_owner != initial_owner:
		queue_free()

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("blocks_global_shortcuts", true)
	var scroll = ScrollContainer.new()
	add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title = Label.new()
	title.text = "Organize emotes"
	box.add_child(title)
	var help = Label.new()
	help.text = "1. Choose a wheel group.  2. Find an emote below.  3. Add it.\nChanges save immediately. Removing a shortcut keeps the animation in your library."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	group_choice = OptionButton.new()
	group_choice.item_selected.connect(func(index): group = str(group_choice.get_item_metadata(index)); _render())
	box.add_child(group_choice)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Group name"
	name_input.max_length = 80
	box.add_child(name_input)
	_button(box, "Create subgroup", func():
		var id = configuration.layout.add_group(group, name_input.text)
		if not id.is_empty(): group = id
		_render())
	_button(box, "Rename group", func(): configuration.layout.rename_group(group, name_input.text); _render())
	_button(box, "Delete group…", _delete_group)
	entries = ItemList.new()
	entries.custom_minimum_size.y = 140
	entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries.item_activated.connect(func(index):
		var entry = configuration.layout.groups[group].entries[index]
		if entry.type == "group": group = entry.id; _render())
	box.add_child(entries)
	var search = LineEdit.new()
	search.placeholder_text = "Find an emote in your library…"
	search.text_changed.connect(filter_library)
	box.add_child(search)
	library_rows = VBoxContainer.new()
	box.add_child(library_rows)
	actions = OptionButton.new()
	actions.visible = false # Retained compatibility seam; direct add rows are primary.
	box.add_child(actions)
	_button(box, "Move selected up", func(): _move(-1))
	_button(box, "Move selected down", func(): _move(1))
	destination = OptionButton.new()
	box.add_child(destination)
	_button(box, "Move selected to group", func():
		var selected = entries.get_selected_items()
		if not selected.is_empty():
			var id = str(destination.get_item_metadata(destination.selected))
			configuration.layout.move_entry(group, selected[0], id, configuration.layout.groups[id].entries.size())
		_render())
	_button(box, "Remove selected shortcut", func():
		var selected = entries.get_selected_items()
		if not selected.is_empty(): configuration.layout.remove_entry(group, selected[0])
		_render())
	_button(box, "Reset wheel layout…", func():
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = "Reset local emote groups and shortcuts? Source assets are kept."
		add_child(dialog)
		dialog.confirmed.connect(func(): configuration.layout.commit(configuration.layout.defaults()); group = "root"; _render(); dialog.queue_free())
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	_button(box, "Done", queue_free)

func configure(service):
	configuration = service
	initial_owner = service.account_owner
	_render()

func _button(parent: Node, text: String, action: Callable):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _render():
	if configuration == null or not is_node_ready(): return
	var layout = configuration.layout
	if not layout.groups.has(group): group = "root"
	group_choice.clear()
	destination.clear()
	for id in layout.groups:
		group_choice.add_item(layout.groups[id].name)
		group_choice.set_item_metadata(group_choice.item_count - 1, id)
		destination.add_item(layout.groups[id].name)
		destination.set_item_metadata(destination.item_count - 1, id)
		if id == group: group_choice.select(group_choice.item_count - 1)
	entries.clear()
	for entry in layout.groups[group].entries:
		var unavailable = entry.type == "emote" and entry.id != "__cancel_emote__" and not configuration.emotes.has(entry.id)
		entries.add_item(("▸ " if entry.type == "group" else "") + entry.name + (" (unavailable)" if unavailable else ""))
	actions.clear()
	for id in configuration.emotes:
		actions.add_item(configuration.emotes[id].name)
		actions.set_item_metadata(actions.item_count - 1, id)
	actions.add_item("Return to movement")
	actions.set_item_metadata(actions.item_count - 1, "__cancel_emote__")
	status.text = layout.last_error
	_render_library()

func filter_library(query: String):
	library_query = query.left(200).to_lower()
	_render_library()

func _render_library():
	if configuration == null or library_rows == null: return
	for child in library_rows.get_children():
		library_rows.remove_child(child)
		child.queue_free()
	var ids = configuration.emotes.keys()
	ids.sort_custom(func(a, b): return configuration.emotes[a].name.naturalnocasecmp_to(configuration.emotes[b].name) < 0)
	for id in ids:
		var emote: Dictionary = configuration.emotes[id]
		if not library_query.is_empty() and not library_query in str(emote.name).to_lower(): continue
		var row = HBoxContainer.new()
		library_rows.add_child(row)
		var label = Label.new()
		label.text = str(emote.name)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var added = configuration.layout.groups[group].entries.any(func(entry): return entry.type == "emote" and entry.id == id)
		var button = _button(row, "Already in group" if added else "Add to this group", func():
			if configuration.layout.add_emote(group, id, str(emote.name)):
				_render()
			else: status.text = configuration.layout.last_error)
		button.disabled = added or not configuration.layout.writable

func _move(delta: int):
	var selected = entries.get_selected_items()
	if selected.is_empty(): return
	configuration.layout.move_entry(group, selected[0], group, selected[0] + delta)
	_render()

func _delete_group():
	if group == "root": return
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Delete this group and all shortcuts pointing to it? Source assets are not deleted."
	add_child(dialog)
	dialog.confirmed.connect(func(): configuration.layout.delete_group(group); group = "root"; _render(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
