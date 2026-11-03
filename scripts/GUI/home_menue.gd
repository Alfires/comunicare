extends Control

const MIC_ICON = preload("res://themes/icons/microphone.svg")
const MUTED_ICON = preload("res://themes/icons/microphone_muted.svg")
const PROFILE_ICON = preload("res://themes/icons/profile.svg")

@onready var microphone: Button = $VBoxContainer/HBoxContainer/Microphone
@onready var profile_button: Button = $VBoxContainer/HBoxContainer/Profile
var profile_panel: Control
var profile_media = preload("res://scripts/profile/profile_media.gd").new()
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
