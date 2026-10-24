extends Node3D
class_name VRViewport2D

@onready var viewport = $SubViewport
@onready var mesh = $MeshInstance3D

func _ready():
	if mesh.material_override == null:
		var material = StandardMaterial3D.new()
		mesh.material_override = material
	
	mesh.material_override.albedo_texture = viewport.get_texture()

func raycast_to_viewport_point(raycast_origin: Vector3, raycast_direction: Vector3) -> Vector2:
	var plane = Plane(global_transform.basis.z, global_position)
	var intersection = plane.intersects_ray(raycast_origin, raycast_direction)
	
	if intersection == null:
		return Vector2(-1, -1)
	
	var local_point = global_transform.affine_inverse() * intersection
	var uv = local_point * 0.5 + Vector3(0.5, 0.5, 0)
	
	return uv * viewport.get_texture().get_size()

func inject_input(event: InputEvent, screen_pos: Vector2):
	var adjusted_event = event.duplicate()
	if adjusted_event is InputEventMouseButton or adjusted_event is InputEventMouseMotion:
		adjusted_event.position = screen_pos
	viewport.push_input(adjusted_event)
