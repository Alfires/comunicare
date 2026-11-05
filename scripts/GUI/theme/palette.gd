extends RefCounted
## Color tokens for every preset and accent. Values are fixed by
## docs/roadmaps/gui-tablet-specification.md §2 and checked for contrast by
## tests/gui_tablet. This is the only place where UI colors are defined.

const PRESETS = {
	"graphite": {"kind": "dark", "background": "#1c1d1f", "surface": "#242528", "surface_raised": "#2e3034", "border": "#4a4d52", "text": "#ebe9e4", "text_muted": "#a9a7a1", "preview_stage": "#2b2c2f"},
	"paper": {"kind": "light", "background": "#f3f1ec", "surface": "#fbfaf7", "surface_raised": "#ffffff", "border": "#cfccc4", "text": "#1f2023", "text_muted": "#5a5c61", "preview_stage": "#e6e3dc"},
	"forest": {"kind": "dark", "background": "#1a201d", "surface": "#212824", "surface_raised": "#2a322d", "border": "#45504a", "text": "#e6ebe7", "text_muted": "#a3ada6", "preview_stage": "#28302b"},
	"sand": {"kind": "light", "background": "#efe8dc", "surface": "#f7f2e9", "surface_raised": "#fdfaf4", "border": "#d3c8b5", "text": "#2b261f", "text_muted": "#5e564a", "preview_stage": "#e4dccd"},
	"night": {"kind": "dark", "background": "#0b0b0c", "surface": "#131315", "surface_raised": "#1b1b1e", "border": "#34343a", "text": "#d9d8d4", "text_muted": "#9a9893", "preview_stage": "#18181b"},
	"high_contrast": {"kind": "hc", "background": "#000000", "surface": "#000000", "surface_raised": "#141414", "border": "#ffffff", "text": "#ffffff", "text_muted": "#e6e6e6", "preview_stage": "#1a1a1a"},
}
## Accent variants: on dark, on light, on high contrast.
const ACCENTS = {
	"teal": ["#4fb3a9", "#1d6b64", "#6fd6cb"],
	"blue": ["#6ea1e0", "#2b5ea8", "#8fb8ee"],
	"amber": ["#e0a43a", "#85591c", "#f0bd5e"],
	"green": ["#7bbf6a", "#3a6b2c", "#98d488"],
	"rose": ["#e07a8f", "#a3364d", "#eda0b0"],
	"violet": ["#a58be0", "#6747a6", "#c0aeee"],
	"neutral": ["#d6d3cc", "#3a3c40", "#e6e6e6"],
}
const ACCENT_ORDER = ["teal", "blue", "amber", "green", "rose", "violet", "match_highlight"]
## interface.hover_color → accent for "Match 3D highlight".
const HIGHLIGHT_ACCENTS = {"cyan": "teal", "yellow": "amber", "green": "green", "magenta": "rose", "white": "neutral"}
const SEMANTIC = {
	"dark": {"success": "#6fbf73", "warning": "#e0b040", "danger": "#e5675c"},
	"light": {"success": "#2e7d32", "warning": "#8a6100", "danger": "#b3261e"},
	"hc": {"success": "#5ee08a", "warning": "#ffd23f", "danger": "#ff6b5e"},
}
const DIM = {"dark": ["#000000", 0.55], "light": ["#1a1a1a", 0.45], "hc": ["#000000", 0.75]}

func presets() -> Array:
	return PRESETS.keys()

func accents() -> Array:
	return ACCENT_ORDER.duplicate()

func is_light(preset: String) -> bool:
	return PRESETS.get(preset, PRESETS.graphite).kind == "light"

func tokens(preset: String, accent: String, highlight: String = "cyan") -> Dictionary:
	if not PRESETS.has(preset):
		preset = "graphite"
	if accent == "match_highlight":
		accent = HIGHLIGHT_ACCENTS.get(highlight, "teal")
	elif not ACCENTS.has(accent) or accent == "neutral":
		accent = "teal"
	var spec: Dictionary = PRESETS[preset]
	var kind: String = spec.kind
	var variant: int = {"dark": 0, "light": 1, "hc": 2}[kind]
	var result := {"kind": kind}
	for key in ["background", "surface", "surface_raised", "border", "text", "text_muted", "preview_stage"]:
		result[key] = Color(spec[key])
	result.accent = Color(ACCENTS[accent][variant])
	result.accent_text = Color("#ffffff") if kind == "light" else Color("#121314")
	result.focus = Color("#ffff00") if kind == "hc" else result.accent
	for key in SEMANTIC[kind]:
		result[key] = Color(SEMANTIC[kind][key])
	var dim: Array = DIM[kind]
	result.overlay_dim = Color(dim[0], 0.65 if preset == "night" else dim[1])
	return result
