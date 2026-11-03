extends SceneTree

var passed := 0
var failed := 0
var skipped := 0
const REGISTRY = "res://scripts/settings/settings_registry.gd"
const STORE = "res://scripts/settings/settings_store.gd"
const VOICE = "res://scripts/player/voice_controller.gd"

func _initialize():
	call_deferred("run")

func check(ok: bool, title: String):
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func require_methods(object: Object, methods: Array, title: String) -> bool:
	var missing: Array = []
	for method in methods:
		if not object.has_method(method):
			missing.append(method)
	check(missing.is_empty(), title + ("; missing: " + str(missing) if not missing.is_empty() else ""))
	return missing.is_empty()

func optional_script(path: String, title: String):
	var exists = ResourceLoader.exists(path)
	check(exists, title)
	return load(path).new() if exists else null

func dispose(object):
	if object is Node:
		object.free()

func test_registry_store():
	var registry = optional_script(REGISTRY, "definition-driven settings registry exists")
	var store = optional_script(STORE, "typed persistent settings store exists")
	if registry == null or store == null:
		skipped += 1
		dispose(registry)
		dispose(store)
		return
	var registry_ok = require_methods(registry, ["register_setting", "unregister_setting", "get_definitions"], "registry extension API")
	var store_ok = require_methods(store, ["configure", "get_value", "set_value", "reset_value", "reset_category", "save_settings", "load_settings"], "store contract API")
	if not registry_ok or not store_ok:
		skipped += 1
		dispose(registry)
		dispose(store)
		return
	var definition = {"id": "test.volume", "category": "Test", "label": "Volume",
		"type": "number", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.1, "persist": true}
	check(registry.register_setting(definition), "register a new ordinary setting in one definition")
	check(not registry.register_setting(definition), "duplicate setting IDs rejected")
	var invalid = definition.duplicate(true)
	invalid.id = "test.invalid"
	invalid.default = "not a number"
	check(not registry.register_setting(invalid), "wrong default type rejected")
	invalid.default = 0.5
	invalid.min = 2.0
	check(not registry.register_setting(invalid), "inverted numeric bounds rejected")
	var changes: Array = []
	check(store.has_signal("setting_changed"), "store publishes setting_changed")
	if store.has_signal("setting_changed"):
		store.connect("setting_changed", func(id, value): changes.append([id, value]))
	store.configure(registry, "res://settings-test.cfg")
	check(store.get_value("test.volume") == 0.5, "registered defaults available before loading a file")
	check(store.set_value("test.volume", 0.8) and store.get_value("test.volume") == 0.8, "valid typed setting change applies")
	var count = changes.size()
	store.set_value("test.volume", 0.8)
	check(changes.size() == count, "unchanged values do not emit duplicate changes")
	check(not store.set_value("test.volume", "bad") and store.get_value("test.volume") == 0.8, "invalid type does not mutate setting")
	check(not store.set_value("test.volume", 9.0), "out-of-range value rejected")
	check(store.save_settings(), "registered setting persists without a hardcoded save key")
	store.set_value("test.volume", 0.2)
	check(store.load_settings() and store.get_value("test.volume") == 0.8, "registered setting round-trips through ConfigFile")
	store.reset_value("test.volume")
	check(store.get_value("test.volume") == 0.5, "individual reset restores registered default")
	store.set_value("test.volume", 0.9)
	store.reset_category("Test")
	check(store.get_value("test.volume") == 0.5, "category reset restores defaults")
	registry.unregister_setting("test.volume")
	var remains := false
	for value in registry.get_definitions():
		if value.id == "test.volume":
			remains = true
	check(not remains, "removing a definition removes it from exposed settings")
	dispose(store)
	dispose(registry)

func test_store_recovery_and_types():
	var registry = load(REGISTRY).new()
	for definition in [
		{"id": "test.toggle", "type": "boolean", "default": true},
		{"id": "test.text", "type": "text", "default": "hello", "max_length": 10},
		{"id": "test.enum", "type": "enum", "default": "a", "options": {"a": "A", "b": "B"}},
		{"id": "test.key", "type": "key_binding", "default": KEY_V},
	]:
		definition.category = "Test"
		definition.label = definition.id
		registry.register_setting(definition)
	var store = load(STORE).new()
	store.configure(registry, "res://typed-test.cfg")
	check(store.load_settings() and store.get_value("test.toggle"), "missing config uses defaults")
	store.set_value("test.toggle", false)
	store.set_value("test.text", "saved")
	store.set_value("test.enum", "b")
	store.set_value("test.key", KEY_M)
	store.save_settings()
	var second = load(STORE).new()
	second.configure(registry, store.config_path)
	second.load_settings()
	check(second.get_value("test.toggle") == false and second.get_value("test.text") == "saved"
		and second.get_value("test.enum") == "b" and second.get_value("test.key") == KEY_M,
		"boolean/text/enum/key values all survive restart")
	check(not second.set_value("test.enum", "unknown") and not second.set_value("test.key", -1), "invalid enum and key values rejected")
	var file = FileAccess.open("res://corrupt.cfg", FileAccess.WRITE)
	file.store_string("[broken\nnot config")
	file.close()
	second.config_path = "res://corrupt.cfg"
	# ConfigFile logs a native error for intentionally malformed input. Suppress
	# only that expected log; assertions still verify recovery and file contents.
	Engine.print_error_messages = false
	var corrupt_loaded: bool = second.load_settings()
	Engine.print_error_messages = true
	check(not corrupt_loaded and not second.save_settings()
		and FileAccess.get_file_as_string("res://corrupt.cfg") == "[broken\nnot config",
		"corrupt config is reported and never overwritten")
	second.configure(registry, "res://missing-directory/settings.cfg")
	check(not second.save_settings() and not second.last_error.is_empty(), "write failures are reported to callers")
	store.free()
	second.free()


func run():
	test_registry_store()
	test_store_recovery_and_types()
	print("Settings core: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
