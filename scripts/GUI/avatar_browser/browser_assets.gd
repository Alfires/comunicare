extends Node
## Downloads for the avatar browser: thumbnails, isolated previews and the
## validated import/apply pipeline. Moved unchanged in behavior from avatar_browser.gd.

const ImportPolicy = preload("res://scripts/discovery/avatars/import_policy.gd")
const SizePolicy = preload("res://scripts/assets/avatar_size_policy.gd")
const AVATAR_LIMIT := SizePolicy.MAX_BYTES
const ANIMATION_LIMIT := 16 * 1024 * 1024
var browser: Control

func _status(text: String):
	browser.status.text = text

static func _sha256(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func pump_thumbnails():
	while browser.thumbnails_active < 2 and not browser.thumbnail_queue.is_empty():
		_load_thumbnail(browser.thumbnail_queue.pop_front())

func _load_thumbnail(job: Dictionary):
	if job.generation != browser.generation: return
	browser.thumbnails_active += 1
	# Thumbnails are deliberately anonymous, even for authenticated custom sources.
	var service = browser._service({"id": "thumbnail", "kind": "builtin", "auth": "none", "base_url": job.record.thumbnail_url})
	var response: Dictionary = await service.request_bytes(job.record.thumbnail_url, 2 * 1024 * 1024)
	browser._release(service)
	browser.thumbnails_active -= 1
	var target = job.target.get_ref()
	if job.generation == browser.generation and is_instance_valid(target) and response.has("bytes"):
		var texture = browser.thumbnail_cache.decode(response.bytes)
		target.texture = texture
		if not response.get("no_store", false): browser.thumbnail_cache.store(job.key, texture)
	pump_thumbnails()

func convert_animation(bytes: PackedByteArray) -> PackedByteArray:
	if browser.conversion_thread != null: return PackedByteArray()
	var converter = preload("res://scripts/discovery/avatars/animation_conversion.gd").new()
	browser.conversion_thread = Thread.new()
	if browser.conversion_thread.start(converter.convert.bind(bytes)) != OK:
		browser.conversion_thread = null
		return PackedByteArray()
	while browser.conversion_thread.is_alive(): await get_tree().process_frame
	var converted: PackedByteArray = browser.conversion_thread.wait_to_finish()
	browser.conversion_thread = null
	return converted

func preview_animation(record: Dictionary):
	var loader = get_node_or_null("/root/DataLoader")
	if loader == null or not browser.registry.sources.has(record.get("provider", "")): return
	var ticket = browser.generation
	var service = browser._service(browser.registry.sources[record.provider], record.provider)
	_status("Downloading motion for an isolated in-place preview…")
	var response: Dictionary = await service.request_bytes(str(record.get("download_url", "")), ANIMATION_LIMIT)
	browser._release(service)
	if ticket != browser.generation: return
	if response.has("error"):
		_status(response.error)
		return
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	var bytes: PackedByteArray = response.bytes
	var clip = reader.read_bytes(bytes)
	if clip.is_empty():
		var converted: PackedByteArray = await convert_animation(bytes)
		if ticket != browser.generation: return
		if not converted.is_empty(): clip = reader.read_bytes(converted)
	if clip.is_empty():
		_status("This animation cannot be previewed by the humanoid importer.")
		return
	var model = await loader.get_avatar_configuration().load_model(get_node("/root/SaveData").data.avatar_url)
	if ticket != browser.generation:
		if model != null: model.free()
		return
	if model == null:
		_status("A compatible local avatar is required for animation preview.")
		return
	var preview = browser.preview
	preview.loader = func(_url): return model
	preview.set_source("browser-animation-preview")
	await preview.load_preview()
	preview.loader = Callable()
	if ticket != browser.generation or not is_instance_valid(preview) or not is_instance_valid(preview.model): return
	var animator = load("res://scripts/assets/avatar_animator.gd").new()
	preview.model.add_child(animator)
	# Safe preview tree disables imported processing; reenable only our new layer.
	animator.process_mode = Node.PROCESS_MODE_ALWAYS
	animator.attach(preview.model)
	if not animator.play_clip(clip.clips[0], true): _status(animator.last_error)

func preview_record(record: Dictionary):
	if not browser.registry.sources.has(record.get("provider", "")):
		_status("This provider was removed. Search again before previewing.")
		return
	var source: Dictionary = browser.registry.sources[record.provider]
	if source.auth != "none":
		_status("Authenticated model preview is available after validated import; credentials never enter the preview URL cache.")
		return
	var loader = get_node_or_null("/root/DataLoader")
	if loader == null: return
	var ticket = browser.generation
	var service = browser._service(source)
	_status("Downloading the model for a preview…")
	var response: Dictionary = await service.request_bytes(str(record.get("download_url", "")), SizePolicy.limits(SizePolicy.store_for(self)).hard)
	browser._release(service)
	if ticket != browser.generation: return
	if response.has("error"):
		_status(response.error)
		return
	var bytes: PackedByteArray = response.bytes
	if not await SizePolicy.confirm(self, bytes.size(), SizePolicy.buffer_identity(bytes)):
		_status("Avatar preview canceled or above the configured size limit.")
		return
	if ticket != browser.generation: return
	if not record.get("sha256", "").is_empty() and _sha256(bytes) != record.sha256:
		_status("Source digest mismatch; preview rejected.")
		return
	if preload("res://scripts/assets/humanoid_animation.gd").new().document(bytes, AVATAR_LIMIT).is_empty():
		_status("Preview requires a bounded self-contained binary model.")
		return
	var preview = browser.preview
	preview.loader = func(_url): return await loader._load_model_from_buffer(bytes)
	preview.set_source("browser-preview")
	await preview.load_preview()
	if ticket == browser.generation and is_instance_valid(preview) and is_instance_valid(preview.model):
		_status("Preview ready. Use this avatar downloads, validates and equips it.")

func import_record(record: Dictionary, equip: bool = false):
	if browser.editor_open: return
	if not browser.registry.sources.has(record.get("provider", "")):
		_status("This provider was removed. Search again before applying.")
		return
	var loader = get_node_or_null("/root/DataLoader")
	var save = get_node_or_null("/root/SaveData")
	if loader == null or save == null or save.profile.get_local_fingerprint() != browser.account_owner: return
	var eligibility = ImportPolicy.new().evaluate(record)
	if not eligibility.can_import or not eligibility.share:
		_status("This source lacks a supported format or reviewed CC0 redistribution rights.")
		return
	var ticket = browser.generation
	var service = browser._service(browser.registry.sources[record.provider], record.provider)
	if equip:
		service.download_progress.connect(func(received, total):
			if total > 0: browser._loading_progress(clampf(float(received) / total, 0, 1) * 70, "Downloading avatar…")
			else: browser._loading_progress(0, "Downloading avatar… (%d KiB)" % (received / 1024)))
	_status("Downloading and validating; your equipped avatar is unchanged…")
	var response: Dictionary = await service.request_bytes(str(record.get("download_url", "")), SizePolicy.limits(SizePolicy.store_for(self)).hard if record.type == "avatar" else ANIMATION_LIMIT)
	browser._release(service)
	if ticket != browser.generation or not is_inside_tree() or save.profile.get_local_fingerprint() != browser.account_owner: return
	if response.has("error") or response.get("no_store", false):
		_status(str(response.get("error", "No-store assets cannot be saved as an applied source.")))
		return
	var bytes: PackedByteArray = response.bytes
	if record.type == "avatar":
		if not await SizePolicy.confirm(self, bytes.size(), SizePolicy.buffer_identity(bytes)):
			_status("Avatar import canceled or above the configured size limit.")
			return
		if ticket != browser.generation or save.profile.get_local_fingerprint() != browser.account_owner: return
	if not record.get("sha256", "").is_empty() and _sha256(bytes) != record.sha256:
		_status("Source digest mismatch; not imported.")
		return
	if record.get("in_place", false):
		if browser.conversion_thread != null:
			_status("An animation conversion is already running.")
			return
		bytes = await convert_animation(bytes)
		if ticket != browser.generation: return
		if bytes.is_empty():
			_status("In-place adaptation is still incompatible with the humanoid importer.")
			return
	var cache = loader.get_asset_cache()
	if not cache.initialize():
		_status(cache.last_error)
		return
	var path: String = cache.directory.path_join("staging/browser-" + str(Time.get_ticks_usec()))
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status("Cannot stage downloaded asset for import.")
		return
	file.store_buffer(bytes)
	file.close()
	var configuration = loader.get_avatar_configuration()
	if equip: browser._loading_progress(75, "Validating avatar…")
	var imported: Dictionary = await configuration.import_source(path, record.type == "avatar", true)
	DirAccess.remove_absolute(path)
	if ticket != browser.generation or not is_inside_tree() or save.profile.get_local_fingerprint() != browser.account_owner: return
	if imported.is_empty():
		_status(configuration.last_error)
		return
	imported.name = str(record.get("title", "Imported asset")).left(200)
	# Provider/private URLs are not persisted in source config or cache records.
	imported.provenance = {"provider": record.provider, "id": str(record.get("id", "")).left(200), "license": record.license, "author": str(record.get("author", "")).left(200)}
	if record.get("in_place", false): imported.provenance.conversion = "Removed translation tracks; retained humanoid rotations"
	if equip:
		browser._loading_progress(90, "Applying avatar…")
		if await configuration.apply(imported, configuration.sources.duplicate(true)):
			_status("Avatar applied: " + imported.name)
			browser._loading_progress(100, "Avatar changed.")
		else: _status(configuration.last_error)
		return
	var editor = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	browser.add_child(editor)
	browser.editor_open = true
	editor.tree_exited.connect(func(): browser.editor_open = false)
	if record.type == "avatar": editor.draft_model = imported
	else:
		if editor.draft_sources.size() >= 32:
			editor.queue_free()
			_status("Your library already has 32 animation sources. Remove one in Avatar configuration first.")
			return
		if not editor.draft_sources.any(func(item): return item.hash == imported.hash): editor.draft_sources.append(imported)
	editor._render()
	_status("Validated. Review the source editor and Apply explicitly to equip.")
