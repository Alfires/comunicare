extends Node3D

var avatar_import_busy := false
var avatar_import_waiters := 0
var avatar_thread: Thread
signal asset_revision_available(source: String, previous: String, revision: String)
var asset_cache: Node
var cache_poll_elapsed := 0.0
var avatar_sources: Dictionary = {}
var active_world: Dictionary = {}
var animation_thread: Thread
var animation_waiters := 0
var animation_import_busy := false
var animation_import_error := ""
var avatar_configuration: Node
var world_runtime: Node
var world_pickups: Node
var world_thread: Thread
var world_prepare_busy := false
var world_prepare_waiters := 0
signal world_loading_progress(stage: String, fraction: float)

func get_world_pickups() -> Node:
	if not is_instance_valid(world_pickups):
		world_pickups = preload("res://scripts/worlds/world_pickup_controller.gd").new()
		add_child(world_pickups)
		world_pickups.configure(get_node_or_null("/root/NetworkHandler"), self)
	return world_pickups

func _ready():
	add_child(preload("res://scripts/assets/interaction_highlight.gd").new())
	get_tree().node_added.connect(_configure_avatar_camera)

func _configure_avatar_camera(node: Node):
	preload("res://scripts/assets/first_person_avatar.gd").configure_camera(node)

func get_avatar_configuration() -> Node:
	if avatar_configuration == null:
		avatar_configuration = preload("res://scripts/assets/avatar_configuration.gd").new()
		add_child(avatar_configuration)
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("profile") != null:
		var owner: String = save.profile.get_local_fingerprint()
		if not owner.is_empty() and avatar_configuration.account_owner != owner:
			var temporary = save.get("temporary_identity") == true
			avatar_configuration.memory_only = temporary
			avatar_configuration.configure(owner, "" if temporary else "user://avatars/" + owner + ".json", self)
	return avatar_configuration
const MAX_AVATAR_BYTES = 256 * 1024 * 1024
const MAX_AVATAR_WAITERS = 8

func get_asset_cache() -> Node:
	if asset_cache == null:
		asset_cache = preload("res://scripts/assets/asset_cache.gd").new()
		asset_cache.name = "AssetCache"
		add_child(asset_cache)
		asset_cache.revision_available.connect(func(source, previous, revision):
			# Initial acquisition is not an update. Defer callbacks until fetch has
			# released its coalescing job; consumers may immediately request bytes.
			if not previous.is_empty():
				asset_revision_available.emit.call_deferred(source, previous, revision))
		var settings = get_node_or_null("/root/SaveData")
		if settings != null and settings.get("store") != null:
			if not settings.store.setting_changed.is_connected(_cache_setting_changed):
				settings.store.setting_changed.connect(_cache_setting_changed)
			for id in ["cache.quota_mib", "cache.automatic_refresh", "cache.allow_http", "cache.trust_remote_worlds"]:
				_cache_setting_changed(id, settings.store.get_value(id))
	return asset_cache

func _cache_setting_changed(id: String, value: Variant):
	if asset_cache == null or value == null:
		return
	match id:
		"cache.quota_mib": asset_cache.quota_bytes = int(value) * 1024 * 1024
		"cache.automatic_refresh": asset_cache.automatic_refresh = value == true
		"cache.allow_http": asset_cache.allow_http = value == true
		"cache.trust_remote_worlds": asset_cache.trust_remote_worlds = value == true
		"world.scripts_enabled":
			if value == false: stop_world_scripts()

func load_vrm_from_url(url: String, force: bool = false):
	if url in [preload("res://scripts/assets/default_robot.gd").URL, preload("res://scripts/assets/default_robot.gd").LEGACY]:
		return preload("res://scripts/assets/default_robot.gd").create()
	var cache = get_asset_cache()
	var handle: Dictionary = await cache.fetch(url, "avatar", _validate_avatar, force)
	if handle.is_empty():
		return null
	var model = await _load_model_from_file(handle.path)
	if model != null:
		model.set_meta("asset_lease", handle.lease)
		model.set_meta("asset_revision", handle.hash)
		model.set_meta("asset_source", url)
		if not avatar_sources.has(url):
			avatar_sources[url] = []
		avatar_sources[url].append(weakref(model))
	return model

