extends Control
## Discovery is read-only until explicit import into a separate source draft.
## Coordinates browser_sidebar (search/filters), browser_results (card grid),
## browser_detail (preview and apply) and browser_sources (providers/OAuth).
const Registry = preload("res://scripts/discovery/avatars/source_registry.gd")
const Service = preload("res://scripts/discovery/avatars/discovery_service.gd")
const ImportPolicy = preload("res://scripts/discovery/avatars/import_policy.gd")
const COMPACT_WIDTH := 1040.0
const FILTER_KEYS = ["type", "format", "sort", "license", "compatibility", "shareable", "loop"]
var registry = Registry.new()
var state = {"tab": "home", "query": "", "category": "", "cursor": "", "type": "all", "format": "all", "sort": "provider"}
var sidebar: Control
var results_view: Control
var detail: Control
var sources_page: Node
var main_column: VBoxContainer
var status: Label
var results: GridContainer
var search_box: LineEdit
var source_filter: OptionButton
var filter_controls: Dictionary = {}
var tag_field: LineEdit
var advanced_filters: Control
var preview: Control:
	get: return detail.preview if is_instance_valid(detail) else null
var loading_label: Label
var loading_bar: ProgressBar
var generation := 0
var services: Array = []
var cursors: Dictionary = {}
var account_owner := ""
var configuration_path := ""
var selected_record: Dictionary = {}
var conversion_thread: Thread
var catalog_cache: Dictionary = {}
var seen_results: Dictionary = {}
var pagination_button: Button
var pagination_loading := false
var editor_open := false
var preferences_writable := true
var thumbnail_cache = preload("res://scripts/discovery/avatars/thumbnail_cache.gd").new()
var scroll_container: ScrollContainer
var saved_records: Array = []
var saved_scroll := 0
var return_record := ""
var card_buttons: Dictionary = {}
var thumbnail_queue: Array = []
var thumbnails_active := 0
var transport_options: Dictionary = {} # Isolated test seam; production remains HTTPS-only.
var applying_avatar := false
var compact := false
var assets: Node
var _filter_snapshot: Dictionary = {}

func _ready():
	set_meta("blocks_global_shortcuts", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for value in [
		{"id": "osa", "kind": "builtin", "name": "100Avatars R1 · CC0", "adapter": "osa", "auth": "none", "base_url": Service.OSA + "avatars/100avatars-r1.json"},
		{"id": "osa-r2", "kind": "builtin", "name": "100Avatars R2 · CC0", "adapter": "osa", "auth": "none", "base_url": Service.OSA + "avatars/100avatars-r2.json"},
		{"id": "osa-r3", "kind": "builtin", "name": "100Avatars R3 · CC0", "adapter": "osa", "auth": "none", "base_url": Service.OSA + "avatars/100avatars-r3.json"},
		{"id": "osa-neon", "kind": "builtin", "name": "NeonGlitch86 · verified CC0 subset", "adapter": "osa-neon", "auth": "none", "base_url": Service.OSA + "avatars/NeonGlitch86.json"},
		{"id": "vox", "kind": "builtin", "name": "Public CC0 VRMA manifest", "adapter": "vox", "auth": "none", "base_url": Service.VOX + "manifest.json"}]: registry.add_source(value)
	sources_page = preload("res://scripts/GUI/avatar_browser/browser_sources.gd").new()
	add_child(sources_page)
	sources_page.configure(self)
	sources_page.load_preferences()
	assets = preload("res://scripts/GUI/avatar_browser/browser_assets.gd").new()
	add_child(assets)
	assets.browser = self
	var layout = HBoxContainer.new()
	layout.name = "BrowserLayout"
	layout.theme_type_variation = "WideHBox"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	sidebar = preload("res://scripts/GUI/avatar_browser/browser_sidebar.gd").new()
	layout.add_child(sidebar)
	search_box = sidebar.search
	source_filter = sidebar.source_filter
	filter_controls = sidebar.filter_controls
	tag_field = sidebar.tag_field
	advanced_filters = sidebar.advanced_filters
	sidebar.navigate.connect(_navigate)
	sidebar.search_submitted.connect(submit_home_search)
	sidebar.filters_changed.connect(_filters_changed)
	main_column = VBoxContainer.new()
	main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(main_column)
	status = Label.new()
	status.theme_type_variation = "CaptionLabel"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_column.add_child(status)
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_column.add_child(scroll_container)
	results_view = preload("res://scripts/GUI/avatar_browser/browser_results.gd").new()
	scroll_container.add_child(results_view)
	results = results_view.grid
	results_view.record_selected.connect(_details)
	var detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.name = "DetailScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(detail_scroll)
	detail = preload("res://scripts/GUI/avatar_browser/browser_detail.gd").new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail)
	detail.visibility_changed.connect(func(): detail_scroll.visible = detail.visible)
	detail_scroll.visible = false
	loading_label = detail.status_label
	loading_bar = detail.progress
	detail.preview_failed.connect(func(message): status.text = message)
	detail.apply_requested.connect(func(record):
		if record.get("type") == "animation": await _import_record(record)
		else: await _apply_avatar(record))
	detail.preview_requested.connect(_preview_record)
	detail.animation_preview_requested.connect(_preview_animation)
	detail.in_place_requested.connect(func(record):
		var converted = record.duplicate(true)
		converted.in_place = true
		_import_record(converted))
	detail.back_requested.connect(_restore_results)
	resized.connect(_layout)
	_refresh_sources()
	_filter_snapshot = _filters_only(sidebar.state())
	_layout()
	_home()

