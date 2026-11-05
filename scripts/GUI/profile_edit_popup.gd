extends Control

signal saved
signal closed
const Identity = preload("res://scripts/profile/profile_identity.gd")
var service
var profile_owner := ""
var snapshot: Dictionary = {}
var controls: Dictionary = {}
var source_revision := 0
var confirm_discard: Control
var media = preload("res://scripts/profile/profile_media.gd").new()
var picture: TextureRect
var avatar_preview: Control
var file_picker: FileDialog
var selected_file_kind := ""
var return_focus: WeakRef
var editing_field := ""

func _ready():
	z_index = 20
	set_meta("blocks_global_shortcuts", true)
	add_child(media)
	media.icon_ready.connect(func(texture):
		if is_instance_valid(picture):
			picture.texture = texture)
	media.failed.connect(_show_error)
	$Panel/Margin/Layout/Actions/Save.pressed.connect(save_edit)
	$Panel/Margin/Layout/Actions/Cancel.pressed.connect(request_cancel)
	file_picker = FileDialog.new()
	file_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_picker.access = FileDialog.ACCESS_FILESYSTEM
	file_picker.use_native_dialog = false
	file_picker.file_selected.connect(_file_selected)
	add_child(file_picker)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			media.cancel()
			if is_instance_valid(avatar_preview):
				avatar_preview.clear_preview())

func open_editor(profile_service, fingerprint: String, field: String = "profile.username") -> bool:
	if field == "profile.avatar_url": return false # Avatar setup owns model selection.
	if field not in Identity.defaults():
		return false
	if not profile_service.can_edit(fingerprint):
		return false
	if visible and service == profile_service and profile_owner == fingerprint and editing_field == field:
		controls.values()[0].grab_focus()
		return true
	var focus = get_viewport().gui_get_focus_owner()
	return_focus = weakref(focus) if focus != null else null
	service = profile_service
	profile_owner = fingerprint
	snapshot = service.get_profile(fingerprint)
	source_revision = int(snapshot.get("revision", 0))
	editing_field = field
	_build_fields()
	$Panel/Margin/Layout/Status.text = "" if field in ["profile.username", "profile.description"] else "Save a URL. Files are preview-only, not uploaded."
	show()
	controls.values()[0].grab_focus()
	return true

func _build_fields():
	for child in $Panel/Margin/Layout/Scroll/Fields.get_children():
		$Panel/Margin/Layout/Scroll/Fields.remove_child(child)
		child.queue_free()
	controls.clear()
	picture = null
	avatar_preview = null
	for pair in [["profile.username", "Name"], ["profile.description", "Description"],
		["profile.icon_source", "Profile picture HTTPS URL (empty = default)"], ["profile.avatar_url", "Avatar VRM URL"]]:
		if not editing_field.is_empty() and pair[0] != editing_field:
			continue
		$Panel/Margin/Layout/Title.text = pair[1]
		var input: Control
		if pair[0] == "profile.description":
			input = TextEdit.new()
			input.custom_minimum_size.y = 100
			input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		else:
			input = LineEdit.new()
			input.max_length = 128 if pair[0] == "profile.username" else 4096
		input.text = str(snapshot.get(pair[0], ""))
		input.custom_minimum_size.y = 40
		controls[pair[0]] = input
		$Panel/Margin/Layout/Scroll/Fields.add_child(input)
		if pair[0] == "profile.description":
			var counter = Label.new()
			$Panel/Margin/Layout/Scroll/Fields.add_child(counter)
			var update_counter = func(): counter.text = "%d / 1024 characters" % input.text.length()
			input.text_changed.connect(update_counter)
			update_counter.call()
		if pair[0] in ["profile.icon_source", "profile.avatar_url"]:
			var actions = HBoxContainer.new()
			var preview = Button.new()
			preview.text = "Preview URL"
			preview.pressed.connect(_preview_url.bind(pair[0]))
			actions.add_child(preview)
			var file = Button.new()
			file.text = "Preview file…"
			file.tooltip_text = "Local preview only. A local path is never shared or stored as a public URL."
			file.pressed.connect(_choose_file.bind(pair[0]))
			actions.add_child(file)
			if pair[0] == "profile.icon_source":
				var reset = Button.new()
				reset.text = "Default"
				reset.pressed.connect(func():
					controls["profile.icon_source"].text = ""
					media.request_icon(""))
				actions.add_child(reset)
			$Panel/Margin/Layout/Scroll/Fields.add_child(actions)
	if editing_field == "profile.icon_source":
		picture = TextureRect.new()
		picture.custom_minimum_size = Vector2(64, 64)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture = media.DEFAULT_ICON
		$Panel/Margin/Layout/Scroll/Fields.add_child(picture)
	elif editing_field == "profile.avatar_url":
		avatar_preview = load("res://scenes/GUI/avatar_preview.tscn").instantiate()
		avatar_preview.custom_minimum_size.y = 180
		$Panel/Margin/Layout/Scroll/Fields.add_child(avatar_preview)
		avatar_preview.failed.connect(_show_error)
		avatar_preview.set_source(str(snapshot.get("profile.avatar_url", "")))