func read_animation(path: String, bytes: PackedByteArray = PackedByteArray()) -> Dictionary:
	if not is_inside_tree() or animation_waiters >= 8:
		return {}
	animation_waiters += 1
	while animation_import_busy:
		await get_tree().process_frame
	animation_waiters -= 1
	animation_import_busy = true
	animation_thread = Thread.new()
	if animation_thread.start(_read_animation_worker.bind(path, bytes)) != OK:
		animation_thread = null
		animation_import_busy = false
		return {}
	while animation_thread.is_alive():
		await get_tree().process_frame
	var result: Dictionary = animation_thread.wait_to_finish()
	animation_thread = null
	animation_import_busy = false
	animation_import_error = result.get("error", "")
	return result.get("data", {})

func _read_animation_worker(path: String, bytes: PackedByteArray) -> Dictionary:
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	var data = reader.read_file(path) if not path.is_empty() else reader.read_bytes(bytes)
	return {"data": data, "error": reader.last_error}

func _validate_avatar(path: String, require_humanoid: bool = false) -> bool:
	# URL VRM assets must be self-contained binary glTF; a local preview's
	# existing byte import remains independent from this network trust gate.
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_AVATAR_BYTES:
		return false
	var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
	var bytes = file.get_buffer(file.get_length())
	file.close()
	if reader.document(bytes, MAX_AVATAR_BYTES).is_empty():
		return false
	var model = await _load_model_from_file(path)
	if model == null:
		return false
	if require_humanoid:
		var compatible = reader._skeleton(model) != null and not model.get_meta("humanoid_bones", {}).is_empty()
		model.free()
		return compatible
	model.free()
	return true

func _process(delta: float):
	cache_poll_elapsed += delta
	if cache_poll_elapsed < 900 or asset_cache == null or not asset_cache.automatic_refresh:
		return
	cache_poll_elapsed = randf_range(-30, 30)
	for source in avatar_sources.keys():
		avatar_sources[source] = avatar_sources[source].filter(func(reference): return reference.get_ref() != null)
		if avatar_sources[source].is_empty():
			avatar_sources.erase(source)
		else:
			await asset_cache.fetch(source, "avatar", _validate_avatar)
	if not active_world.get("source_url", "").is_empty():
		await asset_cache.fetch(active_world.source_url, "world", _validate_world_archive)
	await _refresh_avatar_sources(false)

func _refresh_avatar_sources(force: bool):
	if avatar_configuration == null: return
	var cache = get_asset_cache()
	var configured: Array = avatar_configuration.sources.duplicate(true)
	if not avatar_configuration.model.is_empty():
		var source: Dictionary = avatar_configuration.model.duplicate(true)
		if not source.get("url", "").is_empty():
			await cache.fetch(source.url, "avatar", avatar_configuration._validate_model, force)
	for source in configured:
		if not source.get("url", "").is_empty():
			await cache.fetch(source.url, "animation", avatar_configuration._validate_animation, force)

func refresh_loaded_assets():
	var cache = get_asset_cache()
	for source in avatar_sources.keys():
		avatar_sources[source] = avatar_sources[source].filter(func(reference): return reference.get_ref() != null)
		if not avatar_sources[source].is_empty():
			await cache.fetch(source, "avatar", _validate_avatar, true)
	if not active_world.get("source_url", "").is_empty():
		await cache.fetch(active_world.source_url, "world", _validate_world_archive, true)
	await _refresh_avatar_sources(true)

func _load_model_from_buffer(buffer: PackedByteArray) -> Node3D:
	if buffer.is_empty() or buffer.size() > MAX_AVATAR_BYTES:
		return null
	return await _import_avatar(buffer, "")

func _load_model_from_file(path: String) -> Node3D:
	return await _import_avatar(PackedByteArray(), path)