func _layout():
	compact = size.x > 0 and size.x < COMPACT_WIDTH
	detail.set_compact(compact)
	sidebar.visible = not (compact and detail.visible)
	main_column.visible = not (compact and detail.visible)

func _navigate(id: String):
	match id:
		"home": _home()
		"search": state.tab = "search"; _search(false)
		"configuration": _open_configuration()
		"providers": sources_page.render()

func _filters_only(values: Dictionary) -> Dictionary:
	var result = values.duplicate()
	result.erase("query")
	return result

func _filters_changed(values: Dictionary):
	var filters = _filters_only(values)
	if filters == _filter_snapshot: return # Typing only; search runs on submit.
	_filter_snapshot = filters
	for key in FILTER_KEYS: state[key] = values[key]
	state.tag = values.tag
	_search(false)

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _refresh_sources():
	var list: Array = []
	for id in registry.sources: list.append({"id": id, "name": registry.sources[id].name})
	sidebar.set_sources(list)

func _clear():
	pagination_loading = false
	pagination_button = null
	thumbnail_queue.clear()
	card_buttons.clear()
	results_view.clear()

func _home():
	_cancel_pending()
	generation += 1
	state.tab = "home"
	_clear()
	status.text = "Public catalogs: opening a category or search contacts the selected providers with your IP address and query. Built-in catalogs never require login."
	for category in ["Humanoid avatars", "Robots", "Animations and emotes"]:
		results_view.add_page_button(category, select_category.bind(category))
	results_view.add_page_button("Load category recommendations (external requests)", _home_feeds)
	results_view.add_page_button("Browse all public catalogs", func(): submit_home_search(""))

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
	_filter_snapshot = _filters_only(sidebar.state())
	_search(false)

func get_search_state() -> Dictionary:
	return state.duplicate(true)

func _service(source: Dictionary, id: String = "") -> Node:
	var service = Service.new()
	add_child(service)
	services.append(service)
	service.configure(source)
	service.options = transport_options.duplicate()
	service.catalogs = catalog_cache
	if not id.is_empty(): service.credentials = registry.get_credentials(id)
	return service

