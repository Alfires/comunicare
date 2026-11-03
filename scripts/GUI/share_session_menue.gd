extends Control

@onready var session_id: LineEdit = $VBoxContainer/HBoxContainer/session_id
@onready var player_list: VBoxContainer = $VBoxContainer/ScrollContainer/player_list
var header: Label
var count: Label
var status: Label
var edit_button: Button
var refresh_button: Button
var editor: VBoxContainer
var name_input: LineEdit
var description_input: TextEdit
var type_input: OptionButton
var save_button: Button
var profile_panel: Control
var confirmation: ConfirmationDialog
var confirm_action := ""
var confirm_target: Dictionary = {}
var draft_session := ""
var draft_revision := -1
var displayed_session := ""
var last_busy := false
var rows: Dictionary = {}
var request_list: VBoxContainer
var request_peer: RelayPeer

func _ready():
	$VBoxContainer/Label.text = "Active Instance"
	$VBoxContainer/HBoxContainer/copy.text = "Copy code"
	header = Label.new()
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer.add_child(header)
	$VBoxContainer.move_child(header, 1)
	var actions = HBoxContainer.new()
	$VBoxContainer.add_child(actions)
	$VBoxContainer.move_child(actions, 3)
	edit_button = _button(actions, "Edit instance", _begin_edit)
	refresh_button = _button(actions, "Refresh", NetworkHandler.refresh_instance)
	editor = VBoxContainer.new()
	$VBoxContainer.add_child(editor)
	$VBoxContainer.move_child(editor, 4)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Instance name"
	name_input.max_length = 128
	editor.add_child(name_input)
	description_input = TextEdit.new()
	description_input.custom_minimum_size.y = 80
	description_input.placeholder_text = "Description (up to 2048 characters)"
	editor.add_child(description_input)
	type_input = OptionButton.new()
	for label in ["Public", "Private — closed", "Friends — admins' friends", "Friends+ — friends of admins' friends", "Request — friends need approval"]:
		type_input.add_item(label)
	editor.add_child(type_input)
	var edit_actions = HBoxContainer.new()
	editor.add_child(edit_actions)
	save_button = _button(edit_actions, "Save", _save_edit)
	_button(edit_actions, "Cancel", _cancel_edit)
	editor.hide()
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$VBoxContainer.add_child(status)
	$VBoxContainer.move_child(status, 5)
	count = Label.new()
	$VBoxContainer.add_child(count)
	$VBoxContainer.move_child(count, 6)
	request_list = VBoxContainer.new()
	$VBoxContainer.add_child(request_list)
	$VBoxContainer.move_child(request_list, 6)
	player_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirmation = ConfirmationDialog.new()
	confirmation.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation.get_label().custom_minimum_size.x = 240
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm_moderation)
	NetworkHandler.active_instance_changed.connect(_render)
	NetworkHandler.participants_changed.connect(_render)
	NetworkHandler.instance_management_finished.connect(_management_finished)
	if SaveData.get("profile") != null:
		SaveData.profile.remote_profiles_changed.connect(_render)
		SaveData.profile.profile_changed.connect(_profile_changed)
	visibility_changed.connect(_visibility_changed)
	_render()
	if is_visible_in_tree():
		NetworkHandler.refresh_instance()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var result = Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, 40)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func _profile_changed(_owner: String):
	_render()

func _visibility_changed():
	if is_visible_in_tree():
		_render()
		NetworkHandler.refresh_instance()
	elif is_instance_valid(profile_panel):
		profile_panel.cancel_edit()

func _exit_tree():
	if request_peer != null and request_peer.join_requests_changed.is_connected(_render_requests):
		request_peer.join_requests_changed.disconnect(_render_requests)
	NetworkHandler.active_instance_changed.disconnect(_render)
	NetworkHandler.participants_changed.disconnect(_render)
	NetworkHandler.instance_management_finished.disconnect(_management_finished)
	if SaveData.get("profile") != null:
		SaveData.profile.remote_profiles_changed.disconnect(_render)
		SaveData.profile.profile_changed.disconnect(_profile_changed)