func _import_avatar(buffer: PackedByteArray, path: String) -> Node3D:
	if not is_inside_tree() or avatar_import_waiters >= MAX_AVATAR_WAITERS:
		return null
	avatar_import_waiters += 1
	while avatar_import_busy:
		await get_tree().process_frame
	avatar_import_waiters -= 1
	avatar_import_busy = true
	avatar_thread = Thread.new()
	var error = avatar_thread.start(_build_avatar.bind(buffer, path))
	if error != OK:
		avatar_import_busy = false
		avatar_thread = null
		return null
	# Never join a running importer on the frame thread. Each job owns all of its
	# resources and creates a detached tree; only callers attach it on this thread.
	while avatar_thread.is_alive():
		await get_tree().process_frame
	var result = avatar_thread.wait_to_finish()
	avatar_thread = null
	avatar_import_busy = false
	return result as Node3D

func _build_avatar(buffer: PackedByteArray, path: String) -> Node3D:
	# Worker only: no SceneTree access, shared import state, global extension
	# registration, or reparenting. Do not install per-job extensions globally.
	if not path.is_empty():
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() == 0 or file.get_length() > MAX_AVATAR_BYTES:
			return null
		buffer = file.get_buffer(file.get_length())
		file.close()
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var error = gltf.append_from_buffer(buffer, "", state, 8)
	if error != OK:
		return null
	var model = gltf.generate_scene(state) as Node3D
	if model != null:
		var reader = preload("res://scripts/assets/humanoid_animation.gd").new()
		var mapping = reader.humanoid_nodes(state.json)
		var bone_names: Dictionary = {}
		var nodes = state.get_nodes()
		for bone in mapping:
			if mapping[bone] < nodes.size():
				bone_names[bone] = nodes[mapping[bone]].resource_name
		model.set_meta("humanoid_bones", bone_names)
		model.set_meta("vrm_legacy_orientation", state.json.get("extensions", {}).has("VRM"))
		preload("res://scripts/assets/avatar_rig_profile.gd").prepare(model)
		var annotations: Dictionary = {}
		var extensions: Dictionary = state.json.get("extensions", {})
		var first_person = extensions.get("VRMC_vrm", {}).get("firstPerson", {})
		for entry in first_person.get("meshAnnotations", []):
			var index = int(entry.get("node", -1))
			if index >= 0 and index < nodes.size(): annotations[str(nodes[index].resource_name)] = entry.get("type", "auto")
		var legacy = extensions.get("VRM", {}).get("firstPerson", {})
		for entry in legacy.get("meshAnnotations", []):
			var flag = str(entry.get("firstPersonFlag", "Auto"))
			var types = {"Auto": "auto", "Both": "both", "ThirdPersonOnly": "thirdPersonOnly", "FirstPersonOnly": "firstPersonOnly"}
			for index in nodes.size():
				if nodes[index].mesh == int(entry.get("mesh", -1)) and nodes[index].mesh >= 0:
					annotations[str(nodes[index].resource_name)] = types.get(flag, "auto")
		preload("res://scripts/assets/first_person_avatar.gd").prepare(model, annotations)
	return model

func _exit_tree():
	if world_thread != null and world_thread.is_started():
		world_thread.wait_to_finish()
		world_thread = null
	if animation_thread != null and animation_thread.is_started():
		animation_thread.wait_to_finish()
		animation_thread = null
	# Shutdown is the only blocking join. A detached result must not leak if the
	# owning loader is removed before its awaiting caller can receive the model.
	if avatar_thread != null and avatar_thread.is_started():
		var result = avatar_thread.wait_to_finish()
		if is_instance_valid(result):
			result.free()
		avatar_thread = null


func load_world_from_url(cne_word_url: String) -> bool:
	var staged = await prepare_world_from_url(cne_word_url)
	return await activate_world(staged) if not staged.is_empty() else false