func _release(service: Node):
	services.erase(service)
	service.queue_free()

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
		var service = _service(source, id)
		var response: Dictionary = await service.search({"query": "", "type": "all", "cursor": ""})
		_release(service)
		if ticket != generation: return
		for item in response.get("items", []).slice(0, 6):
			var record: Dictionary = item.duplicate(true)
			record.provider = id
			_remember_feed_record(record)
	status.text = "Samples from enabled public catalogs. Use Search to filter everything."

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
	status.text = "Searching… Compatibility is checked on import, not guessed from listings."
	var selected = str(source_filter.get_selected_metadata())
	var count := 0
	var errors: Array = []
	for id in registry.sources.keys():
		var source: Dictionary = registry.sources[id]
		if not source.enabled or (not selected.is_empty() and selected != id): continue
		if more and cursors.get(id, "").is_empty(): continue
		var service = _service(source, id)
		var query = state.duplicate()
		query.cursor = cursors.get(id, "")
		var response: Dictionary = await service.search(query)
		_release(service)
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
	status.text = "%s results on this page, ranked by each provider. %s" % [count, "\n".join(errors)]
	results_view.empty_state.visible = saved_records.is_empty()
	pagination_loading = false
	_update_pagination()

func _details(record: Dictionary):
	saved_scroll = scroll_container.scroll_vertical
	return_record = str(record.get("provider", "")) + ":" + str(record.get("id", ""))
	_cancel_pending()
	generation += 1
	selected_record = record
	detail.show_record(record, ImportPolicy.new().evaluate(record))
	_layout()
	if record.get("type") == "avatar" and ImportPolicy.new().evaluate(record).can_import:
		_preview_record.call_deferred(record)

func _restore_results():
	_cancel_pending()
	generation += 1
	_clear()
	for record in saved_records: _card(record)
	_update_pagination()
	if compact: detail.visible = false
	_layout()
	_restore_focus.call_deferred()

func _restore_focus():
	if not is_inside_tree(): return
	scroll_container.scroll_vertical = saved_scroll
	if card_buttons.has(return_record) and card_buttons[return_record].is_visible_in_tree(): card_buttons[return_record].grab_focus()

func _card(record: Dictionary):
	var card: Button = results_view.add_record(record)
	var key = str(record.get("provider", "")) + ":" + str(record.get("id", ""))
	card_buttons[key] = card
	var image: TextureRect = card.get_meta("thumbnail")
	var cached = thumbnail_cache.get_texture(key)
	if cached != null: image.texture = cached
	elif not str(record.get("thumbnail_url", "")).is_empty():
		thumbnail_queue.append({"record": record, "target": weakref(image), "key": key, "generation": generation})
		assets.pump_thumbnails()

func _apply_avatar(record: Dictionary):
	if applying_avatar or editor_open: return
	if detail.record != record: _details(record)
	applying_avatar = true
	_loading_progress(0, "Loading avatar…")
	await _import_record(record, true)
	applying_avatar = false
	if not is_instance_valid(detail): return
	if loading_bar.value < 100: detail.show_error("Could not apply avatar. " + status.text)
	else: preload("res://scripts/GUI/toast_host.gd").notify(self, "Avatar changed.", "success")

func _loading_progress(value: float, message: String):
	if is_instance_valid(detail): detail.set_progress(value, "%s %d%%" % [message, int(value)] if value < 100 else message)

func _exit_tree():
	if conversion_thread != null:
		conversion_thread.wait_to_finish()
		conversion_thread = null
	generation += 1
	registry.clear_credentials()
	_cancel_pending()

func _cancel_pending():
	if is_instance_valid(sources_page): sources_page.cancel()
	for service in services.duplicate():
		if is_instance_valid(service): service.cancel()

func _process(_delta):
	if is_instance_valid(sources_page): sources_page.poll()
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("profile") != null and save.profile.get_local_fingerprint() != account_owner:
		_cancel_pending()
		registry.clear_credentials()
		queue_free()

func _preview_record(record: Dictionary):
	if detail.record != record: _details(record)
	await assets.preview_record(record)

func _preview_animation(record: Dictionary):
	if detail.record != record: _details(record)
	await assets.preview_animation(record)

func _import_record(record: Dictionary, equip: bool = false):
	await assets.import_record(record, equip)

func _open_configuration():
	if editor_open: return
	var editor = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	add_child(editor)
	editor_open = true
	editor.tree_exited.connect(func(): editor_open = false)
