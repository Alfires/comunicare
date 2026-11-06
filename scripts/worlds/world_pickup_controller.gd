extends Node
## Client adapter: reviewed local items, same relay leases for desktop and VR.
var coordinator: Node
var loader: Node
var peer
var items: Dictionary = {}
var states: Dictionary = {}
var anchors: Dictionary = {}
var originals: Dictionary = {}
var local_sequence := 0
var received_sequence := -1
var session := ""
var revision := ""
var elapsed := 0.0
var snapshot_elapsed := 0.0
var local_only := false
var local_actions: Dictionary = {}
var local_world: WeakRef
const LOCAL_NOTICE = "Home objects are local to this client; changes are not synchronized with other players."

func activate_local(world: Node3D, local_items: Dictionary, actions: Dictionary = {}):
	reset()
	local_only = true
	local_world = weakref(world)
	for id in local_items:
		var item = local_items[id]
		if not item is RigidBody3D or not world.is_ancestor_of(item): continue
		items[id] = weakref(item)
		originals[id] = {"transform": item.global_transform, "freeze": item.freeze, "layer": item.collision_layer, "mask": item.collision_mask}
		states[id] = {"holder": -1, "grip": ""}
	for id in actions:
		var entry = actions[id]
		if entry is Dictionary and entry.get("node") is Node3D and entry.get("action") is Callable and world.is_ancestor_of(entry.node):
			local_actions[id] = {"node": weakref(entry.node), "action": entry.action}
	world.tree_exiting.connect(reset, CONNECT_ONE_SHOT)

func cancel_local_input():
	if not local_only: return
	for grip in anchors.keys(): release_grip(grip)

func reset_local_item(id: String) -> bool:
	if not local_only or not items.has(id): return false
	var item = items[id].get_ref()
	if not is_instance_valid(item): return false
	var grip: String = states[id].grip
	if not grip.is_empty(): release_grip(grip)
	item.global_transform = originals[id].transform
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	return true

func activate_nearest(anchor: Node3D, max_distance: float = 0.3) -> bool:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree(): return false
	if not get_tree().get_nodes_in_group("emote_wheel_input").is_empty(): return false
	if coordinator != null and coordinator.get("session_busy") == true: return false
	var runtime = loader.get("world_runtime") if loader != null else null
	if is_instance_valid(runtime) and runtime.enabled:
		var target := ""
		var nearest = clampf(max_distance, 0.05, 2.0)
		for id in runtime.bindings:
			var node = runtime.entities[id].get_ref()
			if not node is Node3D or not node.is_inside_tree(): continue
			var separation = node.global_position.distance_to(anchor.global_position)
			if separation < nearest and _unobstructed(anchor, node):
				nearest = separation
				target = id
		if not target.is_empty(): return runtime.dispatch("use", target).ok
	if not local_only: return false
	var selected: Callable
	var distance = clampf(max_distance, 0.05, 2.0)
	for entry in local_actions.values():
		var node = entry.node.get_ref()
		if not is_instance_valid(node): continue
		var separation = node.global_position.distance_to(anchor.global_position)
		if separation < distance and _unobstructed(anchor, node):
			distance = separation
			selected = entry.action
	if not selected.is_valid(): return false
	selected.call()
	return true

func configure(network: Node, data_loader: Node):
	coordinator = network
	loader = data_loader

func activate(world: Node, document: Dictionary, world_revision: String):
	reset()
	revision = world_revision
	session = str(coordinator.get("current_session_id")) if coordinator != null else ""
	_attach_peer()
	if peer != null and not peer.current_session_id.is_empty(): session = peer.current_session_id
	for id in document.get("entities", {}):
		var entry: Dictionary = document.entities[id]
		if not entry.get("pickup", false): continue
		var item = world if entry.path == "." else world.get_node_or_null(NodePath(entry.path))
		if item is Node3D:
			items[id] = weakref(item)
			originals[id] = {"transform": item.transform}
			if item is RigidBody3D:
				originals[id].freeze = item.freeze
				originals[id].layer = item.collision_layer
				originals[id].mask = item.collision_mask
	_attach_peer()
	_snapshot()

func _attach_peer():
	var current = coordinator.get("peer") if coordinator != null else null
	if peer == current: return
	if peer != null and peer.world_data.is_connected(receive): peer.world_data.disconnect(receive)
	peer = current
	if peer != null: peer.world_data.connect(receive)

func reset():
	if local_world != null and is_instance_valid(local_world.get_ref()):
		var world = local_world.get_ref()
		if world.tree_exiting.is_connected(reset): world.tree_exiting.disconnect(reset)
	local_world = null
	for id in items:
		_restore(id)
	items.clear()
	states.clear()
	anchors.clear()
	originals.clear()
	local_only = false
	local_actions.clear()
	received_sequence = -1
	snapshot_elapsed = 0.0
	# Sender sequence spans activations within the same connection, because a
	# relay lease can survive other peers changing worlds in the same instance.
	session = ""
	revision = ""

