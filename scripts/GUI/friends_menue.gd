extends Control

const ToastHost = preload("res://scripts/GUI/toast_host.gd")
var service
var layout: VBoxContainer
var list: VBoxContainer
var scroll: ScrollContainer
var status_label: Label
var preference: OptionButton
var key_input: TextEdit
var nickname: LineEdit
var key_review: Label
var add_panel: VBoxContainer
var profile_panel: Control
var confirmation: ConfirmationDialog
var pending_action: Callable
var last_owner := ""
var restore_scroll := 0
var restore_owner := ""

func _ready():
	layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var top = HBoxContainer.new()
	layout.add_child(top)
	_label(top, "Friends").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preference = OptionButton.new()
	for text in ["Online", "Do Not Disturb", "Offline (appear offline)"]:
		preference.add_item(text)
	preference.tooltip_text = "Presence is shared only with accepted friends on this relay. Offline does not disconnect your game."
	top.add_child(preference)
	preference.item_selected.connect(func(index):
		if service != null:
			service.set_status(["online", "do_not_disturb", "offline"][index]))
	var actions = HBoxContainer.new()
	layout.add_child(actions)
	_button(actions, "Add public key", func(): add_panel.visible = not add_panel.visible)
	_button(actions, "Refresh", func():
		if service != null:
			service.refresh())
	status_label = _label(layout, "Account not loaded")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_panel = VBoxContainer.new()
	layout.add_child(add_panel)
	key_input = TextEdit.new()
	key_input.placeholder_text = "Paste the complete PUBLIC key (never a private key)"
	key_input.custom_minimum_size.y = 90
	add_panel.add_child(key_input)
	key_review = _label(add_panel, "Review the fingerprint before saving or sending.")
	key_review.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	key_input.text_changed.connect(func():
		var fingerprint = preload("res://scripts/profile/profile_identity.gd").fingerprint(key_input.text.strip_edges() + "\n")
		key_review.text = "Invalid public key" if fingerprint.is_empty() else "Fingerprint: " + fingerprint)
	nickname = LineEdit.new()
	nickname.placeholder_text = "Optional private local nickname"
	nickname.max_length = 128
	add_panel.add_child(nickname)
	var add_actions = HBoxContainer.new()
	add_panel.add_child(add_actions)
	_button(add_actions, "Save contact", _save_contact.bind(false))
	_button(add_actions, "Send friend request", _save_contact.bind(true))
	_button(add_actions, "Cancel", func(): add_panel.hide())
	add_panel.hide()
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	confirmation = ConfirmationDialog.new()
	confirmation.get_label().autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	confirmation.get_label().custom_minimum_size.x = 240
	confirmation.confirmed.connect(func():
		if pending_action.is_valid():
			pending_action.call()
		pending_action = Callable())
	add_child(confirmation)
	if SaveData.has_signal("account_ready"):
		SaveData.account_ready.connect(_bind_service)
	_bind_service()

func _bind_service():
	if service != null and service.changed.is_connected(_render):
		service.changed.disconnect(_render)
	service = SaveData.get("friends")
	if service != null:
		service.changed.connect(_render)
	_render()

func _exit_tree():
	if service != null and service.changed.is_connected(_render):
		service.changed.disconnect(_render)
	if SaveData.has_signal("account_ready") and SaveData.account_ready.is_connected(_bind_service):
		SaveData.account_ready.disconnect(_bind_service)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var result = Button.new()
	result.text = text
	result.custom_minimum_size.y = 40
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func _label(parent: Node, text: String) -> Label:
	var result = Label.new()
	result.text = text
	parent.add_child(result)
	return result

func _save_contact(send: bool):
	if service == null:
		return
	if service.add_contact(key_input.text, nickname.text):
		var owner = preload("res://scripts/profile/profile_identity.gd").fingerprint(key_input.text.strip_edges() + "\n")
		if send and not service.send_request(owner):
			return
		key_input.clear()
		nickname.clear()
		add_panel.hide()

func _ask(text: String, action: Callable):
	pending_action = action
	confirmation.dialog_text = text
	confirmation.popup_centered(Vector2i(mini(480, int(get_viewport_rect().size.x) - 32), 180))

