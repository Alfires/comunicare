extends Node3D
## Original deterministic composition using individual cleared optimized models.
func _ready():
	var trees = Node3D.new(); trees.name = "Trees"; add_child(trees)
	var rocks = Node3D.new(); rocks.name = "Rocks"; add_child(rocks)
	var borders = Node3D.new(); borders.name = "EdgeBorders"; add_child(borders)
	var positions = [Vector3(-15,0,-30), Vector3(-10,0,-39), Vector3(-5,0,-42), Vector3(5,0,-40), Vector3(13,0,-34), Vector3(-20,0,-35), Vector3(-27,0,-29), Vector3(-35,0,-24), Vector3(-39,0,-18), Vector3(-39,0,-5), Vector3(-40,0,4), Vector3(-35,0,14), Vector3(-33,0,25), Vector3(-26,0,32), Vector3(-16,0,37), Vector3(-6,0,40), Vector3(4,0,38), Vector3(37,0,-17), Vector3(40,0,-9), Vector3(41,0,0), Vector3(40,0,10), Vector3(-15,0,-18), Vector3(-8,0,-26), Vector3(8,0,-32)]
	for index in positions.size():
		var variant = ["a", "b", "c"][index % 3]
		var tree = load("res://assets/welcome_island/models/runtime/pine_sapling_small_" + variant + ".scn").instantiate()
		trees.add_child(tree); tree.position = positions[index]
		tree.scale = Vector3.ONE * (3.5 + (index % 4) * 0.5)
		tree.rotation.y = index * 1.7
		for mesh in tree.find_children("*", "MeshInstance3D", true, false):
			mesh.visibility_range_end = 160
			mesh.lod_bias = 4
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in 28:
		var angle = index * TAU / 28
		var rock = load("res://assets/welcome_island/models/runtime/boulder_01.scn").instantiate()
		rocks.add_child(rock)
		rock.position = Vector3(cos(angle) * 47, -0.3 if index % 2 else -3, sin(angle) * 47)
		rock.scale = Vector3(4 + index % 3, 3 + index % 2, 4)
		rock.rotation.y = angle
		for mesh in rock.find_children("*", "MeshInstance3D", true, false): mesh.visibility_range_end = 130
		if index % 2 == 0:
			var body = StaticBody3D.new(); borders.add_child(body); body.position = Vector3(cos(angle)*51, 0.4, sin(angle)*51)
			var collision = CollisionShape3D.new(); var shape = BoxShape3D.new(); shape.size = Vector3(3, 1.2, 3)
			collision.shape = shape; body.add_child(collision)
	for index in 18:
		var angle = index * TAU / 18
		var rock = load("res://assets/welcome_island/models/runtime/boulder_01.scn").instantiate()
		rocks.add_child(rock)
		rock.position = Vector3(cos(angle) * (32 + index % 4), -8 - index % 5, sin(angle) * (32 + index % 4))
		rock.scale = Vector3(7, 5, 7); rock.rotation = Vector3(0.2, angle, 0.3)
	# Trunk-sized proxies, never detailed foliage/rock collision.
	for tree in trees.get_children():
		var body = StaticBody3D.new(); tree.add_child(body)
		var collision = CollisionShape3D.new(); var shape = CylinderShape3D.new()
		shape.radius = 0.06; shape.height = 0.8; collision.shape = shape; collision.position.y = 0.4; body.add_child(collision)