func _restore(id: String):
	var item = items[id].get_ref()
	if item is RigidBody3D and originals.has(id):
		item.freeze = originals[id].get("freeze", false)
		item.collision_layer = originals[id].get("layer", 1)
		item.collision_mask = originals[id].get("mask", 1)

func _send(value: Dictionary) -> bool:
	_attach_peer()
	if peer == null or not peer.world_supported or session.is_empty() or peer.current_session_id != session: return false
	value.session_id = session
	value.revision = revision
	peer.send_world(value)
	return true

func _snapshot():
	_send({"op": "snapshot"})

func request_grab(id: String, grip: String, anchor: Node3D) -> bool:
	if not items.has(id) or not grip in ["left", "right", "virtual"] or not is_instance_valid(anchor): return false
	var item = items[id].get_ref()
	if not item is Node3D or not item.is_inside_tree() or not anchor.is_inside_tree() or item.global_position.distance_to(anchor.global_position) > 2.0: return false
	if not _unobstructed(anchor, item): return false
	if states.get(id, {}).get("holder", -1) != -1: return false
	if local_only:
		if held_by_local(grip): return false
		anchors[grip] = weakref(anchor)
		states[id] = {"holder": 0, "grip": grip}
		item.freeze = true
		item.collision_layer = 0
		item.collision_mask = 0
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
		_world_event("grab", id)
		return true
	anchors[grip] = weakref(anchor)
	local_sequence += 1
	return _send({"op": "grab", "entity": id, "grip": grip, "epoch": states.get(id, {}).get("epoch", 0), "sequence": local_sequence})

func _unobstructed(anchor: Node3D, item: Node3D) -> bool:
	var query = PhysicsRayQueryParameters3D.create(anchor.global_position, item.global_position)
	var exclusions: Array[RID] = []
	var ancestor: Node = anchor
	while ancestor != null:
		if ancestor is CollisionObject3D: exclusions.append(ancestor.get_rid())
		ancestor = ancestor.get_parent()
	query.exclude = exclusions
	var hit = anchor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == item or item.is_ancestor_of(hit.collider)

func grab_nearest(anchor: Node3D, grip: String, max_distance: float = 0.3) -> bool:
	var selected = nearest_available(anchor, max_distance)
	return request_grab(selected, grip, anchor) if not selected.is_empty() else false

func nearest_available(anchor: Node3D, max_distance: float = 0.3) -> String:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree(): return ""
	var selected = ""
	var distance = clampf(max_distance, 0.05, 2.0)
	for id in items:
		var item = items[id].get_ref()
		if not item is Node3D or states.get(id, {}).get("holder", -1) != -1: continue
		var separation = item.global_position.distance_to(anchor.global_position)
		if separation < distance and _unobstructed(anchor, item):
			selected = id
			distance = separation
	return selected

func release_grip(grip: String) -> bool:
	if local_only:
		for id in states:
			if states[id].holder == 0 and states[id].grip == grip:
				_restore(id)
				var item = items[id].get_ref()
				if is_instance_valid(item):
					item.linear_velocity = Vector3.ZERO
					item.angular_velocity = Vector3.ZERO
				states[id] = {"holder": -1, "grip": ""}
				anchors.erase(grip)
				_world_event("release", id)
				return true
		return false
	if peer == null: return false
	for id in states:
		var state: Dictionary = states[id]
		if state.holder == peer.world_peer_id and state.grip == grip:
			local_sequence += 1
			return _send({"op": "release", "entity": id, "epoch": state.epoch, "sequence": local_sequence})
	return false

func held_by_local(grip: String) -> bool:
	if local_only:
		return states.values().any(func(state): return state.holder == 0 and state.grip == grip)
	if peer == null: return false
	for state in states.values():
		if state.holder == peer.world_peer_id and state.grip == grip: return true
	return false

func receive(value: Dictionary):
	if value.get("session_id") != session or value.get("revision") != revision: return
	if not value.get("sequence") is float and not value.get("sequence") is int: return
	if value.sequence <= received_sequence: return
	var previous_states = states.duplicate(true)
	if value.get("op") == "snapshot" and value.get("items") is Dictionary:
		var checked: Dictionary = {}
		for id in value.items:
			if items.has(id) and _valid_state(value.items[id]): checked[id] = value.items[id].duplicate(true)
		states = checked
	elif value.get("op") in ["item", "pose"] and items.has(value.get("entity")) and _valid_state(value):
		states[value.entity] = value.duplicate(true)
	else:
		return
	received_sequence = int(value.sequence)
	for id in items:
		var item = items[id].get_ref()
		if not is_instance_valid(item): continue
		if item is RigidBody3D:
			var held = states.get(id, {}).get("holder", -1) != -1
			if held:
				item.freeze = true
				# Remote held props never apply forces to the player's body.
				item.collision_layer = 0
				item.collision_mask = 0
			else:
				_restore(id)
		var old_holder = previous_states.get(id, {}).get("holder", -1)
		var new_holder = states.get(id, {}).get("holder", -1)
		if peer != null and old_holder != new_holder:
			if new_holder == peer.world_peer_id: _world_event("grab", id)
			elif old_holder == peer.world_peer_id: _world_event("release", id)

