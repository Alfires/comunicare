extends "res://common.gd"
## Parts 2–5: tokens/palette, theme builder, color settings, hard-coded styling,
## font and icon set.

const VARIATIONS = {
	"HeaderLabel": "Label", "CaptionLabel": "Label", "MutedLabel": "Label",
	"PrimaryButton": "Button", "DangerButton": "Button", "IconButton": "Button",
	"NavButton": "Button", "QuickTile": "Button", "Sidebar": "PanelContainer",
	"ListRow": "PanelContainer", "PreviewStage": "PanelContainer", "Toast": "PanelContainer",
	"TabletFrame": "PanelContainer", "StatusBar": "PanelContainer",
}
const CUSTOM_COLORS = {
	"EmoteWheel": ["segment", "segment_hover", "segment_disabled", "label", "label_disabled", "message"],
	"CircularValue": ["background", "track", "knob"],
	"ErrorPopup": ["shade"],
	"PreviewStage": ["background"],
	"DesktopOverlay": ["dim"],
}
const REQUIRED_ICONS = ["home", "quick", "friends", "world", "avatar", "instance", "settings",
	"emote", "close", "search", "rotate", "zoom", "reset", "folder", "warning", "check",
	"people", "pin", "microphone", "microphone_muted", "profile", "back", "edit"]
## Values from docs/roadmaps/gui-tablet-specification.md §2.1/§2.2.
const SPEC_PRESETS = {
	"graphite": {"background": "#1c1d1f", "surface": "#242528", "surface_raised": "#2e3034", "border": "#4a4d52", "text": "#ebe9e4", "text_muted": "#a9a7a1", "preview_stage": "#2b2c2f"},
	"paper": {"background": "#f3f1ec", "surface": "#fbfaf7", "surface_raised": "#ffffff", "border": "#cfccc4", "text": "#1f2023", "text_muted": "#5a5c61", "preview_stage": "#e6e3dc"},
	"forest": {"background": "#1a201d", "surface": "#212824", "surface_raised": "#2a322d", "border": "#45504a", "text": "#e6ebe7", "text_muted": "#a3ada6", "preview_stage": "#28302b"},
	"sand": {"background": "#efe8dc", "surface": "#f7f2e9", "surface_raised": "#fdfaf4", "border": "#d3c8b5", "text": "#2b261f", "text_muted": "#5e564a", "preview_stage": "#e4dccd"},
	"night": {"background": "#0b0b0c", "surface": "#131315", "surface_raised": "#1b1b1e", "border": "#34343a", "text": "#d9d8d4", "text_muted": "#9a9893", "preview_stage": "#18181b"},
	"high_contrast": {"background": "#000000", "surface": "#000000", "surface_raised": "#141414", "border": "#ffffff", "text": "#ffffff", "text_muted": "#e6e6e6", "preview_stage": "#1a1a1a"},
}
const SPEC_ACCENTS = { # on dark, on light, on high contrast
	"teal": ["#4fb3a9", "#1d6b64", "#6fd6cb"], "blue": ["#6ea1e0", "#2b5ea8", "#8fb8ee"],
	"amber": ["#e0a43a", "#85591c", "#f0bd5e"], "green": ["#7bbf6a", "#3a6b2c", "#98d488"],
	"rose": ["#e07a8f", "#a3364d", "#eda0b0"], "violet": ["#a58be0", "#6747a6", "#c0aeee"],
}
const DRAWN_SCRIPTS = ["res://scripts/GUI/circular_value_control.gd", "res://scripts/GUI/emote_wheel.gd",
	"res://scripts/GUI/xr_emote_wheel.gd", "res://scripts/GUI/error_popup.gd"]

func suite_name() -> String:
	return "theme (parts 2-5)"

func run():
	test_palette()
	await test_builder()
	await test_project_theme()
	await test_color_settings()
	await test_swatch_settings_ui()
	test_hard_coded_styling()
	test_font()
	test_icons()
	test_no_glyph_buttons()

