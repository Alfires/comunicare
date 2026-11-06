extends VBoxContainer
## Shared empty state: muted icon, one sentence and at most one action
## (docs/roadmaps/gui-tablet-specification.md §4.7).

var icon_rect: TextureRect
var message: Label
var action_button: Button
var _action: Callable

func _init():
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(icon_rect)
	message = Label.new()
	message.name = "Message"
	message.theme_type_variation = "MutedLabel"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	action_button = Button.new()
	action_button.name = "Action"
	action_button.custom_minimum_size.y = 48
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.pressed.connect(func(): if _action.is_valid(): _action.call())
	add_child(action_button)

func _notification(what: int):
	if what == NOTIFICATION_THEME_CHANGED and is_instance_valid(icon_rect):
		icon_rect.modulate = get_theme_color("font_color", "MutedLabel")

func configure(icon: Texture2D, text: String, action_label: String = "", action: Callable = Callable()):
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	message.text = text
	_action = action
	action_button.text = action_label
	action_button.visible = not action_label.is_empty() and action.is_valid()
