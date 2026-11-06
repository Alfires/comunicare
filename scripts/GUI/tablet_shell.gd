extends PanelContainer
## Shared tablet layout for the PC overlay and the VR tablet
## (docs/roadmaps/gui-tablet-specification.md §3–§4.1). Owns navigation:
## pages never build their own tabs or back buttons.

signal close_requested
signal quick_action(id: String)
signal page_changed(id: String)

const PAGES = ["quick", "friends", "worlds", "avatars", "instance", "settings"]
const SCENES = {
	"quick": "res://scenes/GUI/quick_page.tscn",
	"friends": "res://scenes/GUI/friends_menue.tscn",
	"worlds": "res://scenes/GUI/world_explorer.tscn",
	"avatars": "res://scenes/GUI/avatar_browser.tscn",
	"instance": "res://scenes/GUI/share_session_menue.tscn",
	"settings": "res://scenes/GUI/settings_menue.tscn",
}
const TITLES = {"quick": "Quick", "friends": "Friends", "worlds": "Worlds", "avatars": "Avatars", "instance": "Instance", "settings": "Settings"}
const ICONS = {"quick": "quick", "friends": "friends", "worlds": "world", "avatars": "avatar", "instance": "instance", "settings": "settings"}
const TOOLTIPS = {
	"quick": "Quick actions and online friends",
	"friends": "Contacts, requests and friend profiles",
	"worlds": "Browse worlds and join instances",
	"avatars": "Find, preview and change avatars",
	"instance": "People, invites and settings of the current instance",
	"settings": "All settings",
}
const PRESENCE = ["online", "do_not_disturb", "offline"]
const PRESENCE_LABELS = ["Online", "Do not disturb", "Appear offline"]
const MIC_ICON = preload("res://themes/icons/microphone.svg")
const MUTED_ICON = preload("res://themes/icons/microphone_muted.svg")
const PROFILE_ICON = preload("res://themes/icons/profile.svg")

## id → Callable returning a Control. Prefilled with the production scenes;
## tests and hosts may replace entries before the page is first opened.
var page_factories: Dictionary = {}
var pages: Dictionary = {}
var stack: Array = []
var current := ""
var compact := false
var vr_mode := false
var profile_panel: Control
var nav_buttons: Dictionary = {}
var _nav_group := ButtonGroup.new()
var _clock_timer: Timer
var _profile_media

func _init():
	for id in PAGES:
		var path: String = SCENES[id]
		page_factories[id] = func(): return load(path).instantiate()

func _ready():
	var toasts = preload("res://scripts/GUI/toast_host.gd").new()
	toasts.name = "Toasts"
	%ContentArea.add_child(toasts)
	set_meta("toast_host", toasts)
	_build_nav()
	%BackButton.pressed.connect(back)
	%CloseButton.pressed.connect(func(): close_requested.emit())
	%ProfileButton.pressed.connect(open_own_profile)
	%MicButton.toggled.connect(_mic_toggled)
	%PinButton.toggled.connect(_pin_toggled)
	%PresenceButton.get_popup().id_pressed.connect(_presence_chosen)
	_clock_timer = Timer.new()
	_clock_timer.wait_time = 15.0
	_clock_timer.timeout.connect(_update_clock)
	add_child(_clock_timer)
	_clock_timer.start()
	_update_clock()
	var save = _save()
	if save != null:
		save.voice.mute_changed.connect(_mute_changed)
		save.voice.availability_changed.connect(_availability_changed)
		save.store.setting_changed.connect(_setting_changed)
		_mute_changed(save.voice.is_muted())
		if save.get("friends") != null:
			save.friends.changed.connect(_presence_changed)
		if save.get("profile") != null and ResourceLoader.exists("res://scripts/profile/profile_media.gd"):
			_profile_media = load("res://scripts/profile/profile_media.gd").new()
			add_child(_profile_media)
			_profile_media.icon_ready.connect(func(texture): %ProfileButton.icon = texture)
			save.profile.profile_changed.connect(_profile_changed)
			_profile_changed(save.profile.get_local_fingerprint())
	_presence_changed()
	var network = _network()
	if network != null:
		for name in ["active_instance_changed", "participants_changed"]:
			if network.has_signal(name):
				network.connect(name, refresh_status)
	refresh_status()
	set_vr_mode(get_viewport() != null and get_viewport().get_meta("vr_menu", false))
	open_page("quick")

