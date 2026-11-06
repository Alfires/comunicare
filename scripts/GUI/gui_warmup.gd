extends Node
## Moves one-time GUI costs out of user interaction (measured with
## tests/real_ui --suite perf): menu page scenes are loaded on worker threads,
## and the avatar preview's render pipelines (lights, shadows, environment and the
## default robot's materials) are compiled by rendering the real stage once
## off-screen. Without this the first preview froze for 1.5 s (Forward+) to
## 2.4 s (Compatibility). Avatar-specific shaders (for example MToon) can still
## compile on their first appearance.

signal finished(report: Dictionary)

const SCENES = [
	"res://scenes/GUI/settings_menue.tscn", "res://scenes/GUI/world_explorer.tscn",
	"res://scenes/GUI/share_session_menue.tscn", "res://scenes/GUI/friends_menue.tscn",
	"res://scenes/GUI/avatar_browser.tscn", "res://scenes/GUI/profile_menue.tscn",
	"res://scenes/GUI/avatar_preview.tscn", "res://scenes/GUI/avatar_stage.tscn",
]
const WARM_MODEL = "res://assets/avatars/placeholder/RobotExpressive.glb"
## Pages without network side effects, created once off-screen so first-use
## initialization (dialogs, first layout of these controls) happens at startup.
const WARM_INSTANCES = ["res://scenes/GUI/tablet_shell.tscn", "res://scenes/GUI/settings_menue.tscn"]
const RENDER_FRAMES := 3
## Heavy steps (pipeline compiles, first layouts) are spread out so their short
## hitches never stack into one long freeze while the world is starting.
const STEP_SPACING_FRAMES := 10
const GLYPH_SIZES = [14, 18, 24]
const GLYPHS = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ÄÖÜäöüß…·–—×°"

static var done := false
var _pending: Array = []
var _loaded: Array = [] # Keeps preloaded resources cached while the game runs.
var _stage: Control
var _frames := 0
var _start_usec := 0
var _pipelines_before := 0
var _steps: Array = []
var _next_step_frame := 0
var _glyph_layer: CanvasLayer
var _glyph_item: RID

static func pipeline_compilations() -> int:
	var total := 0
	for info in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
		total += RenderingServer.get_rendering_info(info)
	return total

## Starts once per process; headless/server runs and COMUNICARE_GUI_WARMUP=0 skip it.
static func start(host: Node) -> Node:
	if done or DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server") or "--relay" in OS.get_cmdline_args() \
		or OS.get_environment("COMUNICARE_GUI_WARMUP") == "0":
		return null
	done = true
	var warmup = load("res://scripts/GUI/gui_warmup.gd").new()
	warmup.name = "GuiWarmup"
	host.get_tree().root.add_child.call_deferred(warmup)
	return warmup

func _ready():
	_start_usec = Time.get_ticks_usec()
	_steps.append(_warm_glyphs)
	for path in SCENES + WARM_INSTANCES + [WARM_MODEL]:
		if not path in _pending and ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path, "", true) == OK:
			_pending.append(path)

func _process(_delta: float):
	for path in _pending.duplicate():
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_pending.erase(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded.append(ResourceLoader.load_threaded_get(path))
			if path == WARM_MODEL:
				_steps.append(_render_stage)
			if path in WARM_INSTANCES:
				_steps.append(_warm_instance.bind(_loaded.back()))
	if not _steps.is_empty() and Engine.get_process_frames() >= _next_step_frame:
		_steps.pop_front().call()
		_next_step_frame = Engine.get_process_frames() + STEP_SPACING_FRAMES
	if is_instance_valid(_stage) and _stage.visible:
		_frames += 1
		if _frames > RENDER_FRAMES:
			# Hidden and idle instead of freed: freeing materials while their
			# pipelines still compile in the background stalled a frame for ~5 s.
			_stage.visible = false
			_stage.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _glyph_item.is_valid() and _frames_since_glyphs() > 1:
		RenderingServer.free_rid(_glyph_item)
		_glyph_item = RID()
		_glyph_layer.queue_free()
	for entry in _warm_nodes.duplicate():
		if Engine.get_process_frames() - entry.frame > 2:
			entry.layer.queue_free()
			_warm_nodes.erase(entry)
	if _pending.is_empty() and _steps.is_empty() and (_stage == null or not _stage.visible) and not _glyph_item.is_valid() and _warm_nodes.is_empty():
		var report = {"seconds": (Time.get_ticks_usec() - _start_usec) / 1000000.0, "scenes": _loaded.size(),
			"pipelines_compiled": pipeline_compilations() - _pipelines_before}
		finished.emit(report)
		set_process(false)

var _glyph_frame := 0

func _frames_since_glyphs() -> int:
	return Engine.get_process_frames() - _glyph_frame

## Rasterizes the interface font's common glyphs at the theme's three sizes (and
## the SemiBold variation) into the glyph atlas by drawing them once on a
## throwaway RenderingServer canvas item outside the visible area.
func _warm_glyphs():
	var theme = ThemeDB.get_project_theme()
	if theme == null or theme.default_font == null:
		return
	var fonts: Array = [theme.default_font]
	if theme.has_font("font", "HeaderLabel"):
		fonts.append(theme.get_font("font", "HeaderLabel"))
	_glyph_layer = CanvasLayer.new()
	_glyph_layer.layer = -100
	add_child(_glyph_layer)
	_glyph_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_glyph_item, _glyph_layer.get_canvas())
	RenderingServer.canvas_item_set_transform(_glyph_item, Transform2D(0, Vector2(-8192, -8192)))
	var y := 0.0
	for font in fonts:
		for size in GLYPH_SIZES:
			y += size * 1.5
			font.draw_string(_glyph_item, Vector2(0, y), GLYPHS, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_glyph_frame = Engine.get_process_frames()

## Renders the production avatar stage once, outside the visible area.
func _render_stage():
	var scene: PackedScene = load("res://scenes/GUI/avatar_stage.tscn")
	var model_scene = _loaded.filter(func(item): return item is PackedScene and item.resource_path == WARM_MODEL)
	if scene == null or model_scene.is_empty():
		return
	_pipelines_before = pipeline_compilations()
	var layer = CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	_stage = scene.instantiate()
	_stage.position = Vector2(-4096, -4096)
	_stage.size = Vector2(128, 128)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_stage)
	_stage.set_model(model_scene[0].instantiate())

var _warm_nodes: Array = []

## Instantiates a page off-screen for two frames, then frees it.
func _warm_instance(scene: Resource):
	if not scene is PackedScene:
		return
	var layer = CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	var node = scene.instantiate()
	if node is Control:
		node.position = Vector2(-8192, -8192)
		node.size = Vector2(1000, 750)
	layer.add_child(node)
	_warm_nodes.append({"layer": layer, "frame": Engine.get_process_frames()})
