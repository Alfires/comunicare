extends Node
## Client instance animation state and opt-in, requested file distribution.

const Reader = preload("res://scripts/assets/humanoid_animation.gd")
const Defaults = preload("res://scripts/assets/default_animations.gd")
const Animator = preload("res://scripts/assets/avatar_animator.gd")
signal changed
var transport
var coordinator: Node
var loader: Node
var sequence := 0
var local_state: Dictionary = {}
var local_handle: Dictionary = {}
var local_animator: Node
var local_clip: Dictionary = {}
var remote_states: Dictionary = {}
var remote_animators: Dictionary = {}
var incoming: Dictionary = {}
var outgoing: Array = []
var assets: Dictionary = {}
var pending_assets: Dictionary = {}
var clock_offset := 0.0
var clock_ready := false
var clock_elapsed := 10.0
var snapshot_elapsed := 3.0
var transfer_elapsed := 0.0
var last_error := ""
var reader = Reader.new()
var accept_remote := true
var locomotion_elapsed := 0.0
var configuration: Node
var active_emote := ""
var active_role := ""
var applied_revision := -1
var wheel: Control
var wheel_layer: CanvasLayer
var xr_wheel: Node3D
var saved_session := ""
var published_sequence := -1
var local_model_handle: Dictionary = {}
var model_incoming: Dictionary = {}
var model_loading: Dictionary = {}
var remote_tracking: Dictionary = {}
var tracking_nodes: Dictionary = {}

func configure(network: Node, data_loader: Node):
	coordinator = network
	loader = data_loader
	if loader != null and loader.has_method("get_avatar_configuration"):
		configuration = loader.get_avatar_configuration()

func _process(delta: float):
	if coordinator == null:
		return
	_update_tracking(delta)
	if configuration != null and not local_state.is_empty() and local_state.get("configuration_owner", "") != configuration.account_owner:
		clear()
	if transport != coordinator.peer:
		if transport != null and transport.animation_data.is_connected(receive):
			transport.animation_data.disconnect(receive)
		clear()
		transport = coordinator.peer
		if transport != null:
			transport.animation_data.connect(receive)
	if saved_session != coordinator.current_session_id:
		saved_session = coordinator.current_session_id
		active_role = ""
	locomotion_elapsed += delta
	if locomotion_elapsed >= 0.1:
		locomotion_elapsed = 0
		_update_locomotion()
	if transport == null or not transport.animation_supported:
		return
	if not local_state.is_empty() and published_sequence != local_state.sequence and local_state.get("share", false):
		local_state.offset = AnimationState.playhead(local_state, now())
		local_state.started = now()
		_send(local_state.duplicate())
	for id in remote_states.keys():
		if not _member(id):
			_remove_remote(id)
	clock_elapsed += delta
	snapshot_elapsed += delta
	transfer_elapsed += delta
	if clock_elapsed >= 10:
		clock_elapsed = 0
		transport.send_animation({"op": "clock", "nonce": Time.get_ticks_msec()})
	if snapshot_elapsed >= 3 and not coordinator.current_session_id.is_empty() and not coordinator.session_busy:
		snapshot_elapsed = 0
		_send({"op": "snapshot"})
		for id in remote_states:
			_apply_remote(id)
		# Keyframes repair drift after clock estimation changes, including self.
		if not local_state.is_empty() and is_instance_valid(local_animator) and is_instance_valid(local_animator.player):
			var target = AnimationState.playhead(local_state, now())
			if absf(local_animator.player.current_animation_position - target) > 0.1:
				local_animator.player.seek(target, true)
	if transfer_elapsed >= 0.07 and not outgoing.is_empty():
		transfer_elapsed = 0
		_send_chunk()
	for id in incoming.keys():
		if incoming[id].expires < Time.get_ticks_msec():
			incoming.erase(id)
	for id in model_incoming.keys():
		if model_incoming[id].expires < Time.get_ticks_msec(): model_incoming.erase(id)