# --- Part 2 -----------------------------------------------------------------

func test_palette():
	if not begin(2): return
	var colors = script_component("res://scripts/GUI/theme/palette.gd", ["presets", "accents", "tokens"])
	if colors == null: return
	check(Array(colors.presets()) == PRESETS, "palette offers exactly the six roadmap presets in order")
	check(Array(colors.accents()) == ACCENTS, "palette offers the six accents plus Match 3D highlight")
	var incomplete: Array = []
	var weak_text: Array = []
	var weak_accent: Array = []
	var weak_focus: Array = []
	for preset in PRESETS:
		for accent in ACCENTS:
			for highlight in (HIGHLIGHTS if accent == "match_highlight" else ["cyan"]):
				var tokens = colors.tokens(preset, accent, highlight)
				var label = "%s/%s/%s" % [preset, accent, highlight]
				if not tokens is Dictionary or TOKENS.any(func(key): return not tokens.get(key) is Color):
					incomplete.append(label)
					continue
				var minimum = 7.0 if preset == "high_contrast" else 4.5
				for pair in [["text", "background"], ["text", "surface"], ["text", "surface_raised"], ["text_muted", "surface"]]:
					if contrast(tokens[pair[0]], tokens[pair[1]]) < minimum:
						weak_text.append(label + ":" + pair[0] + "/" + pair[1])
				if contrast(tokens.accent_text, tokens.accent) < 4.5:
					weak_accent.append(label)
				if contrast(tokens.focus, tokens.background) < 3.0 or contrast(tokens.danger, tokens.surface) < 3.0:
					weak_focus.append(label)
	check(incomplete.is_empty(), "every preset × accent defines all %d Color tokens %s" % [TOKENS.size(), incomplete.slice(0, 3)])
	if not incomplete.is_empty(): return
	check(weak_text.is_empty(), "body/muted text reaches 4.5:1 (7:1 high contrast) on every surface %s" % [weak_text.slice(0, 3)])
	check(weak_accent.is_empty(), "accent_text on accent reaches 4.5:1 for every accent incl. matched highlights %s" % [weak_accent.slice(0, 3)])
	check(weak_focus.is_empty(), "focus ring and danger reach 3:1 non-text contrast %s" % [weak_focus.slice(0, 3)])
	# "Made by people" restraint rules: neutral surfaces, non-neon accents.
	var loud: Array = []
	for preset in PRESETS:
		var tokens = colors.tokens(preset, "teal", "cyan")
		for key in ["background", "surface", "surface_raised", "border"]:
			if tokens[key].s > 0.25: loud.append(preset + "." + key)
		for accent in ACCENTS.slice(0, 6):
			var value: Color = colors.tokens(preset, accent, "cyan").accent
			if value.s > 0.85: loud.append(preset + "." + accent)
	check(loud.is_empty(), "surfaces stay neutral (saturation ≤ 0.25) and accents are not neon (≤ 0.85) %s" % [loud.slice(0, 4)])
	for preset in ["graphite", "forest", "night"]:
		check(luminance(colors.tokens(preset, "teal", "cyan").background) < 0.08, preset + " is a dark preset")
	for preset in ["paper", "sand"]:
		var background: Color = colors.tokens(preset, "teal", "cyan").background
		check(luminance(background) > 0.7 and not background.is_equal_approx(Color.WHITE), preset + " is light but off-white")
	check(luminance(colors.tokens("night", "teal", "cyan").background) < luminance(colors.tokens("graphite", "teal", "cyan").background),
		"Night is darker than Graphite for low-brightness VR use")
	var backgrounds: Array = []
	for preset in PRESETS:
		backgrounds.append(colors.tokens(preset, "teal", "cyan").background.to_html())
	var unique: Dictionary = {}
	for value in backgrounds: unique[value] = true
	check(unique.size() == PRESETS.size(), "every preset has a distinct background")
	var accents: Dictionary = {}
	for accent in ACCENTS.slice(0, 6):
		accents[colors.tokens("graphite", accent, "cyan").accent.to_html()] = true
	check(accents.size() == 6, "each named accent produces a distinct color")
	var yellow: Color = colors.tokens("graphite", "match_highlight", "yellow").accent
	check(yellow.h > 0.09 and yellow.h < 0.2 and not yellow.is_equal_approx(colors.tokens("graphite", "match_highlight", "cyan").accent),
		"Match 3D highlight follows interface.hover_color (yellow → yellow accent)")
	var mismatched: Array = []
	for preset in SPEC_PRESETS:
		var tokens = colors.tokens(preset, "teal", "cyan")
		for key in SPEC_PRESETS[preset]:
			if not colors_equal(tokens[key], Color(SPEC_PRESETS[preset][key])): mismatched.append(preset + "." + key)
		var kind = 2 if preset == "high_contrast" else (1 if preset in ["paper", "sand"] else 0)
		for accent in SPEC_ACCENTS:
			var value = colors.tokens(preset, accent, "cyan").accent
			if not colors_equal(value, Color(SPEC_ACCENTS[accent][kind])): mismatched.append(preset + "/" + accent)
	check(mismatched.is_empty(), "palette values match the specification tables %s" % [mismatched.slice(0, 5)])
	var mapped: Array = []
	for pair in [["cyan", "teal"], ["yellow", "amber"], ["green", "green"], ["magenta", "rose"]]:
		if not colors_equal(colors.tokens("graphite", "match_highlight", pair[0]).accent, colors.tokens("graphite", pair[1], "cyan").accent):
			mapped.append(pair[0])
	check(mapped.is_empty() and colors_equal(colors.tokens("graphite", "match_highlight", "white").accent, Color("#d6d3cc")),
		"Match 3D highlight maps cyan/yellow/green/magenta/white to Teal/Amber/Green/Rose/Neutral %s" % [mapped])
	check(colors.tokens("unknown", "unknown", "cyan") == colors.tokens("graphite", "teal", "cyan"),
		"unknown preset/accent fall back to Graphite/Teal")
	check(colors.tokens("paper", "rose", "cyan") == colors.tokens("paper", "rose", "cyan"), "tokens are deterministic")

