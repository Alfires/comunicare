@tool
extends EditorPlugin
var dock: VBoxContainer
var document: Dictionary
var text: TextEdit
var status: Label
var picker: EditorFileDialog
var operation := ""
var entity_list: OptionButton
var entity_name: LineEdit
var position_fields: Array[SpinBox] = []
var size_fields: Array[SpinBox] = []
var selection := "spawn"
var history: Array[Dictionary] = []
var future: Array[Dictionary] = []
var controls: VBoxContainer

func _enter_tree():
	dock = VBoxContainer.new()
	dock.name = "World Tools"
	dock.custom_minimum_size.x = 280
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(scroll)
	controls = VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(controls)
	for pair in [["New world", _new_world], ["Open project…", func(): _choose("open")], ["Save project…", func(): _choose("save")], ["Validate", _validate], ["Add pickup", _add_pickup], ["Add interactable", _add_interactable], ["Add scenery", func(): _add_entity("scenery")], ["Add hide-on-use behavior", _bind_hide], ["Analyze optimization", _analyze], ["Export .cworld…", func(): _choose("export")]]:
		var button = Button.new()
		button.text = pair[0]
		button.pressed.connect(pair[1])
		controls.add_child(button)
	var help = Label.new()
	help.text = "Select an entity; edit and Apply fields.\nBehaviors target the selected entity.\nPC/VR launch and model import: pending."
	controls.add_child(help)
	entity_list = OptionButton.new()
	entity_list.item_selected.connect(func(index): selection = str(entity_list.get_item_metadata(index)); _populate_fields())
	controls.add_child(entity_list)
	entity_name = LineEdit.new()
	entity_name.placeholder_text = "Entity name"
	controls.add_child(entity_name)
	for kind in ["Position", "Box size"]:
		var row = HBoxContainer.new()
		controls.add_child(row)
		var label = Label.new()
		label.text = kind
		row.add_child(label)
		for axis in ["X", "Y", "Z"]:
			var field = SpinBox.new()
			field.prefix = axis
			field.step = 0.1
			field.min_value = -10000 if kind == "Position" else 0.01
			field.max_value = 10000 if kind == "Position" else 100
			row.add_child(field)
			if kind == "Position": position_fields.append(field)
			else: size_fields.append(field)
	for pair in [["Apply entity fields", _apply_fields], ["Duplicate selected", _duplicate], ["Delete selected (referenced entities are protected)", _delete], ["Undo tool action", _undo], ["Redo tool action", _redo]]:
		var button = Button.new()
		button.text = pair[0]
		button.pressed.connect(pair[1])
		controls.add_child(button)
	text = TextEdit.new()
	text.custom_minimum_size = Vector2(280, 260)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(text)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(status)
	picker = EditorFileDialog.new()
	picker.access = EditorFileDialog.ACCESS_FILESYSTEM
	picker.file_selected.connect(_selected)
	dock.add_child(picker)
	_new_world()

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()

func _new_world():
	history.clear()
	future.clear()
	document = {"schema": 1, "world_id": Crypto.new().generate_random_bytes(16).hex_encode(), "title": "New world", "entities": [{"id": "spawn", "name": "Spawn", "type": "spawn", "position": [0, 1, 0]}, {"id": "floor", "name": "Floor", "type": "scenery", "position": [0, -0.1, 0], "collider": {"type": "box", "size": [20, 0.2, 20]}}], "assets": [], "behaviors": [], "capabilities": []}
	_refresh()

func _refresh():
	text.text = JSON.stringify(document, "\t")
	entity_list.clear()
	for entity in document.entities:
		entity_list.add_item(entity.name + " · " + entity.type)
		var index = entity_list.item_count - 1
		entity_list.set_item_metadata(index, entity.id)
		if entity.id == selection: entity_list.select(index)
	if not document.entities.any(func(entity): return entity.id == selection): selection = document.entities[0].id
	_populate_fields()

