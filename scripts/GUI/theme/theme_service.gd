extends RefCounted
## Owned by SaveData. Applies the selected color scheme to the shared project
## Theme (themes/default.tres, registered as gui/theme/custom) and keeps it in
## sync with Interface settings. Rebuilding the same Theme instance updates
## every open control, including the VR tablet's SubViewport.

signal applied(tokens: Dictionary)

const THEME_PATH = "res://themes/default.tres"
const WATCHED = ["interface.theme_preset", "interface.accent", "interface.hover_color", "interface.ui_scale", "interface.reduce_motion", "interface.roundness"]

var palette = preload("res://scripts/GUI/theme/palette.gd").new()
var builder = preload("res://scripts/GUI/theme/theme_builder.gd").new()
var store
var theme: Theme
var tokens: Dictionary = {}
var reduce_motion := false
var ui_scale := 1.0

func configure(settings, target: Theme = null):
	store = settings
	theme = target
	if store != null and not store.setting_changed.is_connected(_setting_changed):
		store.setting_changed.connect(_setting_changed)

func resolve_theme() -> Theme:
	if theme == null:
		theme = ThemeDB.get_project_theme()
	if theme == null and ResourceLoader.exists(THEME_PATH):
		theme = load(THEME_PATH)
	return theme

func _value(id: String, fallback: Variant) -> Variant:
	if store == null or store.registry == null or store.registry.get_definition(id).is_empty():
		return fallback
	return store.get_value(id)

func apply():
	tokens = palette.tokens(str(_value("interface.theme_preset", "graphite")), str(_value("interface.accent", "teal")),
		str(_value("interface.hover_color", "cyan")))
	builder.roundness = builder.ROUNDNESS.get(str(_value("interface.roundness", "subtle")), 1.0)
	reduce_motion = bool(_value("interface.reduce_motion", false))
	ui_scale = float(_value("interface.ui_scale", 1.0))
	var target = resolve_theme()
	if target != null:
		builder.build(target, tokens)
	var tree = Engine.get_main_loop()
	if tree is SceneTree and tree.root != null and not ("--relay" in OS.get_cmdline_args()):
		tree.root.content_scale_factor = ui_scale
	applied.emit(tokens)

func current_tokens() -> Dictionary:
	return tokens

func _setting_changed(id: String, _value_unused: Variant):
	if id in WATCHED:
		apply()