func _render():
	if not is_node_ready():
		return
	var previous_scroll = scroll.scroll_vertical
	var focused = get_viewport().gui_get_focus_owner()
	var focused_id: String = focused.get_meta("focus_id", "") if focused != null else ""
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	if service == null or service.owner.is_empty():
		status_label.text = "Account not loaded"
		return
	if last_owner != service.owner:
		last_owner = service.owner
		key_input.clear()
		nickname.clear()
		add_panel.hide()
		confirmation.hide()
		pending_action = Callable()
		previous_scroll = 0
		if is_instance_valid(profile_panel) and profile_panel.visible:
			profile_panel._close()
	status_label.text = service.last_error
	if status_label.text.is_empty():
		status_label.text = "Offline — local records available; requests queued on this device" if not service.connected else (
			"Relay does not support Friends yet" if not service.supported else "Status is scoped to this relay. Requests are saved locally; no server mailbox.")
	preference.select(["online", "do_not_disturb", "offline"].find(service.state.preferred_status))
	var contacts: Dictionary = service.contacts()
	for section in ["Friends", "Incoming requests", "Outgoing requests", "Saved contacts"]:
		_label(list, section)
		var count := 0
		for owner in contacts:
			var relation: Dictionary = service.relationship(owner)
			var kind: String = relation.get("status", "contact")
			var expected = {"friends": "Friends", "accepting": "Outgoing requests", "incoming": "Incoming requests", "outgoing": "Outgoing requests", "contact": "Saved contacts"}[kind]
			if contacts[owner].blocked:
				expected = "Saved contacts"
			if expected != section:
				continue
			count += 1
			var row = VBoxContainer.new()
			row.set_meta("fingerprint", owner)
			list.add_child(row)
			var title = _button(row, service.label(owner) + " · " + owner.left(12), _open_profile.bind(owner))
			title.clip_text = true
			title.set_meta("focus_id", owner)
			title.tooltip_text = owner
			var text = "Blocked" if contacts[owner].blocked else {"friends": service.status(owner), "incoming": "Incoming request — explicit acceptance required", "outgoing": "Waiting for acceptance / delivery", "accepting": "Accepting — waiting for durable receipt", "contact": service.relationship_label(owner) + " · Status unavailable"}[kind]
			_label(row, text).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var buttons = HFlowContainer.new()
			row.add_child(buttons)
			if kind == "friends" and not contacts[owner].blocked:
				var location: Dictionary = service.friend_session(owner)
				if not location.is_empty():
					_label(row, "In: " + location.name + " · " + location.session_id).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					var same = NetworkHandler.current_session_id == location.session_id
					var join = _button(buttons, "Same instance" if same else "Join friend", _join_friend.bind(owner))
					join.disabled = same or NetworkHandler.session_busy
				else: _label(row, "Instance not shared or unavailable")
			if contacts[owner].blocked:
				_button(buttons, "Unblock", service.block.bind(owner, false))
			elif kind == "incoming":
				_button(buttons, "Accept", service.act.bind(owner, "accept"))
				_button(buttons, "Decline", service.act.bind(owner, "decline"))
			elif kind == "outgoing":
				_button(buttons, "Cancel request", service.act.bind(owner, "cancel"))
			elif kind in ["friends", "accepting"]:
				_button(buttons, "Remove friend", _ask.bind("Remove friendship with %s?\n%s" % [service.label(owner), owner], service.act.bind(owner, "revoke")))
			else:
				_button(buttons, "Send friend request", service.send_request.bind(owner))
				_button(buttons, "Delete contact", _ask.bind("Delete saved contact?\n" + owner, service.remove_contact.bind(owner)))
			if not contacts[owner].blocked:
				_button(buttons, "Block", _ask.bind("Block account and revoke local friendship?\n" + owner, service.block.bind(owner)))
			if focused_id == owner:
				title.grab_focus()
		if count == 0 and section == "Friends" and contacts.is_empty():
			var empty = preload("res://scripts/GUI/empty_state.gd").new()
			empty.configure(preload("res://themes/icons/friends.svg"), "You have no contacts yet.", "Add someone", func():
				add_panel.show()
				key_input.grab_focus())
			list.add_child(empty)
		elif count == 0:
			_label(list, "None yet")
	scroll.set_deferred("scroll_vertical", previous_scroll)

func _join_friend(owner: String):
	if NetworkHandler.session_busy: return
	var location: Dictionary = service.friend_session(owner)
	if location.is_empty():
		status_label.text = "Friend location expired or is no longer shared. Refresh and try again."
		return
	status_label.text = "Joining friend's instance…"
	if not await NetworkHandler.join_session(location.session_id, location.world_url):
		status_label.text = NetworkHandler.last_session_error
	else:
		status_label.text = "Joined friend's instance."
		ToastHost.notify(self, "Joined your friend's instance.", "success")

func _open_profile(owner: String):
	restore_scroll = scroll.scroll_vertical
	restore_owner = owner
	if not is_instance_valid(profile_panel):
		profile_panel = load("res://scenes/GUI/profile_menue.tscn").instantiate()
		add_child(profile_panel)
		profile_panel.closed.connect(func():
			layout.show()
			scroll.set_deferred("scroll_vertical", restore_scroll)
			for child in list.find_children("*", "Button", true, false):
				if child.get_meta("focus_id", "") == restore_owner:
					child.grab_focus())
	layout.hide()
	profile_panel.open_profile(service, owner)
