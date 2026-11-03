extends Node

signal setting_changed(id: String, value: Variant)
signal persistence_error(message: String)
signal saved
var registry
var config_path := "user://user.cfg"
var values: Dictionary = {}
var dirty := false
var last_error := ""
var write_blocked := false
var save_at := 0

func configure(definitions, path: String):
	if registry != null and registry.definitions_changed.is_connected(_sync_definitions):
		registry.definitions_changed.disconnect(_sync_definitions)
	registry = definitions
	config_path = path
	values.clear()
	registry.definitions_changed.connect(_sync_definitions)
	_sync_definitions()

func _sync_definitions():
	for id in values.keys():
		if not registry.definitions.has(id):
			values.erase(id)
	for definition in registry.get_definitions():
		if not values.has(definition.id):
			values[definition.id] = definition.default

func get_value(id: String) -> Variant:
	return values.get(id)

func set_value(id: String, value: Variant) -> bool:
	var definition: Dictionary = registry.get_definition(id)
	if definition.is_empty() or not registry.validate(definition, value):
		return false
	if values.get(id) == value:
		return true
	values[id] = value
	dirty = true
	save_at = Time.get_ticks_msec() + 400
	setting_changed.emit(id, value)
	return true

func reset_value(id: String):
	var definition: Dictionary = registry.get_definition(id)
	if not definition.is_empty():
		set_value(id, definition.default)

func reset_category(category: String):
	for definition in registry.get_definitions():
		if definition.category == category:
			reset_value(definition.id)

func _failure(message: String) -> bool:
	last_error = message
	persistence_error.emit(message)
	return false

func load_settings() -> bool:
	var config = ConfigFile.new()
	var error = config.load(config_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		write_blocked = true
		return _failure("Cannot read settings; existing file preserved: " + error_string(error))
	var version = config.get_value("meta", "version", 0)
	if not version is int or version > 1:
		write_blocked = true
		return _failure("Unsupported settings version; existing file preserved")
	write_blocked = false
	last_error = ""
	for definition in registry.get_definitions():
		var value = config.get_value("settings", definition.id, definition.default)
		if version == 0 and definition.has("legacy_key"):
			value = config.get_value("UserSettings", definition.legacy_key, value)
		if not registry.validate(definition, value):
			value = definition.default
		if values.get(definition.id) != value:
			values[definition.id] = value
			setting_changed.emit(definition.id, value)
	dirty = false
	return true

func save_settings() -> bool:
	if write_blocked:
		return _failure("Settings file is unreadable; repair or back it up before saving")
	var config = ConfigFile.new()
	var error = config.load(config_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return _failure("Existing settings file cannot be read; not overwritten")
	# Preserve unrelated legacy sections, but remove settings no longer registered.
	if config.has_section("settings"):
		config.erase_section("settings")
	config.set_value("meta", "version", 1)
	for definition in registry.get_definitions():
		if definition.get("persist", true):
			config.set_value("settings", definition.id, values[definition.id])
	var temporary = config_path + ".tmp"
	error = config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, config_path)
	if error != OK:
		return _failure("Settings not saved: " + error_string(error))
	dirty = false
	last_error = ""
	saved.emit()
	return true

func _process(_delta):
	if dirty and not write_blocked and Time.get_ticks_msec() >= save_at:
		if not save_settings():
			# Retry on the next user edit, not every frame.
			save_at = 9223372036854775807

func _exit_tree():
	if dirty and not write_blocked:
		save_settings()

func _notification(what):
	if what == NOTIFICATION_PREDELETE and registry != null \
		and registry.definitions_changed.is_connected(_sync_definitions):
		registry.definitions_changed.disconnect(_sync_definitions)