func test_builder():
	if not begin(2): return
	var colors = palette()
	var builder = script_component("res://scripts/GUI/theme/theme_builder.gd", ["build"])
	if builder == null or colors == null:
		if colors == null: check(false, "theme builder test needs palette.gd")
		return
	var tokens: Dictionary = colors.tokens("graphite", "teal", "cyan")
	var theme = Theme.new()
	var changes = [0]
	theme.changed.connect(func(): changes[0] += 1)
	check(builder.build(theme, tokens) == theme, "builder mutates and returns the provided Theme instance")
	check(changes[0] > 0, "building emits Theme.changed so open controls refresh")
	var button = theme.get_stylebox("normal", "Button")
	check(button is StyleBoxFlat and colors_equal(button.bg_color, tokens.surface_raised) and button.corner_radius_top_left == 4,
		"Button uses surface_raised with a 4 px radius")
	var panel = theme.get_stylebox("panel", "PanelContainer")
	check(panel is StyleBoxFlat and colors_equal(panel.bg_color, tokens.surface) and panel.corner_radius_top_left == 6,
		"PanelContainer uses surface with a 6 px radius")
	check(colors_equal(theme.get_color("font_color", "Label"), tokens.text), "Label text uses the text token")
	var wrong: Array = []
	for name in VARIATIONS:
		if theme.get_type_variation_base(name) != StringName(VARIATIONS[name]): wrong.append(name)
	check(wrong.is_empty(), "type variations replace inline overrides %s" % [wrong])
	var primary = theme.get_stylebox("normal", "PrimaryButton")
	check(primary is StyleBoxFlat and colors_equal(primary.bg_color, tokens.accent)
		and colors_equal(theme.get_color("font_color", "PrimaryButton"), tokens.accent_text), "PrimaryButton is the only accent-filled button")
	var danger = theme.get_stylebox("normal", "DangerButton")
	check(danger is StyleBoxFlat and colors_equal(danger.bg_color, tokens.danger), "DangerButton uses the danger token")
	check(colors_equal(theme.get_color("font_color", "MutedLabel"), tokens.text_muted), "MutedLabel uses text_muted")
	var nav = theme.get_stylebox("pressed", "NavButton")
	check(nav is StyleBoxFlat and nav.border_width_left >= 3 and colors_equal(nav.border_color, tokens.accent),
		"active NavButton is marked with an accent bar")
	var focus = theme.get_stylebox("focus", "Button")
	check(focus is StyleBoxFlat and not focus.draw_center and focus.border_width_top >= 2 and colors_equal(focus.border_color, tokens.focus),
		"focus is a visible ≥2 px ring in the focus color")
	var body = theme.get_font_size("font_size", "Label")
	var header = theme.get_font_size("font_size", "HeaderLabel")
	var caption = theme.get_font_size("font_size", "CaptionLabel")
	var sizes: Dictionary = {}
	for type in ["Label", "HeaderLabel", "CaptionLabel", "MutedLabel", "Button"]:
		sizes[theme.get_font_size("font_size", type)] = true
	check(theme.has_default_font_size() and header > body and body > caption and sizes.size() == 3,
		"exactly three text sizes: title > body > caption")
	check(body == 18 and header == 24 and caption == 14 and theme.default_font_size == 18,
		"text sizes match the specification: 18 / 24 / 14 px")
	var spacing: Array = []
	for pair in [["separation", "VBoxContainer"], ["separation", "HBoxContainer"], ["h_separation", "GridContainer"],
		["v_separation", "GridContainer"]]:
		var value = theme.get_constant(pair[0], pair[1])
		if value <= 0 or value % 4 != 0: spacing.append("%s.%s=%s" % [pair[1], pair[0], value])
	check(spacing.is_empty(), "spacing constants follow the 4 px grid %s" % [spacing])
	var decorative: Array = []
	for type in theme.get_stylebox_type_list():
		for name in theme.get_stylebox_list(type):
			var box = theme.get_stylebox(name, type)
			if not (box is StyleBoxFlat or box is StyleBoxEmpty or box is StyleBoxLine):
				decorative.append("%s.%s" % [type, name])
			elif box is StyleBoxFlat and (box.shadow_size > 8 or box.shadow_color.a > 0.35):
				decorative.append("%s.%s shadow" % [type, name])
	check(decorative.is_empty(), "no textures/gradients and only subtle shadows (≤8 px, ≤35%% alpha) %s" % [decorative.slice(0, 4)])
	var missing: Array = []
	for type in CUSTOM_COLORS:
		for name in CUSTOM_COLORS[type]:
			if not theme.has_color(name, type): missing.append(type + "." + name)
	check(missing.is_empty(), "custom-drawn controls get theme colors %s" % [missing])
	check(colors_equal(theme.get_color("background", "PreviewStage"), tokens.preview_stage), "PreviewStage background uses its token")
	check(colors_equal(theme.get_color("dim", "DesktopOverlay"), tokens.overlay_dim), "desktop overlay dim uses its token")
	var holder = PanelContainer.new()
	holder.theme = theme
	var label = Label.new()
	holder.add_child(label)
	root.add_child(holder)
	var paper: Dictionary = colors.tokens("paper", "teal", "cyan")
	builder.build(theme, paper)
	await frames() # Control connects to Theme.changed deferred.
	check(colors_equal(label.get_theme_color("font_color"), paper.text), "rebuilding the same Theme recolors already-open controls")
	holder.free()