func now() -> float:
	return Time.get_ticks_msec() + clock_offset

var walk_reference_speed := 3.0
var locomotion_running := false

func _update_locomotion():
	for player in get_tree().get_nodes_in_group("player"):
		if player is CharacterBody3D and _local_model() != null:
			if not active_emote.is_empty():
				var replaced = not is_instance_valid(local_animator) or local_animator.avatar != _local_model() \
					or (configuration != null and local_state.get("configuration_revision") != configuration.revision)
				if replaced or Vector2(player.velocity.x, player.velocity.z).length() > 0.15 or not player.is_on_floor() \
					or (not local_state.get("loop", false) and AnimationState.playhead(local_state, now()) >= local_state.get("duration", 0)):
					cancel_emote()
				else:
					return
			walk_reference_speed = player.get_walk_speed() if player.has_method("get_walk_speed") else 3.0
			var motion = resolve_motion(player.is_on_floor(), player.global_basis.inverse() * player.velocity, now())
			var revision = configuration.revision if configuration != null else 0
			var changed_model = not is_instance_valid(local_animator) or local_animator.avatar != _local_model()
			if active_role != motion or applied_revision != revision or changed_model:
				var item = configuration.roles.get(motion, {}) if configuration != null else {}
				if item.is_empty():
					item = {"clip": Defaults.clip(motion), "builtin": motion, "handle": {}, "index": 0, "share": true, "loop": motion in ["walk", "run", "strafe_left", "strafe_right", "fall"]}
				if not item.get("share", false) and transport != null and transport.animation_supported:
					item = {"clip": Defaults.clip(motion), "builtin": motion, "handle": {}, "index": 0, "share": true, "loop": motion in ["walk", "run", "strafe_left", "strafe_right", "fall"]}
				var applied = _apply_resolved(item, "locomotion", motion)
				if not applied and item.get("builtin", "").is_empty():
					applied = _apply_resolved({"clip": Defaults.clip(motion), "builtin": motion, "handle": {}, "index": 0,
						"share": true, "loop": motion in ["walk", "run", "strafe_left", "strafe_right", "fall"]}, "locomotion", motion)
				if applied:
					active_role = motion
					applied_revision = revision
			return

func resolve_motion(grounded: bool, velocity: Vector3, _at_msec: float) -> String:
	var motion = "neutral"
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var threshold = maxf(walk_reference_speed, 0.1) * (1.1 if locomotion_running else 1.3)
	locomotion_running = grounded and horizontal_speed > threshold
	if not grounded: motion = "jump" if velocity.y > 0 else "neutral"
	elif horizontal_speed > 0.1:
		if absf(velocity.x) > absf(velocity.z): motion = "strafe_left" if velocity.x < 0 else "strafe_right"
		else: motion = "run" if locomotion_running else "walk"
	return motion

static func tracking_mask(clip: Dictionary) -> Dictionary:
	var result = clip.duplicate(true)
	result.tracks = result.tracks.filter(func(track): return track.bone not in ["head", "leftEye", "rightEye", "jaw", "leftHand", "rightHand"])
	return result

static func strafe_pose(clip: Dictionary) -> Dictionary:
	var result = clip.duplicate(true)
	var legs = ["leftUpperLeg", "rightUpperLeg", "leftLowerLeg", "rightLowerLeg", "leftFoot", "rightFoot", "leftToes", "rightToes"]
	result.tracks = result.tracks.filter(func(track): return track.bone in legs)
	# Upper body uses the exact forward-walk samples/bases. Only legs use
	# sideways reorientation, so arms swing naturally without twisting sideways.
	for track in Defaults.clip("walk").tracks:
		if track.bone not in legs: result.tracks.append(track.duplicate(true))
	return result

