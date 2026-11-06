extends Node3D
## Floating, movable VR tablet hosting the shared menu
## (docs/roadmaps/gui-tablet-specification.md §4.3). The screen faces local +Z.
## The node itself is never scaled; scale_factor resizes the meshes so the
## node transform stays orthonormal for raycasts and placement.

signal haptic(hand: String, amplitude: float, duration: float)

const PHYSICAL := Vector2(1600, 1200)
const LOGICAL := Vector2(1000, 750)
const STATUS_BAR_HEIGHT := 56.0
const FRAME_BAND := 0.04
const ZONE_DEPTH := 0.05
const FORWARD := 0.55
const BELOW_EYES := 0.20
const SIDE_OFFSET := 0.12
const FOLLOW_ANGLE := 45.0
const FOLLOW_DISTANCE := 1.5
const TOUCH_HOVER := 0.03
const TOUCH_PRESS := 0.008
const TOUCH_BEHIND := 0.02

@onready var viewport: SubViewport = $Viewport
@onready var menu: Control = $Viewport/Menu
@onready var keyboard_anchor: Node3D = %KeyboardAnchor

var screen_size_m := Vector2(0.55, 0.4125)
var scale_factor := 1.0:
	set(value):
		scale_factor = clampf(value, 0.6, 1.6)
		_apply_scale()
var pin_mode := "pinned"
var hand_side := "either"
var smoothing := 0.35
var reduce_motion := false
var direct_touch_enabled := false
var store

var _grabs: Dictionary = {} # hand → {"offset": Transform3D, "last": Transform3D}
var _two_hand: Dictionary = {}
var _relative: Variant = null
var _following := false
var _anchor_rest: Vector3

func _ready():
	_anchor_rest = keyboard_anchor.position
	var screen_material = StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	screen_material.albedo_texture = viewport.get_texture()
	$Screen.material_override = screen_material
	var frame_material = StandardMaterial3D.new()
	frame_material.roughness = 0.8
	$Frame.material_override = frame_material
	var theme = ThemeDB.get_project_theme()
	if theme != null:
		theme.changed.connect(_theme_changed)
	_theme_changed()
	_apply_scale()

func _theme_changed():
	var theme = ThemeDB.get_project_theme()
	if theme != null and theme.has_color("frame", "TabletFrame") and $Frame.material_override != null:
		$Frame.material_override.albedo_color = theme.get_color("frame", "TabletFrame")

func _apply_scale():
	if not is_node_ready():
		return
	var mesh_scale = Vector3(scale_factor, scale_factor, 1.0)
	$Screen.scale = mesh_scale
	$Frame.scale = mesh_scale
	keyboard_anchor.position = Vector3(_anchor_rest.x * scale_factor, _anchor_rest.y * scale_factor, _anchor_rest.z)

func size_m() -> Vector2:
	return screen_size_m * scale_factor

# --- settings ------------------------------------------------------------------

func configure(settings):
	store = settings
	if store == null:
		return
	if not store.setting_changed.is_connected(_setting_changed):
		store.setting_changed.connect(_setting_changed)
	for id in ["vr.menu_pin_mode", "vr.menu_scale", "vr.menu_direct_touch", "vr.menu_hand", "interface.reduce_motion", "interface.ui_scale"]:
		if not store.registry.get_definition(id).is_empty():
			_setting_changed(id, store.get_value(id))

func _setting_changed(id: String, value: Variant):
	match id:
		"vr.menu_pin_mode": pin_mode = str(value)
		"vr.menu_scale": scale_factor = float(value)
		"vr.menu_direct_touch": direct_touch_enabled = bool(value)
		"vr.menu_hand": hand_side = str(value)
		"interface.reduce_motion": reduce_motion = bool(value)
		"interface.ui_scale":
			var factor = maxf(0.5, float(value))
			viewport.size_2d_override = Vector2i(LOGICAL / factor)

func effective_smoothing() -> float:
	return 0.0 if reduce_motion else smoothing

# --- placement -----------------------------------------------------------------

static func _flat_forward(basis: Basis) -> Vector3:
	var forward = -basis.z
	forward.y = 0
	if forward.length_squared() < 0.0001:
		forward = basis.y
		forward.y = 0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD

static func _yaw_only(value: Transform3D) -> Transform3D:
	var forward = _flat_forward(value.basis)
	return Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), value.origin)

static func _facing(position: Vector3, target: Vector3) -> Basis:
	var z = (target - position).normalized()
	var x = Vector3.UP.cross(z)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)

func _summon_transform(head: Transform3D) -> Transform3D:
	var forward = _flat_forward(head.basis)
	var right = forward.cross(Vector3.UP).normalized()
	var side = {"left": -1.0, "right": 1.0}.get(hand_side, 0.0)
	var position = head.origin + forward * FORWARD + Vector3.DOWN * BELOW_EYES + right * side * SIDE_OFFSET
	return Transform3D(_facing(position, head.origin), position)

func place_initial(head: Transform3D):
	_following = false
	global_transform = _summon_transform(head)

func summon(head: Transform3D):
	place_initial(head)

## Stores the placement relative to the player's yaw and position (session only).
func remember_placement(player: Transform3D):
	_relative = _yaw_only(player).affine_inverse() * global_transform

func restore_placement(player: Transform3D) -> bool:
	if _relative == null:
		return false
	global_transform = _yaw_only(player) * _relative
	return true

