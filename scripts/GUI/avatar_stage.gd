extends SubViewportContainer
## Reusable 3D avatar stage: orbit camera, three-point lighting, floor disc and
## a themed background (docs/roadmaps/gui-tablet-specification.md §4.5).
## It only displays a model it is given; loading and safety live in avatar_preview.gd.

const YAW_PER_PIXEL := 0.01
const PITCH_PER_PIXEL := 0.006
const PAN_PER_PIXEL := 0.002
const MIN_PITCH := -20.0
const MAX_PITCH := 45.0
const DEFAULT_PITCH := 8.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const MAX_PAN := 1.0
const RENDER_CAP := 768.0
const HEAD_BONES = ["Head", "head", "J_Bip_C_Head", "mixamorig:Head"]
const LIGHTS = {"Key": Vector3(-35, -30, 0), "Fill": Vector3(-10, 140, 0), "Rim": Vector3(-20, 180, 0)}

@onready var viewport: SubViewport = $Viewport
@onready var pivot: Node3D = $Viewport/Stage/Pivot
@onready var camera: Camera3D = $Viewport/Stage/Camera
@onready var floor_mesh: MeshInstance3D = $Viewport/Stage/Floor
@onready var environment: Environment = $Viewport/Stage/Environment.environment

var model: Node3D
var yaw := 0.0
var target_yaw := 0.0
var pitch := deg_to_rad(DEFAULT_PITCH)
var target_pitch := deg_to_rad(DEFAULT_PITCH)
var zoom := 1.0
var target_zoom := 1.0
var pan_offset := Vector3.ZERO
var smoothing := 0.25
var reduce_motion := false
var animating := false
var framing := "full"
var bounds := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
var _target := Vector3.ZERO
var _distance := 4.0
var _dirty := true

func _ready():
	for name in LIGHTS:
		get_node("Viewport/Stage/" + name).rotation_degrees = LIGHTS[name]
	var material = StandardMaterial3D.new()
	material.roughness = 1.0
	floor_mesh.material_override = material
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resized.connect(_resized)
	visibility_changed.connect(func(): _dirty = true)
	_apply_theme()
	_resized()
	_update_camera()

func _notification(what: int):
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_apply_theme()

func background_color() -> Color:
	return get_theme_color("background", "PreviewStage")

func _apply_theme():
	var background = background_color()
	environment.background_color = background
	environment.ambient_light_color = background.lightened(0.3)
	environment.ambient_light_energy = 0.4
	floor_mesh.material_override.albedo_color = get_theme_color("floor", "PreviewStage")
	_dirty = true

func _resized():
	# stretch_shrink keeps render resolution bounded without altering layout.
	stretch_shrink = maxi(1, ceili(maxf(size.x, size.y) / RENDER_CAP))
	_fit_distance()
	_dirty = true

# --- model ---------------------------------------------------------------------

func set_model(node: Node3D):
	clear()
	model = node
	pivot.add_child(model)
	_normalize()
	frame("full")
	_dirty = true

func clear():
	if is_instance_valid(model):
		if model.get_parent() == pivot:
			pivot.remove_child(model)
		model.queue_free()
	model = null
	animating = false
	if is_node_ready():
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

static func _mesh_bounds(node: Node, parent_transform: Transform3D, result: Array):
	var transform = parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var box: AABB = transform * node.get_aabb()
		if box.position.is_finite() and box.size.is_finite():
			if result.is_empty():
				result.append(box)
			else:
				result[0] = result[0].merge(box)
	for child in node.get_children():
		_mesh_bounds(child, transform, result)

## Scales the longest side to 2 units and centers the model (stage space).
func _normalize():
	var boxes: Array = []
	_mesh_bounds(model, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		bounds = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
		return
	var box: AABB = boxes[0]
	var extent = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if is_finite(extent) and extent > 0.00001:
		var factor = 2.0 / extent
		model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), -box.get_center() * factor) * model.transform
		box = AABB((box.position - box.get_center()) * factor, box.size * factor)
	bounds = pivot.transform * box
	floor_mesh.position = Vector3(0, bounds.position.y - 0.006, 0)