func emote_catalog() -> Dictionary:
	if configuration != null:
		var actions: Dictionary = configuration.emotes.duplicate()
		actions["__cancel_emote__"] = {"name": "Return to movement"}
		return actions
	var catalog: Dictionary = {}
	for id in ["dance", "interact"]:
		catalog["builtin:" + id] = {"name": id.capitalize(), "clip": Defaults.clip(id), "builtin": id,
			"handle": {}, "index": 0, "share": true, "loop": id == "dance"}
	return catalog

func request_emote(id: String) -> bool:
	var catalog = emote_catalog()
	if not catalog.has(id):
		last_error = "This animation is not in the applied avatar's sources."
		return false
	if not catalog[id].get("share", false) and transport != null and transport.animation_supported:
		last_error = "This motion has no redistribution permission; enable permission in avatar source configuration."
		return false
	if _apply_resolved(catalog[id], "emote", id):
		active_emote = id
		active_role = ""
		return true
	return false

func cancel_emote():
	active_emote = ""
	active_role = ""
	locomotion_elapsed = 1.0

func _apply_resolved(item: Dictionary, kind: String, action_id: String) -> bool:
	var clip: Dictionary = item.clip.duplicate(true)
	clip.motion_role = action_id if kind == "locomotion" else ""
	if kind == "locomotion" and action_id in ["strafe_left", "strafe_right"]:
		clip = strafe_pose(clip)
	if _is_vr():
		clip = tracking_mask(clip)
		if clip.tracks.is_empty():
			last_error = "This action has no untracked VR animation channels."
			return false
	if not _play_resolved(clip, item.get("builtin", ""), item.get("handle", {}), item.get("index", 0), item.get("loop", false), 1.0, item.get("share", false)):
		return false
	local_state.kind = kind
	local_state.role = action_id
	local_state.mask = "tracked_head_hands" if _is_vr() else "full"
	local_state.avatar_revision = str(_local_model().get_meta("asset_revision", ""))
	local_state.configuration_revision = configuration.revision if configuration != null else 0
	local_state.configuration_owner = configuration.account_owner if configuration != null else ""
	local_state.share = item.get("share", false)
	local_model_handle = {}
	if configuration != null and not configuration.model.is_empty() and configuration.model.get("share", false):
		local_model_handle = loader.get_asset_cache().revision_handle(configuration.model.hash)
		if not local_model_handle.is_empty():
			local_state.model_hash = local_model_handle.hash
			local_state.model_size = FileAccess.open(local_model_handle.path, FileAccess.READ).get_length()
	if item.get("share", false): _send(local_state.duplicate())
	return true

func _is_vr() -> bool:
	for player in get_tree().get_nodes_in_group("player"):
		if player.get("vrm_model") is Node3D: return true
	return false

func _send(value: Dictionary):
	if transport != null and transport.animation_supported and not coordinator.session_busy \
		and not coordinator.current_session_id.is_empty():
		value.session_id = coordinator.current_session_id
		transport.send_animation(value)
		if value.get("op") == "state": published_sequence = int(value.sequence)

func toggle_emote_menu():
	if not is_inside_tree():
		last_error = "Animation controller is not attached yet; retry after startup."
		return
	if is_instance_valid(wheel) and wheel.visible:
		wheel.dismiss()
		return
	for player in get_tree().get_nodes_in_group("player"):
		if player.get("right_controller") is XRController3D:
			open_xr_menu(player.right_controller, player.xr_camera, false)
			return
	if not is_instance_valid(wheel_layer):
		wheel_layer = CanvasLayer.new()
		wheel_layer.layer = 50
		get_tree().root.add_child(wheel_layer)
	if not is_instance_valid(wheel) or wheel.get_parent() != wheel_layer:
		wheel = preload("res://scripts/GUI/emote_wheel.gd").new()
		wheel_layer.add_child(wheel)
		wheel.emote_selected.connect(_choose_emote)
	var menu_layout = configuration.layout if configuration != null else preload("res://scripts/assets/emote_layout.gd").new()
	wheel.open(menu_layout, emote_catalog())