func update_follow(head: Transform3D, _delta: float):
	if pin_mode != "follow" or not _grabs.is_empty():
		_following = false
		return
	var offset = global_position - head.origin
	var flat = Vector3(offset.x, 0, offset.z)
	var angle = rad_to_deg(_flat_forward(head.basis).angle_to(flat.normalized())) if flat.length_squared() > 0.0001 else 0.0
	if angle > FOLLOW_ANGLE or flat.length() > FOLLOW_DISTANCE:
		_following = true
	if not _following:
		return
	var target = _summon_transform(head)
	_move_toward(target)
	if global_position.distance_to(target.origin) < 0.01:
		_following = false

func _move_toward(target: Transform3D):
	var amount = effective_smoothing()
	if amount <= 0.0:
		global_transform = target
	else:
		global_transform = global_transform.interpolate_with(target, 1.0 - amount).orthonormalized()

# --- pointer and touch ---------------------------------------------------------

func _local_to_pixel(local: Vector3) -> Vector2:
	var size = size_m()
	var uv = Vector2(local.x / size.x + 0.5, 0.5 - local.y / size.y)
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1:
		return Vector2(-1, -1)
	return uv * PHYSICAL

## Physical viewport pixel hit by a ray, or (-1, -1). Only front-face hits count.
func raycast_to_pixel(origin: Vector3, direction: Vector3) -> Vector2:
	if not origin.is_finite() or not direction.is_finite() or direction.dot(global_basis.z) >= -0.00001:
		return Vector2(-1, -1)
	var hit = Plane(global_basis.z, global_position).intersects_ray(origin, direction)
	if hit == null:
		return Vector2(-1, -1)
	return _local_to_pixel(to_local(hit))

## VRViewport2D-compatible name used by the player's pointer code.
func raycast_to_viewport_point(origin: Vector3, direction: Vector3) -> Vector2:
	return raycast_to_pixel(origin, direction)

## Pushes a pointer event at a physical pixel; the viewport converts it to logical layout coordinates.
func inject_input(event: InputEvent, pixel: Vector2):
	var copy = event.duplicate()
	if copy is InputEventMouse:
		copy.position = pixel
		copy.global_position = pixel
	viewport.push_input(copy)

func is_status_bar_pixel(pixel: Vector2) -> bool:
	return pixel.x >= 0 and pixel.y >= 0 and pixel.y <= STATUS_BAR_HEIGHT / LOGICAL.y * PHYSICAL.y

## {pixel, hover, pressed} for a fingertip near the screen, or {} when out of range.
func touch_pixel(fingertip: Vector3) -> Dictionary:
	if not direct_touch_enabled:
		return {}
	var local = to_local(fingertip)
	if local.z > TOUCH_HOVER or local.z < -TOUCH_BEHIND:
		return {}
	var pixel = _local_to_pixel(Vector3(local.x, local.y, 0))
	if pixel.x < 0:
		return {}
	return {"pixel": pixel, "hover": true, "pressed": local.z <= TOUCH_PRESS}

# --- grabbing --------------------------------------------------------------------

func grab_zone_contains(point: Vector3) -> bool:
	var local = to_local(point)
	if absf(local.z) > ZONE_DEPTH:
		return false
	var half = size_m() * 0.5
	var x = absf(local.x)
	var y = absf(local.y)
	if x > half.x + FRAME_BAND or y > half.y + FRAME_BAND:
		return false
	if x > half.x or y > half.y:
		return true # Frame border band.
	return local.y >= half.y - size_m().y * STATUS_BAR_HEIGHT / LOGICAL.y

func world_grab_blocked(point: Vector3) -> bool:
	return is_visible_in_tree() and grab_zone_contains(point)

func is_grabbed() -> bool:
	return not _grabs.is_empty()

## force: grab although the hand is outside the zone (laser on the status bar).
func begin_grab(hand: String, hand_transform: Transform3D, force := false) -> bool:
	if _grabs.has(hand) or not (force or grab_zone_contains(hand_transform.origin)):
		return false
	_grabs[hand] = {"offset": hand_transform.affine_inverse() * global_transform, "last": hand_transform}
	_following = false
	if _grabs.size() == 2:
		_begin_two_hand()
	haptic.emit(hand, 0.3, 0.03)
	return true

func _begin_two_hand():
	var hands = _grabs.values()
	var first: Vector3 = hands[0].last.origin
	var second: Vector3 = hands[1].last.origin
	_two_hand = {"distance": maxf(0.01, first.distance_to(second)), "scale": scale_factor,
		"mid": (first + second) * 0.5, "origin": global_position, "limited": false}

func update_grab(hand: String, hand_transform: Transform3D):
	if not _grabs.has(hand):
		return
	_grabs[hand].last = hand_transform
	if _grabs.size() == 2:
		var hands = _grabs.values()
		var first: Vector3 = hands[0].last.origin
		var second: Vector3 = hands[1].last.origin
		var wanted = _two_hand.scale * first.distance_to(second) / _two_hand.distance
		scale_factor = wanted
		var limited = not is_equal_approx(wanted, scale_factor)
		if limited and not _two_hand.limited:
			haptic.emit(hand, 0.4, 0.04)
		_two_hand.limited = limited
		var target = global_transform
		target.origin = _two_hand.origin + ((first + second) * 0.5 - _two_hand.mid)
		_move_toward(target)
		return
	_move_toward(hand_transform * _grabs[hand].offset)

func end_grab(hand: String):
	if not _grabs.erase(hand):
		return
	_two_hand.clear()
	# The remaining hand continues from the current pose.
	for other in _grabs:
		_grabs[other].offset = _grabs[other].last.affine_inverse() * global_transform
