extends Node
## Account-scoped source selection; never store private paths in public profiles.

signal changed
const Defaults = preload("res://scripts/assets/default_animations.gd")
const Layout = preload("res://scripts/assets/emote_layout.gd")
const ROLES = ["walk", "run", "strafe_left", "strafe_right", "jump"]
var account_owner := ""
var path := ""
var revision := 0
var model: Dictionary = {}
var sources: Array = []
var roles: Dictionary = {}
var emotes: Dictionary = {}
var layout = Layout.new()
var writable := true
var memory_only := false
var last_error := ""
var loader: Node
var generation := 0
var pending_updates: Dictionary = {}
var applying_update := false

func _ready():
	if loader != null and loader.has_signal("asset_revision_available") and not loader.asset_revision_available.is_connected(_source_updated):
		loader.asset_revision_available.connect(_source_updated)

func _source_updated(url: String, previous: String, next: String):
	pending_updates[url] = {"previous": previous, "next": next}
	if applying_update: return
	applying_update = true
	while not pending_updates.is_empty():
		var source_url: String = pending_updates.keys()[0]
		var update: Dictionary = pending_updates[source_url]
		pending_updates.erase(source_url)
		await _apply_source_update(source_url, update.previous, update.next)
	applying_update = false

func _apply_source_update(url: String, previous: String, next: String):
	var candidate_model = model.duplicate(true)
	var candidate_sources = sources.duplicate(true)
	var updated := false
	if candidate_model.get("url") == url and candidate_model.get("hash") == previous:
		candidate_model.hash = next
		updated = true
	for source in candidate_sources:
		if source.get("url") == url and source.get("hash") == previous:
			source.hash = next
			updated = true
	if updated: await apply(candidate_model, candidate_sources)

func configure(fingerprint: String, file_path: String, data_loader: Node):
	generation += 1
	pending_updates.clear()
	account_owner = fingerprint
	path = file_path
	loader = data_loader
	if loader.has_signal("asset_revision_available") and not loader.asset_revision_available.is_connected(_source_updated):
		loader.asset_revision_available.connect(_source_updated)
	revision = 0
	model = {}
	sources = []
	writable = true
	last_error = ""
	_reset_catalog()
	layout.configure("" if memory_only else path + ".wheel.json")
	if not memory_only and FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var parser = JSON.new()
		if file == null or file.get_length() > 1024 * 1024 or parser.parse(file.get_as_text()) != OK \
			or not _valid_store(parser.data):
			writable = false
			last_error = "Avatar configuration corrupt or owned by another account; original preserved."
		else:
			model = parser.data.model
			sources = parser.data.sources
			revision = int(parser.data.revision)
	changed.emit()
	_restore()

