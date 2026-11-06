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
var pagination_button: Button
var pagination_loading := false
var editor_open := false
var filter_controls: Dictionary = {}
var preferences_writable := true
var tag_field: LineEdit
var thumbnail_cache = preload("res://scripts/discovery/avatars/thumbnail_cache.gd").new()
var scroll_container: ScrollContainer
var saved_records: Array = []
var saved_scroll := 0
var return_record := ""
var card_buttons: Dictionary = {}
var thumbnail_queue: Array = []
var thumbnails_active := 0
var credential_store: Node
var oauth_listener: TCPServer
var oauth_peer: StreamPeerTCP
var oauth_buffer := ""
var oauth_id := ""
var oauth_config: Dictionary = {}
var oauth = preload("res://scripts/discovery/avatars/oauth_session.gd").new()
var oauth_exchange: HTTPRequest
var transport_options: Dictionary = {} # Isolated test seam; production remains HTTPS-only.
var advanced_filters: Control
var applying_avatar := false
var loading_popup: AcceptDialog
var loading_label: Label
var loading_bar: ProgressBar

func _loading_progress(value: float, message: String):
	if not is_instance_valid(loading_popup): return
	loading_bar.value = value
	loading_label.text = "%s\n%d%%" % [message, int(value)]

func _apply_avatar(record: Dictionary):
	if applying_avatar or editor_open: return
	if is_instance_valid(loading_popup): loading_popup.queue_free()
	applying_avatar = true
	loading_popup = AcceptDialog.new()
	loading_popup.title = "Loading avatar"
	loading_popup.exclusive = true
	loading_popup.get_ok_button().hide()
	loading_popup.close_requested.connect(func(): pass)
	var layout = VBoxContainer.new()
	loading_popup.add_child(layout)
	loading_label = Label.new()
	layout.add_child(loading_label)
	loading_bar = ProgressBar.new()
	loading_bar.custom_minimum_size = Vector2(320, 28)
	loading_bar.show_percentage = false
	layout.add_child(loading_bar)
	add_child(loading_popup)
	loading_popup.popup_centered(Vector2i(360, 150))
	_loading_progress(0, "Loading avatar…")
	await _import_record(record, true)
	applying_avatar = false
	if not is_instance_valid(loading_popup): return
	loading_popup.get_ok_button().show()
	loading_popup.confirmed.connect(loading_popup.queue_free)
	loading_popup.close_requested.connect(loading_popup.queue_free)
	if loading_bar.value < 100: loading_label.text = "Could not apply avatar.\n" + status.text

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _ready():
	credential_store = preload("res://scripts/discovery/avatars/credential_store.gd").new()
	add_child(credential_store)
	set_meta("blocks_global_shortcuts", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for value in [
		{"id": "osa", "kind": "builtin", "name": "100Avatars R1 · CC0", "adapter": "osa", "auth": "none", "base_url": Service.OSA + "avatars/100avatars-r1.json"},
		{"id": "osa-r2", "kind": "builtin", "name": "100Avatars R2 · CC0", "adapter": "osa", "auth": "none", "base_url": Service.OSA + "avatars/100avatars-r2.json"},
		{"id": "osa-r3", "kind": "builtin", "name": "100Avatars R3 · CC0", "adapter": "osa", "auth": "none", "base_url": Service.OSA + "avatars/100avatars-r3.json"},
		{"id": "osa-neon", "kind": "builtin", "name": "NeonGlitch86 · verified CC0 subset", "adapter": "osa-neon", "auth": "none", "base_url": Service.OSA + "avatars/NeonGlitch86.json"},
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
	layout.name = "BrowserLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 105
	layout.add_child(sidebar)
	_button(sidebar, "Home", _home)
	_button(sidebar, "Search", func(): state.tab = "search"; _search(false))
	_button(sidebar, "My avatar", _open_configuration)
	_button(sidebar, "Providers", _sources)
	var scroll = ScrollContainer.new()
	scroll_container = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var title = Label.new()
	title.text = "Avatar browser"
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search avatars and animations…"
	search_box.max_length = 200
	search_box.text_submitted.connect(submit_home_search)
	content.add_child(search_box)
	_button(content, "Search", func(): submit_home_search(search_box.text))
	var filters = HFlowContainer.new()
	advanced_filters = filters
	filters.visible = false
	var advanced = CheckButton.new()
	advanced.text = "Advanced filters"
	advanced.toggled.connect(func(enabled): filters.visible = enabled)
	content.add_child(advanced)
	content.add_child(filters)
	for definition in [["type", ["all", "avatar", "animation"]], ["format", ["all", "vrm", "vrma", "glb"]], ["sort", ["provider", "title"]], ["license", ["all", "CC0", "attribution", "unknown"]], ["compatibility", ["all", "unknown", "verified", "incompatible"]], ["shareable", ["all", "yes"]], ["loop", ["all", "yes", "no"]]]:
		var selector = OptionButton.new()
		selector.tooltip_text = str(definition[0]).capitalize()
		for item in definition[1]: selector.add_item(item)
		selector.item_selected.connect(func(index): state[definition[0]] = definition[1][index]; _search(false))
		filter_controls[definition[0]] = selector
		var field = VBoxContainer.new()
		var label = Label.new()
		label.text = str(definition[0]).capitalize()
		field.add_child(label)
		field.add_child(selector)
		filters.add_child(field)
	tag_field = LineEdit.new()
	tag_field.placeholder_text = "Filter tags (fetched metadata)"
	tag_field.max_length = 80
	tag_field.text_submitted.connect(func(text): state.tag = text; _search(false))
	filters.add_child(tag_field)
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
	pagination_loading = false
	pagination_button = null
	thumbnail_queue.clear()
	card_buttons.clear()
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
	for key in ["license", "compatibility", "shareable", "loop"]:
		state[key] = "all"
		if filter_controls.has(key): filter_controls[key].select(0)
	state.tag = ""
	if is_instance_valid(tag_field): tag_field.clear()
	state.tab = "search"
	state.category = category
	state.query = "robot" if category.to_lower() == "robots" else ""
	search_box.text = state.query
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
	saved_records.clear()
	cursors.clear()
	seen_results.clear()
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
		service.options = transport_options.duplicate()
		service.catalogs = catalog_cache
		service.credentials = registry.get_credentials(id)
		var response: Dictionary = await service.search({"query": "", "type": "all", "cursor": ""})
		services.erase(service)
		service.queue_free()
		if ticket != generation: return
		for item in response.get("items", []).slice(0, 6):
			var record: Dictionary = item.duplicate(true)
			record.provider = id
			_remember_feed_record(record)
	status.text = "Category samples from enabled public catalogs; select Search to filter everything."

func _remember_feed_record(record: Dictionary):
	var key = str(record.get("provider", "")) + ":" + str(record.get("id", ""))
	if seen_results.has(key): return
	seen_results[key] = true
	saved_records.append(record.duplicate(true))
	_card(record)

func _update_pagination():
	if is_instance_valid(pagination_button):
		if pagination_button.get_parent() == results: results.remove_child(pagination_button)
		pagination_button.queue_free()
	pagination_button = null
	if cursors.values().any(func(cursor): return cursor is String and not cursor.is_empty()):
		pagination_button = _button(results, "Load more", func(): _search(true))

func _search(more: bool):
	if not is_instance_valid(results): return
	if more and pagination_loading: return
	if not more: state.query = search_box.text.left(200)
	if is_instance_valid(pagination_button): pagination_button.disabled = true
	_cancel_pending()
	generation += 1
	var ticket = generation
	state.tab = "search"
	if not more:
		saved_records.clear()
		cursors.clear()
		seen_results.clear()
		_clear()
	pagination_loading = true
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
		service.options = transport_options.duplicate()
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
			saved_records.append(record)
			_card(record)
	status.text = "%s results on this page. Search covers fetched public catalogs; provider ranking, not global popularity. %s" % [count, "\n".join(errors)]
	pagination_loading = false
	_update_pagination()

func _details(record: Dictionary):
	saved_scroll = scroll_container.scroll_vertical
	return_record = str(record.get("provider", "")) + ":" + str(record.get("id", ""))
	_cancel_pending()
	generation += 1
	_clear()
	selected_record = record
	var info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "%s\nAuthor: %s\nLicense: %s\nFormat: %s\nCompatibility: unverified until import\nNo asset is equipped by browsing." % [str(record.get("title", "")).left(200), str(record.get("author", "Unknown")).left(200), str(record.get("license", "Unknown")).left(100), str(record.get("format", "Unknown")).left(20)]
	results.add_child(info)
	var page = str(record.get("page_url", ""))
	if preload("res://scripts/discovery/avatars/request_policy.gd").new().valid_url(page): _button(results, "Open source page", func(): OS.shell_open(page))
	if ImportPolicy.new().evaluate(record).can_import:
		if record.get("type") == "avatar": _button(results, "1. Preview avatar", _preview_record.bind(record))
		var action = _apply_avatar.bind(record) if record.get("type") == "avatar" else _import_record.bind(record)
		var import_button = _button(results, "Apply avatar" if record.get("type") == "avatar" else "Add animation to my library", action)
		import_button.disabled = not ImportPolicy.new().evaluate(record).share
		if import_button.disabled: import_button.tooltip_text = "Equipping requires reviewed redistribution permission. Preview is still available."
		if record.get("type") == "animation":
			_button(results, "Preview animation on a separate copy of my avatar (in-place)", _preview_animation.bind(record))
			var converted = record.duplicate(true)
			converted.in_place = true
			_button(results, "Import animation in-place (remove translation tracks)", _import_record.bind(converted))
	_button(results, "Back to results", _restore_results)

func _restore_results():
	_cancel_pending()
	generation += 1
	_clear()
	for record in saved_records: _card(record)
	_update_pagination()
	_restore_focus.call_deferred()

func _restore_focus():
	if not is_inside_tree(): return
	scroll_container.scroll_vertical = saved_scroll
	if card_buttons.has(return_record): card_buttons[return_record].grab_focus()

func _card(record: Dictionary):
	var row = HBoxContainer.new()
	results.add_child(row)
	var image = TextureRect.new()
	image.custom_minimum_size = Vector2(80, 80)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)
	var title = str(record.get("title", "Asset")).left(100) + " · " + str(record.get("type", ""))
	var button = _button(row, title, _details.bind(record))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var key = str(record.get("provider", "")) + ":" + str(record.get("id", ""))
	card_buttons[key] = button
	image.texture = thumbnail_cache.get_texture(key)
	if image.texture == null and not str(record.get("thumbnail_url", "")).is_empty():
		thumbnail_queue.append({"record": record, "target": weakref(image), "key": key, "generation": generation})
		_pump_thumbnails()

func _pump_thumbnails():
	while thumbnails_active < 2 and not thumbnail_queue.is_empty():
		_load_thumbnail(thumbnail_queue.pop_front())

func _load_thumbnail(job: Dictionary):
	if job.generation != generation: return
	thumbnails_active += 1
	var service = Service.new()
	add_child(service)
	services.append(service)
	# Thumbnails are deliberately anonymous, even for authenticated custom sources.
	service.configure({"id": "thumbnail", "kind": "builtin", "auth": "none", "base_url": job.record.thumbnail_url})
	var response: Dictionary = await service.request_bytes(job.record.thumbnail_url, 2 * 1024 * 1024)
	services.erase(service)
	service.queue_free()
	thumbnails_active -= 1
	var target = job.target.get_ref()
	if job.generation == generation and is_instance_valid(target) and response.has("bytes"):
		var texture = thumbnail_cache.decode(response.bytes)
		target.texture = texture
		if not response.get("no_store", false): thumbnail_cache.store(job.key, texture)
	_pump_thumbnails()

func _preview_animation(record: Dictionary):
	var loader = get_node_or_null("/root/DataLoader")
	if loader == null: return
	var ticket = generation
	var service = Service.new()
	add_child(service)
	services.append(service)
	service.configure(registry.sources[record.provider])
	service.credentials = registry.get_credentials(record.provider)
	status.text = "Downloading motion for isolated in-place preview…"
	var response: Dictionary = await service.request_bytes(str(record.get("download_url", "")), 16 * 1024 * 1024)
	services.erase(service)
	service.queue_free()
	if ticket != generation: return
	if response.has("error"):
		status.text = response.error
		return
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	var bytes: PackedByteArray = response.bytes
	var clip = reader.read_bytes(bytes)
	if clip.is_empty():
		var converted: PackedByteArray = await _convert_animation(bytes)
		if ticket != generation: return
		if not converted.is_empty(): clip = reader.read_bytes(converted)
	if clip.is_empty():
		status.text = "This animation cannot be previewed by the humanoid importer."
		return
	var configuration = loader.get_avatar_configuration()
	var model = await configuration.load_model(get_node("/root/SaveData").data.avatar_url)
	if ticket != generation:
		if model != null: model.free()
		return
	if model == null:
		status.text = "A compatible local avatar is required for animation preview."
		return
	if is_instance_valid(preview): preview.queue_free()
	preview = load("res://scenes/GUI/avatar_preview.tscn").instantiate()
	preview.custom_minimum_size = Vector2(240, 320)
	results.add_child(preview)
	preview.loader = func(_url): return model
	preview.set_source("browser-animation-preview")
	await preview.load_preview()
	preview.loader = Callable()
	if ticket != generation or not is_instance_valid(preview) or not is_instance_valid(preview.model): return
	var animator = load("res://scripts/assets/avatar_animator.gd").new()
	preview.model.add_child(animator)
	# Safe preview tree disables imported processing; reenable only our new layer.
	animator.process_mode = Node.PROCESS_MODE_ALWAYS
	animator.attach(preview.model)
	if not animator.play_clip(clip.clips[0], true): status.text = animator.last_error

func _convert_animation(bytes: PackedByteArray) -> PackedByteArray:
	if conversion_thread != null: return PackedByteArray()
	var converter = preload("res://scripts/discovery/avatars/animation_conversion.gd").new()
	conversion_thread = Thread.new()
	if conversion_thread.start(converter.convert.bind(bytes)) != OK:
		conversion_thread = null
		return PackedByteArray()
	while conversion_thread.is_alive(): await get_tree().process_frame
	var converted: PackedByteArray = conversion_thread.wait_to_finish()
	conversion_thread = null
	return converted

func _preview_record(record: Dictionary):
	if not registry.sources.has(record.get("provider", "")):
		status.text = "This provider was removed. Search again before previewing."
		return
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
	service.options = transport_options.duplicate()
	status.text = "Downloading model for an independent preview…"
	var response: Dictionary = await service.request_bytes(str(record.get("download_url", "")), 256 * 1024 * 1024)
	services.erase(service)
	service.queue_free()
	if ticket != generation: return
	if response.has("error"):
		status.text = response.error
		return
	var bytes: PackedByteArray = response.bytes
	if not record.get("sha256", "").is_empty():
		var digest = HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(bytes)
		if digest.finish().hex_encode() != record.sha256:
			status.text = "Source digest mismatch; preview rejected."
			return
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	if reader.document(bytes, 256 * 1024 * 1024).is_empty():
		status.text = "Preview requires a bounded self-contained binary model."
		return
	if is_instance_valid(preview): preview.queue_free()
	preview = load("res://scenes/GUI/avatar_preview.tscn").instantiate()
	preview.custom_minimum_size = Vector2(240, 320)
	results.add_child(preview)
	preview.failed.connect(func(message): status.text = message)
	preview.loader = func(_url): return await loader._load_model_from_buffer(bytes)
	preview.set_source("browser-preview")
	await preview.load_preview()
	if ticket == generation and is_instance_valid(preview) and is_instance_valid(preview.model):
		status.text = "Preview ready. Click Apply avatar to download, validate and equip."

func _import_record(record: Dictionary, equip: bool = false):
	if editor_open: return
	if not registry.sources.has(record.get("provider", "")):
		status.text = "This provider was removed. Search again before applying."
		return
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
	service.options = transport_options.duplicate()
	service.credentials = registry.get_credentials(record.provider)
	if equip:
		service.download_progress.connect(func(received, total):
			if total > 0: _loading_progress(clampf(float(received) / total, 0, 1) * 70, "Downloading avatar…")
			else: _loading_progress(0, "Downloading avatar… (%d KiB)" % (received / 1024)))
	status.text = "Downloading and validating; your equipped avatar is unchanged…"
	var response: Dictionary = await service.request_bytes(str(record.get("download_url", "")), 256 * 1024 * 1024 if record.type == "avatar" else 16 * 1024 * 1024)
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
	if not cache.initialize():
		status.text = cache.last_error
		return
	var path: String = cache.directory.path_join("staging/browser-" + str(Time.get_ticks_usec()))
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Cannot stage downloaded asset for import."
		return
	file.store_buffer(bytes)
	file.close()
	var configuration = loader.get_avatar_configuration()
	if equip: _loading_progress(75, "Validating avatar…")
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
	if equip:
		_loading_progress(90, "Applying avatar…")
		if await configuration.apply(imported, configuration.sources.duplicate(true)):
			status.text = "Avatar applied: " + imported.name
			_loading_progress(100, "Avatar applied!")
		else: status.text = configuration.last_error
		return
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

func _open_configuration():
	if editor_open: return
	var editor = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	add_child(editor)
	editor_open = true
	editor.tree_exited.connect(func(): editor_open = false)

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
	status.text = "Custom schema-1 API sources. Built-ins stay anonymous. Optional custom PKCE login uses your system browser; remember tokens only via the OS secret service."
	for id in registry.sources.keys():
		var source: Dictionary = registry.sources[id]
		_button(results, ("Disable " if source.enabled else "Enable ") + source.name, func(): registry.sources[id].enabled = not registry.sources[id].enabled; _persist_sources(); _sources())
		if source.kind == "custom":
			if source.auth == "oauth": _button(results, "OAuth sign in: " + source.name, _start_oauth.bind(id))
			_button(results, "Remember credential in OS keyring: " + source.name, _remember_credential.bind(id))
			_button(results, "Restore from OS keyring: " + source.name, _restore_credential.bind(id))
			_button(results, "Forget OS keyring credential: " + source.name, _forget_credential.bind(id))
			var rename_field = LineEdit.new()
			rename_field.text = source.base_url
			rename_field.placeholder_text = "Edit endpoint (clears credential)"
			results.add_child(rename_field)
			_button(results, "Update endpoint: " + source.name, func():
				var updated = source.duplicate()
				updated.base_url = rename_field.text.strip_edges()
				if not registry.policy.valid_url(updated.base_url): return
				_cancel_pending()
				await credential_store.perform("clear", account_owner, id, registry.policy.origin(source.base_url))
				registry.remove_source(id)
				registry.add_source(updated)
				_persist_sources(); _refresh_sources(); _sources())
			var credential = LineEdit.new()
			credential.secret = true
			credential.placeholder_text = "New memory-only token for " + source.name
			results.add_child(credential)
			_button(results, "Set credential / sign in: " + source.name, func(): registry.set_credentials(id, {"token": credential.text}); credential.clear())
			_button(results, "Test connection: " + source.name, func(): source_filter.select(registry.sources.keys().find(id) + 1); _search(false))
			_button(results, "Sign out / clear credential: " + source.name, func(): _forget_credential(id))
			_button(results, "Remove " + source.name, func():
				_cancel_pending()
				await credential_store.perform("clear", account_owner, id, registry.policy.origin(source.base_url))
				registry.remove_source(id); _persist_sources(); _refresh_sources(); _sources())
	var name_field = LineEdit.new()
	name_field.placeholder_text = "Custom source name"
	results.add_child(name_field)
	var endpoint = LineEdit.new()
	endpoint.placeholder_text = "https://your-provider.example/catalog"
	endpoint.max_length = 4096
	results.add_child(endpoint)
	var auth = OptionButton.new()
	for mode in ["none", "bearer", "api_key", "oauth"]: auth.add_item(mode)
	results.add_child(auth)
	var token = LineEdit.new()
	token.placeholder_text = "Optional provider token (memory only)"
	token.secret = true
	results.add_child(token)
	var oauth_fields: Array = []
	for placeholder in ["OAuth authorization HTTPS URL (optional)", "OAuth token HTTPS URL (optional)", "OAuth public client ID (no secret)", "OAuth scopes"]:
		var field = LineEdit.new()
		field.placeholder_text = placeholder
		results.add_child(field)
		oauth_fields.append(field)
	_button(results, "Confirm endpoint and add custom API", func():
		var id = "custom-" + str(Time.get_ticks_usec())
		if registry.add_source({"id": id, "kind": "custom", "name": name_field.text, "base_url": endpoint.text.strip_edges(), "auth": auth.get_item_text(auth.selected), "oauth": {"authorization_url": oauth_fields[0].text.strip_edges(), "token_url": oauth_fields[1].text.strip_edges(), "client_id": oauth_fields[2].text, "scope": oauth_fields[3].text}}):
			if auth.selected != 0: registry.set_credentials(id, {"token": token.text, "memory_only": true})
			_persist_sources(); _refresh_sources(); _sources()
		else: status.text = "Invalid HTTPS endpoint or unsupported source configuration.")

func _cancel_pending():
	_cancel_oauth()
	if is_instance_valid(oauth_exchange):
		oauth_exchange.cancel_request()
		oauth_exchange.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())
		oauth_exchange = null
	for service in services.duplicate():
		if is_instance_valid(service): service.cancel()

