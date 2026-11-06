extends RefCounted
## Fills a Theme from palette tokens (docs/roadmaps/gui-tablet-specification.md §2).
## build() mutates the given Theme in place so every open control, including
## menus inside SubViewports, picks up a new color scheme without restart.

## Variable font (wght 200–800, default 400 = Regular). See THIRD_PARTY_ASSETS.md.
const FONT = "res://themes/fonts/AtkinsonHyperlegibleNext-Variable.ttf"
const BODY := 18
const TITLE := 24
const CAPTION := 14

var tokens: Dictionary
var theme: Theme
var dark := true
var semibold: FontVariation
## Corner roundness multiplier from interface.roundness, set by the theme service.
var roundness := 1.0
const ROUNDNESS = {"square": 0.0, "subtle": 1.0, "rounded": 2.0, "round": 3.0}
const MAX_RADIUS := 24

func build(target: Theme, values: Dictionary) -> Theme:
	theme = target
	tokens = values
	dark = values.get("kind", "dark") != "light"
	roundness = float(values.get("roundness_scale", roundness))
	theme.set_block_signals(true)
	_fonts()
	_constants()
	_labels()
	_buttons()
	_inputs()
	_containers()
	_popups()
	_ranges()
	_variations()
	_custom_colors()
	theme.set_block_signals(false)
	theme.emit_changed()
	return theme

# --- helpers ----------------------------------------------------------------

func c(name: String) -> Color:
	return tokens[name]

func mix(base: Color, toward: Color, amount: float) -> Color:
	return base.lerp(toward, amount)

func hover(base: Color) -> Color:
	return mix(base, c("text"), 0.08 if dark else 0.05)

func pressed(base: Color) -> Color:
	return mix(base, c("text"), 0.14 if dark else 0.10)

func faded(color: Color, alpha: float = 0.45) -> Color:
	return Color(color, color.a * alpha)

## Scales a design radius (spec values at "subtle") by the roundness setting.
func r(radius: int) -> int:
	return mini(int(round(radius * roundness)), MAX_RADIUS)

func box(fill: Color, radius: int = 4, margin_x: int = 12, margin_y: int = 8) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(r(radius))
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.anti_aliasing = true
	style.corner_detail = 6
	style.shadow_color = Color(style.shadow_color, 0.0)
	return style

func bordered(fill: Color, radius: int = 4, margin_x: int = 12, margin_y: int = 8, width: int = 1) -> StyleBoxFlat:
	var style = box(fill, radius, margin_x, margin_y)
	style.set_border_width_all(width)
	style.border_color = c("border")
	return style

func clear_box(margin_x: int = 12, margin_y: int = 8) -> StyleBoxFlat:
	var style = box(Color(c("surface"), 0.0), 4, margin_x, margin_y)
	style.draw_center = false
	return style

func focus_ring(radius: int = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(2)
	style.border_color = c("focus")
	style.set_corner_radius_all(r(radius))
	style.set_expand_margin_all(2)
	style.shadow_color = Color(style.shadow_color, 0.0)
	return style

func shadowed(style: StyleBoxFlat, size: int) -> StyleBoxFlat:
	style.shadow_size = size
	style.shadow_color = Color(0, 0, 0, 0.30 if dark else 0.18)
	style.shadow_offset = Vector2(0, 2)
	return style

func set_button_boxes(type: String, normal: StyleBox, hovered: StyleBox, down: StyleBox, disabled: StyleBox = null, radius: int = 4):
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hovered)
	theme.set_stylebox("pressed", type, down)
	theme.set_stylebox("hover_pressed", type, down)
	theme.set_stylebox("disabled", type, disabled if disabled != null else normal)
	theme.set_stylebox("focus", type, focus_ring(radius))

func set_font_colors(type: String, normal: Color, accent_hover: bool = false):
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(name, type, normal)
	theme.set_color("font_disabled_color", type, faded(normal))
	for name in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		theme.set_color(name, type, normal)
	theme.set_color("icon_disabled_color", type, faded(normal))
	if accent_hover:
		theme.set_color("font_pressed_color", type, c("text"))

# --- sections ---------------------------------------------------------------

func _fonts():
	theme.default_font_size = BODY
	if ResourceLoader.exists(FONT):
		theme.default_font = load(FONT)

func _semibold() -> Font:
	if semibold == null and ResourceLoader.exists(FONT):
		semibold = FontVariation.new()
		semibold.base_font = load(FONT)
		var weight = TextServerManager.get_primary_interface().name_to_tag("wght")
		semibold.variation_opentype = {weight: 600}
	return semibold