func _world_event(event: String, id: String):
	var runtime = loader.get("world_runtime") if loader != null else null
	if is_instance_valid(runtime) and runtime.enabled and runtime.bindings.has(id): runtime.dispatch(event, id)

func _valid_state(value: Variant) -> bool:
	var guard = preload("res://scripts/worlds/world_data.gd")
	if not value is Dictionary or not guard.integer(value.get("holder"), -1, 255) or not guard.integer(value.get("epoch"), 0, 2147483646): return false
	if value.epoch < 0 or value.epoch > 2147483646: return false
	if value.holder != -1 and (not value.get("generation") is String or not value.get("grip") in ["left", "right", "virtual"]): return false
	if not value.get("position", []) is Array or not value.get("rotation", []) is Array: return false
	if value.get("position", []).is_empty() and value.get("rotation", []).is_empty(): return true
	if value.position.size() != 3 or value.rotation.size() != 4: return false
	for number in value.position + value.rotation:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 10000: return false
	return absf(Quaternion(value.rotation[0], value.rotation[1], value.rotation[2], value.rotation[3]).length_squared() - 1.0) < 0.02

func _process(delta: float):
	if local_only:
		for id in states:
			var state = states[id]
			if state.holder != 0: continue
			var item = items[id].get_ref()
			var anchor = anchors.get(state.grip)
			var hand = anchor.get_ref() if anchor != null else null
			if not is_instance_valid(hand) or not is_instance_valid(item):
				release_grip(state.grip)
				continue
			# Disabled held collision must not let a controller teleport props through
			# walls or restore physics inside geometry. Retain the last safe pose.
			if hand.global_transform.is_finite() and _local_carry_clear(item, hand.global_transform):
				item.global_transform = hand.global_transform
		return
	if coordinator == null or loader == null: return
	_attach_peer()
	if peer != null and peer.current_session_id != session:
		if not session.is_empty(): reset()
		return
	if peer == null or not peer.world_supported: return
	snapshot_elapsed += delta
	if snapshot_elapsed >= 5.0:
		snapshot_elapsed = 0.0
		_snapshot()
	elapsed += delta
	var send_pose = elapsed >= 0.05
	if send_pose: elapsed = 0.0
	for id in states:
		var item = items.get(id).get_ref() if items.has(id) else null
		var state: Dictionary = states[id]
		if not item is Node3D or not item.is_inside_tree(): continue
		if state.holder == peer.world_peer_id:
			var anchor = anchors.get(state.grip)
			if anchor == null or not is_instance_valid(anchor.get_ref()):
				if send_pose: release_grip(state.grip)
				continue
			var hand: Node3D = anchor.get_ref()
			item.global_transform = hand.global_transform
			if send_pose:
				var q = item.global_basis.orthonormalized().get_rotation_quaternion()
				local_sequence += 1
				_send({"op": "pose", "entity": id, "epoch": state.epoch, "sequence": local_sequence, "position": [item.global_position.x, item.global_position.y, item.global_position.z], "rotation": [q.x, q.y, q.z, q.w]})
		elif not state.get("position", []).is_empty():
			var target = Vector3(state.position[0], state.position[1], state.position[2])
			item.global_position = item.global_position.lerp(target, minf(1.0, delta * 20.0))
			var q = Quaternion(state.rotation[0], state.rotation[1], state.rotation[2], state.rotation[3])
			item.global_basis = Basis(item.global_basis.orthonormalized().get_rotation_quaternion().slerp(q, minf(1.0, delta * 20.0)))

func _exit_tree():
	reset()
	if peer != null and peer.world_data.is_connected(receive): peer.world_data.disconnect(receive)

func _local_carry_clear(item: RigidBody3D, target: Transform3D) -> bool:
	var space = item.get_world_3d().direct_space_state
	var mask := 1
	# Use the original mask: the held body's live mask is intentionally zero.
	for id in items:
		if items[id].get_ref() == item:
			mask = originals[id].get("mask", 1)
			break
	for child in item.find_children("*", "CollisionShape3D", true, false):
		if child.disabled or child.shape == null: continue
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = child.shape
		query.collision_mask = mask
		query.exclude = [item.get_rid()]
		var relative = item.global_transform.affine_inverse() * child.global_transform
		query.transform = item.global_transform * relative
		query.motion = target.origin - item.global_position
		if query.motion.length_squared() > 0.000001 and space.cast_motion(query)[0] < 1.0: return false
		query.transform = target * relative
		query.motion = Vector3.ZERO
		if not space.intersect_shape(query).is_empty(): return false
	return true
