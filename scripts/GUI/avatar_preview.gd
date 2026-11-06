extends PanelContainer
## Avatar preview: loads a model safely into the reusable avatar stage and shows
## clear empty/loading/error/ready states (docs/roadmaps/gui-tablet-specification.md §4.5).
const FirstPerson = preload("res://scripts/assets/first_person_avatar.gd")
const MAX_LOCAL_BYTES := 1024 * 1024 * 1024
const READY_HINT = "Drag to turn · right-drag to move · scroll to zoom · double-click to reset"
const LOCAL_HINT = "Local preview only. The file is not uploaded."
const FRAMING_TITLES = {"full": "Frame: full body", "upper": "Frame: upper body", "face": "Frame: face"}

signal failed(message: String)
@onready var stage = %StageContainer
@onready var toolbar: Control = %Toolbar
@onready var status_label: Label = %StatusLabel
@onready var loading: Range = %Loading
@onready var retry_button: Button = %RetryButton
var viewport: SubViewport:
	get: return stage.viewport if stage != null else null
var source := ""
var generation := 0
var model: Node3D
var loader: Callable
var state := "empty"
var file_picker: FileDialog
var bytes_loader: Callable
var animator: Node

func _ready():
	if DataLoader.has_signal("asset_revision_available"):
		DataLoader.asset_revision_available.connect(_asset_updated)
	if "indeterminate" in loading:
		loading.indeterminate = true
	retry_button.pressed.connect(load_preview)
	stage.gui_input.connect(_preview_input)
	$ToolbarAnchor/Toolbar/Framing.pressed.connect(_cycle_framing)
	$ToolbarAnchor/Toolbar/ResetView.pressed.connect(reset_view)
	$ToolbarAnchor/Toolbar/Idle.toggled.connect(func(enabled): set_idle_animation(enabled))
	mouse_entered.connect(_show_toolbar.bind(true))
	mouse_exited.connect(func():
		if not get_global_rect().has_point(get_global_mouse_position()): _show_toolbar(false))
	visibility_changed.connect(_visibility_changed)
	$ToolbarAnchor/Toolbar/OpenFile.pressed.connect(func(): _file_dialog().popup_centered_ratio(0.8))
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("registry") != null and save.get("store") != null \
		and not save.registry.get_definition("interface.reduce_motion").is_empty():
		stage.reduce_motion = bool(save.store.get_value("interface.reduce_motion"))
		save.store.setting_changed.connect(_setting_changed)
	_show_toolbar(_in_vr())
	_set_state(state)

## Created on first use: a FileDialog builds a full file browser UI.
func _file_dialog() -> FileDialog:
	if not is_instance_valid(file_picker):
		file_picker = FileDialog.new()
		file_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_picker.access = FileDialog.ACCESS_FILESYSTEM
		file_picker.use_native_dialog = false
		file_picker.filters = PackedStringArray(["*.vrm ; VRM avatar"])
		file_picker.file_selected.connect(load_file)
		add_child(file_picker)
	return file_picker

func _exit_tree():
	generation += 1
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("store") != null and save.store.setting_changed.is_connected(_setting_changed):
		save.store.setting_changed.disconnect(_setting_changed)

func _setting_changed(id: String, value: Variant):
	if id == "interface.reduce_motion":
		stage.reduce_motion = bool(value)

func _in_vr() -> bool:
	return get_viewport() != null and get_viewport().get_meta("vr_menu", false)

## Desktop shows the toolbar on hover; the VR tablet always shows it.
func _show_toolbar(shown: bool):
	toolbar.visible = shown or _in_vr()
	toolbar.modulate.a = 1.0

func _set_state(next: String, message: String = ""):
	state = next
	loading.visible = next == "loading"
	retry_button.visible = next == "error"
	status_label.visible = next != "ready"
	match next:
		"empty":
			status_label.text = "No avatar set." if source.is_empty() else "Click to load this avatar."
		"loading":
			status_label.text = "Loading avatar…"
		"error":
			status_label.text = message if not message.is_empty() else "Could not load this avatar. Check the link and try again."
	if source == "local-preview":
		stage.tooltip_text = LOCAL_HINT + "\n" + READY_HINT
	elif next == "ready":
		stage.tooltip_text = READY_HINT
	else:
		stage.tooltip_text = "" if source.is_empty() else "Click to load this avatar"

func _asset_updated(url: String, _previous: String, _revision: String):
	if url == source and is_instance_valid(model) and is_visible_in_tree() and not loader.is_valid():
		load_preview()

