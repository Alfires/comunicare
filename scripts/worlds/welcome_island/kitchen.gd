extends Node3D
## Local kitchen play; no recipes, damage, account writes or network authority.
var items: Dictionary = {}
var homes: Dictionary = {}
var water: MeshInstance3D
var hob: MeshInstance3D
var door: Node3D
var heat_level := 0
var storage_open := false
var fridge_open := false
var fridge_door: Node3D
const INVENTORY = ["Cup", "Bowl", "Plate", "Pot", "Pan", "Spoon", "Board", "Canister"]

func _ready():
	add_to_group("home_kitchen")
	var house = get_parent()
	house._box("KitchenCounter", Vector3(6.6, 0.44, -3.2), Vector3(1.5, 0.88, 5.6), true)
	house._furniture("Sink", "kitchenSink", Vector3(6.6, 0, -5.5), Vector3(1.3, 0.9, 1.3), false)
	house._furniture("Cooker", "kitchenStoveElectric", Vector3(6.6, 0, -0.5), Vector3(1.3, 0.9, 1.3), false)
	house._furniture("Fridge", "kitchenFridgeSmall", Vector3(5, 0, -6), Vector3(1.2, 1.4, 1.1))
	for index in INVENTORY.size():
		var id = "kitchen." + INVENTORY[index]
		var item = RigidBody3D.new(); item.name = INVENTORY[index]; item.mass = 0.25
		add_child(item)
		item.position = Vector3(6.5 + (index % 2) * 0.35, 1.05, -5.3 + (index / 2) * 0.8)
		var size = Vector3(0.2, 0.16, 0.2)
		if index in [2, 6]: size = Vector3(0.3, 0.035, 0.25)
		if index == 5: size = Vector3(0.05, 0.03, 0.3)
		var asset = ["cup", "bowl", "plate", "pot", "frying-pan", "utensil-spoon", "cutting-board", "can"][index]
		var model = load("res://assets/welcome_island/models/kitchenware/" + asset + ".glb").instantiate()
		model.name = "AuthoredModel"; item.add_child(model)
		var bounds := AABB(); var first := true
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var box = model.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
			bounds = box if first else bounds.merge(box); first = false
		var factor = minf(size.x / maxf(bounds.size.x, 0.01), minf(size.y / maxf(bounds.size.y, 0.01), size.z / maxf(bounds.size.z, 0.01)))
		model.scale = Vector3.ONE * factor
		model.position = -(bounds.position + bounds.size * 0.5) * factor
		var shape = CollisionShape3D.new(); var collision = BoxShape3D.new(); collision.size = size
		shape.shape = collision; item.add_child(shape)
		items[id] = item; homes[id] = item.global_transform
	water = _effect("FaucetWater", Vector3(6.3, 1.1, -5.6), Vector3(0.035, 0.4, 0.035), Color(0.3, 0.65, 0.8))
	hob = _effect("HobHeat", Vector3(6.4, 0.9, -1), Vector3(0.6, 0.02, 0.6), Color(0.8, 0.22, 0.04))
	door = house._box("StorageDoor", Vector3(5.82, 0.4, -4.2), Vector3(0.08, 0.7, 0.8), true)
	fridge_door = house._box("FridgeDoor", Vector3(4.4, 0.6, -6), Vector3(0.08, 1.1, 0.9), true)
	# Body remains outside the broad central exit corridor.
	reset_kitchen()

func _effect(label: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new(); node.name = label; node.position = center
	var mesh = BoxMesh.new(); mesh.size = size; node.mesh = mesh
	var material = StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.3
	node.material_override = material; add_child(node); return node

func set_faucet(enabled: bool) -> bool:
	water.visible = enabled
	return true

func set_heat(level: int) -> bool:
	if level < 0 or level > 2: return false
	heat_level = level; hob.visible = level > 0
	hob.material_override.albedo_color = Color(0.8, 0.2, 0.02) if level == 2 else Color(0.35, 0.09, 0.02)
	return true

func set_storage(open: bool) -> bool:
	var query = PhysicsShapeQueryParameters3D.new(); var box = BoxShape3D.new()
	box.size = Vector3(0.5, 0.7, 0.8); query.shape = box
	query.transform.origin = get_parent().to_global(Vector3(5.5, 0.4, -4.2))
	var body = door.get_child(0)
	if body is CollisionObject3D: query.exclude = [body.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return false
	storage_open = open; door.position.x = 5.2 if open else 5.82
	return true

func reset_kitchen():
	set_faucet(false); set_heat(0)
	# Reset cannot force a door through an occupying player or held object.
	if not storage_open or set_storage(false):
		storage_open = false; door.position.x = 5.82
	if not fridge_open or set_fridge(false):
		fridge_open = false; fridge_door.position.x = 4.4
	var world = get_tree().current_scene
	for id in items:
		if world != null and world.get("local_pickups") != null: world.local_pickups.reset_local_item(id)
		items[id].global_transform = homes[id]
		items[id].linear_velocity = Vector3.ZERO; items[id].angular_velocity = Vector3.ZERO

func make_controls() -> VBoxContainer:
	var panel = VBoxContainer.new()
	for action in [["Kitchen faucet on/off", func(): set_faucet(not water.visible)], ["Hob: off / low / high", func(): set_heat((heat_level + 1) % 3)], ["Open/close kitchen storage", func(): set_storage(not storage_open)], ["Open/close fridge", func(): set_fridge(not fridge_open)], ["Reset kitchen (water and hob off)", reset_kitchen]]:
		var button = Button.new(); button.text = action[0]; button.custom_minimum_size.y = 44
		button.pressed.connect(action[1]); panel.add_child(button)
	return panel

func set_fridge(open: bool) -> bool:
	var query = PhysicsShapeQueryParameters3D.new(); var box = BoxShape3D.new()
	box.size = Vector3(0.45, 1.1, 0.9); query.shape = box
	query.transform.origin = get_parent().to_global(Vector3(4.05, 0.6, -6))
	var body = fridge_door.get_child(0)
	if body is CollisionObject3D: query.exclude = [body.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return false
	fridge_open = open; fridge_door.position.x = 3.8 if open else 4.4
	return true

func _exit_tree():
	heat_level = 0
	if is_instance_valid(water): water.visible = false
	if is_instance_valid(hob): hob.visible = false
