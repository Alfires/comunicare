extends Node3D


func _on_area_3d_body_entered(body: Node3D) -> void:
	print("Object entered void: ", body.name)
	body.global_position = Vector3(0, 1, 0)
	
	if body is RigidBody3D:
		body.linear_velocity = Vector3.ZERO