func test_project_theme():
	if not begin(2): return
	var gui = RegEx.create_from_string("(?ms)^\\[gui\\]\\s*$(.*?)(?=^\\[|\\z)").search(evidence("project.godot"))
	check(gui != null and gui.get_string(1).contains('theme/custom="res://themes/default.tres"'),
		"project.godot registers themes/default.tres as the project theme ([gui] theme/custom)")
	var theme = project_theme()
	check(theme != null and theme.resource_path == "res://themes/default.tres", "the shared Theme loads at startup for every window")
	var save = autoload("SaveData")
	var service = save.get("theme_service") if save != null else null
	check(service != null and service.has_method("current_tokens") and service.has_method("apply"),
		"SaveData owns a theme service after settings load")
	if service == null or theme == null or not service.has_method("current_tokens"): return
	var viewport = SubViewport.new()
	var label = Label.new()
	viewport.add_child(label)
	root.add_child(viewport)
	await frames()
	check(colors_equal(label.get_theme_color("font_color"), service.current_tokens().get("text")),
		"a Label inside a SubViewport (VR tablet path) resolves the active palette")
	viewport.free()
	check(not source("res://scripts/GUI/menue.gd").contains('get_theme_stylebox("panel").duplicate()'),
		"menue.gd no longer patches TabContainer margins at runtime (wiring check)")