func prepare_world_from_url(url: String, expected_revision: String = "") -> Dictionary:
	if not WorldAddress.is_valid(url):
		return {}
	if url == "default_wold":
		var home = load("res://scenes/world.tscn")
		var revision = built_in_world_revision()
		if not expected_revision.is_empty() and expected_revision != revision:
			return {}
		var spawn = preload("res://scripts/worlds/welcome_island/home_contract.gd").SPAWN
		return {"scene": home, "spawn_point": [spawn.x, spawn.y, spawn.z], "revision": revision} if home is PackedScene and not revision.is_empty() else {}
	var cache = get_asset_cache()
	var handle: Dictionary = cache.revision_handle(expected_revision) if not expected_revision.is_empty() else {}
	if handle.is_empty():
		handle = await cache.fetch(url, "world", _validate_world_archive)
	if handle.is_empty():
		return {}
	if not expected_revision.is_empty() and handle.hash != expected_revision:
		cache.last_error = "The instance's pinned world revision is no longer available at this URL."
		return {}
	# Never activate old extracted resource graphs or .ready markers. Rebuild
	# application-owned nodes from the exact verified immutable archive instead.
	var staged = await prepare_world_async(handle.path)
	if not staged.is_empty():
		staged["asset_handle"] = handle
		staged["revision"] = handle.hash
		staged["source_url"] = url
	return staged

func built_in_world_revision() -> String:
	# The built-in scene is shipped with the application, not publisher content.
	return preload("res://scripts/worlds/welcome_island/home_contract.gd").revision()

class TemporaryWorld extends RefCounted:
	var cache: WeakRef
	var path: String
	func _notification(what):
		if what == NOTIFICATION_PREDELETE and cache != null:
			var owner = cache.get_ref()
			if is_instance_valid(owner):
				owner._clear_directory(path)
				if DirAccess.dir_exists_absolute(path):
					DirAccess.remove_absolute(path)

func _validate_world_archive(path: String) -> bool:
	var result = await _world_job(path, false)
	if not result.ok: get_asset_cache().last_error = result.error
	return result.ok

func load_world(cne_word_path: String) -> bool:
	var extract_path = "user://worlds/" + str(Time.get_ticks_usec()) + "/content/"
	var staged = await prepare_world_async(cne_word_path)
	return await activate_world(staged) if not staged.is_empty() else false

func prepare_world(archive_path: String, _extract_path: String) -> Dictionary:
	var result = preload("res://scripts/worlds/world_builder.gd").new().build_package(archive_path)
	if not result.ok:
		get_asset_cache().last_error = result.error
		return {}
	return result

func prepare_world_async(path: String) -> Dictionary:
	world_loading_progress.emit("Preparing validated world", 0.0)
	var result = await _world_job(path, true)
	if not result.get("ok", false):
		get_asset_cache().last_error = result.get("error", "World preparation failed")
		return {}
	world_loading_progress.emit("World prepared", 0.8)
	return result

func _world_job(path: String, build: bool) -> Dictionary:
	if not is_inside_tree() or world_prepare_waiters >= 4: return {"ok": false, "error": "World preparation queue full"}
	world_prepare_waiters += 1
	while world_prepare_busy: await get_tree().process_frame
	world_prepare_waiters -= 1
	world_prepare_busy = true
	world_thread = Thread.new()
	if world_thread.start(_build_world_job.bind(path, build)) != OK:
		world_thread = null
		world_prepare_busy = false
		return {"ok": false, "error": "Cannot start world preparation worker"}
	while world_thread.is_alive(): await get_tree().process_frame
	var result: Dictionary = world_thread.wait_to_finish()
	world_thread = null
	world_prepare_busy = false
	return result

func _build_world_job(path: String, build: bool) -> Dictionary:
	# All nodes remain detached; no SceneTree or global extension registration.
	if build: return preload("res://scripts/worlds/world_builder.gd").new().build_package(path)
	return preload("res://scripts/worlds/world_package_reader.gd").new().inspect_package(path)

func _prepare_extracted_world(_extract_path: String) -> Dictionary:
	# Compatibility entry point deliberately fails closed: unpacked legacy
	# content has no verified safe archive/document boundary.
	return {}

