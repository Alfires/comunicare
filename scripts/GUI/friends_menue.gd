extends Control
## Friends page: search, All/Online/Requests filter, grouped contact cards with a
## round avatar and presence, one primary action per contact and a "more" menu
## for the rest. Consent, blocking and delivery stay owned by the friend service.

const ToastHost = preload("res://scripts/GUI/toast_host.gd")
const ContactAvatar = preload("res://scripts/GUI/contact_avatar.gd")
const SECTIONS = ["Friends", "Incoming requests", "Outgoing requests", "Saved contacts"]
const SECTION_OF = {"friends": "Friends", "accepting": "Outgoing requests", "incoming": "Incoming requests", "outgoing": "Outgoing requests", "contact": "Saved contacts"}
const PRESENCE_ORDER = {"online": 0, "do_not_disturb": 1}
const PRESENCE_TEXT = {"online": "Online", "do_not_disturb": "Do not disturb"}
const FILTERS = [["all", "All"], ["online", "Online"], ["requests", "Requests"]]

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
var search: LineEdit
var filter := "all"
var filter_buttons: Dictionary = {}
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
	var toolbar = HFlowContainer.new()
	layout.add_child(toolbar)
	search = LineEdit.new()
	search.placeholder_text = "Search friends and contacts"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(220, 44)
	search.set_meta("blocks_global_shortcuts", true)
	search.text_changed.connect(func(_text): _render())
	toolbar.add_child(search)
	var group = ButtonGroup.new()
	for entry in FILTERS:
		var button = Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = "NavButton"
		button.custom_minimum_size.y = 44
		button.button_pressed = entry[0] == filter
		button.pressed.connect(func():
			filter = entry[0]
			_render())
		toolbar.add_child(button)
		filter_buttons[entry[0]] = button
	var refresh = Button.new()
	refresh.theme_type_variation = "IconButton"
	refresh.icon = preload("res://themes/icons/reset.svg")
	refresh.tooltip_text = "Refresh friend status"
	refresh.custom_minimum_size = Vector2(44, 44)
	refresh.pressed.connect(func():
		if service != null:
			service.refresh())
	toolbar.add_child(refresh)
	var add = _button(toolbar, "Add public key", func():
		add_panel.visible = not add_panel.visible
		if add_panel.visible: key_input.grab_focus())
	add.theme_type_variation = "PrimaryButton"
	preference = OptionButton.new()
	for text in ["Online", "Do not disturb", "Appear offline"]:
		preference.add_item(text)
	preference.tooltip_text = "Presence is shared only with accepted friends on this relay. Appearing offline does not disconnect your game."
	preference.custom_minimum_size.y = 44
	toolbar.add_child(preference)
	preference.item_selected.connect(func(index):
		if service != null:
			service.set_status(["online", "do_not_disturb", "offline"][index]))
	status_label = _label(layout, "Account not loaded")
	status_label.theme_type_variation = "CaptionLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_add_panel()
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

func _build_add_panel():
	var card = PanelContainer.new()
	card.theme_type_variation = "Card"
	layout.add_child(card)
	add_panel = VBoxContainer.new()
	card.add_child(add_panel)
	add_panel.visibility_changed.connect(func(): card.visible = add_panel.visible)
	var title = _label(add_panel, "Add someone by public key")
	title.theme_type_variation = "HeaderLabel"
	_label(add_panel, "Ask them for their public key (Profile, Show key). Never paste a private key.").theme_type_variation = "CaptionLabel"
	key_input = TextEdit.new()
	key_input.placeholder_text = "Paste the complete PUBLIC key (never a private key)"
	key_input.custom_minimum_size.y = 90
	key_input.set_meta("blocks_global_shortcuts", true)
	add_panel.add_child(key_input)
	key_review = _label(add_panel, "Review the fingerprint before saving or sending.")
	key_review.theme_type_variation = "CaptionLabel"
	key_review.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	key_input.text_changed.connect(func():
		var fingerprint = preload("res://scripts/profile/profile_identity.gd").fingerprint(key_input.text.strip_edges() + "\n")
		key_review.text = "Invalid public key" if fingerprint.is_empty() else "Fingerprint: " + fingerprint)
	nickname = LineEdit.new()
	nickname.placeholder_text = "Optional private nickname (only you see it)"
	nickname.max_length = 128
	nickname.set_meta("blocks_global_shortcuts", true)
	add_panel.add_child(nickname)
	var add_actions = HBoxContainer.new()
	add_panel.add_child(add_actions)
	_button(add_actions, "Send friend request", _save_contact.bind(true)).theme_type_variation = "PrimaryButton"
	_button(add_actions, "Save contact", _save_contact.bind(false))
	_button(add_actions, "Cancel", func(): add_panel.hide())
	add_panel.hide()
	card.hide()

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
	result.custom_minimum_size.y = 44
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
		ToastHost.notify(self, "Friend request sent." if send else "Contact saved.", "success")