func _choose_emote(id: String):
	if id == "__cancel_emote__":
		cancel_emote()
	elif not request_emote(id):
		if is_instance_valid(wheel):
			wheel.message = last_error
			wheel.queue_redraw()
		return
	if is_instance_valid(wheel): wheel.dismiss()

func open_xr_menu(hand: XRController3D, camera: XRCamera3D, hold: bool):
	if not is_inside_tree() or not is_instance_valid(hand) or not is_instance_valid(camera):
		return
	if is_instance_valid(xr_wheel): xr_wheel.queue_free()
	xr_wheel = preload("res://scripts/GUI/xr_emote_wheel.gd").new()
	get_tree().root.add_child(xr_wheel)
	var menu_layout = configuration.layout if configuration != null else preload("res://scripts/assets/emote_layout.gd").new()
	xr_wheel.open(hand, camera, menu_layout, emote_catalog(), hold)
	wheel = xr_wheel.wheel
	wheel.emote_selected.connect(_choose_emote)

func _input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo: return
	if not InputMap.has_action("toggle_animation_menu") or not event.is_action_pressed("toggle_animation_menu"): return
	var save = get_node_or_null("/root/SaveData")
	if DisplayServer.has_feature(DisplayServer.FEATURE_IME) and not DisplayServer.ime_get_text().is_empty(): return
	if is_instance_valid(wheel) and wheel.visible:
		wheel.dismiss()
	elif save != null and save.get("voice") != null and not save.voice.input_blocked and not save.voice._focus_blocks_input(get_tree().root):
		toggle_emote_menu()
	else: return
	get_viewport().set_input_as_handled()

func _local_model() -> Node3D:
	for player in get_tree().get_nodes_in_group("player"):
		if player.get("vrm_model") is Node3D:
			return player.vrm_model
		if player.get("avatar_model") is Node3D:
			return player.avatar_model
	return null

func _new_animator(model: Node3D) -> Node:
	var animator = Animator.new()
	model.add_child(animator)
	animator.attach(model)
	return animator

func _dispose_animator(animator: Node):
	if is_instance_valid(animator):
		animator.stop()
		if is_instance_valid(animator.player):
			animator.player.queue_free()
		animator.queue_free()

func _play_resolved(clip: Dictionary, builtin: String, handle: Dictionary, clip_index: int,
		looping: bool, speed: float, share: bool) -> bool:
	var model = _local_model()
	if model == null:
		last_error = "No compatible avatar is loaded."
		return false
	if share and builtin.is_empty() and handle.is_empty():
		last_error = "No validated imported motion is available to share."
		return false
	if not is_instance_valid(local_animator) or local_animator.avatar != model:
		if is_instance_valid(local_animator):
			_dispose_animator(local_animator)
		local_animator = _new_animator(model)
	# Stop the previously advertised motion before switching to a private clip.
	if builtin.is_empty() and not share:
		_clear_local()
	if not local_animator.play_clip(clip, looping, speed):
		last_error = local_animator.last_error
		return false
	local_clip = clip
	local_handle = handle if share else {}
	sequence += 1
	local_state = {"op": "state", "version": 2, "sequence": sequence, "action": "resolved",
		"loop": looping, "speed": speed, "offset": 0.0, "duration": clip.duration,
		"builtin": builtin, "library": Defaults.LIBRARY, "hash": "", "started": now()}
	if builtin.is_empty() and share and not handle.is_empty():
		local_state.hash = handle.hash
		local_state.size = FileAccess.open(handle.path, FileAccess.READ).get_length()
		local_state.clip = clip_index
	last_error = "Playing locally" if transport == null or not transport.animation_supported or (builtin.is_empty() and not share) else "Playing and sharing with compatible instance players"
	changed.emit()
	return true

func _clear_local():
	local_state.clear()
	local_handle.clear()
	local_clip.clear()
	outgoing.clear()
	if is_instance_valid(local_animator):
		local_animator.stop()
	changed.emit()

