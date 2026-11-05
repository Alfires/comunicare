extends Node
## Local overlays: never modifies shared mesh/material resources or sends packets.
var overlays: Dictionary = {}
var material: StandardMaterial3D

func _ready():
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.8, 1, 0.35)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _process(_delta):
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
				if hand.get_is_active(): anchors.append([hand.global_position, 0.3])
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.get("world_grip") is Node3D:
			anchors.append([player.world_grip.global_position, 1.5])
		for entry in anchors:
			var best: Node3D
			var distance: float = entry[1]
			for id in pickup.items:
				var item = pickup.items[id].get_ref()
				if not item is Node3D or pickup.states.get(id, {}).get("holder", -1) != -1: continue
				var separation: float = item.global_position.distance_to(entry[0])
				if separation < distance and _clear_path(player, entry[0], item.global_position, item): best = item; distance = separation
			if best != null: targets.append(best)
		var controller = network.get_animation_controller()
		var mirror = controller.get("local_mirror") if controller != null else null
		if is_instance_valid(mirror) and mirror.visible:
			for entry in anchors:
				var local: Vector3 = mirror.to_local(entry[0])
				var nearest = Vector3(clampf(local.x, -mirror.dimensions.x / 2, mirror.dimensions.x / 2), clampf(local.y, -mirror.dimensions.y / 2, mirror.dimensions.y / 2), 0)
				if mirror.to_global(nearest).distance_to(entry[0]) < entry[1] and _clear_path(player, entry[0], mirror.to_global(nearest)): targets.append(mirror)
	for target in overlays.keys():
		if not is_instance_valid(target) or not target in targets:
			for overlay in overlays[target]:
				if is_instance_valid(overlay): overlay.queue_free()
			overlays.erase(target)
	for target in targets:
		if overlays.has(target): continue
		var meshes: Array = target.find_children("*", "MeshInstance3D", true, false)
		if target is MeshInstance3D: meshes.append(target)
		var created: Array = []
		for mesh in meshes:
			if mesh.get_meta("interaction_overlay", false): continue
			var overlay = MeshInstance3D.new()
			overlay.mesh = mesh.mesh
			overlay.material_override = material
			overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			overlay.set_meta("interaction_overlay", true)
			mesh.add_child(overlay)
			overlay.scale = Vector3.ONE * 1.005
			created.append(overlay)
		overlays[target] = created

func _clear_path(player: Node3D, start: Vector3, end: Vector3, target: Node3D = null) -> bool:
	var ray = PhysicsRayQueryParameters3D.create(start, start.lerp(end, 0.98))
	var excluded: Array[RID] = []
	if player is CollisionObject3D: excluded.append(player.get_rid())
	if target is CollisionObject3D: excluded.append(target.get_rid())
	if target != null:
		for child in target.find_children("*", "CollisionObject3D", true, false): excluded.append(child.get_rid())
	ray.exclude = excluded
	return player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
