extends Node
## Local overlays: never modifies shared mesh/material resources or sends packets.
var overlays: Dictionary = {}
var material: StandardMaterial3D

func _ready():
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.8, 1, 0.35)
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test = false

func _physics_process(_delta):
	var save = get_node_or_null("/root/SaveData")
	if save == null or save.get("store") == null: return
	var colors = {"cyan": Color(0.2, 0.8, 1, 0.35), "yellow": Color(1, 0.85, 0.1, 0.35), "green": Color(0.2, 1, 0.3, 0.35), "magenta": Color(1, 0.2, 0.8, 0.35), "white": Color(1, 1, 1, 0.35)}
	material.albedo_color = colors.get(save.store.get_value("interface.hover_color"), colors.cyan)
	var targets: Array = []
	var loader = get_node_or_null("/root/DataLoader")
	var network = get_node_or_null("/root/NetworkHandler")
	if loader == null or network == null: return
	var pickup = loader.get_world_pickups()
	for player in get_tree().get_nodes_in_group("player"):
		if save.voice.input_blocked or network.session_busy: continue
		if player.get("focused") == false or not get_tree().get_nodes_in_group("emote_wheel_input").is_empty(): continue
		if player.has_method("_menu_open") and player._menu_open(): continue
		var anchors: Array = []
		if player.get("left_controller") is XRController3D:
			for hand in [player.left_controller, player.right_controller]:
				if hand.get_is_active(): anchors.append([hand.global_position, 0.3, hand])
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.get("world_grip") is Node3D:
			anchors.append([player.world_grip.global_position, 1.5, player.world_grip])
		for entry in anchors:
			var grip = "virtual" if not entry[2] is XRController3D else ("left" if entry[2] == player.left_controller else "right")
			if pickup.held_by_local(grip): continue
			var selected: String = pickup.nearest_available(entry[2], entry[1])
			if not selected.is_empty(): targets.append(pickup.items[selected].get_ref())
		var controller = network.get_animation_controller()
		var mirror = controller.get("local_mirror") if controller != null else null
		if is_instance_valid(mirror) and mirror.visible:
			for entry in anchors:
				if not entry[2] is XRController3D:
					if pickup.held_by_local("virtual") or not pickup.nearest_available(entry[2], entry[1]).is_empty(): continue
					var hit = mirror.desktop_grab_hit(player.camera)
					if hit != null and _clear_path(player, player.camera.global_position, hit): targets.append(mirror)
					continue
				if not mirror.can_grab_at(entry[0], entry[1]): continue
				var local: Vector3 = mirror.to_local(entry[0])
				var nearest = Vector3(clampf(local.x, -mirror.dimensions.x / 2, mirror.dimensions.x / 2), clampf(local.y, -mirror.dimensions.y / 2, mirror.dimensions.y / 2), 0)
				if mirror.to_global(nearest).distance_to(entry[0]) < entry[1] and _clear_path(player, entry[0], mirror.to_global(nearest)): targets.append(mirror)
	show_targets(targets)

func show_targets(targets: Array):
	for target in overlays.keys():
		if not is_instance_valid(target) or not target in targets:
			for entry in overlays[target]:
				var mesh = entry.mesh.get_ref()
				if is_instance_valid(mesh) and mesh.material_overlay == material: mesh.material_overlay = entry.previous
			overlays.erase(target)
	for target in targets:
		if overlays.has(target): continue
		var meshes: Array = target.find_children("*", "MeshInstance3D", true, false)
		if target is MeshInstance3D: meshes.append(target)
		var created: Array = []
		for mesh in meshes:
			created.append({"mesh": weakref(mesh), "previous": mesh.material_overlay})
			mesh.material_overlay = material
		overlays[target] = created

func _exit_tree():
	show_targets([])

func _clear_path(player: Node3D, start: Vector3, end: Vector3, target: Node3D = null) -> bool:
	var ray = PhysicsRayQueryParameters3D.create(start, start.lerp(end, 0.98))
	var excluded: Array[RID] = []
	if player is CollisionObject3D: excluded.append(player.get_rid())
	if target is CollisionObject3D: excluded.append(target.get_rid())
	if target != null:
		for child in target.find_children("*", "CollisionObject3D", true, false): excluded.append(child.get_rid())
	ray.exclude = excluded
	return player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