func receive(value: Dictionary):
	if value.get("op") == "pose":
		if not TrackingPose.valid(value) or coordinator.session_busy or value.get("session_id") != coordinator.current_session_id: return
		var id = int(value.get("peer_id", -1))
		if not _member(id) or not value.get("generation") is String: return
		var previous: Dictionary = remote_tracking.get(id, {})
		if previous.get("generation") == value.generation and value.sequence <= previous.get("sequence", 0): return
		var clean = value.duplicate(true)
		clean.received = Time.get_ticks_msec()
		clean.decoded = TrackingPose.decode_targets(value.targets)
		remote_tracking[id] = clean
		return
	if value.get("op") == "clock":
		if AnimationState.integer(value.get("nonce"), 0, Time.get_ticks_msec()) and AnimationState.number(value.get("time"), 0, 9007199254740991):
			var rtt = Time.get_ticks_msec() - value.nonce
			if rtt <= 2000:
				clock_offset = value.time - (value.nonce + rtt * 0.5)
				clock_ready = true
		return
	if value.get("op") == "left":
		if value.get("session_id") == coordinator.current_session_id and AnimationState.integer(value.get("peer_id"), 0, 255) and remote_states.get(int(value.peer_id), {}).get("generation") == value.get("generation"):
			_remove_remote(int(value.peer_id))
		return
	if coordinator.session_busy or value.get("session_id") != coordinator.current_session_id:
		return
	match value.get("op"):
		"state":
			if not AnimationState.valid(value) or not AnimationState.integer(value.get("peer_id"), 0, 255) \
				or not value.get("generation") is String or value.generation.length() != 32 \
				or not AnimationState.number(value.get("started"), 0, 9007199254740991):
				return
			var id = int(value.peer_id)
			if not _member(id):
				# The relay echoes our own state with canonical timing.
				if not local_state.is_empty() and value.sequence == local_state.sequence:
					local_state.started = value.started
				return
			var previous: Dictionary = remote_states.get(id, {})
			if previous.get("generation") == value.generation and value.get("configuration_revision", 0) < previous.get("configuration_revision", 0): return
			if previous.get("generation") == value.generation and previous.get("sequence", 0) > value.sequence:
				return
			if previous.get("hash") != value.get("hash") or previous.get("generation") != value.generation:
				incoming.erase(id)
				if not previous.get("hash", "").is_empty():
					assets.erase(previous.hash)
			if previous.get("model_hash") != value.get("model_hash") or previous.get("generation") != value.generation:
				model_incoming.erase(id)
			remote_states[id] = value.duplicate(true)
			_apply_remote(id)
		"request":
			var kind = value.get("asset_kind", "animation")
			var offered = local_model_handle if kind == "avatar" else local_handle
			if not offered.is_empty() and value.get("hash") == offered.get("hash") \
				and AnimationState.integer(value.get("requester"), 0, 255) and _member(int(value.requester)) and outgoing.size() < 4:
				for request in outgoing:
					if request.target == int(value.requester) and request.get("asset_kind", "animation") == kind:
						return
				outgoing.append({"target": int(value.requester), "asset_kind": kind, "hash": value.hash, "offset": 0})
		"chunk":
			_receive_chunk(value)

func _member(id: int) -> bool:
	return transport != null and id in transport.session_peers