func _members() -> Array:
	if not NetworkHandler.active_instance.is_empty():
		return NetworkHandler.active_instance.members
	# Display-only compatibility fallback while a new relay snapshot is loading.
	# Profiles never confer roles, and unavailable profiles are not counted as a
	# complete roster. Modern relay snapshots replace this fallback atomically.
	var members: Array = []
	if SaveData.get("profile") != null and not NetworkHandler.current_session_id.is_empty():
		members.append({"fingerprint": SaveData.profile.get_local_fingerprint(), "peer_id": -1, "role": "member"})
		for owner in SaveData.profile.remote:
			var profile: Dictionary = SaveData.profile.remote[owner]
			if profile.get("session_id") == NetworkHandler.current_session_id:
				members.append({"fingerprint": owner, "peer_id": profile.get("peer_id", -1), "role": "member"})
	return members

func _render():
	if not is_node_ready():
		return
	if request_peer != NetworkHandler.peer:
		if request_peer != null and request_peer.join_requests_changed.is_connected(_render_requests):
			request_peer.join_requests_changed.disconnect(_render_requests)
		request_peer = NetworkHandler.peer
		if request_peer != null:
			request_peer.join_requests_changed.connect(_render_requests)
	_render_requests()
	var session: String = NetworkHandler.current_session_id
	var state: Dictionary = NetworkHandler.active_instance
	var admin: bool = NetworkHandler.is_instance_admin()
	var busy: bool = NetworkHandler.session_busy or not NetworkHandler.management_pending.is_empty()
	if displayed_session != session or (NetworkHandler.session_busy and not last_busy):
		_cancel_edit()
		confirmation.hide()
		if is_instance_valid(profile_panel):
			profile_panel.cancel_edit()
	displayed_session = session
	last_busy = NetworkHandler.session_busy
	if not admin:
		_cancel_edit()
		confirmation.hide()
	session_id.text = session if not session.is_empty() else "No active instance"
	$VBoxContainer/HBoxContainer/copy.disabled = session.is_empty() or NetworkHandler.session_busy
	header.text = "No active instance" if session.is_empty() else "Loading authoritative instance details…"
	if not state.is_empty():
		var types = ["Public", "Private — closed", "Friends", "Friends+", "Request — friends need approval"]
		header.text = "%s\nSession type: %s\n%s" % [state.name, types[int(state.mode)], state.description]
	edit_button.visible = admin
	edit_button.disabled = busy
	refresh_button.disabled = session.is_empty() or NetworkHandler.session_busy
	save_button.disabled = busy or not admin
	status.text = NetworkHandler.instance_status
	if NetworkHandler.session_busy:
		status.text = "Changing instance…"
	elif not NetworkHandler.management_pending.is_empty():
		status.text = "Waiting for relay…"
	elif editor.visible and not state.is_empty() and int(state.revision) != draft_revision:
		status.text = "Instance changed while editing. Cancel and reopen the editor to reload before saving."
		save_button.disabled = true
	var members = _members() if not session.is_empty() else []
	var retained := {}
	var local_owner = SaveData.profile.get_local_fingerprint() if SaveData.get("profile") != null else ""
	for member in members:
		var owner: String = member.fingerprint
		retained[owner] = true
		var profile: Dictionary = SaveData.profile.get_profile(owner) if SaveData.get("profile") != null else {}
		var title = str(profile.get("profile.username", "Profile loading — " + owner.left(8)))
		var signature = [title, member.role, member.peer_id, admin, busy]
		if rows.has(owner) and rows[owner].get_meta("signature") == signature:
			continue
		if rows.has(owner):
			_remove_row(owner)
		var hb = HBoxContainer.new()
		hb.set_meta("fingerprint", owner)
		hb.set_meta("signature", signature)
		player_list.add_child(hb)
		rows[owner] = hb
		var name_button = _button(hb, title, open_profile.bind(owner))
		name_button.clip_text = true
		name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_button.custom_minimum_size.x = 64
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.tooltip_text = owner
		var badge = Label.new()
		badge.text = ("You · " if owner == local_owner else "") + ("Admin" if member.role == "admin" else "Member")
		hb.add_child(badge)
		if admin and owner != local_owner:
			for action in ["Kick", "Ban", "Make admin"]:
				if action == "Make admin" and member.role == "admin":
					continue
				var action_button = _button(hb, action, _ask_moderation.bind(action, member.duplicate(true), title))
				action_button.disabled = busy
	for owner in rows.keys():
		if not retained.has(owner):
			_remove_row(owner)
	count.text = "Players (%d)" % members.size()