func _process(_delta):
	_poll_oauth()
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

func _remember_credential(id: String):
	var source: Dictionary = registry.sources[id]
	if registry.get_credentials(id).get("token", "").is_empty():
		status.text = "Sign in or set a provider credential before remembering it."
		return
	var result: Dictionary = await credential_store.perform("store", account_owner, id, registry.policy.origin(source.base_url), str(registry.get_credentials(id).get("token", "")))
	status.text = "Stored in OS keyring." if result.get("ok") else "OS keyring unavailable/locked; credential remains memory-only."

func _restore_credential(id: String):
	var source: Dictionary = registry.sources[id].duplicate(true)
	var result: Dictionary = await credential_store.perform("lookup", account_owner, id, registry.policy.origin(source.base_url))
	if registry.sources.has(id) and registry.sources[id].base_url == source.base_url and result.get("ok"):
		registry.set_credentials(id, {"token": result.get("token", "")})
	status.text = "Keyring lookup finished; secrets are never written to source preferences."

func _forget_credential(id: String):
	var source: Dictionary = registry.sources[id]
	registry.secrets.erase(id)
	_cancel_pending()
	generation += 1
	await credential_store.perform("clear", account_owner, id, registry.policy.origin(source.base_url))
	status.text = "Credential cleared from memory; keyring removal requested."