func _apply_remote(id: int):
	if not remote_states.has(id) or not _member(id) or not accept_remote:
		return
	var value: Dictionary = remote_states[id]
	var remote = coordinator.get_node_or_null(str(id))
	if remote == null or not remote.get("avatar") is Node3D:
		return
	if not value.get("model_hash", "").is_empty() and remote.avatar.get_meta("asset_revision", "") != value.model_hash:
		_prepare_remote_model(id, value)
		return
	if value.get("model_hash", "").is_empty() and not value.get("avatar_revision", "").is_empty() \
		and remote.avatar.get_meta("asset_revision", "") != value.avatar_revision:
		return # Wait for the profile-selected avatar rather than animate a stale rig.
	var clip: Dictionary
	if value.get("builtin") in Defaults.IDS:
		clip = Defaults.clip(value.builtin)
	else:
		if not assets.has(value.hash):
			if assets.size() >= 4:
				return
			if pending_assets.has(value.hash):
				return
			if loader != null and not pending_assets.has(value.hash):
				var saved = loader.get_asset_cache().revision_handle(value.hash)
				if not saved.is_empty():
					pending_assets[value.hash] = true
					var parsed = await loader.read_animation(saved.path)
					pending_assets.erase(value.hash)
					if not remote_states.has(id) or remote_states[id].get("hash") != value.hash:
						return
					if not parsed.is_empty():
						assets[value.hash] = {"parsed": parsed, "handle": saved}
						_apply_remote(id)
						return
			if not incoming.has(id) and incoming.size() < 4 and assets.size() < 4:
				incoming[id] = {"hash": value.hash, "bytes": PackedByteArray(), "size": value.size, "expires": Time.get_ticks_msec() + 180000}
				_send({"op": "request", "owner": id, "hash": value.hash})
			return
		var parsed: Dictionary = assets[value.hash].parsed
		if value.clip >= parsed.clips.size():
			return
		clip = parsed.clips[int(value.clip)]
	if absf(float(clip.duration) - float(value.duration)) > 0.01:
		return
	if value.get("kind") == "locomotion" and value.get("role") in ["strafe_left", "strafe_right"]:
		clip = strafe_pose(clip)
	if not value.loop and AnimationState.playhead(value, now()) >= value.duration:
		if is_instance_valid(remote_animators.get(id)): remote_animators[id].stop()
		return
	if value.get("mask") == "tracked_head_hands":
		clip = tracking_mask(clip)
		if clip.tracks.is_empty(): return
	var animator = remote_animators.get(id)
	if not is_instance_valid(animator) or animator.avatar != remote.avatar:
		if is_instance_valid(animator):
			_dispose_animator(animator)
		animator = _new_animator(remote.avatar)
		remote_animators[id] = animator
	var position = AnimationState.playhead(value, now())
	if animator.descriptor.get("generation") == value.generation and animator.descriptor.get("sequence") == value.sequence:
		if absf(animator.player.current_animation_position - position) > 0.1:
			animator.player.seek(position, true)
		return
	clip = clip.duplicate(true)
	clip.motion_role = str(value.get("role", "")) if value.get("kind") == "locomotion" else ""
	if not animator.play_clip(clip, value.loop, value.speed, position):
		last_error = animator.last_error
		return
	animator.descriptor = {"generation": value.generation, "sequence": value.sequence}

func _send_chunk():
	var request: Dictionary = outgoing.pop_front()
	var offered = local_model_handle if request.get("asset_kind") == "avatar" else local_handle
	if not _member(request.target) or offered.is_empty() or request.hash != offered.hash:
		return
	var file = FileAccess.open(offered.path, FileAccess.READ)
	if file == null:
		return
	file.seek(request.offset)
	var bytes = file.get_buffer(AnimationState.CHUNK_BYTES)
	if bytes.is_empty():
		return
	_send({"op": "chunk", "asset_kind": request.get("asset_kind", "animation"), "target": request.target, "hash": request.hash,
		"offset": request.offset, "bytes": Marshalls.raw_to_base64(bytes)})
	request.offset += bytes.size()
	if request.offset < file.get_length():
		outgoing.append(request)