func _remove_row(owner: String):
	var node: Node = rows[owner]
	player_list.remove_child(node)
	node.queue_free()
	rows.erase(owner)

func _render_requests():
	if not is_instance_valid(request_list):
		return
	for child in request_list.get_children():
		request_list.remove_child(child)
		child.queue_free()
	if request_peer == null or not NetworkHandler.is_instance_admin():
		return
	for token in request_peer.join_requests:
		var request: Dictionary = request_peer.join_requests[token]
		if request.session_id != NetworkHandler.current_session_id:
			continue
		var row = HBoxContainer.new()
		request_list.add_child(row)
		var label = Label.new()
		var name = request.fingerprint.left(12)
		if SaveData.get("friends") != null and SaveData.friends.contacts().has(request.fingerprint):
			name = SaveData.friends.label(request.fingerprint) + " · " + name
		label.text = "Join request · " + name
		label.clip_text = true
		label.tooltip_text = request.fingerprint
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_button(row, "Allow", request_peer.decide_join.bind(token, true))
		_button(row, "Decline", request_peer.decide_join.bind(token, false))

func _begin_edit():
	var state: Dictionary = NetworkHandler.active_instance
	if state.is_empty() or not NetworkHandler.is_instance_admin():
		return
	draft_session = state.session_id
	draft_revision = int(state.revision)
	name_input.text = state.name
	description_input.text = state.description
	type_input.select(int(state.mode))
	editor.show()
	_render()

func _cancel_edit():
	if is_instance_valid(editor):
		editor.hide()
	draft_session = ""
	draft_revision = -1

func _save_edit():
	if draft_session != NetworkHandler.current_session_id:
		_cancel_edit()
		return
	var changes = {"name": name_input.text, "description": description_input.text, "mode": type_input.selected}
	if not InstanceState.valid_metadata(changes):
		status.text = "Enter a non-blank name (1–128 characters) and a description up to 2048 characters."
		return
	NetworkHandler.manage_instance("update_metadata", {}, changes, draft_revision)

func _management_finished(result: Dictionary):
	if result.get("success", false):
		_cancel_edit()
	_render()

func _ask_moderation(action: String, target: Dictionary, title: String):
	confirm_action = {"Kick": "kick", "Ban": "ban", "Make admin": "make_admin"}[action]
	confirm_target = target
	confirmation.dialog_text = "%s %s?\nAccount: %s\n%s" % [action, title, target.fingerprint,
		"Reconnect policy is saved on admin clients, never on the relay. Admissions require available moderators." if action == "Ban" else "This affects only the active instance."]
	confirmation.popup_centered(Vector2i(mini(480, int(get_viewport_rect().size.x) - 32), 200))

func _confirm_moderation():
	NetworkHandler.manage_instance(confirm_action, confirm_target)
	confirm_target = {}

func open_profile(owner: String):
	if SaveData.get("profile") == null:
		return
	if not is_instance_valid(profile_panel):
		profile_panel = load("res://scenes/GUI/profile_menue.tscn").instantiate()
		add_child(profile_panel)
		profile_panel.closed.connect(func(): $VBoxContainer.show())
	$VBoxContainer.hide()
	profile_panel.open_profile(SaveData.profile, owner)

func _on_copy_pressed():
	if not NetworkHandler.current_session_id.is_empty() and not NetworkHandler.session_busy:
		DisplayServer.clipboard_set(NetworkHandler.current_session_id)
