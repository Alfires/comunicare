extends Control
## Long read-only text (license terms, long descriptions) drawn directly through
## TextServer and RenderingServer. Unlike Label it does no shaping while hidden
## and none on theme changes until it is shown again, and its glyph commands live
## on an own canvas item that is only re-recorded when text, width, font or color
## change. Measured: 19 hidden license Labels cost ~500 ms to create and ~600 ms
## per theme switch; this control costs nothing until expanded.

var text := "":
	set(value):
		if value == text:
			return
		text = value
		_invalidate()
var theme_type := &"Label"

var _canvas_item: RID
var _paragraph: TextParagraph
var _shaped_width := -1.0
var _shaped_key := ""
var _recorded := false
var _height := 0.0

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_item = RenderingServer.canvas_item_create()

func _notification(what: int):
	match what:
		NOTIFICATION_ENTER_CANVAS:
			RenderingServer.canvas_item_set_parent(_canvas_item, get_canvas_item())
		NOTIFICATION_THEME_CHANGED:
			_shaped_key = ""
			_invalidate()
		NOTIFICATION_RESIZED:
			if absf(size.x - _shaped_width) > 0.5:
				_invalidate()
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_visible_in_tree() and _shaped_width < 0:
				update_minimum_size()
				queue_redraw()
		NOTIFICATION_PREDELETE:
			if _canvas_item.is_valid():
				RenderingServer.free_rid(_canvas_item)

func _invalidate():
	_shaped_width = -1.0
	_recorded = false
	update_minimum_size()
	queue_redraw()

func is_shaped() -> bool:
	return _paragraph != null and _shaped_width >= 0

## Shapes once for the current width/font; skipped entirely while hidden.
func _ensure_shaped() -> bool:
	if not is_visible_in_tree() or size.x < 1.0 or text.is_empty():
		return false
	var font: Font = get_theme_font("font", theme_type)
	var font_size: int = get_theme_font_size("font_size", theme_type)
	var key = "%s:%d" % [font.get_rid(), font_size]
	if _paragraph != null and key == _shaped_key and absf(size.x - _shaped_width) <= 0.5:
		return true
	_paragraph = TextParagraph.new()
	_paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	_paragraph.add_string(text, font, font_size)
	_paragraph.width = size.x
	_shaped_width = size.x
	_shaped_key = key
	_recorded = false
	_height = _paragraph.get_size().y
	return true

func _get_minimum_size() -> Vector2:
	if not _ensure_shaped():
		return Vector2.ZERO
	return Vector2(0, _height)

func _draw():
	if not _ensure_shaped():
		RenderingServer.canvas_item_clear(_canvas_item)
		return
	if _recorded:
		return
	RenderingServer.canvas_item_clear(_canvas_item)
	_paragraph.draw(_canvas_item, Vector2.ZERO, get_theme_color("font_color", theme_type))
	_recorded = true
	if not is_equal_approx(_height, size.y):
		update_minimum_size()
