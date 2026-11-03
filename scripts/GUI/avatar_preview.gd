extends PanelContainer

signal failed(message: String)
@onready var viewport: SubViewport = $Layout/ViewportContainer/Viewport
@onready var pivot: Node3D = $Layout/ViewportContainer/Viewport/Stage/Pivot
@onready var camera: Camera3D = $Layout/ViewportContainer/Viewport/Stage/Camera
var source := ""
var generation := 0
var model: Node3D
var loader: Callable
var fitted_distance := 3.0
var zoom := 1.0
var file_picker: FileDialog
var bytes_loader: Callable

func _ready():
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	$Layout/Load.pressed.connect(load_preview)
	$Layout/Controls/Left.pressed.connect(func(): pivot.rotate_y(0.3))
	$Layout/Controls/Right.pressed.connect(func(): pivot.rotate_y(-0.3))
	$Layout/Controls/ZoomIn.pressed.connect(_zoom.bind(0.85))
	$Layout/Controls/ZoomOut.pressed.connect(_zoom.bind(1.15))
	$Layout/Controls/Reset.pressed.connect(reset_view)
	$Layout/Controls/Left.pressed.connect(_load_if_empty)
	$Layout/Controls/Right.pressed.connect(_load_if_empty)
	$Layout/ViewportContainer.gui_input.connect(_preview_input)
	visibility_changed.connect(_visibility_changed)
	$Layout/ViewportContainer.resized.connect(_resize_viewport)
	_resize_viewport()
	file_picker = FileDialog.new()
	file_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_picker.access = FileDialog.ACCESS_FILESYSTEM
	file_picker.use_native_dialog = false
	file_picker.filters = PackedStringArray(["*.vrm ; VRM avatar"])
	file_picker.file_selected.connect(load_file)
	add_child(file_picker)
	$Layout/Controls/OpenFile.pressed.connect(func(): file_picker.popup_centered_ratio(0.8))

func load_file(path: String) -> bool:
	if path.get_extension().to_lower() != "vrm":
		failed.emit("Choose a VRM file for the avatar preview.")
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() == 0 or file.get_length() > 64 * 1024 * 1024:
		failed.emit("VRM file is unreadable, empty or larger than 64 MiB.")
		return false
	var bytes = file.get_buffer(file.get_length())
	file.close()
	# Loading local data is isolated to this preview; public URLs/profile and the
	# equipped avatar are untouched. Never send the original path over network.
	loader = func(_source):
		if bytes_loader.is_valid():
			return await bytes_loader.call(bytes)
		return await DataLoader._load_model_from_buffer(bytes)
	clear_preview()
	source = "local-preview"
	$Layout/ViewportContainer.tooltip_text = "Local file preview only • drag to rotate • scroll to zoom"
	await load_preview()
	return is_instance_valid(model)

func _load_if_empty():
	if not is_instance_valid(model) and not $Layout/Load.disabled:
		load_preview()

func set_source(url: String):
	clear_preview()
	# Restore the URL loader after a locally selected preview.
	if source == "local-preview":
		loader = Callable()
	source = url
	$Layout/Load.disabled = source.is_empty()
	$Layout/ViewportContainer.tooltip_text = "Drag to rotate" if source.is_empty() else "Click to load avatar (external request), then drag to rotate"
	$Layout/Status.text = "Load an independent 3D preview." if not source.is_empty() else "No avatar available."

func clear_preview():
	generation += 1
	if is_instance_valid(model):
		pivot.remove_child(model)
		model.queue_free()
	model = null
	if is_node_ready():
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		$Layout/Load.disabled = false
		$Layout/Status.text = "Load an independent 3D preview."

func load_preview():
	if source.is_empty():
		return
	generation += 1
	var ticket = generation
	$Layout/Load.disabled = true
	$Layout/Status.text = "Loading avatar…"
	var result = await _load_model(source)
	if ticket != generation or not is_visible_in_tree():
		if is_instance_valid(result):
			result.queue_free()
		return
	$Layout/Load.disabled = false
	if not result is Node3D or not _safe_preview_tree(result):
		if is_instance_valid(result):
			result.queue_free()
		$Layout/Status.text = "Avatar preview failed. Retry with a trusted VRM URL."
		failed.emit($Layout/Status.text)
		return
	if is_instance_valid(model):
		pivot.remove_child(model)
		model.queue_free()
	model = result
	pivot.add_child(model)
	_fit_model()
	$Layout/Status.text = "Drag to rotate • scroll or +/− to zoom"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _load_model(url: String):
	if loader.is_valid():
		return await loader.call(url)
	return await DataLoader.load_vrm_from_url(url)

func _safe_preview_tree(node: Node) -> bool:
	# Preview content must not contain player/network/physics/script behavior.
	# Current GLTF loader generates model nodes; imported script-bearing trees
	# are refused before they enter the scene tree. This is not a full sandbox.
	if node.get_script() != null or node is CollisionObject3D or node is AudioStreamPlayer \
		or node is AudioStreamPlayer3D:
		return false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for group in node.get_groups():
		node.remove_from_group(group)
	for child in node.get_children():
		if not _safe_preview_tree(child):
			return false
	return true

func _bounds(node: Node, parent_transform: Transform3D, result: Array):
	var transform = parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var box: AABB = transform * node.get_aabb()
		if box.position.is_finite() and box.size.is_finite():
			if result.is_empty():
				result.append(box)
			else:
				result[0] = result[0].merge(box)
	for child in node.get_children():
		_bounds(child, transform, result)

func _fit_model():
	var boxes: Array = []
	_bounds(model, Transform3D.IDENTITY, boxes)
	if not boxes.is_empty():
		var box: AABB = boxes[0]
		var extent = maxf(box.size.x, maxf(box.size.y, box.size.z))
		if is_finite(extent) and extent > 0.00001:
			# Normalize around origin: stable framing even for tiny/huge models.
			var scale_factor = 2.0 / extent
			model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor),
				-box.get_center() * scale_factor) * model.transform
	var aspect = maxf(float(viewport.size.x) / maxf(1, viewport.size.y), 0.1)
	var half_fov = deg_to_rad(camera.fov * 0.5)
	fitted_distance = maxf(3.5, 1.3 / (tan(half_fov) * minf(aspect, 1.0)))
	camera.near = 0.01
	camera.far = 100
	reset_view()

func reset_view():
	# VRM/glTF characters face -Z; camera is on +Z, so turn their front toward it.
	pivot.rotation = Vector3(0, PI, 0)
	zoom = 1.0
	camera.position = Vector3(0, 0, fitted_distance)

func _zoom(factor: float):
	zoom = clampf(zoom * factor, 0.5, 3.0)
	camera.position.z = fitted_distance * zoom

func _preview_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_load_if_empty()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.85)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.15)
		accept_event()
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		pivot.rotate_y(event.relative.x * 0.01)
		accept_event()

func _resize_viewport():
	var dimensions: Vector2 = $Layout/ViewportContainer.size
	# stretch_shrink keeps render resolution bounded without altering layout.
	$Layout/ViewportContainer.stretch_shrink = maxi(1, ceili(maxf(dimensions.x, dimensions.y) / 768.0))

func _visibility_changed():
	if not is_visible_in_tree():
		if is_instance_valid(file_picker):
			file_picker.hide()
		clear_preview()
		$Layout/Status.text = "Load an independent 3D preview."

func _exit_tree():
	generation += 1