func _prepare_remote_model(id: int, state: Dictionary):
	if loader == null or model_loading.has(id): return
	var handle = loader.get_asset_cache().revision_handle(state.model_hash)
	if handle.is_empty():
		if not model_incoming.has(id) and model_incoming.size() < 2:
			model_incoming[id] = {"hash": state.model_hash, "size": state.model_size, "bytes": PackedByteArray(), "expires": Time.get_ticks_msec() + 900000}
			_send({"op": "request", "asset_kind": "avatar", "owner": id, "hash": state.model_hash})
		return
	model_loading[id] = true
	var model = await loader._load_model_from_file(handle.path)
	model_loading.erase(id)
	if not remote_states.has(id) or remote_states[id].get("model_hash") != state.model_hash or not _member(id):
		if model != null: model.queue_free()
		return
	var remote = coordinator.get_node_or_null(str(id))
	if remote == null or model == null:
		if model != null: model.queue_free()
		return
	model.set_meta("asset_lease", handle.lease)
	model.set_meta("asset_revision", handle.hash)
	if remote.get("avatar_generation") != null: remote.avatar_generation += 1
	if remote.has_method("attach_avatar"):
		remote.attach_avatar(model)
	else:
		if is_instance_valid(remote.avatar): remote.avatar.queue_free()
		remote.avatar = model
		remote.add_child(model)
	_apply_remote(id)

func _store_remote_model(id: int, request: Dictionary):
	if loader == null or not remote_states.has(id) or remote_states[id].get("model_hash") != request.hash: return
	var cache = loader.get_asset_cache()
	cache.initialize()
	var path = cache.directory.path_join("staging/avatar-%s-%s" % [id, Time.get_ticks_usec()])
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	file.store_buffer(request.bytes)
	file.close()
	var handle = await cache.import_file(path, "avatar", loader._validate_avatar, false)
	cache._remove_file(path)
	if not handle.is_empty() and remote_states.has(id) and remote_states[id].get("model_hash") == request.hash:
		_prepare_remote_model(id, remote_states[id])

func _receive_chunk(value: Dictionary):
	if not AnimationState.integer(value.get("owner"), 0, 255) or not value.get("bytes") is String or value.bytes.length() > 10924:
		return
	var owner = int(value.owner)
	var pending = model_incoming if value.get("asset_kind", "animation") == "avatar" else incoming
	if not pending.has(owner) or not _member(owner):
		return
	var request: Dictionary = pending[owner]
	if value.get("hash") != request.hash or value.get("offset") != request.bytes.size():
		return
	var bytes = Marshalls.base64_to_raw(value.bytes)
	if bytes.is_empty() or bytes.size() > AnimationState.CHUNK_BYTES or request.bytes.size() + bytes.size() > request.size:
		pending.erase(owner)
		return
	request.bytes.append_array(bytes)
	if request.bytes.size() != request.size:
		return
	pending.erase(owner)
	var digest = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(request.bytes)
	if digest.finish().hex_encode() != request.hash:
		return
	if value.get("asset_kind", "animation") == "avatar":
		await _store_remote_model(owner, request)
		return
	var parsed: Dictionary = {}
	var handle: Dictionary = {}
	if loader != null:
		parsed = await loader.read_animation("", request.bytes)
		if parsed.is_empty() or not remote_states.has(owner) or remote_states[owner].get("hash") != request.hash:
			return
		var cache = loader.get_asset_cache()
		cache.initialize()
		var path = cache.directory.path_join("staging/received-%s-%s" % [owner, Time.get_ticks_usec()])
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return
		file.store_buffer(request.bytes)
		file.close()
		handle = await cache.import_file(path, "animation", func(_path): return true, false)
		cache._remove_file(path)
		if handle.is_empty() or not remote_states.has(owner) or remote_states[owner].get("hash") != request.hash:
			return
	else:
		parsed = reader.read_bytes(request.bytes)
	if parsed.is_empty():
		return
	assets[request.hash] = {"parsed": parsed, "handle": handle}
	_apply_remote(owner)

