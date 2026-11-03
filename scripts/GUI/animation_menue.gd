extends Control

const Reader = preload("res://scripts/assets/humanoid_animation.gd")
const Defaults = preload("res://scripts/assets/default_animations.gd")
var clips: Array = []
var selected: OptionButton
var status: Label
var link: LineEdit
var looping: CheckButton
var speed: SpinBox
var picker: FileDialog
var handle: Dictionary = {}
var source_url := ""
var generation := 0
var reader = Reader.new()
var full_body: CheckButton
var share: CheckButton
var clip_handles: Array = []
var clip_indices: Array = []

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var layout = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	scroll.add_child(layout)
	var title = Label.new()
	title.text = "Animations"
	layout.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Defaults: original CC0 motions. Imported clips must use humanoid metadata and rotation-only tracks."
	layout.add_child(status)
	selected = OptionButton.new()
	selected.custom_minimum_size.y = 44
	layout.add_child(selected)
	for id in Defaults.IDS:
		clips.append(Defaults.clip(id))
		clip_handles.append({})
		clip_indices.append(0)
		selected.add_item("Default • " + id.capitalize())
	selected.item_selected.connect(func(_index): stop())
	link = LineEdit.new()
	link.placeholder_text = "HTTPS link to a self-contained .vrma or humanoid .glb"
	link.max_length = 4096
	layout.add_child(link)
	_button(layout, "Add animation link", func(): import_link(link.text.strip_edges()))
	_button(layout, "Import animation file (.vrma / .glb)", func(): picker.popup_centered_ratio(0.8))
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.vrma,*.glb ; Humanoid animation"])
	picker.file_selected.connect(import_file)
	add_child(picker)
	looping = CheckButton.new()
	looping.text = "Loop"
	looping.button_pressed = true
	layout.add_child(looping)
	speed = SpinBox.new()
	speed.min_value = 0.25
	speed.max_value = 2.0
	speed.step = 0.25
	speed.value = 1.0
	speed.prefix = "Speed "
	layout.add_child(speed)
	full_body = CheckButton.new()
	full_body.text = "Allow full-body playback in VR (tracking still owns head and hands)"
	layout.add_child(full_body)
	share = CheckButton.new()
	share.text = "Share imported motion with this instance (I have redistribution permission)"
	layout.add_child(share)
	_button(layout, "Play on my avatar", play)
	_button(layout, "Pause", func():
		NetworkHandler.get_animation_controller().pause(true))
	_button(layout, "Resume", func():
		NetworkHandler.get_animation_controller().pause(false))
	_button(layout, "Stop", stop)
	_button(layout, "Remove selected imported motion", _confirm_remove)
	_button(layout, "Use automatic desktop locomotion", func():
		NetworkHandler.get_animation_controller().stop()
		NetworkHandler.get_animation_controller().automatic_motion = true
		status.text = "Automatic desktop locomotion enabled.")
	var remote = CheckButton.new()
	remote.text = "Accept synchronized remote animations and requested motion downloads"
	remote.button_pressed = NetworkHandler.get_animation_controller().accept_remote
	remote.toggled.connect(func(value):
		var controller = NetworkHandler.get_animation_controller()
		controller.accept_remote = value
		if not value:
			for id in controller.remote_states.keys():
				controller._remove_remote(id))
	layout.add_child(remote)
	_restore_imports()

