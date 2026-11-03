extends Control

signal closed
var service
var profile_owner := ""
var snapshot: Dictionary = {}
var editor: Control
var media = preload("res://scripts/profile/profile_media.gd").new()
@onready var body: VBoxContainer = $Content/Details/DetailsScroll/Body
@onready var edit_button: Button = $Content/Details/Header/Edit
@onready var avatar_preview: Control = $Content/AvatarColumn/AvatarPreview
var edit_buttons: Dictionary = {}
var friend_actions: HFlowContainer

func _ready():
	$Content/Details/Header/Back.pressed.connect(_close)
	edit_button.pressed.connect(open_editor)
	edit_buttons = {
		"profile.username": body.get_node("Identity/NameColumn/EditName"),
		"profile.description": body.get_node("DescriptionRow/EditDescription"),
		"profile.icon_source": body.get_node("Identity/ImageColumn/EditImage"),
		"profile.avatar_url": $Content/AvatarColumn/EditAvatar,
	}
	for field in edit_buttons:
		edit_buttons[field].text = ""
		edit_buttons[field].icon = preload("res://themes/icons/edit.svg")
		edit_buttons[field].tooltip_text = "Edit " + field.trim_prefix("profile.").replace("_", " ")
		edit_buttons[field].custom_minimum_size = Vector2(36, 36)
		edit_buttons[field].pressed.connect(open_editor.bind(field))
	body.get_node("KeyActions/ShowKey").toggled.connect(func(value): body.get_node("FullPublicKey").visible = value)
	body.get_node("KeyActions/CopyKey").pressed.connect(func(): DisplayServer.clipboard_set(get_displayed_public_key()))
	body.get_node("LoadPicture").pressed.connect(func(): media.request_icon(str(snapshot.get("profile.icon_source", ""))))
	add_child(media)
	media.icon_ready.connect(func(texture): body.get_node("Identity/ImageColumn/Picture").texture = texture)
	media.failed.connect(_show_error)
	avatar_preview.failed.connect(_show_error)
	friend_actions = HFlowContainer.new()
	body.add_child(friend_actions)
	body.move_child(friend_actions, 1)

func open_profile(profile_service, fingerprint: String):
	if is_instance_valid(editor):
		editor.cancel_edit()
	_unsubscribe()
	service = profile_service
	profile_owner = fingerprint
	service.profile_changed.connect(_profile_changed)
	service.remote_profiles_changed.connect(_remote_changed)
	show()
	_refresh()

func is_editable() -> bool:
	return service != null and service.can_edit(profile_owner)

func get_displayed_public_key() -> String:
	return str(snapshot.get("public_key", ""))

func _refresh():
	media.cancel()
	snapshot = service.get_profile(profile_owner)
	edit_button.hide()
	for button in edit_buttons.values():
		button.visible = is_editable() and not snapshot.is_empty()
	body.get_node("Identity/ImageColumn/Picture").texture = media.DEFAULT_ICON
	body.get_node("Identity/NameColumn/Name").text = str(snapshot.get("profile.username", "Profile unavailable"))
	body.get_node("Identity/NameColumn/Name").tooltip_text = body.get_node("Identity/NameColumn/Name").text
	var description = str(snapshot.get("profile.description", ""))
	body.get_node("DescriptionRow/Description").text = description if not description.is_empty() else "No description yet."
	body.get_node("Fingerprint").text = "Public key fingerprint:\n" + profile_owner if not snapshot.is_empty() else ""
	body.get_node("FullPublicKey").text = get_displayed_public_key()
	body.get_node("FullPublicKey").hide()
	body.get_node("KeyActions/ShowKey").set_pressed_no_signal(false)
	body.get_node("KeyActions").visible = not snapshot.is_empty()
	body.get_node("LoadPicture").visible = not str(snapshot.get("profile.icon_source", "")).is_empty()
	body.get_node("Status").text = "My profile" if is_editable() else "Read-only • owner-signed public profile"
	var avatar_source = str(snapshot.get("profile.avatar_url", ""))
	var avatar_changed = avatar_preview.source != avatar_source
	if avatar_changed:
		avatar_preview.set_source(avatar_source)
	if not snapshot.is_empty() \
		and (avatar_changed or not is_instance_valid(avatar_preview.model)):
		avatar_preview.load_preview()
	if snapshot.is_empty():
		if is_instance_valid(editor):
			editor.cancel_edit()
		_show_error("Profile unavailable: account key is not loaded or user left the instance.")
	elif is_editable():
		# Own icon source is already user-approved. Visitor fetches stay opt-in.
		media.request_icon(str(snapshot.get("profile.icon_source", "")))

func open_editor(field: String = "profile.username") -> bool:
	if not is_editable():
		return false
	if not is_instance_valid(editor):
		editor = load("res://scenes/GUI/profile_edit_popup.tscn").instantiate()
		add_child(editor)
		editor.saved.connect(_refresh)
	return editor.open_editor(service, profile_owner, field)

func _show_error(message: String):
	body.get_node("Status").text = message
	preload("res://scripts/GUI/error_popup.gd").show_error(self, message)

func cancel_edit():
	if is_instance_valid(editor) and editor.visible:
		editor.cancel_edit()
	else:
		_close()

func _unhandled_input(event: InputEvent):
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(editor) and editor.visible:
			editor.request_cancel()
		else:
			_close()

func _close():
	if is_instance_valid(editor):
		editor.cancel_edit()
	media.cancel()
	avatar_preview.clear_preview()
	hide()
	closed.emit()

func _profile_changed(changed_owner: String):
	if changed_owner == profile_owner:
		_refresh()

func _remote_changed():
	if not is_editable():
		_refresh()

func _unsubscribe():
	if service != null:
		if service.profile_changed.is_connected(_profile_changed):
			service.profile_changed.disconnect(_profile_changed)
		if service.remote_profiles_changed.is_connected(_remote_changed):
			service.remote_profiles_changed.disconnect(_remote_changed)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and not is_visible_in_tree():
		media.cancel()
		if is_instance_valid(editor):
			editor.cancel_edit()

func _exit_tree():
	_unsubscribe()