func _remove_remote(id: int):
	remote_tracking.erase(id)
	if tracking_nodes.has(id):
		var state: Dictionary = tracking_nodes[id]
		if is_instance_valid(state.modifier): state.modifier.queue_free()
		for node in state.nodes.values():
			if is_instance_valid(node): node.queue_free()
		tracking_nodes.erase(id)
	remote_states.erase(id)
	incoming.erase(id)
	model_incoming.erase(id)
	model_loading.erase(id)
	outgoing = outgoing.filter(func(item): return item.target != id)
	if is_instance_valid(remote_animators.get(id)):
		_dispose_animator(remote_animators[id])
	remote_animators.erase(id)
	# Parsed motions are live-session data, not an inventory of departed users.
	assets.clear()

func clear():
	for id in tracking_nodes.keys(): _remove_remote(id)
	remote_tracking.clear()
	for id in remote_states.keys():
		_remove_remote(id)
	remote_states.clear()
	incoming.clear()
	outgoing.clear()
	assets.clear()
	local_state.clear()
	local_handle.clear()
	local_model_handle.clear()
	model_incoming.clear()
	model_loading.clear()
	if is_instance_valid(local_animator):
		local_animator.stop()
	clock_ready = false
	clock_offset = 0
	published_sequence = -1
	active_emote = ""
	active_role = ""
	if is_instance_valid(wheel) and wheel.visible: wheel.dismiss()

func _exit_tree():
	clear()
	if is_instance_valid(wheel_layer): wheel_layer.queue_free()
	if is_instance_valid(xr_wheel): xr_wheel.queue_free()
	if transport != null and transport.animation_data.is_connected(receive):
		transport.animation_data.disconnect(receive)

func _update_tracking(delta: float):
	for id in remote_tracking.keys():
		var value: Dictionary = remote_tracking[id]
		if not _member(id) or Time.get_ticks_msec() - value.received > 1000:
			if tracking_nodes.has(id):
				if is_instance_valid(tracking_nodes[id].modifier):
					tracking_nodes[id].modifier.set_tracking_validity({"head": false, "leftHand": false, "rightHand": false})
					tracking_nodes[id].modifier.set_body_targets({})
			continue
		var remote = coordinator.get_node_or_null(str(id))
		if remote == null or not remote.get("avatar") is Node3D: continue
		var avatar: Node3D = remote.avatar
		if avatar.get_meta("asset_revision", "") != value.avatar_revision: continue
		if tracking_nodes.has(id) and (not is_instance_valid(tracking_nodes[id].avatar) or tracking_nodes[id].avatar != avatar):
			var old: Dictionary = tracking_nodes[id]
			if is_instance_valid(old.modifier): old.modifier.queue_free()
			for node in old.nodes.values():
				if is_instance_valid(node): node.queue_free()
			tracking_nodes.erase(id)
		if not tracking_nodes.has(id):
			var rig = Reader.new()._skeleton(avatar)
			if rig == null: continue
			var nodes: Dictionary = {}
			for role in ["head", "leftHand", "rightHand"]:
				var node = Node3D.new()
				remote.add_child(node)
				nodes[role] = node
			var modifier = preload("res://scripts/assets/avatar_tracking.gd").new()
			rig.add_child(modifier)
			modifier.configure(avatar.get_meta("humanoid_bones", {}), nodes.head, nodes.leftHand, nodes.rightHand)
			tracking_nodes[id] = {"avatar": avatar, "rig": rig, "nodes": nodes, "modifier": modifier, "initialized": false}
		var state: Dictionary = tracking_nodes[id]
		var validity: Dictionary = {}
		for role in state.nodes:
			validity[role] = value.decoded.has(role)
			if validity[role]:
				var node: Node3D = state.nodes[role]
				node.transform = node.transform.interpolate_with(value.decoded[role], minf(1, delta * 20)) if state.initialized else value.decoded[role]
		state.initialized = true
		state.modifier.set_tracking_validity(validity)
		var body: Dictionary = {}
		for role in ["hips", "leftFoot", "rightFoot"]:
			if value.decoded.has(role): body[role] = state.rig.global_transform.affine_inverse() * remote.global_transform * value.decoded[role]
		state.modifier.set_body_targets(body)
