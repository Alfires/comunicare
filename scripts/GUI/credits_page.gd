extends VBoxContainer
## Locally bundled notices only; opening a website is a separate explicit action.
signal source_requested(url: String)
const TextBlock = preload("res://scripts/GUI/text_block.gd")
var entries: Array = []
var error_text := ""

var _loaded := false

## Builds the notices the first time the page is shown (Settings creates it hidden).
func _ready():
	visibility_changed.connect(func(): if is_visible_in_tree() and not _loaded: _load_bundled())
	if is_visible_in_tree():
		_load_bundled()

func _load_bundled():
	_loaded = true
	var records: Array = []
	for path in ["res://assets/credits.json", "res://assets/welcome_island/manifest.json"]:
		if not FileAccess.file_exists(path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("assets") is Array:
			records.append_array(data.assets)
	load_entries(records)

func load_entries(records: Array):
	_loaded = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	entries.clear()
	error_text = ""
	_add_text("Credits", true)
	_add_text("Bundled third-party assets. Full license text is available here without internet.")
	var ids := {}
	for record in records:
		if not record is Dictionary or not _valid_record(record) or ids.has(record.get("id", "")):
			error_text = "Some bundled credit records or license files are missing or invalid."
			continue
		var path: String = record.license_file
		if not path.begins_with("res://"): path = "res://" + path
		if not FileAccess.file_exists(path):
			error_text = "Some bundled credit records or license files are missing or invalid."
			continue
		var terms = FileAccess.get_file_as_string(path)
		if terms.is_empty():
			error_text = "Some bundled credit records or license files are missing or invalid."
			continue
		var entry = record.duplicate(true)
		entry.terms = terms
		ids[entry.id] = true
		entries.append(entry)
		_add_text(entry.title, true)
		_add_text("%s\n%s\n%s" % [entry.author, entry.license, entry.get("attribution", "")])
		_add_text(entry.modifications)
		_add_text(entry.source)
		var source = Button.new()
		source.text = "Open source website"
		source.custom_minimum_size.y = 44
		source.pressed.connect(func(): source_requested.emit(entry.source))
		add_child(source)
		var toggle = Button.new()
		toggle.text = "Show full license text"
		toggle.custom_minimum_size.y = 44
		add_child(toggle)
		# Full terms are shaped only when expanded (see text_block.gd).
		var license_text = TextBlock.new()
		license_text.visible = false
		license_text.text = terms
		add_child(license_text)
		toggle.pressed.connect(func():
			license_text.visible = not license_text.visible
			toggle.text = "Hide full license text" if license_text.visible else "Show full license text")
	if not error_text.is_empty(): _add_text(error_text)
	if records.is_empty(): _add_text("No bundled asset notices available.")

func _valid_record(record: Dictionary) -> bool:
	for key in ["id", "title", "author", "source", "license", "license_file", "modifications"]:
		if not record.get(key) is String or record[key].strip_edges().is_empty(): return false
	var path: String = record.license_file
	if ".." in path or "\\" in path or (":" in path and not path.begins_with("res://")): return false
	if not record.source.begins_with("https://"): return false
	return record.license in ["CC0-1.0", "CC-BY-4.0", "OFL-1.1"] and (record.license != "CC-BY-4.0" or not str(record.get("attribution", "")).is_empty())

func _add_text(value: String, heading: bool = false) -> Label:
	var label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = "HeaderLabel" if heading else &""
	add_child(label)
	return label
