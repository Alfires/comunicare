extends Control
## Discovery is read-only until explicit import into a separate source draft.
const Registry = preload("res://scripts/discovery/avatars/source_registry.gd")
const Service = preload("res://scripts/discovery/avatars/discovery_service.gd")
const ImportPolicy = preload("res://scripts/discovery/avatars/import_policy.gd")
var registry = Registry.new()
var state = {"tab": "home", "query": "", "category": "", "cursor": "", "type": "all", "format": "all", "sort": "provider"}
var content: VBoxContainer
var search_box: LineEdit
var status: Label
var results: VBoxContainer
var generation := 0
var services: Array = []
var cursors: Dictionary = {}
var source_filter: OptionButton
var account_owner := ""
var configuration_path := ""
var selected_record: Dictionary = {}
var preview: Control
var conversion_thread: Thread
var catalog_cache: Dictionary = {}
var seen_results: Dictionary = {}
var editor_open := false
var filter_controls: Dictionary = {}
var preferences_writable := true

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _ready():
	set_meta("blocks_global_shortcuts", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for value in [
		{"id": "osa", "kind": "builtin", "name": "100Avatars R1 · CC0", "adapter": "osa", "auth": "none", "base_url": Service.OSA + "avatars/100avatars-r1.json"},
		{"id": "vox", "kind": "builtin", "name": "Public CC0 VRMA manifest", "adapter": "vox", "auth": "none", "base_url": Service.VOX + "manifest.json"}]: registry.add_source(value)
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("profile") != null:
		account_owner = save.profile.get_local_fingerprint()
		configuration_path = "user://avatars/" + account_owner + ".discovery.json"
		if FileAccess.file_exists(configuration_path):
			var file = FileAccess.open(configuration_path, FileAccess.READ)
			preferences_writable = false
			if file != null and file.get_length() < 65536:
				var data = JSON.parse_string(file.get_as_text())
				if data is Array:
					preferences_writable = true
					for value in data:
						if not value is Dictionary or value.get("kind") != "custom" or not registry.add_source(value): preferences_writable = false
	var layout = HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 105
	layout.add_child(sidebar)
	_button(sidebar, "Home", _home)
	_button(sidebar, "Search", func(): state.tab = "search"; _search(false))
	_button(sidebar, "Sources", _sources)
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search avatars and animations…"
	search_box.max_length = 200
	search_box.text_submitted.connect(submit_home_search)
	content.add_child(search_box)
	_button(content, "Search", func(): submit_home_search(search_box.text))
	var filters = HFlowContainer.new()
	content.add_child(filters)
	for definition in [["type", ["all", "avatar", "animation"]], ["format", ["all", "vrm", "vrma", "glb"]], ["sort", ["provider", "title"]]]:
		var selector = OptionButton.new()
		for item in definition[1]: selector.add_item(item)
		selector.item_selected.connect(func(index): state[definition[0]] = definition[1][index]; _search(false))
		filter_controls[definition[0]] = selector
		filters.add_child(selector)
	source_filter = OptionButton.new()
	source_filter.item_selected.connect(func(_index): _search(false))
	filters.add_child(source_filter)
	_refresh_sources()
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	results = VBoxContainer.new()
	content.add_child(results)
	_home()

func _refresh_sources():
	source_filter.clear()
	source_filter.add_item("All providers")
	source_filter.set_item_metadata(0, "")
	for id in registry.sources:
		source_filter.add_item(registry.sources[id].name)
		source_filter.set_item_metadata(source_filter.item_count - 1, id)

func _clear():
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	for child in results.get_children():
		results.remove_child(child)
		child.queue_free()

func _home():
	_cancel_pending()
	generation += 1
	state.tab = "home"
	_clear()
	status.text = "Public catalogs: opening a category/search contacts the selected providers with your IP and query. Built-ins never require login."
	for category in ["Humanoid avatars", "Robots", "Animations and emotes"]:
		_button(results, category, select_category.bind(category))
	_button(results, "Load category recommendations (external requests)", _home_feeds)
	_button(results, "Browse all public catalogs", func(): submit_home_search(""))

func submit_home_search(query: String):
	state.tab = "search"
	state.query = query.left(200)
	state.category = ""
	state.cursor = ""
	if is_instance_valid(search_box): search_box.text = state.query
	_search(false)

func select_category(category: String):
	state.tab = "search"
	state.category = category
	state.query = "robot" if category.to_lower() == "robots" else ""
	state.type = "animation" if "animation" in category.to_lower() else "avatar"
	state.cursor = ""
	state.format = "all"
	if filter_controls.has("type"):
		filter_controls.type.select(2 if state.type == "animation" else 1)
		filter_controls.format.select(0)
	_search(false)

func get_search_state() -> Dictionary:
	return state.duplicate(true)

func _home_feeds():
	_cancel_pending()
	generation += 1
	var ticket = generation
	_clear()
	status.text = "Loading public category sections…"
	for id in registry.sources:
		var source: Dictionary = registry.sources[id]
		if not source.enabled: continue
		var heading = Label.new()
		heading.text = source.name
		results.add_child(heading)
		var service = Service.new()
		add_child(service)
		services.append(service)
		service.configure(source)
		service.catalogs = catalog_cache
		service.credentials = registry.get_credentials(id)
		var response: Dictionary = await service.search({"query": "", "type": "all", "cursor": ""})
		services.erase(service)
		service.queue_free()
		if ticket != generation: return
		for item in response.get("items", []).slice(0, 6):
			var record: Dictionary = item.duplicate(true)
			record.provider = id
			_button(results, str(record.get("title", "Asset")).left(100), _details.bind(record))
	status.text = "Category samples from enabled public catalogs; select Search to filter everything."

func _search(more: bool):
	if not is_instance_valid(results): return
	_cancel_pending()
	generation += 1
	var ticket = generation
	state.tab = "search"
	if not more:
		cursors.clear()
		seen_results.clear()
		_clear()
	status.text = "Searching… (compatibility is checked on import, not guessed from listings)"
	var selected = str(source_filter.get_selected_metadata())
	var count := 0
	var errors: Array = []
	for id in registry.sources.keys():
		var source: Dictionary = registry.sources[id]
		if not source.enabled or (not selected.is_empty() and selected != id): continue
		if more and cursors.get(id, "").is_empty(): continue
		var service = Service.new()
		add_child(service)
		services.append(service)
		service.configure(source)
		service.catalogs = catalog_cache
		service.credentials = registry.get_credentials(id)
		var query = state.duplicate()
		query.cursor = cursors.get(id, "")
		var response: Dictionary = await service.search(query)
		services.erase(service)
		service.queue_free()
		if ticket != generation or not is_inside_tree(): return
		if response.has("error"):
			errors.append(source.name + ": " + str(response.error))
			continue
		cursors[id] = str(response.get("next_cursor", ""))
		for item in response.get("items", []):
			if not item is Dictionary: continue
			var key = id + ":" + str(item.get("id", ""))
			if seen_results.has(key): continue
			seen_results[key] = true
			var record = item.duplicate(true)
			record.provider = id
			count += 1
			_button(results, str(record.get("title", "Asset")).left(100) + " · " + str(record.get("type", "unknown")) + " · " + source.name, _details.bind(record))
	status.text = "%s results on this page. Search covers fetched public catalogs; provider ranking, not global popularity. %s" % [count, "\n".join(errors)]
	if cursors.values().any(func(cursor): return not str(cursor).is_empty()): _button(results, "Load more", func(): _search(true))

func _details(record: Dictionary):
	_cancel_pending()
	generation += 1
	_clear()
	selected_record = record
	var info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "%s\nAuthor: %s\nLicense: %s\nFormat: %s\nCompatibility: unverified until import\nNo asset is equipped by browsing." % [str(record.get("title", "")).left(200), str(record.get("author", "Unknown")).left(200), str(record.get("license", "Unknown")).left(100), str(record.get("format", "Unknown")).left(20)]
	results.add_child(info)
	var page = str(record.get("page_url", ""))
	if Service.new().policy.valid_url(page): _button(results, "Open source page", func(): OS.shell_open(page))
	if ImportPolicy.new().evaluate(record).can_import:
		if record.get("type") == "avatar": _button(results, "Preview model (external download)", _preview_record.bind(record))
		_button(results, "Download, validate and review in Avatar configuration", _import_record.bind(record))
		if record.get("type") == "animation":
			var converted = record.duplicate(true)
			converted.in_place = true
			_button(results, "Import animation in-place (remove translation tracks)", _import_record.bind(converted))
	_button(results, "Back to results", func(): _search(false))

func _preview_record(record: Dictionary):
	var source: Dictionary = registry.sources[record.provider]
	if source.auth != "none":
		status.text = "Authenticated model preview is available after validated import; credentials never enter the preview URL cache."
		return
	var loader = get_node_or_null("/root/DataLoader")
	if loader == null: return
	var ticket = generation
	var service = Service.new()
	add_child(service)
	services.append(service)
	service.configure(source)
	var response: Dictionary = await service.request_bytes(str(record.get("download_url", "")), 64 * 1024 * 1024)
	services.erase(service)
	service.queue_free()
	if ticket != generation: return
	if response.has("error"):
		status.text = response.error
		return
	var bytes: PackedByteArray = response.bytes
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	if reader.document(bytes, 64 * 1024 * 1024).is_empty():
		status.text = "Preview requires a bounded self-contained binary model."
		return
	var model = await loader._load_model_from_buffer(bytes)
	if ticket != generation:
		if model != null: model.free()
		return
	if model == null:
		status.text = "Model preview import failed."
		return
	if is_instance_valid(preview): preview.queue_free()
	preview = load("res://scenes/GUI/avatar_preview.tscn").instantiate()
	preview.custom_minimum_size = Vector2(240, 320)
	results.add_child(preview)
	model.free()
	preview.loader = func(_url): return await loader._load_model_from_buffer(bytes)
	preview.set_source("browser-preview")
	await preview.load_preview()

func _import_record(record: Dictionary):
	if editor_open: return
	var loader = get_node_or_null("/root/DataLoader")
	var save = get_node_or_null("/root/SaveData")
	if loader == null or save == null or save.profile.get_local_fingerprint() != account_owner: return
	var eligibility = ImportPolicy.new().evaluate(record)
	if not eligibility.can_import or not eligibility.share:
		status.text = "This source lacks supported format or reviewed CC0 redistribution rights."
		return
	var ticket = generation
	var service = Service.new()
	add_child(service)
	services.append(service)
	service.configure(registry.sources[record.provider])
	service.credentials = registry.get_credentials(record.provider)
	status.text = "Downloading and validating; your equipped avatar is unchanged…"
	var response: Dictionary = await service.request_bytes(str(record.get("download_url", "")), 64 * 1024 * 1024 if record.type == "avatar" else 16 * 1024 * 1024)
	services.erase(service)
	service.queue_free()
	if ticket != generation or not is_inside_tree() or save.profile.get_local_fingerprint() != account_owner: return
	if response.has("error") or response.get("no_store", false):
		status.text = str(response.get("error", "No-store assets cannot be saved as an applied source."))
		return
	var bytes: PackedByteArray = response.bytes
	if not record.get("sha256", "").is_empty():
		var hash = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		if hash.finish().hex_encode() != record.sha256:
			status.text = "Source digest mismatch; not imported."
			return
	var cache = loader.get_asset_cache()
	if record.get("in_place", false):
		if conversion_thread != null:
			status.text = "An animation conversion is already running."
			return
		var converter = preload("res://scripts/discovery/avatars/animation_conversion.gd").new()
		conversion_thread = Thread.new()
		if conversion_thread.start(converter.convert.bind(bytes)) != OK:
			conversion_thread = null
			return
		while conversion_thread.is_alive(): await get_tree().process_frame
		bytes = conversion_thread.wait_to_finish()
		conversion_thread = null
		if ticket != generation: return
		if bytes.is_empty():
			status.text = "In-place adaptation is still incompatible with the humanoid importer."
			return
	if not cache.initialize(): return
	var path: String = cache.directory.path_join("staging/browser-" + str(Time.get_ticks_usec()))
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	file.store_buffer(bytes)
	file.close()
	var configuration = loader.get_avatar_configuration()
	var imported: Dictionary = await configuration.import_source(path, record.type == "avatar", true)
	DirAccess.remove_absolute(path)
	if ticket != generation or not is_inside_tree() or save.profile.get_local_fingerprint() != account_owner: return
	if imported.is_empty():
		status.text = configuration.last_error
		return
	imported.name = str(record.get("title", "Imported asset")).left(200)
	# Provider/private URLs are not persisted in source config or cache records.
	imported.provenance = {"provider": record.provider, "id": str(record.get("id", "")).left(200), "license": record.license, "author": str(record.get("author", "")).left(200)}
	if record.get("in_place", false): imported.provenance.conversion = "Removed translation tracks; retained humanoid rotations"
	var editor = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	add_child(editor)
	editor_open = true
	editor.tree_exited.connect(func(): editor_open = false)
	if record.type == "avatar": editor.draft_model = imported
	else:
		if editor.draft_sources.size() >= 32:
			editor.queue_free()
			status.text = "Your library already has 32 animation sources. Remove one in Avatar configuration first."
			return
		if not editor.draft_sources.any(func(item): return item.hash == imported.hash): editor.draft_sources.append(imported)
	editor._render()
	status.text = "Validated. Review the source editor and Apply explicitly to equip."

func _persist_sources():
	if configuration_path.is_empty(): return
	if not preferences_writable:
		status.text = "Existing source preferences are unreadable; original preserved. Changes are memory-only."
		return
	DirAccess.make_dir_recursive_absolute(configuration_path.get_base_dir())
	var file = FileAccess.open(configuration_path + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(registry.export_configuration().filter(func(item): return item.kind == "custom")))
	file.close()
	DirAccess.rename_absolute(configuration_path + ".tmp", configuration_path)

func _sources():
	_cancel_pending()
	generation += 1
	_clear()
	status.text = "Custom API: schema-1 JSON catalog/search endpoint. Credentials are memory-only for this browser; no OAuth/password automation. Only contact endpoints you trust."
	for id in registry.sources.keys():
		var source: Dictionary = registry.sources[id]
		_button(results, ("Disable " if source.enabled else "Enable ") + source.name, func(): registry.sources[id].enabled = not registry.sources[id].enabled; _persist_sources(); _sources())
		if source.kind == "custom":
			var rename_field = LineEdit.new()
			rename_field.text = source.base_url
			rename_field.placeholder_text = "Edit endpoint (clears credential)"
			results.add_child(rename_field)
			_button(results, "Update endpoint: " + source.name, func():
				var updated = source.duplicate()
				updated.base_url = rename_field.text.strip_edges()
				if not registry.policy.valid_url(updated.base_url): return
				registry.remove_source(id)
				registry.add_source(updated)
				_persist_sources(); _refresh_sources(); _sources())
			var credential = LineEdit.new()
			credential.secret = true
			credential.placeholder_text = "New memory-only token for " + source.name
			results.add_child(credential)
			_button(results, "Set credential / sign in: " + source.name, func(): registry.set_credentials(id, {"token": credential.text}); credential.clear())
			_button(results, "Test connection: " + source.name, func(): source_filter.select(registry.sources.keys().find(id) + 1); _search(false))
			_button(results, "Sign out / clear credential: " + source.name, func(): registry.secrets.erase(id); _sources())
			_button(results, "Remove " + source.name, func(): registry.remove_source(id); _persist_sources(); _refresh_sources(); _sources())
	var name_field = LineEdit.new()
	name_field.placeholder_text = "Custom source name"
	results.add_child(name_field)
	var endpoint = LineEdit.new()
	endpoint.placeholder_text = "https://your-provider.example/catalog"
	endpoint.max_length = 4096
	results.add_child(endpoint)
	var auth = OptionButton.new()
	for mode in ["none", "bearer", "api_key"]: auth.add_item(mode)
	results.add_child(auth)
	var token = LineEdit.new()
	token.placeholder_text = "Optional provider token (memory only)"
	token.secret = true
	results.add_child(token)
	_button(results, "Confirm endpoint and add custom API", func():
		var id = "custom-" + str(Time.get_ticks_usec())
		if registry.add_source({"id": id, "kind": "custom", "name": name_field.text, "base_url": endpoint.text.strip_edges(), "auth": auth.get_item_text(auth.selected)}):
			if auth.selected != 0: registry.set_credentials(id, {"token": token.text, "memory_only": true})
			_persist_sources(); _refresh_sources(); _sources()
		else: status.text = "Invalid HTTPS endpoint or unsupported source configuration.")

func _cancel_pending():
	for service in services.duplicate():
		if is_instance_valid(service): service.cancel()

func _process(_delta):
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("profile") != null and save.profile.get_local_fingerprint() != account_owner:
		_cancel_pending()
		registry.clear_credentials()
		queue_free()

func _exit_tree():
	if conversion_thread != null:
		conversion_thread.wait_to_finish()
		conversion_thread = null
	generation += 1
	registry.clear_credentials()
	_cancel_pending()