func activate_world(staged: Dictionary) -> bool:
	if not staged.get("scene") is PackedScene:
		return false
	if is_instance_valid(world_pickups): world_pickups.reset()
	if get_tree().change_scene_to_packed(staged.scene) != OK:
		return false
	await get_tree().scene_changed
	var activating_scene = get_tree().current_scene
	# Collision is installed with the scene before visual reveal. Bound first
	# visibility/upload work across frames rather than revealing every mesh at once.
	var reveal: Array = []
	if staged.get("document") is Dictionary:
		for mesh in get_tree().current_scene.find_children("*", "MeshInstance3D", true, false):
			if mesh.visible:
				mesh.hide()
				reveal.append(mesh)
		var spawn_position = staged.get("spawn_point", [0, 0, 0])
		var center = Vector3(spawn_position[0], spawn_position[1], spawn_position[2])
		reveal.sort_custom(func(a, b): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
		for player in get_tree().get_nodes_in_group("player"):
			if player.has_method("set_player_pos"): player.set_player_pos(center)
		for index in reveal.size():
			if is_instance_valid(reveal[index]): reveal[index].show()
			if index % 8 == 7:
				world_loading_progress.emit("Revealing nearby world", 0.8 + 0.2 * float(index + 1) / reveal.size())
				await get_tree().process_frame
				if not is_instance_valid(activating_scene) or get_tree().current_scene != activating_scene: return false
	active_world = staged.duplicate()
	if staged.get("document") is Dictionary:
		world_runtime = preload("res://scripts/worlds/world_runtime.gd").new()
		get_tree().current_scene.add_child(world_runtime)
		var configured = world_runtime.configure(get_tree().current_scene, staged.document)
		var save = get_node_or_null("/root/SaveData")
		if "storage.local" in world_runtime.capabilities and save != null and save.get("profile") != null:
			world_runtime.local_store = preload("res://scripts/worlds/world_local_store.gd").new()
			world_runtime.local_store.configure(save.profile.get_local_fingerprint(), str(staged.get("source_url", "")), save.get("temporary_identity") == true)
		if save != null and save.get("store") != null and not save.store.setting_changed.is_connected(_cache_setting_changed):
			save.store.setting_changed.connect(_cache_setting_changed)
		var enabled = save == null or save.get("store") == null or save.store.get_value("world.scripts_enabled") != false
		if configured.ok and enabled:
			world_runtime.dispatch("start", "")
		else:
			world_runtime.stop_scripts()
		get_world_pickups().activate(get_tree().current_scene, staged.document, str(staged.get("revision", "")))
	var spawn = staged.get("spawn_point", [0, 0, 0])
	for player in get_tree().get_nodes_in_group("player"):
		if player is Node3D:
			preload("res://scripts/worlds/welcome_island/home_contract.gd").reset_player(player, Vector3(spawn[0], spawn[1], spawn[2]))
	world_loading_progress.emit("Ready", 1.0)
	return true

func stop_world_scripts():
	if is_instance_valid(world_runtime): world_runtime.stop_scripts()

func _safe_archive_path(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not ":" in path \
		and not "\\" in path and not ".." in path.split("/")

func extract_zip(zip_path: String, extract_to: String) -> bool:
	var reader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		print("Failed to open ZIP: ", zip_path)
		return false

	var files = reader.get_files()
	if files.size() > 4096:
		reader.close()
		return false
	var total_bytes = 0
	for file in files:
		if not _safe_archive_path(file):
			reader.close()
			return false
		if file.ends_with("/"):
			continue

		# Extract file
		var content = reader.read_file(file)
		total_bytes += content.size()
		if total_bytes > 256 * 1024 * 1024:
			reader.close()
			return false
		var full_path = extract_to + file

		create_directories_recursive(full_path.get_base_dir())

		var f = FileAccess.open(full_path, FileAccess.WRITE)
		if f == null:
			print("Failed to write: ", full_path)
			reader.close()
			return false
		f.store_buffer(content)
		f = null

	reader.close()
	return true

func load_manifest(manifest_path: String) -> Dictionary:
	var file = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		print("Manifest not found: ", manifest_path)
		return {}

	var json_string = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		print("Failed to parse manifest JSON")
		return {}

	return json.data if json.data is Dictionary else {}

func create_directories_recursive(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		return

	var parent = path.get_base_dir()
	if parent != path and parent != "":
		create_directories_recursive(parent)

	DirAccess.make_dir_absolute(path)
