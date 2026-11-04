extends PanelContainer
var player: Node
var rows: VBoxContainer
var status: Label
var choices: Dictionary = {}
var elapsed := 0.0
var countdown := -1.0

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
			else: player.tracker_roles.assign(role, id)
			if player.get("role_offsets") != null: player.role_offsets.erase(role))
		rows.add_child(choice)
	var calibrate = Button.new()
	calibrate.text = "Calibrate current body pose (3-second countdown)"
	calibrate.custom_minimum_size.y = 44
	calibrate.pressed.connect(_calibrate)
	rows.add_child(calibrate)
	var cancel = Button.new()
	cancel.text = "Cancel calibration"
	cancel.pressed.connect(func(): countdown = -1; status.text = "Calibration cancelled; previous values kept.")
	rows.add_child(cancel)
	var close = Button.new()
	close.text = "Back"
	close.pressed.connect(queue_free)
	rows.add_child(close)

func configure(owner_player: Node):
	player = owner_player
	_refresh()

func _process(delta: float):
	if not is_instance_valid(player): queue_free(); return
	if countdown >= 0:
		countdown -= delta
		status.text = "Stand comfortably with feet on the floor and arms matching your avatar. Keep assigned trackers still. Calibrating in %s…" % int(ceil(maxf(0, countdown)))
		if countdown <= 0:
			countdown = -1
			_capture()
		return
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
	status.text = "Runtime body trackers: %s. Assign correct roles, then calibrate their mounting position/orientation against the avatar pose. Assignments are session-local; recalibrate after reassignment or recenter. No device means animation fallback." % devices.size()
	if not player.rig_report.get("valid", false): status.text += "\nRig warnings: " + str(player.rig_report.get("errors", []))

func _calibrate():
	if not is_instance_valid(player.tracking_modifier) or player.tracking_calibration.path.is_empty():
		status.text = "Load an account-owned avatar before calibration."
		return
	countdown = 3.0

func _capture():
	if not is_instance_valid(player.skeleton) or not is_instance_valid(player.tracking_modifier): return
	var samples: Dictionary = player.tracker_roles.targets(Time.get_ticks_msec())
	var desired: Dictionary = {}
	var mapping: Dictionary = player.vrm_model.get_meta("humanoid_bones", {})
	for role in ["hips", "leftFoot", "rightFoot"]:
		var index = player.skeleton.find_bone(str(mapping.get(role, "")))
		if samples.has(role) and index >= 0:
			desired[role] = player.skeleton.global_transform * player.skeleton.get_bone_global_rest(index)
	var offsets = player.tracking_calibration.capture_roles(samples, desired)
	if offsets.size() != desired.size():
		status.text = "Tracker distance/orientation invalid. Previous calibration kept."
		return
	var data = {"schema": 1, "eye_height": clampf(player.xr_camera.position.y, 0.3, 2.5), "scale": 1.0,
		"head_offset": [0.0, 0.0, 0.0], "left_grip_offset": [0.0, 0.0, 0.0], "right_grip_offset": [0.0, 0.0, 0.0], "role_offsets": offsets}
	if player.tracking_calibration.save_calibration(data):
		player.tracking_modifier.set_calibration(data)
		player.role_offsets = offsets
		status.text = "Calibrated %s body roles against avatar reference pose. Move slowly to verify axes/reach; wrong role or stance requires recalibration." % offsets.size()
	else: status.text = "Calibration not saved: " + player.tracking_calibration.last_error