func draft() -> Dictionary:
	var values: Dictionary = snapshot.duplicate(true)
	for id in controls:
		values[id] = controls[id].text
	return values

func is_dirty() -> bool:
	for id in controls:
		if controls[id].text != snapshot.get(id):
			return true
	return false

func save_edit() -> bool:
	if service == null or not service.can_edit(profile_owner):
		_show_error("Only the profile owner can save changes.")
		return false
	if int(service.get_profile(profile_owner).get("revision", -1)) != source_revision:
		_show_error("Profile changed elsewhere. Cancel and reopen before saving.")
		return false
	if not service.save_profile(profile_owner, draft()):
		_show_error(service.last_error)
		return false
	_close()
	saved.emit()
	return true

func request_cancel():
	if is_dirty():
		_show_discard()
	else:
		_close()

func _show_discard():
	if is_instance_valid(confirm_discard):
		confirm_discard.show()
		return
	confirm_discard = Control.new()
	confirm_discard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_discard.z_index = 50
	add_child(confirm_discard)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_discard.add_child(center)
	var panel = PanelContainer.new()
	center.add_child(panel)
	var column = VBoxContainer.new()
	panel.add_child(column)
	var question = Label.new()
	question.text = "Discard unsaved profile changes?"
	column.add_child(question)
	var keep = Button.new()
	keep.text = "Keep editing"
	keep.pressed.connect(confirm_discard.hide)
	column.add_child(keep)
	var discard = Button.new()
	discard.text = "Discard"
	discard.pressed.connect(_close)
	column.add_child(discard)
	keep.grab_focus()

func cancel_edit():
	# Explicit discard, also used when switching identities/session views.
	_close()

func _close():
	file_picker.hide()
	if is_instance_valid(confirm_discard):
		confirm_discard.hide()
	var error = get_node_or_null("ErrorPopup")
	if error != null:
		error.dismiss()
	media.cancel()
	if is_instance_valid(avatar_preview):
		avatar_preview.clear_preview()
	hide()
	if return_focus != null:
		var focus = return_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	closed.emit()

func _preview_url(id: String):
	if id == "profile.icon_source":
		media.request_icon(controls[id].text)
	elif Identity.valid_url(controls[id].text):
		avatar_preview.loader = Callable()
		avatar_preview.set_source(controls[id].text)
		avatar_preview.load_preview()
	else:
		_show_error("Enter a valid HTTP(S) VRM URL.")

func _choose_file(id: String):
	selected_file_kind = id
	file_picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Profile image"]) \
		if id == "profile.icon_source" else PackedStringArray(["*.vrm ; VRM avatar"])
	file_picker.popup_centered_ratio(0.8)

func _file_selected(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	var maximum = 5 * 1024 * 1024 if selected_file_kind == "profile.icon_source" else 64 * 1024 * 1024
	if file == null or file.get_length() > maximum:
		_show_error("Selected file is unreadable or exceeds the size limit.")
		return
	var bytes = file.get_buffer(file.get_length())
	file.close()
	if selected_file_kind == "profile.icon_source":
		if path.get_extension().to_lower() not in ["png", "jpg", "jpeg", "webp"]:
			_show_error("Choose a PNG, JPEG or WebP file.")
			return
		var texture = media.texture_from_bytes(bytes)
		if texture == null:
			_show_error("Image is invalid or exceeds 2048×2048 pixels.")
			return
		media.cancel()
		picture.texture = texture
	else:
		if path.get_extension().to_lower() != "vrm":
			_show_error("Choose a VRM file.")
			return
		avatar_preview.loader = func(_source): return await DataLoader._load_model_from_buffer(bytes)
		avatar_preview.set_source("local-preview")
		avatar_preview.load_preview()
	$Panel/Margin/Layout/Status.text = "File preview only; enter a public URL to save/share this media. Your original file is unchanged."

func _show_error(message: String):
	preload("res://scripts/GUI/error_popup.gd").show_error(self, message)

func _input(event: InputEvent):
	if not is_visible_in_tree() or file_picker.visible:
		return
	var error = get_node_or_null("ErrorPopup")
	if error != null and error.visible:
		return
	if is_instance_valid(confirm_discard) and confirm_discard.visible and event is InputEventKey \
		and not event.is_action_pressed("ui_cancel") and not event.is_action("ui_accept") \
		and not event.is_action("ui_focus_next") and not event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(confirm_discard) and confirm_discard.visible:
			confirm_discard.hide()
		else:
			request_cancel()