func _cancel_oauth():
	oauth.clear()
	oauth_id = ""
	if oauth_listener != null: oauth_listener.stop()
	oauth_listener = null
	if oauth_peer != null: oauth_peer.disconnect_from_host()
	oauth_peer = null
	oauth_buffer = ""

func _start_oauth(id: String):
	_cancel_pending()
	oauth_listener = TCPServer.new()
	if oauth_listener.listen(0, "127.0.0.1") != OK:
		status.text = "Cannot open OAuth loopback callback."
		_cancel_oauth()
		return
	oauth_config = registry.sources[id].oauth.duplicate()
	oauth_config.redirect_uri = "http://127.0.0.1:" + str(oauth_listener.get_local_port()) + "/callback"
	var url = oauth.begin(oauth_config)
	if url.is_empty(): _cancel_oauth(); return
	oauth_id = id
	OS.shell_open(url)
	status.text = "Complete custom-provider sign in in your system browser. The callback expires in three minutes."

func _poll_oauth():
	if oauth_listener == null: return
	if Time.get_ticks_msec() > oauth.expires: _cancel_oauth(); return
	if oauth_peer == null and oauth_listener.is_connection_available(): oauth_peer = oauth_listener.take_connection()
	if oauth_peer == null: return
	oauth_peer.poll()
	if oauth_peer.get_available_bytes() > 0:
		oauth_buffer += oauth_peer.get_utf8_string(mini(8192, oauth_peer.get_available_bytes()))
	if oauth_buffer.length() > 8192: _cancel_oauth(); return
	if not "\r\n\r\n" in oauth_buffer: return
	var request_line = oauth_buffer.get_slice("\r\n", 0).split(" ")
	var fields := {}
	var expected_host = oauth_config.redirect_uri.trim_prefix("http://").get_slice("/", 0)
	var host := ""
	for header in oauth_buffer.split("\r\n"):
		if header.to_lower().begins_with("host:"): host = header.substr(5).strip_edges()
	if host == expected_host and request_line.size() == 3 and request_line[0] == "GET" and request_line[1].begins_with("/callback?"):
		fields = oauth.accept_callback(oauth_config.redirect_uri.get_slice("/callback", 0) + request_line[1], oauth_config)
	var body = "Return to Comunicare to check sign in."
	oauth_peer.put_data(("HTTP/1.1 200 OK\r\nContent-Length: %s\r\nConnection: close\r\n\r\n" % body.length() + body).to_utf8_buffer())
	var id = oauth_id
	_cancel_oauth()
	if not fields.is_empty(): _exchange_oauth(id, fields)

func _exchange_oauth(id: String, fields: Dictionary):
	if not registry.sources.has(id): return
	var ticket = generation
	var request = HTTPRequest.new()
	oauth_exchange = request
	request.timeout = 20
	request.body_size_limit = 16384
	request.max_redirects = 0
	add_child(request)
	var values: Array[String] = []
	for key in fields: values.append(str(key).uri_encode() + "=" + str(fields[key]).uri_encode())
	if request.request(registry.sources[id].oauth.token_url, ["Content-Type: application/x-www-form-urlencoded"], HTTPClient.METHOD_POST, "&".join(values)) != OK:
		request.queue_free()
		return
	var response = await request.request_completed
	request.queue_free()
	oauth_exchange = null
	if ticket != generation or not registry.sources.has(id): return
	var parser = JSON.new()
	if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200 and parser.parse(response[3].get_string_from_utf8()) == OK and parser.data is Dictionary:
		if str(parser.data.get("token_type", "Bearer")).to_lower() == "bearer" and registry.set_credentials(id, {"token": parser.data.get("access_token", "")}):
			status.text = "Signed in. Token is memory-only unless you explicitly remember it in the OS keyring."
			return
	status.text = "OAuth exchange failed. No credential was saved."