func _populate_fields():
	for entity in document.entities:
		if entity.id != selection: continue
		entity_name.text = entity.name
		for axis in 3:
			position_fields[axis].value = entity.position[axis]
			size_fields[axis].value = entity.get("collider", {}).get("size", [1, 1, 1])[axis]
			size_fields[axis].editable = entity.type != "spawn"

func _commit(result: Dictionary):
	if not result.ok:
		status.text = result.get("error", "Action rejected")
		return
	history.append(document.duplicate(true))
	if history.size() > 32: history.pop_front()
	future.clear()
	document = result.document
	_refresh()
	status.text = "Changed draft. Save project to keep changes."

func _apply_fields():
	if not _read(): return
	_commit(preload("res://addons/comunicare_world_tools/entity_tools.gd").new().update_entity(document, selection, entity_name.text,
		[position_fields[0].value, position_fields[1].value, position_fields[2].value], [size_fields[0].value, size_fields[1].value, size_fields[2].value]))

func _duplicate():
	if not _read(): return
	var result = preload("res://addons/comunicare_world_tools/interaction_tools.gd").new().duplicate_entity(document, selection)
	if result.ok: selection = result.entity_id
	_commit(result)

func _delete():
	if _read(): _commit(preload("res://addons/comunicare_world_tools/entity_tools.gd").new().delete_entity(document, selection))

func _undo():
	if history.is_empty() or not _read(): return
	future.append(document.duplicate(true))
	document = history.pop_back()
	_refresh()

func _redo():
	if future.is_empty() or not _read(): return
	history.append(document.duplicate(true))
	document = future.pop_back()
	_refresh()

func _read() -> bool:
	var parsed = preload("res://scripts/worlds/world_text_parser.gd").new().parse_json(text.text)
	if not parsed.ok:
		status.text = parsed.error
		return false
	var checked = preload("res://addons/comunicare_world_tools/authoring_document.gd").new().validate(parsed.value)
	if not checked.ok:
		status.text = checked.error
		return false
	document = parsed.value
	return true

func _validate():
	if _read(): status.text = "Valid primitive world. Export uses the production validator."

func _choose(action: String):
	operation = action
	picker.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE if action == "open" else EditorFileDialog.FILE_MODE_SAVE_FILE
	picker.filters = PackedStringArray(["*.cworld ; Playable world"]) if action == "export" else PackedStringArray(["*.json ; Authoring project"])
	picker.popup_centered_ratio(0.7)

func _selected(path: String):
	var service = preload("res://addons/comunicare_world_tools/authoring_document.gd").new()
	var result: Dictionary
	if operation == "open":
		result = service.load_project(path)
		if result.ok:
			history.clear()
			future.clear()
			document = result.document
			_refresh()
	else:
		if not _read(): return
		result = preload("res://addons/comunicare_world_tools/world_exporter.gd").new().export_package(document, path) if operation == "export" else service.save_project(document, path)
	status.text = "Completed: " + path if result.ok else result.error

func _add_pickup(): _add_entity("pickup")
func _add_interactable(): _add_entity("interactable")
func _add_entity(type: String):
	if not _read(): return
	var copy = document.duplicate(true)
	selection = Crypto.new().generate_random_bytes(16).hex_encode()
	copy.entities.append({"id": selection, "name": type.capitalize(), "type": type, "position": [0, 1, -2], "collider": {"type": "box", "size": [1, 1, 1]}})
	var checked = preload("res://addons/comunicare_world_tools/authoring_document.gd").new().validate(copy)
	if checked.ok: checked.document = copy
	_commit(checked)

func _bind_hide():
	if not _read(): return
	var id: String = selection
	var result = preload("res://addons/comunicare_world_tools/interaction_tools.gd").new().bind_behavior(document, id, "use", [{"op": "command", "capability": "entity.visual", "entity": id, "property": "visible", "value": false}])
	_commit(result)
	status.text = "Bound hide-on-use to " + id if result.ok else result.error

func _analyze():
	if not _read(): return
	status.text = JSON.stringify(preload("res://addons/comunicare_world_tools/world_optimizer.gd").new().analyze(document))
