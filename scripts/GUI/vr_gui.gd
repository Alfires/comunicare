@tool
extends Node3D
class_name VRViewport2D

@onready var viewport = $SubViewport
@onready var mesh = $MeshInstance3D
@export var size := Vector2(2,1.5)
@export var pixel_per_unit: int = 200

func _ready():
	if mesh.material_override == null:
		var material = StandardMaterial3D.new()
		mesh.material_override = material
	else:
		mesh.material_override = mesh.material_override.duplicate()
	
	mesh.material_override.albedo_texture = viewport.get_texture()
	mesh.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.mesh = mesh.mesh.duplicate()
	mesh.mesh.size = size
	viewport.size = size * pixel_per_unit

func raycast_to_viewport_point(raycast_origin: Vector3, raycast_direction: Vector3) -> Vector2:
	if not raycast_origin.is_finite() or not raycast_direction.is_finite() or raycast_direction.dot(global_basis.z) >= -0.00001:
		return Vector2(-1, -1)
	var plane = Plane(global_transform.basis.z, global_position)
	var intersection = plane.intersects_ray(raycast_origin, raycast_direction)
	
	if intersection == null:
		return Vector2(-1, -1)
	
	var local_point = global_transform.affine_inverse() * intersection
	var uv = Vector2(local_point.x / size.x + 0.5, 0.5 - local_point.y / size.y)
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1: return Vector2(-1, -1)
	return uv * Vector2(viewport.size)

func inject_input(event: InputEvent, screen_pos: Vector2):
	var adjusted_event = event.duplicate()
	if adjusted_event is InputEventMouseButton or adjusted_event is InputEventMouseMotion:
		adjusted_event.position = screen_pos
	viewport.push_input(adjusted_event)