func _exit_tree():
	var save = _save()
	if save == null:
		return
	for pair in [[save.voice.mute_changed, _mute_changed], [save.voice.availability_changed, _availability_changed],
		[save.store.setting_changed, _setting_changed]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	if save.get("friends") != null and save.friends.changed.is_connected(_presence_changed):
		save.friends.changed.disconnect(_presence_changed)
	if save.get("profile") != null and save.profile.profile_changed.is_connected(_profile_changed):
		save.profile.profile_changed.disconnect(_profile_changed)
	var network = _network()
	if network != null:
		for name in ["active_instance_changed", "participants_changed"]:
			if network.has_signal(name) and network.is_connected(name, refresh_status):
				network.disconnect(name, refresh_status)

func _save() -> Node:
	return get_node_or_null("/root/SaveData")

func _network() -> Node:
	return get_node_or_null("/root/NetworkHandler")

# --- navigation --------------------------------------------------------------

func _build_nav():
	for id in PAGES:
		var button = Button.new()
		button.name = TITLES[id] + "Nav"
		button.text = TITLES[id]
		button.tooltip_text = TOOLTIPS[id]
		button.theme_type_variation = "NavButton"
		button.toggle_mode = true
		button.button_group = _nav_group
		button.icon = load("res://themes/icons/%s.svg" % ICONS[id])
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size = Vector2(96, 72)
		button.set_meta("page_id", id)
		button.pressed.connect(open_page.bind(id))
		%NavList.add_child(button)
		nav_buttons[id] = button

func page_ids() -> Array:
	return PAGES.duplicate()

func page_scene_paths() -> Dictionary:
	return SCENES.duplicate()

func current_page() -> String:
	return current

## Returns the page control, creating it on first use.
func page(id: String) -> Control:
	if not id in PAGES:
		return null
	if not is_instance_valid(pages.get(id)):
		var control: Control = page_factories[id].call()
		control.set_meta("page_id", id)
		control.visible = false
		%Content.add_child(control)
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages[id] = control
		if control.has_signal("action_requested"):
			control.action_requested.connect(handle_quick_action)
		if control.has_signal("friend_selected"):
			control.friend_selected.connect(func(owner): open_profile(owner))
		if control.has_signal("open_page_requested"):
			control.open_page_requested.connect(open_page)
	return pages[id]

func open_page(id: String) -> bool:
	if not id in PAGES:
		return false
	_clear_stack()
	var target = page(id)
	current = id
	for key in pages:
		if is_instance_valid(pages[key]):
			pages[key].visible = key == id
	# set_pressed_no_signal bypasses ButtonGroup exclusivity; update every item.
	for key in nav_buttons:
		nav_buttons[key].set_pressed_no_signal(key == id)
	_update_header()
	page_changed.emit(id)
	return target != null

func push_page(control: Control, title: String):
	var top = _top()
	if top != null:
		top.visible = false
	if control.get_parent() == null:
		%Content.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.visible = true
	stack.append({"control": control, "title": title})
	_update_header()

func back() -> bool:
	if stack.is_empty():
		return false
	var entry: Dictionary = stack.pop_back()
	var control: Control = entry.control
	if is_instance_valid(control):
		if control == profile_panel:
			profile_panel = null
		control.get_parent().remove_child(control)
		control.queue_free()
	var top = _top()
	if top != null:
		top.visible = true
	_update_header()
	return true

func reset():
	if is_instance_valid(profile_panel) and profile_panel.has_method("cancel_edit") and profile_panel.visible:
		profile_panel.cancel_edit()
	_clear_stack()
	# Pages are rebuilt on next use so closed menus hold no subscriptions or requests.
	for id in pages.keys():
		if id != "quick" and is_instance_valid(pages[id]):
			pages[id].get_parent().remove_child(pages[id])
			pages[id].queue_free()
			pages.erase(id)
	open_page("quick")

func _clear_stack():
	while not stack.is_empty():
		back()

func _top() -> Control:
	if not stack.is_empty():
		return stack.back().control
	return pages.get(current) if is_instance_valid(pages.get(current)) else null

func _update_header():
	%PageTitle.text = stack.back().title if not stack.is_empty() else TITLES.get(current, "")
	%BackButton.visible = not stack.is_empty()

# --- layout ------------------------------------------------------------------

func set_compact(value: bool):
	compact = value
	%NavRail.custom_minimum_size.x = 64 if value else 96
	for id in nav_buttons:
		var button: Button = nav_buttons[id]
		button.text = "" if value else TITLES[id]
		button.tooltip_text = TITLES[id] if value else TOOLTIPS[id]
		button.custom_minimum_size = Vector2(64, 56) if value else Vector2(96, 72)
	%ContentArea.theme_type_variation = "ContentAreaCompact" if value else "ContentArea"

func set_vr_mode(value: bool):
	vr_mode = value
	%PinButton.visible = value
	%CloseButton.tooltip_text = "Close tablet" if value else "Close menu (Esc)"
	var save = _save()
	if value and save != null and not save.registry.get_definition("vr.menu_pin_mode").is_empty():
		%PinButton.set_pressed_no_signal(save.store.get_value("vr.menu_pin_mode") == "pinned")

# --- status bar --------------------------------------------------------------

func refresh_status():
	var network = _network()
	if network != null and network.has_method("get_instance_summary"):
		update_status(network.get_instance_summary())

## info: {title | instance, mode, people}. Empty title means no instance.
func update_status(info: Dictionary):
	var title = str(info.get("title", info.get("instance", "")))
	if title.is_empty():
		%InstanceLabel.text = "Not in an instance"
		%PeopleLabel.visible = false
		return
	var mode = str(info.get("mode", ""))
	%InstanceLabel.text = title if mode.is_empty() else "%s · %s" % [title, mode]
	%PeopleLabel.text = str(int(info.get("people", 0)))
	%PeopleLabel.tooltip_text = "%d people in this instance" % int(info.get("people", 0))
	%PeopleLabel.visible = true

func _update_clock():
	var time = Time.get_time_dict_from_system()
	%Clock.text = "%d:%02d" % [time.hour, time.minute]

func _mic_toggled(muted: bool):
	var save = _save()
	if save != null:
		save.voice.set_muted(muted)

func _mute_changed(muted: bool):
	var save = _save()
	%MicButton.set_pressed_no_signal(muted)
	%MicButton.icon = MUTED_ICON if muted else MIC_ICON
	var binding = save.voice.binding_text() if save != null else ""
	%MicButton.tooltip_text = ("Unmute microphone" if muted else "Mute microphone") + (" (%s)" % binding if not binding.is_empty() else "")
	if save != null and not save.voice.availability.is_empty():
		%MicButton.tooltip_text += "\n" + save.voice.availability

func _availability_changed(_message: String):
	var save = _save()
	if save != null:
		_mute_changed(save.voice.is_muted())

func _setting_changed(id: String, value: Variant):
	if id == "input.toggle_microphone":
		_availability_changed("")
	elif id == "vr.menu_pin_mode":
		%PinButton.set_pressed_no_signal(value == "pinned")

func _pin_toggled(pinned: bool):
	%PinButton.tooltip_text = "Keep the tablet where you put it" if pinned else "Let the tablet follow your view"
	var save = _save()
	if save != null and not save.registry.get_definition("vr.menu_pin_mode").is_empty():
		save.store.set_value("vr.menu_pin_mode", "pinned" if pinned else "follow")

func _presence_chosen(index: int):
	var save = _save()
	if save != null and save.get("friends") != null and index >= 0 and index < PRESENCE.size():
		save.friends.set_status(PRESENCE[index])
	_presence_changed()

func _presence_changed():
	var save = _save()
	var available = save != null and save.get("friends") != null
	%PresenceButton.disabled = not available
	var index = 0
	if available and not save.friends.state.is_empty():
		index = maxi(0, PRESENCE.find(str(save.friends.state.get("preferred_status", "online"))))
	%PresenceButton.text = PRESENCE_LABELS[index]
	$Layout/StatusBar/Row/PresenceDot.state = PRESENCE[index]

func _profile_changed(owner: String):
	var save = _save()
	if save != null and owner == save.profile.get_local_fingerprint() and _profile_media != null:
		var source = str(save.profile.get_profile(owner).get("profile.icon_source", ""))
		if source.is_empty():
			%ProfileButton.icon = PROFILE_ICON
		else:
			_profile_media.request_icon(source)

# --- profiles and quick actions ------------------------------------------------

func open_own_profile():
	var save = _save()
	if save != null and save.get("profile") != null:
		open_profile(save.profile.get_local_fingerprint(), "My profile")

func open_profile(owner: String, title: String = "Profile"):
	var save = _save()
	if save == null or save.get("profile") == null:
		return
	if is_instance_valid(profile_panel) and profile_panel.get("profile_owner") == owner:
		return
	if is_instance_valid(profile_panel):
		back()
	profile_panel = load("res://scenes/GUI/profile_menue.tscn").instantiate()
	push_page(profile_panel, title)
	var panel = profile_panel
	panel.closed.connect(func():
		if not stack.is_empty() and stack.back().control == panel:
			back())
	panel.open_profile(save.profile, owner)

func handle_quick_action(id: String):
	match id:
		"avatar":
			open_page("avatars")
		"invite":
			open_page("instance")
			var instance = pages.get("instance")
			if is_instance_valid(instance) and instance.has_method("focus_invite"):
				instance.focus_invite()
		"mute":
			var save = _save()
			if save != null:
				save.voice.toggle_muted()
		_:
			quick_action.emit(id)
