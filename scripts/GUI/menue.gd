extends Control
## Thin wrapper around the shared tablet shell, kept at this path/UID for the
## VR tablet, the desktop player and existing callers. Navigation lives in
## scripts/GUI/tablet_shell.gd.

signal close_requested

## Index-based access kept for older callers: Home, Friends, World Explorer, Settings.
const LEGACY_TABS = ["quick", "friends", "worlds", "settings"]

@onready var shell = $Shell

var current_tab: int:
	get:
		return LEGACY_TABS.find(shell.current_page()) if shell != null else 0
	set(value):
		if shell != null and value >= 0 and value < LEGACY_TABS.size():
			shell.open_page(LEGACY_TABS[value])

func _ready():
	shell.close_requested.connect(close)

func page(id: String) -> Control:
	return shell.page(id)

func open_page(id: String) -> bool:
	return shell.open_page(id)

func reset():
	shell.reset()

func close():
	if get_viewport().get_meta("vr_menu", false):
		close_requested.emit()
		return
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	close_requested.emit()

func _input(event):
	if get_viewport().get_meta("vr_menu", false): return
	if event.is_action_pressed("open_menue"):
		var focus = get_viewport().gui_get_focus_owner()
		if focus != null and focus.get_meta("blocks_global_shortcuts", false):
			return
		if visible and shell.back():
			get_viewport().set_input_as_handled()
			return
		if not visible:
			reset()
		visible = !visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
