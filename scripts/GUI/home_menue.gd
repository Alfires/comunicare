extends Control

const MIC_ICON = preload("res://themes/icons/microphone.svg")
const MUTED_ICON = preload("res://themes/icons/microphone_muted.svg")
const PROFILE_ICON = preload("res://themes/icons/profile.svg")

@onready var microphone: Button = $VBoxContainer/HBoxContainer/Microphone
@onready var profile_button: Button = $VBoxContainer/HBoxContainer/Profile
var profile_panel: Control
var profile_media = preload("res://scripts/profile/profile_media.gd").new()
@onready var status_selector: OptionButton = $VBoxContainer/Status
var submenu_page: Control
var submenu_kind := ""
var return_focus: Control

func _ready():
	profile_button.icon = PROFILE_ICON
	profile_button.pressed.connect(_open_self_profile)
	add_child(profile_media)
	profile_media.icon_ready.connect(func(texture): profile_button.icon = texture)
	if SaveData.get("profile") != null:
		SaveData.profile.profile_changed.connect(_profile_changed)
		_profile_changed(SaveData.profile.get_local_fingerprint())
	microphone.toggled.connect(_on_toggled)
	SaveData.voice.mute_changed.connect(_update)
	SaveData.voice.availability_changed.connect(_availability_changed)
	SaveData.store.setting_changed.connect(_setting_changed)
	_update(SaveData.voice.is_muted())
	if SaveData.get("friends") != null:
		status_selector.item_selected.connect(func(index): SaveData.friends.set_status(["online", "do_not_disturb", "offline"][index]))
		SaveData.friends.changed.connect(_status_changed)
		_status_changed()
	else:
		status_selector.disabled = true
	$VBoxContainer/MenuGrid/WorldExplorer.pressed.connect(open_home_menu.bind("world_explorer"))
	$VBoxContainer/MenuGrid/ActiveInstance.pressed.connect(open_home_menu.bind("share_session_menue"))
	$Submenu/Back.pressed.connect(close_home_menu)
	visibility_changed.connect(_visibility_changed)

func _status_changed():
	if is_instance_valid(status_selector) and not SaveData.friends.state.is_empty():
		status_selector.select(["online", "do_not_disturb", "offline"].find(SaveData.friends.state.preferred_status))

func _on_toggled(muted: bool):
	SaveData.voice.set_muted(muted)

func _update(muted: bool):
	microphone.set_pressed_no_signal(muted)
	microphone.text = ""
	microphone.icon = MUTED_ICON if muted else MIC_ICON
	microphone.tooltip_text = ("Unmute microphone" if muted else "Mute microphone") \
		+ " (" + SaveData.voice.binding_text() + ")"
	if not SaveData.voice.availability.is_empty():
		microphone.tooltip_text += "\n" + SaveData.voice.availability

func _availability_changed(_message: String):
	_update(SaveData.voice.is_muted())

func _setting_changed(id: String, _value: Variant):
	if id == "input.toggle_microphone":
		_update(SaveData.voice.is_muted())

func _exit_tree():
	if SaveData.get("friends") != null and SaveData.friends.changed.is_connected(_status_changed):
		SaveData.friends.changed.disconnect(_status_changed)
	SaveData.voice.mute_changed.disconnect(_update)
	SaveData.voice.availability_changed.disconnect(_availability_changed)
	SaveData.store.setting_changed.disconnect(_setting_changed)
	if SaveData.get("profile") != null:
		SaveData.profile.profile_changed.disconnect(_profile_changed)

func _profile_changed(owner: String):
	if owner == SaveData.profile.get_local_fingerprint():
		profile_media.request_icon(str(SaveData.profile.get_profile(owner).get("profile.icon_source", "")))

func _open_self_profile():
	if SaveData.get("profile") != null:
		open_profile(SaveData.profile.get_local_fingerprint())

func open_profile(owner: String):
	if not is_instance_valid(profile_panel):
		profile_panel = load("res://scenes/GUI/profile_menue.tscn").instantiate()
		add_child(profile_panel)
		profile_panel.closed.connect(func():
			if submenu_kind.is_empty():
				$VBoxContainer.show())
	$VBoxContainer.hide()
	profile_panel.open_profile(SaveData.profile, owner)

func open_home_menu(kind: String):
	if kind not in ["world_explorer", "share_session_menue"]:
		return
	if kind == "world_explorer" and get_parent() is TabContainer:
		var explorer = get_parent().get_node_or_null("world_explorer")
		if explorer != null:
			get_parent().current_tab = get_parent().get_tab_idx_from_control(explorer)
			return
	close_home_menu()
	submenu_kind = kind
	return_focus = $VBoxContainer/MenuGrid/WorldExplorer if kind == "world_explorer" else $VBoxContainer/MenuGrid/ActiveInstance
	# Lazy construction avoids HTTP/discovery work until the option is opened.
	submenu_page = load("res://scenes/GUI/" + kind + ".tscn").instantiate()
	$VBoxContainer.hide()
	$Submenu.show()
	$Submenu/Content.add_child(submenu_page)
	$Submenu/Back.grab_focus()

func close_home_menu():
	if is_instance_valid(submenu_page):
		$Submenu/Content.remove_child(submenu_page)
		submenu_page.queue_free()
	submenu_page = null
	submenu_kind = ""
	$Submenu.hide()
	$VBoxContainer.show()
	if is_instance_valid(return_focus) and is_visible_in_tree():
		return_focus.grab_focus()

func reset_home():
	if is_instance_valid(profile_panel) and profile_panel.visible:
		profile_panel.cancel_edit()
	close_home_menu()

func _visibility_changed():
	if is_node_ready() and not is_visible_in_tree():
		reset_home()
