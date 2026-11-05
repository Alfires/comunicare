extends "res://common.gd"
## Part 10: avatar stage + preview rewrite. Synthetic models only; no VRM import,
## network or renderer quality claims.

const STAGE = "res://scenes/GUI/avatar_stage.tscn"
const STAGE_METHODS = ["set_model", "clear", "orbit", "pan", "zoom_by", "reset_view", "frame",
	"camera_target", "camera_distance", "process_camera", "is_rendering_continuously"]
const PREVIEW = "res://scenes/GUI/avatar_preview.tscn"

class Gate:
	signal release

func suite_name() -> String:
	return "avatar preview (part 10)"

func run():
	if not begin(10): return
	await test_stage()
	await test_preview_states()
	await test_preview_safety()
	await test_preview_interaction()
	test_copy()

func humanoid(tag := "") -> Node3D:
	var model = Node3D.new()
	model.set_meta("id", tag)
	var skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("Hips")
	skeleton.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)))
	skeleton.add_bone("Head")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)))
	skeleton.reset_bone_poses()
	model.add_child(skeleton)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.5, 1.8, 0.3)
	mesh.mesh = box
	mesh.position.y = 0.9
	skeleton.add_child(mesh)
	return model

func box_model() -> Node3D:
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.6, 1.7, 0.3)
	mesh.mesh = box
	var model = Node3D.new()
	model.add_child(mesh)
	return model

func test_stage():
	var stage = scene_component(STAGE, STAGE_METHODS)
	if stage == null: return
	check(not stage.has_method("load_preview") and not source(stage.get_script().resource_path).contains("DataLoader"),
		"stage has no loading logic")
	root.add_child(stage)
	stage.set("smoothing", 0.0)
	await frames()
	var lights = descendants(stage).filter(func(node): return node is Light3D)
	check(lights.size() >= 3, "three-point lighting")
	var floor = named(stage, "Floor")
	check(floor is MeshInstance3D, "floor disc for grounding")
	var environment = descendants(stage).filter(func(node): return node is WorldEnvironment)
	check(environment.size() == 1 and environment[0].environment != null and environment[0].environment.ambient_light_energy > 0,
		"neutral environment with ambient light")
	var viewport = descendants(stage).filter(func(node): return node is SubViewport)
	check(viewport.size() == 1 and not viewport[0].transparent_bg and viewport[0].own_world_3d, "opaque, isolated preview world")
	if stage.has_method("background_color") and project_theme() != null:
		check(colors_equal(stage.background_color(), project_theme().get_color("background", "PreviewStage")), "background uses the theme PreviewStage color")
	else:
		check(false, "stage exposes background_color from the theme")
	var model = humanoid()
	stage.set_model(model)
	stage.reset_view()
	check(is_equal_approx(float(stage.get("zoom")), 1.0) and stage.get("pan_offset") == Vector3.ZERO
		and float(stage.get("pitch")) >= 0.0 and float(stage.get("pitch")) <= deg_to_rad(15), "reset: front view, zoom 1, no pan")
	var yaw = float(stage.get("yaw"))
	stage.orbit(Vector2(120, 0))
	check(not is_equal_approx(float(stage.get("yaw")), yaw), "horizontal drag orbits yaw")
	stage.orbit(Vector2(0, 100000))
	check(is_equal_approx(float(stage.get("pitch")), deg_to_rad(45)) or is_equal_approx(float(stage.get("pitch")), deg_to_rad(-20)),
		"vertical drag pitch hits a clamp")
	stage.orbit(Vector2(0, -200000))
	var low = float(stage.get("pitch"))
	stage.orbit(Vector2(0, 200000))
	var high = float(stage.get("pitch"))
	check(is_equal_approx(minf(low, high), deg_to_rad(-20)) and is_equal_approx(maxf(low, high), deg_to_rad(45)), "pitch clamps to −20°…+45°")
	stage.zoom_by(0.001)
	check(is_equal_approx(float(stage.get("zoom")), 0.5), "zoom clamps at 0.5")
	stage.zoom_by(1000)
	check(is_equal_approx(float(stage.get("zoom")), 3.0), "zoom clamps at 3")
	stage.pan(Vector2(60, 0))
	check(stage.get("pan_offset") is Vector3 and stage.get("pan_offset").length() > 0, "pan moves the target")
	stage.pan(Vector2(1e6, 1e6))
	check(stage.get("pan_offset").length() <= 1.0, "pan stays bounded near the model")
	stage.reset_view()
	check(stage.frame("full") and stage.frame("upper") and stage.frame("face"), "framing presets full/upper/face")
	check(not stage.frame("bogus"), "unknown framing preset is rejected")
	var targets: Dictionary = {}
	var distances: Dictionary = {}
	for preset in ["full", "upper", "face"]:
		stage.frame(preset)
		targets[preset] = stage.camera_target()
		distances[preset] = stage.camera_distance()
	check(targets.face.y > targets.upper.y and targets.upper.y > targets.full.y, "presets move the target up toward the face")
	check(distances.face < distances.upper and distances.upper < distances.full, "presets move the camera closer")
	var skeleton: Skeleton3D = model.get_node("Skeleton3D")
	var head = (skeleton.global_transform * skeleton.get_bone_global_pose(1)).origin
	check(absf(targets.face.y - head.y) < 0.15, "face framing uses the humanoid Head bone")
	stage.set_model(box_model())
	stage.frame("full")
	var full = stage.camera_target()
	stage.frame("face")
	check(stage.camera_target().y > full.y, "face framing falls back to bounds without a skeleton")
	stage.reset_view()
	stage.orbit(Vector2(100, 0))
	await frames(4)
	check(not stage.is_rendering_continuously() and viewport.size() == 1 and viewport[0].render_target_update_mode != SubViewport.UPDATE_ALWAYS,
		"idle stage stops continuous rendering")
	stage.set("smoothing", 0.25)
	stage.orbit(Vector2(200, 0))
	check(stage.is_rendering_continuously() and not is_equal_approx(float(stage.get("yaw")), float(stage.get("target_yaw"))),
		"smoothed orbit renders while the camera eases")
	for i in 120:
		stage.process_camera(1.0 / 60.0)
	check(absf(float(stage.get("yaw")) - float(stage.get("target_yaw"))) < 0.001, "damped camera converges")
	stage.set("reduce_motion", true)
	stage.orbit(Vector2(200, 0))
	check(is_equal_approx(float(stage.get("yaw")), float(stage.get("target_yaw"))), "reduce motion snaps without easing")
	stage.clear()
	await frames()
	check(descendants(stage).all(func(node): return not node is MeshInstance3D or node == floor), "clear removes the model")
	stage.free()