# --- Part 3 -----------------------------------------------------------------

func test_color_settings():
	if not begin(3): return
	var save = autoload("SaveData")
	var registry = save.registry
	var expected = {
		"interface.theme_preset": {"type": "enum", "default": "graphite", "options": PRESETS},
		"interface.accent": {"type": "enum", "default": "teal", "options": ACCENTS},
		"interface.ui_scale": {"type": "number", "default": 1.0, "min": 0.75, "max": 1.5, "step": 0.05},
		"interface.reduce_motion": {"type": "boolean", "default": false},
	}
	for id in expected:
		var definition: Dictionary = registry.get_definition(id)
		var spec: Dictionary = expected[id]
		var valid = definition.get("category") == "Interface" and definition.get("type") == spec.type \
			and definition.get("default") == spec.default
		if spec.has("options"): valid = valid and definition.get("options") is Dictionary and definition.options.keys() == spec.options
		for key in ["min", "max", "step"]:
			if spec.has(key): valid = valid and is_equal_approx(float(definition.get(key, -1)), spec[key])
		check(valid, "Interface setting registered: " + id)
	var highlight: Dictionary = registry.get_definition("interface.hover_color")
	check(highlight.get("options", {}).keys() == HIGHLIGHTS and highlight.get("default") == "cyan",
		"existing 3D highlight setting is unchanged")
	if registry.get_definition("interface.theme_preset").is_empty(): return
	check(not save.store.set_value("interface.theme_preset", "neon"), "unknown presets are rejected by validation")
	var service = save.get("theme_service")
	var colors = palette()
	var theme = project_theme()
	if service == null or colors == null or theme == null:
		check(false, "live switching needs theme service, palette and project theme")
		return
	save.store.set_value("interface.theme_preset", "paper")
	await frames()
	var paper: Dictionary = colors.tokens("paper", save.store.get_value("interface.accent"), save.store.get_value("interface.hover_color"))
	check(colors_equal(theme.get_color("font_color", "Label"), paper.text) and service.current_tokens() == paper,
		"switching preset recolors the shared Theme live, without restart")
	save.store.set_value("interface.accent", "amber")
	await frames()
	var primary = theme.get_stylebox("normal", "PrimaryButton")
	check(primary is StyleBoxFlat and colors_equal(primary.bg_color, colors.tokens("paper", "amber", "cyan").accent),
		"switching accent recolors primary actions live")
	save.store.set_value("interface.accent", "match_highlight")
	save.store.set_value("interface.hover_color", "yellow")
	await frames()
	check(colors_equal(service.current_tokens().get("accent"), colors.tokens("paper", "match_highlight", "yellow").accent),
		"Match 3D highlight reacts to hover_color changes")
	save.store.set_value("interface.ui_scale", 1.25)
	await frames()
	check(is_equal_approx(root.content_scale_factor, 1.25), "desktop UI scale applies to the root window content scale")
	save.store.set_value("interface.reduce_motion", true)
	check(service.get("reduce_motion") == true, "theme service exposes reduce_motion to animated controls")
	for id in ["interface.theme_preset", "interface.accent", "interface.hover_color", "interface.ui_scale", "interface.reduce_motion"]:
		save.store.reset_value(id)
	await frames()
	check(is_equal_approx(root.content_scale_factor, 1.0), "resetting UI scale restores 1.0")
	await test_roundness(save, theme)

