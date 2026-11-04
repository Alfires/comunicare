extends PanelContainer
var player: Node
var rows: VBoxContainer
var status: Label
var choices: Dictionary = {}
var elapsed := 0.0

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("blocks_global_shortcuts", true)
	var scroll = ScrollContainer.new()
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)
	for role in ["hips", "leftFoot", "rightFoot"]:
		var label = Label.new()
		label.text = role
		rows.add_child(label)
		var choice = OptionButton.new()
		choice.custom_minimum_size.y = 44
		choices[role] = choice
		choice.item_selected.connect(func(index):
			var id = str(choice.get_item_metadata(index))
			if id.is_empty(): player.tracker_roles.unassign(role)
			else: player.tracker_roles.assign(role, id))
		rows.add_child(choice)
	var calibrate = Button.new()
	calibrate.text = "Save current headset height calibration"
	calibrate.custom_minimum_size.y = 44
	calibrate.pressed.connect(_calibrate)
	rows.add_child(calibrate)
	var close = Button.new()
	close.text = "Back"
	close.pressed.connect(queue_free)
	rows.add_child(close)

func configure(owner_player: Node):
	player = owner_player
	_refresh()

func _process(delta: float):
	if not is_instance_valid(player): queue_free(); return
	elapsed += delta
	if elapsed > 1:
		elapsed = 0
		_refresh()

func _refresh():
	if player == null or not is_node_ready(): return
	var devices: Array = player.tracker_roles.available(Time.get_ticks_msec())
	for role in choices:
		var choice: OptionButton = choices[role]
		if choice.get_popup().visible: continue
		choice.clear()
		choice.add_item("Untracked / animation fallback")
		choice.set_item_metadata(0, "")
		for id in devices:
			choice.add_item(str(id))
			choice.set_item_metadata(choice.item_count - 1, id)
			if player.tracker_roles.assignments.get(role) == id: choice.select(choice.item_count - 1)
	status.text = "Runtime body trackers: %s. Assign only the correct physical role. Assignments are session-local. No tracker means animation fallback. Calibration below saves headset height, not a full-body T-pose calibration." % devices.size()
	if not player.rig_report.get("valid", false): status.text += "\nRig warnings: " + str(player.rig_report.get("errors", []))

func _calibrate():
	if not is_instance_valid(player.tracking_modifier) or player.tracking_calibration.path.is_empty():
		status.text = "Load an account-owned avatar before calibration."
		return
	var data = {"schema": 1, "eye_height": clampf(player.xr_camera.position.y, 0.3, 2.5), "scale": 1.0,
		"head_offset": [0.0, 0.0, 0.0], "left_grip_offset": [0.0, 0.0, 0.0], "right_grip_offset": [0.0, 0.0, 0.0]}
	if player.tracking_calibration.save_calibration(data):
		player.tracking_modifier.set_calibration(data)
		status.text = "Headset height saved. Full-body orientation/offset calibration remains manual."
	else: status.text = "Calibration not saved: " + player.tracking_calibration.last_error