func new_preview(size := Vector2(600, 800)) -> Control:
	if not ResourceLoader.exists(PREVIEW):
		check(false, "avatar preview scene exists")
		return null
	var preview = load(PREVIEW).instantiate()
	preview.size = size
	root.add_child(preview)
	await frames()
	return preview

func test_preview_states():
	var preview = await new_preview()
	if preview == null: return
	for method in ["set_source", "clear_preview", "load_preview", "load_file"]:
		check(preview.has_method(method), "existing preview API kept: " + method)
	check(preview.has_signal("failed") and "model" in preview and "loader" in preview and "source" in preview, "existing fields/signals kept")
	check("state" in preview, "preview exposes state")
	check(preview.get("stage") != null and preview.get("stage").get_script() != null
		and preview.get("stage").get_script().resource_path == "res://scripts/GUI/avatar_stage.gd", "preview uses the reusable stage")
	var status = named(preview, "StatusLabel")
	preview.set_source("")
	await frames()
	check(preview.get("state") == "empty" and status is Label and status.visible and status.text.contains("No avatar"), "empty state")
	var gate = Gate.new()
	preview.loader = func(_source):
		await gate.release
		return humanoid("A")
	preview.set_source("https://example.test/a.vrm")
	preview.load_preview()
	await frames()
	var loading = named(preview, "Loading")
	check(preview.get("state") == "loading" and loading is Control and loading.visible, "loading state shows an indicator")
	gate.release.emit()
	await frames(3)
	check(preview.get("state") == "ready" and is_instance_valid(preview.model) and preview.model.get_meta("id", "") == "A", "ready state")
	var failures: Array = []
	preview.failed.connect(func(message): failures.append(message))
	preview.loader = func(_source): return null
	preview.set_source("https://example.test/broken.vrm")
	await preview.load_preview()
	await frames()
	var retry = named(preview, "RetryButton")
	check(preview.get("state") == "error" and retry is BaseButton and retry.visible and failures.size() == 1, "error state with Retry")
	preview.loader = func(_source): return humanoid("retry")
	if retry is BaseButton:
		activate(retry)
		await frames(3)
	check(preview.get("state") == "ready" and is_instance_valid(preview.model) and preview.model.get_meta("id", "") == "retry", "Retry loads again")
	var slow = Gate.new()
	var stale = [null]
	preview.loader = func(_source):
		await slow.release
		var node = humanoid("stale")
		stale[0] = node
		return node
	preview.set_source("https://example.test/old.vrm")
	preview.load_preview()
	preview.loader = func(_source): return humanoid("new")
	preview.set_source("https://example.test/new.vrm")
	await preview.load_preview()
	slow.release.emit()
	await frames(3)
	check(is_instance_valid(preview.model) and preview.model.get_meta("id", "") == "new" and not is_instance_valid(stale[0]),
		"a newer source wins and stale results are freed")
	preview.hide()
	await frames()
	check(not is_instance_valid(preview.model), "hiding the preview releases the model")
	preview.free()

