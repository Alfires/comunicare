extends Control
## Quick page: six large tiles and the online friends strip
## (docs/roadmaps/gui-tablet-specification.md §3.2, §4.1). Mute is handled
## here; every other tile is routed through the shell via action_requested.

signal action_requested(id: String)
signal friend_selected(owner: String)
signal open_page_requested(id: String)

const TILES = [
	{"id": "mute", "label": "Mute", "icon": "microphone", "toggle": true},
	{"id": "emotes", "label": "Emotes", "icon": "emote"},
	{"id": "avatar", "label": "Change avatar", "icon": "avatar"},
	{"id": "invite", "label": "Invite", "icon": "invite"},
	{"id": "respawn", "label": "Respawn", "icon": "respawn"},
	{"id": "mirror", "label": "Mirror", "icon": "mirror", "toggle": true},
]
const MAX_FRIENDS = 8
const MIC_ICON = preload("res://themes/icons/microphone.svg")
const MUTED_ICON = preload("res://themes/icons/microphone_muted.svg")
const PROFILE_ICON = preload("res://themes/icons/profile.svg")

var tiles: Dictionary = {}

func _ready():
	for spec in TILES:
		var tile = Button.new()
		tile.name = spec.id.capitalize().replace(" ", "") + "Tile"
		tile.text = spec.label
		tile.theme_type_variation = "QuickTile"
		tile.icon = load("res://themes/icons/%s.svg" % spec.icon)
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.custom_minimum_size = Vector2(176, 132)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.toggle_mode = spec.get("toggle", false)
		tile.set_meta("quick_action", spec.id)
		tile.pressed.connect(_tile_pressed.bind(spec.id))
		%QuickGrid.add_child(tile)
		tiles[spec.id] = tile
	%OpenFriends.pressed.connect(func(): open_page_requested.emit("friends"))
	resized.connect(_layout)
	visibility_changed.connect(func(): if is_visible_in_tree(): refresh())
	var save = _save()
	if save != null:
		save.voice.mute_changed.connect(_mute_changed)
		if save.get("friends") != null:
			save.friends.changed.connect(refresh_friends)
	var network = _network()
	if network != null:
		for name in ["active_instance_changed", "participants_changed"]:
			if network.has_signal(name):
				network.connect(name, refresh)
	_layout()
	refresh()

func _exit_tree():
	var save = _save()
	if save != null:
		if save.voice.mute_changed.is_connected(_mute_changed):
			save.voice.mute_changed.disconnect(_mute_changed)
		if save.get("friends") != null and save.friends.changed.is_connected(refresh_friends):
			save.friends.changed.disconnect(refresh_friends)
	var network = _network()
	if network != null:
		for name in ["active_instance_changed", "participants_changed"]:
			if network.has_signal(name) and network.is_connected(name, refresh):
				network.disconnect(name, refresh)

func _save() -> Node:
	return get_node_or_null("/root/SaveData")

func _network() -> Node:
	return get_node_or_null("/root/NetworkHandler")

func _layout():
	var width = size.x if size.x > 0 else 600.0
	%QuickGrid.columns = clampi(int(floor((width + 12) / 188.0)), 2, 3)

func refresh():
	var save = _save()
	if save != null:
		_mute_changed(save.voice.is_muted())
	var network = _network()
	var in_instance = network != null and not str(network.get("current_session_id")).is_empty() and network.get("current_session_id") != null
	tiles.invite.disabled = not in_instance
	tiles.invite.tooltip_text = "Share an invite to this instance" if in_instance else "Join an instance to invite people"
	var busy = network != null and network.get("session_busy") == true
	var scene = get_tree().current_scene if is_inside_tree() else null
	var can_respawn = scene != null and scene.has_method("return_player_to_spawn") and not busy
	tiles.respawn.disabled = not can_respawn
	tiles.respawn.tooltip_text = "Return to this world's spawn point" if can_respawn else "Respawn is not available right now"
	var controller = _animation_controller()
	tiles.mirror.disabled = controller == null or not controller.has_method("toggle_local_mirror")
	if controller != null and controller.has_method("is_local_mirror_visible"):
		tiles.mirror.set_pressed_no_signal(controller.is_local_mirror_visible())
	tiles.mirror.tooltip_text = "Show or hide your local mirror"
	tiles.emotes.tooltip_text = "Open the emote wheel"
	tiles.avatar.tooltip_text = "Find, preview and change your avatar"
	refresh_friends()

func _animation_controller():
	var network = _network()
	if network != null and network.has_method("get_animation_controller"):
		return network.get_animation_controller()
	return null

func _mute_changed(muted: bool):
	var tile: Button = tiles.mute
	tile.set_pressed_no_signal(muted)
	tile.text = "Unmute" if muted else "Mute"
	tile.icon = MUTED_ICON if muted else MIC_ICON
	tile.tooltip_text = "Your microphone is muted" if muted else "Your microphone is live"

func _tile_pressed(id: String):
	match id:
		"mute":
			var save = _save()
			if save != null:
				save.voice.toggle_muted()
		"mirror":
			var controller = _animation_controller()
			if controller != null and controller.has_method("toggle_local_mirror"):
				controller.toggle_local_mirror()
			if controller != null and controller.has_method("is_local_mirror_visible"):
				tiles.mirror.set_pressed_no_signal(controller.is_local_mirror_visible())
		_:
			action_requested.emit(id)

func online_friends() -> Array:
	var save = _save()
	if save == null or save.get("friends") == null or save.friends.state.is_empty():
		return []
	var result: Array = []
	for owner in save.friends.contacts():
		if save.friends.is_friend(owner) and save.friends.status(owner) == "online":
			result.append({"owner": owner, "name": save.friends.label(owner)})
	result.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	return result

func refresh_friends():
	for child in %OnlineFriends.get_children():
		%OnlineFriends.remove_child(child)
		child.queue_free()
	var friends = online_friends()
	%NoFriends.visible = friends.is_empty()
	for index in mini(friends.size(), MAX_FRIENDS):
		var friend: Dictionary = friends[index]
		var chip = Button.new()
		chip.theme_type_variation = "FriendChip"
		chip.text = friend.name
		chip.icon = PROFILE_ICON
		chip.custom_minimum_size = Vector2(0, 48)
		chip.tooltip_text = "Open %s's profile" % friend.name
		chip.pressed.connect(func(): friend_selected.emit(friend.owner))
		%OnlineFriends.add_child(chip)
	if friends.size() > MAX_FRIENDS:
		var more = Button.new()
		more.theme_type_variation = "FriendChip"
		more.text = "+%d" % (friends.size() - MAX_FRIENDS)
		more.custom_minimum_size = Vector2(48, 48)
		more.tooltip_text = "Show all friends"
		more.pressed.connect(func(): open_page_requested.emit("friends"))
		%OnlineFriends.add_child(more)