func _constants():
	for type in ["BoxContainer", "VBoxContainer", "HBoxContainer", "FlowContainer", "HFlowContainer", "VFlowContainer"]:
		theme.set_constant("separation", type, 8)
	for type in ["HFlowContainer", "VFlowContainer", "FlowContainer"]:
		theme.set_constant("h_separation", type, 8)
		theme.set_constant("v_separation", type, 8)
	theme.set_constant("h_separation", "GridContainer", 12)
	theme.set_constant("v_separation", "GridContainer", 12)
	theme.set_constant("separation", "HSplitContainer", 8)
	theme.set_constant("separation", "VSplitContainer", 8)

func _labels():
	theme.set_font_size("font_size", "Label", BODY)
	theme.set_color("font_color", "Label", c("text"))
	theme.set_color("font_shadow_color", "Label", Color(c("background"), 0.0))
	theme.set_color("default_color", "RichTextLabel", c("text"))
	theme.set_font_size("normal_font_size", "RichTextLabel", BODY)
	theme.set_color("font_color", "TooltipLabel", c("text"))
	theme.set_font_size("font_size", "TooltipLabel", CAPTION)
	theme.set_stylebox("panel", "TooltipPanel", shadowed(bordered(c("surface_raised"), 4, 8, 6), 4))
	var line = StyleBoxLine.new()
	line.color = c("border")
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	var vertical = StyleBoxLine.new()
	vertical.color = c("border")
	vertical.thickness = 1
	vertical.vertical = true
	theme.set_stylebox("separator", "VSeparator", vertical)
	theme.set_constant("separation", "HSeparator", 16)
	theme.set_constant("separation", "VSeparator", 16)

func _buttons():
	var raised = c("surface_raised")
	var normal = box(raised)
	if tokens.kind == "hc":
		normal = bordered(raised)
	var hovered = box(hover(raised))
	var down = box(pressed(raised))
	var disabled = box(raised)
	for type in ["Button", "OptionButton", "MenuButton"]:
		set_button_boxes(type, normal, hovered, down, disabled)
		theme.set_font_size("font_size", type, BODY)
		set_font_colors(type, c("text"))
		theme.set_constant("h_separation", type, 8)
	theme.set_constant("icon_max_width", "Button", 24)
	# CheckBox/CheckButton inherit Button lookups; keep them flat like labels.
	for type in ["CheckBox", "CheckButton"]:
		set_button_boxes(type, clear_box(4, 4), box(hover(c("surface")), 4, 4, 4), clear_box(4, 4))
		theme.set_stylebox("hover_pressed", type, box(hover(c("surface")), 4, 4, 4))
		set_font_colors(type, c("text"))
		theme.set_font_size("font_size", type, BODY)
	theme.set_color("checkbox_checked_color", "CheckBox", c("accent"))
	theme.set_color("checkbox_unchecked_color", "CheckBox", c("text_muted"))
	theme.set_color("button_checked_color", "CheckButton", c("accent"))
	theme.set_color("button_unchecked_color", "CheckButton", c("text_muted"))
	set_font_colors("LinkButton", c("accent"))
	theme.set_font_size("font_size", "LinkButton", BODY)

func _inputs():
	var field = bordered(c("surface"), 4, 10, 8)
	var focused = bordered(c("surface"), 4, 10, 8)
	focused.border_color = c("focus")
	focused.set_border_width_all(2)
	var read_only = bordered(c("background"), 4, 10, 8)
	for type in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type, field)
		theme.set_stylebox("focus", type, focused)
		theme.set_stylebox("read_only", type, read_only)
		theme.set_color("font_color", type, c("text"))
		theme.set_color("font_placeholder_color", type, c("text_muted"))
		theme.set_color("font_readonly_color", type, c("text_muted"))
		theme.set_color("font_selected_color", type, c("text"))
		theme.set_color("caret_color", type, c("text"))
		theme.set_color("selection_color", type, Color(c("accent"), 0.35))
		theme.set_color("clear_button_color", type, c("text_muted"))
		theme.set_font_size("font_size", type, BODY)