func test_preview_safety():
	var preview = await new_preview()
	if preview == null: return
	var unsafe = humanoid("unsafe")
	var scripted = Node.new()
	var script = GDScript.new()
	script.source_code = "extends Node\n"
	script.reload()
	scripted.set_script(script)
	unsafe.add_child(scripted)
	preview.loader = func(_source): return unsafe
	preview.set_source("https://example.test/unsafe.vrm")
	await preview.load_preview()
	await frames()
	check(not is_instance_valid(preview.model) and (not "state" in preview or preview.get("state") == "error"), "script-bearing models are refused")
	var physics = humanoid("physics")
	physics.add_child(StaticBody3D.new())
	preview.loader = func(_source): return physics
	preview.set_source("https://example.test/physics.vrm")
	await preview.load_preview()
	check(not is_instance_valid(preview.model), "collision/physics nodes are refused")
	var messages: Array = []
	preview.failed.connect(func(message): messages.append(message))
	var accepted = await preview.load_file("res://avatar.glb")
	check(not accepted and messages.size() == 1, "non-VRM local files are refused")
	var empty = FileAccess.open("user://empty.vrm", FileAccess.WRITE)
	empty.close()
	accepted = await preview.load_file(ProjectSettings.globalize_path("user://empty.vrm"))
	check(not accepted, "empty local files are refused")
	preview.free()

func test_preview_interaction():
	var preview = await new_preview()
	if preview == null: return
	var toolbar = named(preview, "Toolbar")
	check(toolbar is Control, "preview has an overlay toolbar")
	var buttons: Array = []
	for name in ["OpenFile", "Framing", "ResetView", "Idle"]:
		var button = named(preview, name)
		if button is BaseButton: buttons.append(button)
	var icon_buttons = buttons.all(func(b): return b.theme_type_variation == "IconButton" and b.icon != null and b.text.is_empty() and not b.tooltip_text.is_empty())
	check(buttons.size() == 4 and icon_buttons, "toolbar: open file, framing, reset, idle icon buttons")
	if toolbar is Control:
		check(not toolbar.visible or toolbar.modulate.a < 0.05, "desktop toolbar is hidden until hover")
		preview.mouse_entered.emit()
		await frames()
		check(toolbar.visible and toolbar.modulate.a > 0.9, "hover reveals the toolbar")
		preview.mouse_exited.emit()
	preview.loader = func(_source): return humanoid("interactive")
	preview.set_source("https://example.test/interactive.vrm")
	await preview.load_preview()
	var stage = preview.get("stage")
	var container = named(preview, "StageContainer")
	if stage != null and container is Control:
		stage.set("smoothing", 0.0)
		var yaw = float(stage.get("yaw"))
		var drag = InputEventMouseMotion.new()
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		drag.relative = Vector2(80, 0)
		container.gui_input.emit(drag)
		check(not is_equal_approx(float(stage.get("yaw")), yaw), "left drag orbits")
		var pan = InputEventMouseMotion.new()
		pan.button_mask = MOUSE_BUTTON_MASK_RIGHT
		pan.relative = Vector2(40, 0)
		container.gui_input.emit(pan)
		check(stage.get("pan_offset").length() > 0, "right drag pans")
		var wheel = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		container.gui_input.emit(wheel)
		check(float(stage.get("zoom")) < 1.0, "wheel zooms")
		var twice = InputEventMouseButton.new()
		twice.button_index = MOUSE_BUTTON_LEFT
		twice.pressed = true
		twice.double_click = true
		container.gui_input.emit(twice)
		check(is_equal_approx(float(stage.get("zoom")), 1.0) and stage.get("pan_offset") == Vector3.ZERO, "double-click resets the view")
	else:
		check(false, "preview exposes stage and StageContainer for input")
	if preview.has_method("set_idle_animation"):
		check(preview.set_idle_animation(true) is bool, "idle animation toggle reports support without errors")
	else:
		check(false, "preview implements set_idle_animation")
	var save = autoload("SaveData")
	if stage != null and not save.registry.get_definition("interface.reduce_motion").is_empty():
		save.store.set_value("interface.reduce_motion", true)
		await frames()
		check(stage.get("reduce_motion") == true, "preview passes reduce motion to the stage")
		save.store.reset_value("interface.reduce_motion")
	preview.free()
	var viewport = SubViewport.new()
	viewport.set_meta("vr_menu", true)
	viewport.size = Vector2i(800, 800)
	root.add_child(viewport)
	var vr_preview = load(PREVIEW).instantiate()
	viewport.add_child(vr_preview)
	await frames()
	var vr_toolbar = named(vr_preview, "Toolbar")
	check(vr_toolbar is Control and vr_toolbar.visible and vr_toolbar.modulate.a > 0.9, "toolbar is always visible on the VR tablet")
	viewport.free()

func test_copy():
	var texts = source("res://scripts/GUI/avatar_preview.gd") + source("res://scenes/GUI/avatar_preview.tscn")
	check(not texts.contains("independent") and not texts.contains("(external request)"), "preview copy is plain and specific")