func load_file(path: String) -> bool:
	if path.get_extension().to_lower() != "vrm":
		failed.emit("Choose a VRM file for the avatar preview.")
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() == 0 or file.get_length() > MAX_LOCAL_BYTES:
		failed.emit("This VRM file is unreadable, empty or larger than 1 GiB.")
		return false
	var policy = preload("res://scripts/assets/avatar_size_policy.gd")
	var ticket = generation
	if not await policy.confirm(self, file.get_length(), policy.file_identity(path)):
		failed.emit("Avatar preview canceled or above the configured size limit.")
		return false
	if ticket != generation: return false
	var bytes = file.get_buffer(file.get_length())
	file.close()
	# Local data stays in this preview; public URLs/profile and the equipped
	# avatar are untouched. Never send the original path over the network.
	loader = func(_source):
		if bytes_loader.is_valid():
			return await bytes_loader.call(bytes)
		return await DataLoader._load_model_from_buffer(bytes)
	clear_preview()
	source = "local-preview"
	await load_preview()
	return is_instance_valid(model)

func _load_if_empty():
	if not is_instance_valid(model) and state != "loading" and not source.is_empty():
		load_preview()

func set_source(url: String):
	clear_preview()
	# Restore the URL loader after a locally selected preview.
	if source == "local-preview":
		loader = Callable()
	source = url
	_set_state("empty")

func clear_preview():
	generation += 1
	_stop_animator()
	if is_node_ready():
		stage.clear()
		$ToolbarAnchor/Toolbar/Idle.set_pressed_no_signal(false)
	elif is_instance_valid(model):
		model.queue_free()
	model = null
	if is_node_ready():
		_set_state("empty")

func load_preview():
	if source.is_empty():
		return
	generation += 1
	var ticket = generation
	_set_state("loading")
	var result = await _load_model(source)
	if ticket != generation or not is_visible_in_tree():
		if is_instance_valid(result):
			result.queue_free()
		return
	if not result is Node3D or not _safe_preview_tree(result):
		if is_instance_valid(result):
			result.queue_free()
		_set_state("error")
		failed.emit(status_label.text)
		return
	_stop_animator()
	model = result
	stage.set_model(model)
	$ToolbarAnchor/Toolbar/Framing.tooltip_text = FRAMING_TITLES.full
	_set_state("ready")

func _load_model(url: String):
	if loader.is_valid():
		return await loader.call(url)
	return await DataLoader.load_vrm_from_url(url)

func _safe_preview_tree(node: Node) -> bool:
	# Preview content must not contain player/network/physics/script behavior.
	# Current GLTF loader generates model nodes; imported script-bearing trees
	# are refused before they enter the scene tree. This is not a full sandbox.
	# The production loader adds this exact bundled helper to mirror blend
	# shapes onto its first-person derivative. Disable it in preview, but do
	# not mistake it for arbitrary script-bearing downloaded content.
	var trusted_helper = node is FirstPerson.BlendShapeSync
	if (node.get_script() != null and not trusted_helper) or node is CollisionObject3D or node is AudioStreamPlayer \
		or node is AudioStreamPlayer3D:
		return false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for group in node.get_groups():
		node.remove_from_group(group)
	for child in node.get_children():
		if not _safe_preview_tree(child):
			return false
	return true

func reset_view():
	stage.reset_view()
	$ToolbarAnchor/Toolbar/Framing.tooltip_text = FRAMING_TITLES.full

func _cycle_framing():
	if is_instance_valid(model):
		$ToolbarAnchor/Toolbar/Framing.tooltip_text = FRAMING_TITLES[stage.next_framing()]

## Shows the relaxed neutral stance (bundled CC0 clip). Returns false without a humanoid rig.
func set_idle_animation(enabled: bool) -> bool:
	_stop_animator()
	var button: Button = $ToolbarAnchor/Toolbar/Idle
	if not enabled:
		button.set_pressed_no_signal(false)
		return true
	if not is_instance_valid(model) or not model.has_meta("humanoid_bones"):
		button.set_pressed_no_signal(false)
		return false
	animator = load("res://scripts/assets/avatar_animator.gd").new()
	model.add_child(animator)
	# The safe preview tree disables imported processing; enable only this layer.
	animator.process_mode = Node.PROCESS_MODE_ALWAYS
	animator.attach(model)
	var played = animator.play_clip(load("res://scripts/assets/default_animations.gd").clip("neutral"), true)
	if not played:
		_stop_animator()
	button.set_pressed_no_signal(played)
	return played

func _stop_animator():
	if is_instance_valid(animator):
		animator.stop()
		if is_instance_valid(animator.player):
			animator.player.queue_free()
		animator.queue_free()
	animator = null

func _preview_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.double_click:
					reset_view()
				else:
					_load_if_empty()
			MOUSE_BUTTON_WHEEL_UP:
				stage.zoom_by(0.85)
			MOUSE_BUTTON_WHEEL_DOWN:
				stage.zoom_by(1.15)
		stage.accept_event()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			stage.orbit(event.relative)
			stage.accept_event()
		elif event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			stage.pan(event.relative)
			stage.accept_event()

func _visibility_changed():
	if not is_visible_in_tree():
		if is_instance_valid(file_picker):
			file_picker.hide()
		clear_preview()