func _containers():
	theme.set_stylebox("panel", "Panel", box(c("surface"), 6, 0, 0))
	theme.set_stylebox("panel", "PanelContainer", box(c("surface"), 6, 0, 0))
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var tab_selected = box(c("surface_raised"), 4, 16, 8)
	tab_selected.border_width_bottom = 2
	tab_selected.border_color = c("accent")
	var tab_unselected = box(Color(c("surface"), 0.0), 4, 16, 8)
	tab_unselected.draw_center = false
	var tab_hover = box(hover(c("surface")), 4, 16, 8)
	for type in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type, tab_selected)
		theme.set_stylebox("tab_unselected", type, tab_unselected)
		theme.set_stylebox("tab_hovered", type, tab_hover)
		theme.set_stylebox("tab_disabled", type, tab_unselected)
		theme.set_stylebox("tab_focus", type, focus_ring())
		theme.set_color("font_selected_color", type, c("text"))
		theme.set_color("font_unselected_color", type, c("text_muted"))
		theme.set_color("font_hovered_color", type, c("text"))
		theme.set_color("font_disabled_color", type, faded(c("text_muted")))
		theme.set_font_size("font_size", type, BODY)
	theme.set_stylebox("panel", "TabContainer", box(c("surface"), 6, 0, 0))
	theme.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	for type in ["ItemList", "Tree"]:
		theme.set_stylebox("panel", type, bordered(c("surface"), 4, 4, 4))
		theme.set_stylebox("focus", type, focus_ring())
		theme.set_stylebox("selected", type, box(Color(c("accent"), 0.30), 4, 4, 4))
		theme.set_stylebox("selected_focus", type, box(Color(c("accent"), 0.40), 4, 4, 4))
		theme.set_stylebox("hovered", type, box(hover(c("surface")), 4, 4, 4))
		theme.set_color("font_color", type, c("text"))
		theme.set_color("font_selected_color", type, c("text"))
		theme.set_color("font_hovered_color", type, c("text"))
		theme.set_color("guide_color", type, Color(c("border"), 0.5))
		theme.set_font_size("font_size", type, BODY)

func _popups():
	var panel = shadowed(bordered(c("surface_raised"), 6, 4, 4), 8)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("hover", "PopupMenu", box(hover(c("surface_raised")), 4, 8, 6))
	theme.set_stylebox("separator", "PopupMenu", theme.get_stylebox("separator", "HSeparator"))
	for name in ["font_color", "font_hover_color", "font_accelerator_color"]:
		theme.set_color(name, "PopupMenu", c("text") if name != "font_accelerator_color" else c("text_muted"))
	theme.set_color("font_disabled_color", "PopupMenu", faded(c("text")))
	theme.set_font_size("font_size", "PopupMenu", BODY)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_stylebox("panel", "PopupPanel", shadowed(bordered(c("surface_raised"), 6, 16, 16), 8))
	var window = shadowed(bordered(c("surface_raised"), 6, 0, 0), 8)
	window.set_expand_margin_all(4)
	window.expand_margin_top = 36
	theme.set_stylebox("embedded_border", "Window", window)
	theme.set_stylebox("embedded_unfocused_border", "Window", window)
	theme.set_color("title_color", "Window", c("text"))
	theme.set_font_size("title_font_size", "Window", BODY)
	theme.set_stylebox("panel", "AcceptDialog", box(c("surface_raised"), 6, 16, 16))