func _ask(text: String, action: Callable):
	pending_action = action
	confirmation.dialog_text = text
	confirmation.popup_centered(Vector2i(mini(480, int(get_viewport_rect().size.x) - 32), 180))

## {owner: {kind, section, blocked, presence}} for every saved contact.
func _contacts_view() -> Dictionary:
	var result := {}
	var contacts: Dictionary = service.contacts()
	for owner in contacts:
		var kind: String = service.relationship(owner).get("status", "contact")
		var blocked: bool = contacts[owner].blocked
		var presence := ""
		if kind == "friends" and not blocked:
			presence = service.status(owner) if service.status(owner) in ["online", "do_not_disturb"] else "offline"
		result[owner] = {"kind": kind, "blocked": blocked, "presence": presence,
			"section": "Saved contacts" if blocked else SECTION_OF.get(kind, "Saved contacts")}
	return result

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
		search.clear()
		confirmation.hide()
		pending_action = Callable()
		previous_scroll = 0
		if is_instance_valid(profile_panel) and profile_panel.visible:
			profile_panel._close()
	status_label.text = service.last_error
	if status_label.text.is_empty():
		status_label.text = "Offline — local records available; requests queued on this device" if not service.connected else (
			"Relay does not support Friends yet" if not service.supported else "Status is scoped to this relay. Requests are saved on this device; there is no server mailbox.")
	preference.select(["online", "do_not_disturb", "offline"].find(service.state.preferred_status))
	var view := _contacts_view()
	var incoming = view.values().filter(func(entry): return entry.kind == "incoming" and not entry.blocked).size()
	filter_buttons.requests.text = "Requests (%d)" % incoming if incoming > 0 else "Requests"
	if view.is_empty():
		var empty = preload("res://scripts/GUI/empty_state.gd").new()
		empty.configure(preload("res://themes/icons/friends.svg"), "You have no contacts yet.", "Add someone", func():
			add_panel.show()
			key_input.grab_focus())
		list.add_child(empty)
		return
	var query = search.text.strip_edges().to_lower()
	var shown := 0
	for section in SECTIONS:
		if filter == "requests" and not section in ["Incoming requests", "Outgoing requests"]:
			continue
		if filter == "online" and section != "Friends":
			continue
		var owners: Array = view.keys().filter(func(owner):
			var entry: Dictionary = view[owner]
			if entry.section != section: return false
			if filter == "online" and entry.presence != "online": return false
			return query.is_empty() or query in (service.label(owner) + " " + owner).to_lower())
		owners.sort_custom(func(a, b):
			var rank_a = PRESENCE_ORDER.get(view[a].presence, 2)
			var rank_b = PRESENCE_ORDER.get(view[b].presence, 2)
			return rank_a < rank_b if rank_a != rank_b else service.label(a).naturalnocasecmp_to(service.label(b)) < 0)
		if owners.is_empty():
			continue
		var header = _label(list, "%s · %d" % [section, owners.size()])
		header.theme_type_variation = "CaptionLabel"
		for owner in owners:
			var title = _contact_row(owner, view[owner])
			if focused_id == owner:
				title.grab_focus()
			shown += 1
	if shown == 0:
		var message = "No contacts match \"%s\"." % search.text.strip_edges() if not query.is_empty() else (
			"None of your friends are online." if filter == "online" else "No open friend requests.")
		_label(list, message).theme_type_variation = "MutedLabel"
	scroll.set_deferred("scroll_vertical", previous_scroll)