func test_roundness(save: Node, theme: Theme):
	var definition: Dictionary = save.registry.get_definition("interface.roundness")
	check(definition.get("category") == "Interface" and definition.get("default") == "subtle"
		and definition.get("options", {}).keys() == ["square", "subtle", "rounded", "round"], "Corner roundness setting registered")
	if definition.is_empty(): return
	var radius = func(type: String, box := "normal") -> int: return theme.get_stylebox(box, type).corner_radius_top_left
	check(radius.call("Button") == 4 and radius.call("PanelContainer", "panel") == 6, "Subtle keeps the specified 4/6 px radii")
	save.store.set_value("interface.roundness", "square")
	await frames()
	check(radius.call("Button") == 0 and radius.call("PanelContainer", "panel") == 0 and radius.call("FriendChip") == 0, "Square removes every corner radius live")
	save.store.set_value("interface.roundness", "round")
	await frames()
	check(radius.call("Button") == 12 and radius.call("PanelContainer", "panel") == 18 and radius.call("FriendChip") == 24,
		"Round triples radii, capped at 24 px so pills stay pills")
	check(save.theme_service.current_tokens().get("roundness_scale") == null, "roundness is not mixed into color tokens")
	save.store.reset_value("interface.roundness")
	await frames()
	check(radius.call("Button") == 4, "resetting roundness restores Subtle")

func test_swatch_settings_ui():
	if not begin(3): return
	var save = autoload("SaveData")
	if save.registry.get_definition("interface.theme_preset").is_empty():
		check(false, "swatch picker needs interface.theme_preset")
		return
	var menu = load("res://scenes/GUI/settings_menue.tscn").instantiate()
	root.add_child(menu)
	await frames()
	var picker = menu.controls.get("interface.theme_preset")
	var path = "res://scripts/GUI/theme/swatch_picker.gd"
	check(picker != null and picker.get_script() != null and picker.get_script().resource_path == path,
		"preset setting renders as a swatch row, not a plain dropdown")
	var accent = menu.controls.get("interface.accent")
	check(accent != null and accent.get_script() != null and accent.get_script().resource_path == path, "accent setting renders as swatches")
	if picker != null and picker.has_method("swatch_buttons"):
		var buttons: Array = picker.swatch_buttons()
		check(buttons.size() == PRESETS.size() and buttons.all(func(b): return b is BaseButton and not b.tooltip_text.is_empty()),
			"one labelled swatch per preset")
		if buttons.size() > 1:
			activate(buttons[1])
			await frames()
			check(save.store.get_value("interface.theme_preset") == "paper", "clicking a swatch commits the enum value")
		save.store.set_value("interface.theme_preset", "graphite")
		await frames()
		check(picker.get("value") == "graphite", "picker reflects external store changes")
	elif picker != null:
		check(false, "swatch picker implements swatch_buttons")
	var shapes = menu.controls.get("interface.roundness")
	check(shapes != null and shapes.has_method("swatch_buttons") and shapes.swatch_buttons().size() == 4, "roundness uses four shape preview swatches")
	save.store.reset_value("interface.theme_preset")
	menu.free()

# --- Part 4 -----------------------------------------------------------------