func _valid_store(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1 or value.get("owner") != account_owner \
		or not value.get("model") is Dictionary or not value.get("sources") is Array \
		or value.sources.size() > 32 or not value.get("revision") is float \
		or value.revision < 0 or value.revision > 2147483647 or value.revision != int(value.revision):
		return false
	if not value.model.is_empty() and not _valid_source(value.model):
		return false
	for source in value.sources:
		if not _valid_source(source):
			return false
	return true

func _valid_source(value: Variant) -> bool:
	return value is Dictionary and preload("res://scripts/assets/asset_cache.gd").valid_hash(value.get("hash")) \
		and value.get("name") is String and value.name.length() <= 256 \
		and value.get("share", false) is bool and value.get("url", "") is String \
		and value.get("url", "").length() <= 4096

func _reset_catalog():
	roles.clear()
	emotes.clear()
	for id in Defaults.IDS:
		var item = {"id": "builtin:" + id, "name": id.capitalize(), "clip": Defaults.clip(id),
			"builtin": id, "handle": {}, "index": 0, "share": true, "loop": id in ["walk", "run", "strafe_left", "strafe_right", "fall", "dance"]}
		if id in ROLES: roles[id] = item
		else: emotes[item.id] = item

func _restore():
	var ticket = generation
	var restored: Array = []
	for source in sources:
		var handle = loader.get_asset_cache().revision_handle(source.hash)
		if handle.is_empty():
			last_error = "An applied animation source is missing from the cache; defaults remain available."
			continue
		var parsed = await loader.read_animation(handle.path)
		if ticket != generation:
			return
		if not parsed.is_empty(): restored.append({"source": source, "handle": handle, "parsed": parsed})
	if ticket != generation: return
	_reset_catalog()
	# Embedded clips precede external overrides.
	if not model.is_empty():
		var handle = loader.get_asset_cache().revision_handle(model.hash)
		if not handle.is_empty():
			var parsed = await loader.read_animation(handle.path)
			if ticket != generation: return
			if not parsed.is_empty(): _merge_source(model, handle, parsed)
	for item in restored:
		_merge_source(item.source, item.handle, item.parsed)
	# Always surface newly applied emotes, even after the wheel was customized.
	# Existing placements are preserved and never duplicated across groups.
	if layout.writable:
		var assigned := {}
		var seen_ids: Array = layout.groups.get("imports", {}).get("known_ids", []).duplicate()
		for group in layout.groups.values():
			for entry in group.entries:
				if entry.type == "emote": assigned[entry.id] = true
		var imported: Array = []
		for id in emotes:
			if not id.begins_with("builtin:") and not assigned.has(id) and not id in seen_ids:
				imported.append({"type": "emote", "id": id, "name": emotes[id].name.left(128)})
		if not imported.is_empty():
			var candidate = layout.groups.duplicate(true)
			if not candidate.has("imports"):
				candidate["imports"] = {"name": "Imported emotes", "entries": []}
			candidate.imports.entries.append_array(imported)
			for id in emotes:
				if not id.begins_with("builtin:") and not id in seen_ids: seen_ids.append(id)
			candidate.imports.known_ids = seen_ids
			if not candidate.root.entries.any(func(entry): return entry.type == "group" and entry.id == "imports"):
				candidate.root.entries.append({"type": "group", "id": "imports", "name": candidate.imports.name})
			layout.commit(candidate)
	changed.emit()

static func role_for(name: String) -> String:
	var normalized = name.to_lower().strip_edges().replace(" ", "").replace("_", "").replace("-", "")
	for role in ROLES:
		if normalized == role.replace("_", "") or normalized == role.replace("_", "") + "loop":
			return role
	return ""

func _merge_source(source: Dictionary, handle: Dictionary, parsed: Dictionary):
	for index in parsed.clips.size():
		var clip: Dictionary = parsed.clips[index]
		var id: String = source.hash + ":" + str(index)
		var role = role_for(clip.name)
		if clip.name.to_lower().strip_edges() in ["idle", "idle_loop", "land", "jump_land", "fall", "fall_loop", "jump_loop"]: continue
		var item = {"id": id, "name": clip.name + " • " + source.name, "clip": clip,
			"builtin": "", "handle": handle, "index": index, "share": source.get("share", false),
			"loop": role in ["idle", "walk", "run", "fall"] or clip.name.to_lower().ends_with("loop")}
		if role.is_empty(): emotes[id] = item
		else: roles[role] = item

func import_source(source: String, is_model: bool, share_allowed: bool) -> Dictionary:
	if loader == null or account_owner.is_empty() or not writable:
		last_error = "Avatar configuration is unavailable or read-only for this account."
		return {}
	last_error = ""
	var cache = loader.get_asset_cache()
	var ticket = generation
	var validator: Callable = _validate_model if is_model else _validate_animation
	var kind = "avatar" if is_model else "animation"
	var handle: Dictionary
	var is_url = source.begins_with("https://") or source.begins_with("http://")
	if is_url: handle = await cache.fetch(source, kind, validator)
	else: handle = await cache.import_file(source, kind, validator)
	if ticket != generation: return {}
	if handle.is_empty():
		if last_error.is_empty():
			last_error = cache.last_error if not cache.last_error.is_empty() else ("Avatar model import failed. Check that the file is a supported self-contained humanoid VRM/GLB." if is_model else loader.animation_import_error)
		return {}
	if handle.get("temporary", false):
		last_error = "No-store sources cannot be saved as an applied avatar configuration."
		return {}
	return {"hash": handle.hash, "name": source.get_file().split("?")[0].left(256),
		"url": source if is_url else "", "share": share_allowed}

func _validate_animation(path_to_file: String) -> bool:
	var parsed = await loader.read_animation(path_to_file)
	if parsed.is_empty(): last_error = loader.animation_import_error
	return not parsed.is_empty()

func _validate_model(path_to_file: String) -> bool:
	if not await loader._validate_avatar(path_to_file, true):
		last_error = "Avatar model validation failed or loading was canceled: expected a self-contained humanoid VRM/GLB within the configured size limit (maximum 1 GiB), with a compatible skeleton and declared mapping."
		return false
	# Embedded motion is optional. Model validity must not depend on standalone
	# animation limits (16 MiB/64 clips/rotation-only); _restore skips unsupported
	# embedded clips and retains bundled/external movement defaults.
	return true

func apply(candidate_model: Dictionary, candidate_sources: Array) -> bool:
	last_error = ""
	if not writable or account_owner.is_empty() or candidate_sources.size() > 32:
		last_error = "Avatar configuration is read-only, has no account owner, or exceeds 32 animation sources."
		return false
	if not candidate_model.is_empty() and not _valid_source(candidate_model):
		last_error = "Invalid avatar selection. Import and validate the model again."
		return false
	for source in candidate_sources:
		if not _valid_source(source):
			last_error = "Invalid animation source. Import and validate the animation again."
			return false
	var ticket = generation
	for source in candidate_sources:
		var source_handle = loader.get_asset_cache().revision_handle(source.hash)
		if source_handle.is_empty() or (await loader.read_animation(source_handle.path)).is_empty():
			last_error = "An animation source is missing or invalid; the applied configuration was not changed."
			return false
		if ticket != generation: return false
	# Build a detached model before committing so a failed candidate never equips.
	if not candidate_model.is_empty():
		var handle = loader.get_asset_cache().revision_handle(candidate_model.hash)
		if handle.is_empty():
			last_error = "Selected avatar is missing from the cache. Import it again before applying."
			return false
		if not await _validate_model(handle.path):
			last_error = "Applied model must contain a compatible humanoid skeleton."
			return false
		if ticket != generation: return false
	if ticket != generation: return false
	var candidate = {"schema": 1, "owner": account_owner, "revision": revision + 1,
		"model": candidate_model, "sources": candidate_sources}
	if not _save(candidate): return false
	generation += 1
	model = candidate_model.duplicate(true)
	sources = candidate_sources.duplicate(true)
	revision += 1
	for source in sources + ([model] if not model.is_empty() else []):
		loader.get_asset_cache().pin_revision(source.hash)
	await _restore()
	return true

func _save(value: Dictionary) -> bool:
	if memory_only: return true
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Cannot save avatar configuration."
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "Cannot commit avatar configuration."
		return false
	return true

func model_key(fallback: String) -> String:
	return "cache:" + model.hash if not model.is_empty() else fallback

func active_avatar(fallback: String) -> Dictionary:
	if model.is_empty(): return {"key": fallback, "url": fallback, "name": "Profile / default avatar", "cached": false}
	return {"key": "cache:" + model.hash, "url": str(model.get("url", "")), "name": str(model.get("name", "Imported avatar")), "cached": true}

func load_model(fallback: String) -> Node3D:
	if model.is_empty(): return await loader.load_vrm_from_url(fallback)
	var handle = loader.get_asset_cache().revision_handle(model.hash)
	if handle.is_empty():
		last_error = "Configured model is missing; using profile avatar fallback."
		return await loader.load_vrm_from_url(fallback)
	var result = await loader._load_model_from_file(handle.path)
	if result != null:
		result.set_meta("asset_lease", handle.lease)
		result.set_meta("asset_revision", handle.hash)
	return result
