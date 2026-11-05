@tool
extends EditorPlugin
var dock: VBoxContainer
var document: Dictionary
var text: TextEdit
var status: Label
var picker: EditorFileDialog
var operation := ""

func _enter_tree():
	dock = VBoxContainer.new()
	dock.name = "World Tools"
	dock.custom_minimum_size.x = 280
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	for pair in [["New world", _new_world], ["Open project…", func(): _choose("open")], ["Save project…", func(): _choose("save")], ["Validate", _validate], ["Add pickup", _add_pickup], ["Add interactable", _add_interactable], ["Add hide-on-use behavior", _bind_hide], ["Analyze optimization", _analyze], ["Export .cworld…", func(): _choose("export")]]:
		var button = Button.new()
		button.text = pair[0]
		button.pressed.connect(pair[1])
		dock.add_child(button)
	var help = Label.new()
	help.text = "Edit entity positions/sizes below.\nBehaviors target the last entity.\nPC/VR launch and model import: pending."
	dock.add_child(help)
	text = TextEdit.new()
	text.custom_minimum_size = Vector2(280, 260)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(text)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status)
	picker = EditorFileDialog.new()
	picker.access = EditorFileDialog.ACCESS_FILESYSTEM
	picker.file_selected.connect(_selected)
	dock.add_child(picker)
	_new_world()

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()

func _new_world():
	document = {"schema": 1, "world_id": Crypto.new().generate_random_bytes(16).hex_encode(), "title": "New world", "entities": [{"id": "spawn", "name": "Spawn", "type": "spawn", "position": [0, 1, 0]}, {"id": "floor", "name": "Floor", "type": "scenery", "position": [0, -0.1, 0], "collider": {"type": "box", "size": [20, 0.2, 20]}}], "assets": [], "behaviors": [], "capabilities": []}
	_refresh()

func _refresh(): text.text = JSON.stringify(document, "\t")

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
	document.entities.append({"id": Crypto.new().generate_random_bytes(16).hex_encode(), "name": type.capitalize(), "type": type, "position": [0, 1, -2], "collider": {"type": "box", "size": [1, 1, 1]}})
	_refresh()

func _bind_hide():
	if not _read(): return
	var id: String = document.entities.back().id
	var result = preload("res://addons/comunicare_world_tools/interaction_tools.gd").new().bind_behavior(document, id, "use", [{"op": "command", "capability": "entity.visual", "entity": id, "property": "visible", "value": false}])
	if result.ok:
		document = result.document
		_refresh()
	status.text = "Bound hide-on-use to " + id if result.ok else result.error

func _analyze():
	if not _read(): return
	status.text = JSON.stringify(preload("res://addons/comunicare_world_tools/world_optimizer.gd").new().analyze(document))