func test_hard_coded_styling():
	if not begin(4): return
	var color_literal = RegEx.create_from_string("Color\\(|Color\\.html|Color\\.[A-Z_]{3,}")
	for path in DRAWN_SCRIPTS:
		var text = source(path)
		if text.is_empty():
			check(false, "custom-drawn script exists: " + path)
			continue
		check(color_literal.search(text) == null, path.get_file() + " has no hard-coded colors")
		# xr_emote_wheel draws nothing itself; it hosts emote_wheel.gd in a SubViewport.
		if path.ends_with("xr_emote_wheel.gd"):
			check(text.contains("emote_wheel.gd"), "xr_emote_wheel.gd reuses the themed desktop wheel (wiring check)")
			continue
		check(text.contains("get_theme_color") and (text.contains("NOTIFICATION_THEME_CHANGED") or path.ends_with("circular_value_control.gd")),
			path.get_file() + " reads theme colors and redraws on theme change (wiring check)")

# --- Part 5 -----------------------------------------------------------------

func test_font():
	if not begin(5): return
	var fonts: Array = []
	var license := false
	var directory = DirAccess.open("res://themes/fonts")
	if directory != null:
		for file in directory.get_files():
			if file.get_extension().to_lower() in ["ttf", "otf", "woff2"]: fonts.append(file)
			if file.to_upper().begins_with("OFL") or file.to_upper().begins_with("LICENSE"): license = true
	check(not fonts.is_empty(), "a font is bundled under themes/fonts")
	check(license, "font license text is stored next to the font")
	var families: Dictionary = {}
	for file in fonts:
		var font = load("res://themes/fonts/" + file)
		if font is FontFile: families[font.get_font_name()] = true
	check(families.size() == 1, "exactly one font family is bundled")
	var credits = evidence("THIRD_PARTY_ASSETS.md")
	check(not fonts.is_empty() and fonts.all(func(file): return credits.contains(file)), "THIRD_PARTY_ASSETS.md records the font files")
	var theme = project_theme()
	check(theme != null and theme.default_font is FontFile and theme.default_font.resource_path.begins_with("res://themes/fonts/"),
		"the project theme uses the bundled font")

func test_icons():
	if not begin(5): return
	var missing: Array = []
	var bad: Array = []
	for name in REQUIRED_ICONS:
		var path = "res://themes/icons/%s.svg" % name
		if not ResourceLoader.exists(path):
			missing.append(name)
			continue
		var texture = load(path)
		var text = source(path)
		if not texture is Texture2D or texture.get_width() != texture.get_height() or not text.contains("stroke") \
			or text.contains("<image") or text.contains("Gradient") or text.contains("<filter"):
			bad.append(name)
	check(missing.is_empty(), "complete icon set present %s" % [missing])
	check(bad.is_empty(), "icons are square stroke SVGs without raster, gradients or glow filters %s" % [bad])

func test_no_glyph_buttons():
	if not begin(5): return
	var text_assignment = RegEx.create_from_string("(?:^|\\s|\\.)text\\s*=\\s*\"([^\"]*)\"")
	var arrows = "←→↑↓↶↷⟵⟶⇦⇨⬅➡✕✖✓✔⟳⟲★☆♥"
	var offenders: Array = []
	for folder in ["res://scenes/GUI", "res://scripts/GUI"]:
		var directory = DirAccess.open(folder)
		if directory == null: continue
		for file in directory.get_files():
			if not file.get_extension() in ["gd", "tscn"]: continue
			var lines = source(folder + "/" + file).split("\n")
			for index in lines.size():
				for found in text_assignment.search_all(lines[index]):
					var value: String = found.get_string(1).strip_edges()
					if value.is_empty(): continue
					var glyph_only = RegEx.create_from_string("[\\p{L}\\p{N}]").search(value) == null
					var has_symbol = false
					for character in value:
						var code = character.unicode_at(0)
						if arrows.contains(character) or code >= 0x1F300 or (code >= 0x2600 and code <= 0x27BF):
							has_symbol = true
					if (glyph_only and not value.contains("%")) or has_symbol:
						offenders.append("%s:%d %s" % [file, index + 1, value])
	check(offenders.is_empty(), "no Unicode glyph/emoji/arrow button labels; icons are used instead %s" % [offenders.slice(0, 5)])
