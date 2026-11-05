extends CanvasLayer
## PC host for the tablet shell: a centered 4:3 2D menu over the dimmed game
## (docs/roadmaps/gui-tablet-specification.md §4.2). Not movable.

signal opened
signal closed

const COMPACT_HEIGHT := 560.0
const HEIGHT_SHARE := 0.86
const PAGE_KEYS = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]

## When true the overlay captures/releases the mouse like the previous menu did.
@export var manage_mouse := true

@onready var shell = %Shell
@onready var dim: ColorRect = %Dim

var _open := false

func _ready():
	visible = false
	shell.close_requested.connect(close)
	shell.quick_action.connect(_quick_action)
	dim.gui_input.connect(_dim_input)
	get_viewport().size_changed.connect(_viewport_resized)
	_viewport_resized()

func is_open() -> bool:
	return _open

func open():
	if _open:
		return
	shell.reset()
	_open = true
	visible = true
	dim.color = dim.get_theme_color("dim", "DesktopOverlay")
	_viewport_resized()
	if manage_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	opened.emit()

func close():
	if not _open:
		return
	_open = false
	visible = false
	var focus = get_viewport().gui_get_focus_owner()
	if focus != null and shell.is_ancestor_of(focus):
		focus.release_focus()
	if manage_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func toggle():
	if _open:
		close()
	else:
		open()

## size is the logical viewport size. Returns {rect: Rect2, compact: bool}.
func layout_for(size: Vector2) -> Dictionary:
	var height = size.y * HEIGHT_SHARE
	var width = height * 4.0 / 3.0
	if height < COMPACT_HEIGHT or width > size.x:
		var compact_width = minf(size.x, size.y * 4.0 / 3.0)
		return {"rect": Rect2(Vector2((size.x - compact_width) * 0.5, 0), Vector2(compact_width, size.y)), "compact": true}
	return {"rect": Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height)), "compact": false}

func apply_layout(size: Vector2):
	var layout = layout_for(size)
	var rect: Rect2 = layout.rect
	shell.position = rect.position
	shell.size = rect.size
	shell.set_compact(layout.compact)

func _viewport_resized():
	if is_inside_tree():
		apply_layout(get_viewport().get_visible_rect().size)

func _focus_blocks() -> bool:
	var focus = get_viewport().gui_get_focus_owner()
	return focus != null and focus.get_meta("blocks_global_shortcuts", false)

func _typing() -> bool:
	var focus = get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit or _focus_blocks()

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("open_menue"):
		if _focus_blocks():
			return false
		if not _open:
			open()
		elif not shell.back():
			close()
		return true
	if _open and event is InputEventKey and event.pressed and not event.echo:
		var code = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		var index = PAGE_KEYS.find(code)
		if index >= 0 and not _typing():
			shell.open_page(shell.PAGES[index])
			return true
	return false

func _input(event: InputEvent):
	if handle_input(event):
		get_viewport().set_input_as_handled()

func _dim_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var save = get_node_or_null("/root/SaveData")
		if save != null and save.voice.input_blocked:
			return # A key binding is being recorded.
		close()

func _quick_action(id: String):
	match id:
		"emotes":
			close()
			var network = get_node_or_null("/root/NetworkHandler")
			if network != null and network.has_method("get_animation_controller"):
				network.get_animation_controller().toggle_emote_menu()
		"respawn":
			var scene = get_tree().current_scene
			var player = get_parent()
			if scene != null and scene.has_method("return_player_to_spawn") and player is Node3D:
				scene.return_player_to_spawn(player)
