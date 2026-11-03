extends Node3D

func load_vrm_from_url(url: String):
	var http = HTTPRequest.new()
	http.timeout = 30
	http.body_size_limit = 64 * 1024 * 1024
	add_child(http)
	if http.request(url) != OK:
		http.queue_free()
		return null
	var response = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return null
	return _load_model_from_buffer(response[3])

func _load_model_from_buffer(bytes: PackedByteArray) -> Node3D:
	var document = GLTFDocument.new()
	var state = GLTFState.new()
	if document.append_from_buffer(bytes, "", state, 8) != OK:
		return null
	return document.generate_scene(state) as Node3D

func load_world_from_url(cne_word_url: String) -> bool:
	var staged = await prepare_world_from_url(cne_word_url)
	return await activate_world(staged) if not staged.is_empty() else false

func prepare_world_from_url(url: String) -> Dictionary:
	if not WorldAddress.is_valid(url):
		return {}
	if url == "default_wold":
		var home = load("res://scenes/world.tscn")
		return {"scene": home, "spawn_point": [0, 1, 0]} if home is PackedScene else {}
	var directory = "user://worlds/" + str(Time.get_ticks_usec()) + "/"
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return {}
	var http_request = HTTPRequest.new()
	http_request.timeout = 30
	http_request.body_size_limit = 128 * 1024 * 1024
	add_child(http_request)
	var error = http_request.request(url)
	if error != OK:
		http_request.queue_free()
		return {}
	var response = await http_request.request_completed
	http_request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return {}
	var archive_path = directory + "world.cne"
	var file = FileAccess.open(archive_path, FileAccess.WRITE)
	if file == null:
		return {}
	file.store_buffer(response[3])
	file.close()
	var staged = prepare_world(archive_path, directory + "content/")
	DirAccess.remove_absolute(archive_path)
	return staged

func load_world(cne_word_path: String) -> bool:
	var extract_path = "user://worlds/" + str(Time.get_ticks_usec()) + "/content/"
	var staged = prepare_world(cne_word_path, extract_path)
	return await activate_world(staged) if not staged.is_empty() else false

func prepare_world(archive_path: String, extract_path: String) -> Dictionary:
	if not extract_zip(archive_path, extract_path):
		return {}
	var manifest = load_manifest(extract_path + "manifest.json")
	if not manifest.get("main_scene") is String or not _safe_archive_path(manifest.main_scene):
		return {}
	var scene_path = extract_path.path_join(manifest.main_scene)
	if not scene_path.ends_with(".tscn") and not scene_path.ends_with(".scn"):
		return {}
	var scene = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if not scene is PackedScene or not scene.can_instantiate():
		return {}
	var spawn = manifest.get("spawn_point", [0, 0, 0])
	if not spawn is Array or spawn.size() != 3:
		return {}
	for coordinate in spawn:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
			return {}
	return {"scene": scene, "spawn_point": spawn}

func activate_world(staged: Dictionary) -> bool:
	if not staged.get("scene") is PackedScene:
		return false
	if get_tree().change_scene_to_packed(staged.scene) != OK:
		return false
	await get_tree().scene_changed
	var spawn = staged.get("spawn_point", [0, 0, 0])
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("set_player_pos"):
			player.set_player_pos(Vector3(spawn[0], spawn[1], spawn[2]))
	return true

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
