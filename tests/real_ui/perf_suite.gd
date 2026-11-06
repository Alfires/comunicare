extends SceneTree
## GUI frame-time benchmark with production autoloads (disposable account from
## run.py). Prints "PERF: <name> total=<ms> worst_frame=<ms>" lines. total is the
## wall time until the action finished (async actions span frames); worst_frame
## is the longest single frame during the action and the frames after it, which
## is what users see as a freeze. Informational unless COMUNICARE_PERF_BUDGET_MS
## is set, then actions whose worst frame exceeds the budget fail.
## Use --rendered --renderer forward_plus for real draw costs.

const FOLLOW_FRAMES := 6
var results: Array = []
var budget := 0.0
var failed := 0

func _initialize():
	call_deferred("run")

## Longest frame seen since the last reset; frames during awaited (async)
## actions count too, so background imports that stall a frame are caught.
var _watch := {"last": 0, "worst": 0.0}

func _watch_frame():
	var now = Time.get_ticks_usec()
	if _watch.last > 0:
		_watch.worst = maxf(_watch.worst, (now - _watch.last) / 1000.0)
	_watch.last = now

func measure(name: String, action: Callable):
	if not process_frame.is_connected(_watch_frame):
		process_frame.connect(_watch_frame)
	await process_frame
	_watch.worst = 0.0
	_watch.last = Time.get_ticks_usec()
	var start = Time.get_ticks_usec()
	await action.call()
	var cpu = (Time.get_ticks_usec() - start) / 1000.0
	for i in FOLLOW_FRAMES:
		await process_frame
	var worst: float = _watch.worst
	results.append({"name": name, "cpu": cpu, "frame": worst})
	var over = budget > 0 and worst > budget
	if over: failed += 1
	print("PERF: %-44s total=%7.2f ms  worst_frame=%7.2f ms%s" % [name, cpu, worst, "  OVER BUDGET" if over else ""])

func humanoid() -> Node3D:
	var model = load("res://assets/avatars/placeholder/RobotExpressive.glb").instantiate()
	return model

func run():
	budget = float(OS.get_environment("COMUNICARE_PERF_BUDGET_MS")) if not OS.get_environment("COMUNICARE_PERF_BUDGET_MS").is_empty() else 0.0
	var save = root.get_node("SaveData")
	save.load_acount()
	save.store.set_value("network.lan_discovery", false)
	root.get_node("DataLoader").get_asset_cache().enabled = false
	root.size = Vector2i(1600, 1000)
	print("Renderer: %s, display: %s" % [RenderingServer.get_video_adapter_name(), DisplayServer.get_name()])
	# SaveData starts the GUI warm-up (preloads + preview pipelines) like at game start.
	# COMUNICARE_GUI_WARMUP=0 measures the cold path without it.
	await process_frame
	var warmup = root.get_node_or_null("GuiWarmup")
	print("Warm-up: %s" % ("running" if warmup != null else "disabled"))
	if warmup != null and warmup.is_processing():
		# Runs in the background at startup; its frames are measured like any action.
		var holder := {}
		await measure("startup: GUI warm-up (background)", func(): holder.report = await warmup.finished)
		var report: Dictionary = holder.report
		print("Warm-up: %.2f s, %d resources, %d pipelines compiled" % [report.seconds, report.scenes, report.pipelines_compiled])
		await measure("startup: 2 s after warm-up", func():
			for i in 120: await process_frame)
	print("Pipeline compilations before measuring: %d" % load("res://scripts/GUI/gui_warmup.gd").pipeline_compilations())
	# Lambdas capture locals by value; share nodes through this Dictionary.
	var ui := {}
	await measure("theme: builder only (fresh Theme)", func():
		load("res://scripts/GUI/theme/theme_builder.gd").new().build(Theme.new(), save.theme_service.current_tokens()))
	await measure("theme: service apply, no UI open", func(): save.theme_service.apply())
	await measure("settings: build page", func():
		ui.settings = load("res://scenes/GUI/settings_menue.tscn").instantiate()
		root.add_child(ui.settings)
		ui.settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT))
	var settings: Control = ui.settings
	for category in ["Interface", "Controls", "VR Movement", "Credits", "Assets"]:
		await measure("settings: select " + category, func(): settings.select_category(category))
	await measure("settings: search 'vol'", func():
		settings.search.text = "vol"
		settings.search.text_changed.emit("vol"))
	await measure("settings: clear search", func():
		settings.search.text = ""
		settings.search.text_changed.emit(""))
	for preset in ["paper", "night", "graphite"]:
		await measure("theme: switch to " + preset, func(): save.store.set_value("interface.theme_preset", preset))
	await measure("theme: switch accent", func(): save.store.set_value("interface.accent", "amber"))
	save.store.reset_value("interface.accent")
	await measure("settings: rebuild on registry change", func():
		save.registry.register_setting({"id": "perf.flag", "category": "Interface", "label": "Perf flag", "type": "boolean", "default": false}))
	save.registry.unregister_setting("perf.flag")
	settings.free()
	await measure("menu: build shell + Quick", func():
		ui.menu = load("res://scenes/GUI/menue.tscn").instantiate()
		root.add_child(ui.menu))
	var menu: Control = ui.menu
	for page in ["friends", "worlds", "instance", "settings", "quick", "settings"]:
		await measure("menu: open " + page, func(): menu.open_page(page))
	await measure("menu: reset (close/reopen)", func(): menu.reset())
	await measure("theme: switch with open menu", func(): save.store.set_value("interface.theme_preset", "forest"))
	save.store.reset_value("interface.theme_preset")
	menu.free()
	await measure("preview: create", func():
		ui.preview = load("res://scenes/GUI/avatar_preview.tscn").instantiate()
		ui.preview.custom_minimum_size = Vector2(400, 500)
		root.add_child(ui.preview))
	var preview: Control = ui.preview
	await measure("preview: load bundled robot", func():
		preview.loader = func(_url): return humanoid()
		preview.set_source("perf-robot")
		await preview.load_preview())
	var avatar_path = OS.get_environment("COMUNICARE_PERF_AVATAR")
	if not avatar_path.is_empty() and FileAccess.file_exists(avatar_path):
		var bytes = FileAccess.get_file_as_bytes(avatar_path)
		await measure("preview: load VRM (production importer)", func():
			preview.loader = func(_url): return await root.get_node("DataLoader")._load_model_from_buffer(bytes)
			preview.set_source("perf-vrm")
			await preview.load_preview())
		await measure("preview: same VRM again", func():
			preview.set_source("perf-vrm-2")
			await preview.load_preview())
	await measure("preview: orbit drag", func(): preview.stage.orbit(Vector2(40, 10)))
	await measure("preview: idle frames", func(): pass)
	print("Pipeline compilations after preview: %d" % load("res://scripts/GUI/gui_warmup.gd").pipeline_compilations())
	preview.free()
	var wheel = load("res://scripts/GUI/emote_wheel.gd").new()
	await measure("emote wheel: open", func(): root.add_child(wheel))
	await measure("emote wheel: hover redraws", func():
		for i in 8:
			wheel.hovered = i
			wheel.queue_redraw())
	wheel.free()
	var worst = results.duplicate()
	worst.sort_custom(func(a, b): return a.frame > b.frame)
	print("\nLongest frames:")
	for item in worst.slice(0, 6):
		print("  %-44s %7.2f ms" % [item.name, item.frame])
	print("GUI perf: %d actions, %d over budget" % [results.size(), failed])
	quit(1 if failed else 0)