func _head_position() -> Variant:
	if not is_instance_valid(model):
		return null
	for skeleton in model.find_children("*", "Skeleton3D", true, false):
		for name in HEAD_BONES:
			var index = skeleton.find_bone(name)
			if index >= 0:
				return (skeleton.global_transform * skeleton.get_bone_global_pose(index)).origin
	return null

# --- camera ---------------------------------------------------------------------

func _fit_distance():
	if not is_node_ready():
		return
	var aspect = maxf(size.x / maxf(1.0, size.y), 0.1) if size.y > 0 else 1.0
	var fitted = 1.15 / (tan(deg_to_rad(camera.fov * 0.5)) * minf(aspect, 1.0))
	_distance = fitted * {"full": 1.0, "upper": 0.6, "face": 0.3}.get(framing, 1.0)

func frame(preset: String) -> bool:
	if not preset in ["full", "upper", "face"]:
		return false
	framing = preset
	var bottom = bounds.position.y
	var height = bounds.size.y
	match preset:
		"full":
			_target = bounds.get_center()
		"upper":
			_target = Vector3(bounds.get_center().x, bottom + height * 0.75, bounds.get_center().z)
		"face":
			var head = _head_position()
			_target = head if head != null else Vector3(bounds.get_center().x, bottom + height * 0.9, bounds.get_center().z)
	_fit_distance()
	zoom = 1.0
	target_zoom = 1.0
	pan_offset = Vector3.ZERO
	_update_camera()
	return true

## Cycles full → upper → face for the toolbar.
func next_framing() -> String:
	var order = ["full", "upper", "face"]
	frame(order[(order.find(framing) + 1) % order.size()])
	return framing

func camera_target() -> Vector3:
	return _target + pan_offset

func camera_distance() -> float:
	return _distance * zoom

func reset_view():
	yaw = 0.0
	target_yaw = 0.0
	pitch = deg_to_rad(DEFAULT_PITCH)
	target_pitch = pitch
	frame("full")

func _smoothing() -> float:
	return 0.0 if reduce_motion else smoothing

func orbit(relative: Vector2):
	target_yaw -= relative.x * YAW_PER_PIXEL
	target_pitch = clampf(target_pitch + relative.y * PITCH_PER_PIXEL, deg_to_rad(MIN_PITCH), deg_to_rad(MAX_PITCH))
	if _smoothing() <= 0.0:
		yaw = target_yaw
		pitch = target_pitch
	_update_camera()

func pan(relative: Vector2):
	var basis = camera.global_basis if camera.is_inside_tree() else camera.basis
	pan_offset += (-basis.x * relative.x + basis.y * relative.y) * PAN_PER_PIXEL * zoom
	pan_offset = pan_offset.limit_length(MAX_PAN)
	_update_camera()

func zoom_by(factor: float):
	target_zoom = clampf(target_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if _smoothing() <= 0.0:
		zoom = target_zoom
	_update_camera()

func process_camera(delta: float):
	var amount = _smoothing()
	var weight = 1.0 if amount <= 0.0 else 1.0 - pow(amount, delta * 60.0)
	yaw = lerpf(yaw, target_yaw, weight)
	pitch = lerpf(pitch, target_pitch, weight)
	zoom = lerpf(zoom, target_zoom, weight)
	_update_camera()

## Animation layers (avatar_animator.gd) add their AnimationPlayer directly under the model.
func _animation_playing() -> bool:
	if not is_instance_valid(model):
		return false
	for child in model.get_children():
		if child is AnimationPlayer and child.is_playing():
			return true
	return false

func is_rendering_continuously() -> bool:
	return animating or _animation_playing() or absf(yaw - target_yaw) > 0.0005 or absf(pitch - target_pitch) > 0.0005 or absf(zoom - target_zoom) > 0.0005

func _update_camera():
	if not is_node_ready():
		return
	var target = camera_target()
	var offset = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch) * Vector3(0, 0, camera_distance())
	camera.transform = Transform3D(Basis.IDENTITY, target + offset).looking_at(target, Vector3.UP)
	_dirty = true

func _process(delta: float):
	if not is_instance_valid(model) or not is_visible_in_tree():
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if is_rendering_continuously():
		process_camera(delta)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif _dirty:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_dirty = false
