extends Node3D

#@onready var http_request = HTTPRequest.new()
var _model: Node3D = null

func load_vrm_from_url(url: String):
	"""Load a VRM model from a URL"""
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request(url)
	print("Downloading modell")
	var response = await http_request.request_completed
	print("responded")
	
	if response[1] != 200:
		printerr("Download failed with response code: ", response[1])
		return
	
	var task_rid = WorkerThreadPool.add_task(_load_model_from_buffer.bindv([response[3]]))
	while not WorkerThreadPool.is_task_completed(task_rid):
		await get_tree().process_frame
	var error = WorkerThreadPool.wait_for_task_completion(task_rid)
	if error != OK:
		print("Error loading model: ", error)
	print("Model loaded on background thread")
	return _model

func _load_model_from_buffer(buffer: PackedByteArray) -> Node3D:
	# Load VRM from byte data directly in background
	var gltf: GLTFDocument = GLTFDocument.new()	
	var state: GLTFState = GLTFState.new()
	
	# Load from buffer instead of file
	var err = gltf.append_from_buffer(buffer, "", state, 8)
	if err != OK:
		printerr("Failed to load model from buffer (Error code: %d)" % err)
		return null
	
	var generated_scene = gltf.generate_scene(state)
	
	_model = generated_scene
	
	return _model

func _load_model_from_file(path: String) -> Node3D:
	"""Load VRM from file path (for local files)"""
	var gltf: GLTFDocument = GLTFDocument.new()
	var vrm_extension: GLTFDocumentExtension = preload("res://addons/vrm/vrm_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm_extension, true)
	
	var state: GLTFState = GLTFState.new()
	
	var err = gltf.append_from_file(path, state, 8)
	if err != OK:
		printerr("Failed to load model from path: %s (Error code: %d)" % [path, err])
		GLTFDocument.unregister_gltf_document_extension(vrm_extension)
		return null
	
	var generated_scene = gltf.generate_scene(state)
	GLTFDocument.unregister_gltf_document_extension(vrm_extension)
	
	if _model != null:
		_model.free()
	
	_model = generated_scene
	add_child(_model)
	
	return generated_scene



func load_world_from_url(cne_word_url: String) -> bool:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.call_deferred("request", cne_word_url)
	print("Downloading World")
	var response = await http_request.request_completed
	if response[1] != 200:
		printerr("Download failed with response code: ", response[1])
		return false

	DirAccess.make_dir_absolute("user://worlds")
	
	var file = FileAccess.open("user://worlds/temp.cne", FileAccess.WRITE)
	file.store_buffer(response[3])
	file.close()
	print("Model downloaded")
	load_world("user://worlds/temp.cne")
	DirAccess.remove_absolute("user://worlds/temp.cne")
	return true

func load_world(cne_word_path: String) -> bool:
	var extract_path = "user://worlds/temp/"
	
	if not extract_zip(cne_word_path, extract_path):
		print("Failed to extract map")
		return false
	
	# Read and parse manifest
	var manifest = load_manifest(extract_path + "manifest.json")
	if manifest == null:
		print("Invalid manifest")
		return false
	
	# Load the main scene
	var main_scene_path = extract_path + manifest["main_scene"]
	
	NetworkHandler.create_session()
	get_tree().change_scene_to_file(main_scene_path)
	
	
	var player = get_tree().get_nodes_in_group("player")[0]
	if player:
		if manifest.has("spawn_point"):
			var sp = manifest["spawn_point"]
			player.set_player_pos(Vector3(sp[0],sp[1],sp[2]))
		else:
			player.set_player_pos(Vector3(0,0,0))
	
	print("Map loaded successfully: ", manifest["name"])
	return true

func extract_zip(zip_path: String, extract_to: String) -> bool:
	var reader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		print("Failed to open ZIP: ", zip_path)
		return false
	
	var files = reader.get_files()
	for file in files:
		if file.ends_with("/"):
			continue
		
		# Extract file
		var content = reader.read_file(file)
		var full_path = extract_to + file
		
		create_directories_recursive(full_path.get_base_dir())
		
		var f = FileAccess.open(full_path, FileAccess.WRITE)
		if f == null:
			print("Failed to write: ", full_path)
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
	
	return json.get_data()

func create_directories_recursive(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		return
	
	var parent = path.get_base_dir()
	if parent != path and parent != "":
		create_directories_recursive(parent)
	
	DirAccess.make_dir_absolute(path)