## One contact card; returns the name button (focus target).
func _contact_row(owner: String, entry: Dictionary) -> Button:
	var row = PanelContainer.new()
	row.theme_type_variation = "ListRow"
	row.set_meta("fingerprint", owner)
	list.add_child(row)
	var line = HBoxContainer.new()
	line.theme_type_variation = "SpacedHBox"
	row.add_child(line)
	var avatar = ContactAvatar.new()
	avatar.display_name = service.label(owner)
	avatar.fingerprint = owner
	avatar.presence = entry.presence
	line.add_child(avatar)
	var text = VBoxContainer.new()
	text.theme_type_variation = "FlushVBox"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var title = Button.new()
	title.text = service.label(owner)
	title.theme_type_variation = "IconButton"
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text = "View profile · " + owner
	title.set_meta("focus_id", owner)
	title.pressed.connect(_open_profile.bind(owner))
	text.add_child(title)
	var caption = _label(text, _status_text(owner, entry))
	caption.theme_type_variation = "CaptionLabel"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions = HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(actions)
	_primary_actions(actions, owner, entry)
	_more_menu(actions, owner, entry)
	return title

func _status_text(owner: String, entry: Dictionary) -> String:
	if entry.blocked:
		return "Blocked"
	match entry.kind:
		"friends":
			var text: String = PRESENCE_TEXT.get(entry.presence, "Offline")
			var location: Dictionary = service.friend_session(owner)
			if not location.is_empty():
				text += " · In " + str(location.name)
			elif entry.presence == "online":
				text += " · Instance not shared"
			return text
		"incoming": return "Wants to be your friend. They are added only if you accept."
		"outgoing": return "Request sent · waiting for them to accept"
		"accepting": return "Accepting · waiting for confirmation"
	return service.relationship_label(owner) + " · status unavailable"

func _primary_actions(actions: HBoxContainer, owner: String, entry: Dictionary):
	if entry.blocked:
		_button(actions, "Unblock", service.block.bind(owner, false))
		return
	match entry.kind:
		"friends":
			var location: Dictionary = service.friend_session(owner)
			if not location.is_empty():
				var same = NetworkHandler.current_session_id == location.session_id
				var join = _button(actions, "Same instance" if same else "Join friend", _join_friend.bind(owner))
				join.disabled = same or NetworkHandler.session_busy
				join.theme_type_variation = "PrimaryButton"
				join.tooltip_text = "In %s · %s" % [location.name, location.session_id]
		"incoming":
			_button(actions, "Accept", service.act.bind(owner, "accept")).theme_type_variation = "PrimaryButton"
			_button(actions, "Decline", service.act.bind(owner, "decline"))
		"outgoing":
			_button(actions, "Cancel request", service.act.bind(owner, "cancel"))
		"contact":
			_button(actions, "Send friend request", service.send_request.bind(owner))

## Secondary and destructive actions live in one menu per contact.
func _more_menu(actions: HBoxContainer, owner: String, entry: Dictionary):
	var more = MenuButton.new()
	more.theme_type_variation = "IconButton"
	more.icon = preload("res://themes/icons/more.svg")
	more.tooltip_text = "More actions"
	more.custom_minimum_size = Vector2(44, 44)
	var items: Array = [["View profile", _open_profile.bind(owner)]]
	if not entry.blocked:
		if entry.kind in ["friends", "accepting"]:
			items.append(["Remove friend…", _ask.bind("Remove friendship with %s?\n%s" % [service.label(owner), owner], service.act.bind(owner, "revoke"))])
		elif entry.kind == "contact":
			items.append(["Delete contact…", _ask.bind("Delete saved contact?\n" + owner, service.remove_contact.bind(owner))])
		items.append(["Block…", _ask.bind("Block account and revoke local friendship?\n" + owner, service.block.bind(owner))])
	var popup = more.get_popup()
	for index in items.size():
		popup.add_item(items[index][0], index)
	popup.id_pressed.connect(func(id): items[id][1].call())
	actions.add_child(more)

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