func _ranges():
	theme.set_stylebox("background", "ProgressBar", box(c("surface_raised"), 4, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", box(c("accent"), 4, 0, 0))
	theme.set_color("font_color", "ProgressBar", c("text"))
	var track = box(c("surface_raised"), 4, 0, 3)
	var area = box(c("accent"), 4, 0, 3)
	for type in ["HSlider", "VSlider"]:
		theme.set_stylebox("slider", type, track)
		theme.set_stylebox("grabber_area", type, area)
		theme.set_stylebox("grabber_area_highlight", type, area)
	for type in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type, box(Color(c("surface"), 0.0), 4, 4, 4))
		theme.set_stylebox("scroll_focus", type, box(Color(c("surface"), 0.0), 4, 4, 4))
		theme.set_stylebox("grabber", type, box(c("border"), 4, 4, 4))
		theme.set_stylebox("grabber_highlight", type, box(mix(c("border"), c("text"), 0.2), 4, 4, 4))
		theme.set_stylebox("grabber_pressed", type, box(mix(c("border"), c("text"), 0.35), 4, 4, 4))

func _variations():
	var semibold = _semibold()
	_variation("HeaderLabel", "Label")
	theme.set_font_size("font_size", "HeaderLabel", TITLE)
	theme.set_color("font_color", "HeaderLabel", c("text"))
	if semibold != null: theme.set_font("font", "HeaderLabel", semibold)
	_variation("CaptionLabel", "Label")
	theme.set_font_size("font_size", "CaptionLabel", CAPTION)
	theme.set_color("font_color", "CaptionLabel", c("text_muted"))
	_variation("MutedLabel", "Label")
	theme.set_font_size("font_size", "MutedLabel", BODY)
	theme.set_color("font_color", "MutedLabel", c("text_muted"))

	_variation("PrimaryButton", "Button")
	var accent = c("accent")
	var accent_hover = accent.lightened(0.08) if dark else accent.darkened(0.08)
	set_button_boxes("PrimaryButton", box(accent), box(accent_hover), box(accent.darkened(0.12)), box(faded(accent, 0.5)))
	set_font_colors("PrimaryButton", c("accent_text"))
	if semibold != null: theme.set_font("font", "PrimaryButton", semibold)

	_variation("DangerButton", "Button")
	var danger = c("danger")
	var danger_hover = danger.lightened(0.08) if dark else danger.darkened(0.08)
	set_button_boxes("DangerButton", box(danger), box(danger_hover), box(danger.darkened(0.12)), box(faded(danger, 0.5)))
	set_font_colors("DangerButton", c("accent_text"))

	_variation("IconButton", "Button")
	set_button_boxes("IconButton", clear_box(12, 12), box(hover(c("surface")), 4, 12, 12), box(pressed(c("surface")), 4, 12, 12), clear_box(12, 12))
	theme.set_stylebox("pressed", "IconButton", _active(c("surface"), 12, 12, false))
	set_font_colors("IconButton", c("text"))
	theme.set_constant("icon_max_width", "IconButton", 24)

	_variation("NavButton", "Button")
	set_button_boxes("NavButton", clear_box(8, 8), box(hover(c("surface")), 4, 8, 8), _active(c("surface_raised"), 8, 8, true))
	set_font_colors("NavButton", c("text_muted"))
	for name in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color", "font_hover_color", "icon_hover_color"]:
		theme.set_color(name, "NavButton", c("text"))
	theme.set_font_size("font_size", "NavButton", CAPTION)
	theme.set_constant("icon_max_width", "NavButton", 24)
	theme.set_constant("h_separation", "NavButton", 4)

	_variation("QuickTile", "Button")
	var tile = box(c("surface_raised"), 4, 16, 16)
	if tokens.kind == "hc": tile = bordered(c("surface_raised"), 4, 16, 16)
	set_button_boxes("QuickTile", tile, box(hover(c("surface_raised")), 4, 16, 16), _active(c("surface_raised"), 16, 16, true))
	set_font_colors("QuickTile", c("text"))
	theme.set_constant("icon_max_width", "QuickTile", 32)
	theme.set_constant("h_separation", "QuickTile", 8)
	theme.set_font_size("font_size", "QuickTile", BODY)

	_variation("Sidebar", "PanelContainer")
	var sidebar = box(c("surface"), 0, 0, 8)
	sidebar.border_width_right = 1
	sidebar.border_color = c("border")
	sidebar.corner_radius_bottom_left = r(12)
	theme.set_stylebox("panel", "Sidebar", sidebar)

	_variation("ListRow", "PanelContainer")
	theme.set_stylebox("panel", "ListRow", box(c("surface_raised"), 4, 12, 8))

	_variation("PreviewStage", "PanelContainer")
	theme.set_stylebox("panel", "PreviewStage", box(c("preview_stage"), 6, 0, 0))

	_variation("Toast", "PanelContainer")
	theme.set_stylebox("panel", "Toast", _toast_box())

	_variation("TabletFrame", "PanelContainer")
	var frame = shadowed(bordered(c("background"), 12, 0, 0), 8)
	theme.set_stylebox("panel", "TabletFrame", frame)

	_variation("StatusBar", "PanelContainer")
	var status = box(c("surface"), 0, 8, 4)
	status.corner_radius_top_left = r(12)
	status.corner_radius_top_right = r(12)
	status.border_width_bottom = 1
	status.border_color = c("border")
	theme.set_stylebox("panel", "StatusBar", status)

	_variation("PageHeader", "PanelContainer")
	var header = box(c("background"), 0, 24, 8)
	theme.set_stylebox("panel", "PageHeader", header)

	# Layout helpers so scenes never need inline theme overrides.
	_variation("FlushVBox", "VBoxContainer")
	theme.set_constant("separation", "FlushVBox", 0)
	_variation("FlushHBox", "HBoxContainer")
	theme.set_constant("separation", "FlushHBox", 0)
	_variation("SectionVBox", "VBoxContainer")
	theme.set_constant("separation", "SectionVBox", 16)
	_variation("WideHBox", "HBoxContainer")
	theme.set_constant("separation", "WideHBox", 24)
	_variation("ErrorLabel", "Label")
	theme.set_font_size("font_size", "ErrorLabel", CAPTION)
	theme.set_color("font_color", "ErrorLabel", c("danger"))
	_variation("SpacedVBox", "VBoxContainer")
	theme.set_constant("separation", "SpacedVBox", 12)
	_variation("SpacedHBox", "HBoxContainer")
	theme.set_constant("separation", "SpacedHBox", 12)
	_variation("CardMargin", "MarginContainer")
	for side in ["left", "right"]: theme.set_constant("margin_" + side, "CardMargin", 16)
	for side in ["top", "bottom"]: theme.set_constant("margin_" + side, "CardMargin", 12)
	_variation("InsetMargin", "MarginContainer")
	for side in ["left", "top", "right", "bottom"]:
		theme.set_constant("margin_" + side, "InsetMargin", 8)
	_variation("ContentArea", "PanelContainer")
	theme.set_stylebox("panel", "ContentArea", box(c("background"), 0, 24, 16))
	_variation("ContentAreaCompact", "PanelContainer")
	theme.set_stylebox("panel", "ContentAreaCompact", box(c("background"), 0, 16, 12))
	_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", bordered(c("surface"), 6, 16, 16))

	_variation("AvatarCard", "Button")
	set_button_boxes("AvatarCard", bordered(c("surface"), 6, 0, 0), bordered(hover(c("surface")), 6, 0, 0), _active(c("surface_raised"), 0, 0, true), null, 6)
	set_font_colors("AvatarCard", c("text"))

	_variation("FriendChip", "Button")
	set_button_boxes("FriendChip", box(c("surface_raised"), 24, 6, 4), box(hover(c("surface_raised")), 24, 6, 4), box(pressed(c("surface_raised")), 24, 6, 4), null, 24)
	set_font_colors("FriendChip", c("text"))
	theme.set_constant("icon_max_width", "FriendChip", 40)

	_variation("Swatch", "Button")
	var swatch = box(c("surface"), 6, 4, 4)
	swatch.set_border_width_all(1)
	swatch.border_color = c("border")
	var chosen = box(c("surface"), 6, 4, 4)
	chosen.set_border_width_all(3)
	chosen.border_color = c("focus")
	set_button_boxes("Swatch", swatch, swatch, chosen, null, 6)
	theme.set_stylebox("hover_pressed", "Swatch", chosen)
	set_font_colors("Swatch", c("text"))
	theme.set_font_size("font_size", "Swatch", CAPTION)

func _variation(name: String, base: String):
	theme.set_type_variation(name, base)

func _active(fill: Color, margin_x: int, margin_y: int, bar: bool) -> StyleBoxFlat:
	var style = box(fill, 4, margin_x, margin_y)
	if bar:
		style.border_width_left = 3
		style.border_color = c("accent")
		style.content_margin_left = margin_x
	else:
		style.bg_color = pressed(fill)
	return style

func _toast_box() -> StyleBoxFlat:
	var style = shadowed(bordered(c("surface_raised"), 6, 16, 12), 6)
	style.shadow_color = Color(0, 0, 0, 0.25)
	return style

func _custom_colors():
	theme.set_color("segment", "EmoteWheel", c("surface_raised"))
	theme.set_color("segment_hover", "EmoteWheel", mix(c("surface_raised"), c("accent"), 0.55))
	theme.set_color("segment_disabled", "EmoteWheel", c("surface"))
	theme.set_color("label", "EmoteWheel", c("text"))
	theme.set_color("label_disabled", "EmoteWheel", c("text_muted"))
	theme.set_color("message", "EmoteWheel", c("warning"))
	theme.set_color("background", "CircularValue", Color(c("surface"), 0.97))
	theme.set_color("track", "CircularValue", c("border"))
	theme.set_color("knob", "CircularValue", c("accent"))
	theme.set_color("label", "CircularValue", c("text"))
	theme.set_color("shade", "ErrorPopup", c("overlay_dim"))
	theme.set_color("background", "PreviewStage", c("preview_stage"))
	theme.set_color("floor", "PreviewStage", c("surface_raised"))
	theme.set_color("dim", "DesktopOverlay", c("overlay_dim"))
	theme.set_color("frame", "TabletFrame", c("surface_raised"))
	for kind in ["success", "warning", "danger"]:
		theme.set_color(kind, "Toast", c(kind))
	theme.set_color("info", "Toast", c("accent"))
	# Initials sit on muted mid-tone avatar colors in every preset.
	theme.set_color("letter", "ContactAvatar", Color(1, 1, 1, 0.95))
	theme.set_color("online", "Presence", c("success"))
	theme.set_color("do_not_disturb", "Presence", c("danger"))
	theme.set_color("offline", "Presence", c("text_muted"))
	theme.set_color("accent", "Palette", c("accent"))
	theme.set_color("danger", "Palette", c("danger"))
	theme.set_color("text_muted", "Palette", c("text_muted"))
