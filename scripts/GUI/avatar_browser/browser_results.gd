extends VBoxContainer
## Avatar browser result grid: thumbnail cards plus a page area for the home
## categories. Network work stays in avatar_browser.gd; cards expose their
## thumbnail slot via the "thumbnail" meta.

signal record_selected(record: Dictionary)

const COLUMN_WIDTH := 220.0
const CARD_SIZE := Vector2(200, 248)
const THUMBNAIL := Vector2(200, 200)
const MODEL_ICON = preload("res://themes/icons/avatar.svg")

var page_box: VBoxContainer
var grid: GridContainer
var empty_state: Control
var _cards: Array = []

func _init():
	page_box = VBoxContainer.new()
	page_box.name = "PageBox"
	add_child(page_box)
	grid = GridContainer.new()
	grid.name = "Grid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)
	var empty = Label.new()
	empty.name = "EmptyState"
	empty.text = "No avatars match these filters."
	empty.theme_type_variation = "MutedLabel"
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.visible = false
	add_child(empty)
	empty_state = empty
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_layout)

func _layout():
	grid.columns = columns_for_width(size.x)

func columns_for_width(width: float) -> int:
	return maxi(1, int(floor(width / COLUMN_WIDTH)))

func cards() -> Array:
	return _cards.filter(func(card): return is_instance_valid(card))

func clear():
	_cards.clear()
	for box in [grid, page_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	empty_state.visible = false

func set_records(records: Array):
	clear()
	for record in records:
		add_record(record)
	empty_state.visible = records.is_empty()

func add_record(record: Dictionary) -> Button:
	var card = Button.new()
	card.theme_type_variation = "AvatarCard"
	card.custom_minimum_size = CARD_SIZE
	card.tooltip_text = str(record.get("title", "Asset")).left(200)
	card.clip_contents = true
	var column = VBoxContainer.new()
	column.theme_type_variation = "FlushVBox"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(column)
	var image = TextureRect.new()
	image.name = "Thumbnail"
	image.custom_minimum_size = THUMBNAIL
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = MODEL_ICON
	column.add_child(image)
	var title = Label.new()
	title.text = str(record.get("title", record.get("name", "Asset"))).left(100)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var caption = Label.new()
	var parts = [str(record.get("type", "")), str(record.get("provider", ""))].filter(func(part): return not part.is_empty())
	caption.text = " · ".join(PackedStringArray(parts))
	caption.theme_type_variation = "CaptionLabel"
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)
	card.set_meta("thumbnail", image)
	card.set_meta("record_key", str(record.get("provider", "")) + ":" + str(record.get("id", "")))
	card.pressed.connect(func(): record_selected.emit(record))
	grid.add_child(card)
	_cards.append(card)
	empty_state.visible = false
	return card

## Page-level button (home categories) above the grid.
func add_page_button(title: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	page_box.add_child(button)
	return button
