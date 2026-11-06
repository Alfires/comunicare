extends VBoxContainer
## Avatar browser detail pane: preview, license/source information, one primary
## action and inline progress instead of a modal dialog.

signal apply_requested(record: Dictionary)
signal preview_requested(record: Dictionary)
signal animation_preview_requested(record: Dictionary)
signal in_place_requested(record: Dictionary)
signal back_requested
signal preview_failed(message: String)

const RequestPolicy = preload("res://scripts/discovery/avatars/request_policy.gd")

var record: Dictionary = {}
var eligibility: Dictionary = {}
var preview: Control
var title_label: Label
var info_label: Label
var use_button: Button
var reason_label: Label
var progress: ProgressBar
var status_label: Label
var actions: VBoxContainer
var back_button: Button
var busy := false

func _init():
	custom_minimum_size.x = 380
	back_button = _button(self, "Back to results", func(): back_requested.emit())
	back_button.visible = false
	title_label = Label.new()
	title_label.theme_type_variation = "HeaderLabel"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title_label)
	info_label = Label.new()
	info_label.theme_type_variation = "MutedLabel"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info_label)
	use_button = _button(self, "Use this avatar", func(): apply_requested.emit(record))
	use_button.name = "UseButton"
	use_button.theme_type_variation = "PrimaryButton"
	reason_label = Label.new()
	reason_label.name = "Reason"
	reason_label.theme_type_variation = "CaptionLabel"
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.visible = false
	add_child(reason_label)
	progress = ProgressBar.new()
	progress.name = "Progress"
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	progress.visible = false
	add_child(progress)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.theme_type_variation = "CaptionLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	actions = VBoxContainer.new()
	add_child(actions)
	visible = false

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func show_record(next: Dictionary, allowed: Dictionary):
	record = next
	eligibility = allowed
	busy = false
	visible = true
	progress.visible = false
	status_label.text = ""
	ensure_preview()
	if preview.is_node_ready():
		preview.set_source("")
	var animation = record.get("type") == "animation"
	title_label.text = str(record.get("title", record.get("name", "Asset"))).left(200)
	info_label.text = "%s\nLicense: %s · Format: %s\nCompatibility is checked when the asset is imported." % [
		str(record.get("author", "Unknown author")).left(200), str(record.get("license", "Unknown")).left(100), str(record.get("format", "unknown")).left(20)]
	use_button.text = "Add to my library" if animation else "Use this avatar"
	var reason := ""
	if not allowed.get("can_import", false):
		reason = "This format cannot be imported."
	elif not allowed.get("share", false):
		reason = "This asset's license does not allow redistribution. You can still preview it."
	reason_label.text = reason
	reason_label.visible = not reason.is_empty()
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	if allowed.get("can_import", false):
		if animation:
			_button(actions, "Preview on my avatar", func(): animation_preview_requested.emit(record))
			_button(actions, "Import in place (remove movement)", func(): in_place_requested.emit(record))
		else:
			_button(actions, "Preview", func(): preview_requested.emit(record))
	var page = str(record.get("page_url", ""))
	if RequestPolicy.new().valid_url(page):
		_button(actions, "Open source page", func(): OS.shell_open(page))
	_update_use()

## The preview is created on first use so browsing never loads 3D/importer code.
func ensure_preview() -> Control:
	if not is_instance_valid(preview):
		preview = load("res://scenes/GUI/avatar_preview.tscn").instantiate()
		preview.custom_minimum_size = Vector2(0, 360)
		add_child(preview)
		move_child(preview, back_button.get_index() + 1)
		preview.failed.connect(func(message): preview_failed.emit(message))
	return preview

func _update_use():
	use_button.disabled = busy or record.is_empty() or not eligibility.get("can_import", false) or not eligibility.get("share", false)

## value 0–100; reaching 100 completes and hides the bar.
func set_progress(value: float, message: String):
	progress.value = value
	status_label.text = message
	busy = value < 100.0
	progress.visible = busy
	_update_use()

func show_error(message: String):
	busy = false
	progress.visible = false
	status_label.text = message
	_update_use()

func set_compact(compact: bool):
	back_button.visible = compact