func _confirm_remove():
	if selected.selected < Defaults.IDS.size():
		status.text = "Built-in defaults cannot be removed."
		return
	var revision: String = clip_handles[selected.selected].get("hash", "")
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Remove this imported motion from the managed library? The original external file is not changed."
	add_child(confirm)
	confirm.confirmed.connect(func():
		stop()
		handle.clear()
		for i in range(clips.size() - 1, Defaults.IDS.size() - 1, -1):
			if clip_handles[i].get("hash") == revision:
				clip_handles.remove_at(i)
				clip_indices.remove_at(i)
				clips.remove_at(i)
				selected.remove_item(i)
		selected.select(0)
		# Yield until outstanding importer/fetch frames have released handles.
		await get_tree().process_frame
		var cache = DataLoader.get_asset_cache()
		status.text = "Motion removed." if cache.remove_revision(revision) else cache.last_error
		confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

func _restore_imports():
	if not DataLoader.has_method("get_asset_cache"):
		return
	var cache = DataLoader.get_asset_cache()
	if not cache.initialize():
		return
	var seen: Dictionary = {}
	for record in cache.records.values():
		if record.kind != "animation" or not record.get("pinned", false) or seen.has(record.hash):
			continue
		seen[record.hash] = true
		var saved = cache.revision_handle(record.hash)
		if saved.is_empty():
			continue
		var parsed = await DataLoader.read_animation(saved.path)
		if not is_inside_tree():
			return
		if parsed.is_empty():
			continue
		_append_clips(parsed, saved)

func _append_clips(parsed: Dictionary, saved: Dictionary):
	for i in parsed.clips.size():
		clips.append(parsed.clips[i])
		clip_handles.append(saved)
		clip_indices.append(i)
		selected.add_item("Imported • " + parsed.clips[i].name)

func _button(parent: Node, text: String, action: Callable):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)

func validate(path: String) -> bool:
	var parsed = await DataLoader.read_animation(path)
	return not parsed.is_empty()

func import_file(path: String):
	if path.get_extension().to_lower() not in ["vrma", "glb"]:
		status.text = "Choose a .vrma or .glb animation."
		return
	generation += 1
	var ticket = generation
	status.text = "Validating animation…"
	var result = await DataLoader.get_asset_cache().import_file(path, "animation", validate)
	if ticket != generation or not is_inside_tree():
		return
	await _install(result, "")

func import_link(url: String):
	generation += 1
	var ticket = generation
	status.text = "Downloading and validating animation…"
	var result = await DataLoader.get_asset_cache().fetch(url, "animation", validate)
	if ticket != generation or not is_inside_tree():
		return
	await _install(result, url)

func _install(result: Dictionary, url: String):
	if result.is_empty():
		status.text = DataLoader.animation_import_error if not DataLoader.animation_import_error.is_empty() else DataLoader.get_asset_cache().last_error
		return
	var parsed = await DataLoader.read_animation(result.path)
	if not is_inside_tree():
		return
	if parsed.is_empty():
		status.text = reader.last_error
		return
	stop()
	handle = result
	if not result.get("temporary", false):
		DataLoader.get_asset_cache().pin_revision(result.hash)
	source_url = url
	var first = clips.size()
	_append_clips(parsed, result)
	selected.select(first)
	share.set_pressed_no_signal(false)
	status.text = "Imported %s clip(s). Enable sharing only if you have permission to redistribute the motion. Links are downloaded locally; only requested verified bytes are shared, never local paths or URL secrets." % parsed.clips.size()

func play():
	var controller = NetworkHandler.get_animation_controller()
	controller.automatic_motion = false
	var builtin = Defaults.IDS[selected.selected] if selected.selected < Defaults.IDS.size() else ""
	if share.button_pressed and clip_handles[selected.selected].get("temporary", false):
		status.text = "This source forbids persistent caching (no-store). Its temporary motion cannot be redistributed."
		return
	controller.play(clips[selected.selected], builtin, clip_handles[selected.selected], clip_indices[selected.selected],
		looping.button_pressed, speed.value, share.button_pressed, full_body.button_pressed)
	status.text = controller.last_error

func stop():
	if NetworkHandler.has_method("get_animation_controller"):
		NetworkHandler.get_animation_controller().automatic_motion = false
		NetworkHandler.get_animation_controller().stop()

func _exit_tree():
	generation += 1
	# Closing a menu must not stop the equipped player's animation.
