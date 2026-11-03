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
var full_body_vr := false
var automatic_motion := true
var locomotion_elapsed := 0.0

func configure(network: Node, data_loader: Node):
	coordinator = network
	loader = data_loader

func _process(delta: float):
	if coordinator == null:
		return
	locomotion_elapsed += delta
	if automatic_motion and locomotion_elapsed >= 0.2:
		locomotion_elapsed = 0
		_update_locomotion()
	if transport != coordinator.peer:
		if transport != null and transport.animation_data.is_connected(receive):
			transport.animation_data.disconnect(receive)
		clear()
		transport = coordinator.peer
		if transport != null:
			transport.animation_data.connect(receive)
	if transport == null or not transport.animation_supported:
		return
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
	if not local_state.is_empty():
		var model = _local_model()
		if model != null and (not is_instance_valid(local_animator) or local_animator.avatar != model):
			local_animator = _new_animator(model)
			local_animator.play_clip(local_clip, local_state.loop, local_state.speed, AnimationState.playhead(local_state, now()))
			local_animator.set_paused(local_state.action != "play")

func now() -> float:
	return Time.get_ticks_msec() + clock_offset

func _update_locomotion():
	for player in get_tree().get_nodes_in_group("player"):
		# Full-body locomotion never overrides live XR tracking automatically.
		if player.get("avatar_model") is Node3D and player is CharacterBody3D:
			var motion = "idle"
			if not player.is_on_floor():
				motion = "jump" if player.velocity.y > 0 else "fall"
			elif Vector2(player.velocity.x, player.velocity.z).length() > 0.1:
				motion = "run" if Vector2(player.velocity.x, player.velocity.z).length() > 4 else "walk"
			if local_state.get("builtin") != motion:
				play(Defaults.clip(motion), motion, {}, 0, true, 1.0, true, false)
			return

func _send(value: Dictionary):
	if transport != null and transport.animation_supported and not coordinator.session_busy \
		and not coordinator.current_session_id.is_empty():
		value.session_id = coordinator.current_session_id
		transport.send_animation(value)

func _local_model() -> Node3D:
	for player in get_tree().get_nodes_in_group("player"):
		if player.get("vrm_model") is Node3D:
			return player.vrm_model if full_body_vr else null
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

func play(clip: Dictionary, builtin: String, handle: Dictionary, clip_index: int,
		looping: bool, speed: float, share: bool, vr_allowed: bool) -> bool:
	full_body_vr = vr_allowed
	var model = _local_model()
	if model == null:
		last_error = "No compatible avatar loaded, or full-body VR playback is not enabled."
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
		stop()
	if not local_animator.play_clip(clip, looping, speed):
		last_error = local_animator.last_error
		return false
	local_clip = clip
	local_handle = handle if share else {}
	sequence += 1
	local_state = {"op": "state", "version": 1, "sequence": sequence, "action": "play",
		"loop": looping, "speed": speed, "offset": 0.0, "duration": clip.duration,
		"builtin": builtin, "library": "comunicare.procedural.v1", "hash": "", "started": now()}
	if builtin.is_empty() and share and not handle.is_empty():
		local_state.hash = handle.hash
		local_state.size = FileAccess.open(handle.path, FileAccess.READ).get_length()
		local_state.clip = clip_index
	if not builtin.is_empty() or share:
		_send(local_state.duplicate())
	last_error = "Playing locally" if transport == null or not transport.animation_supported or (builtin.is_empty() and not share) else "Playing and sharing with compatible instance players"
	changed.emit()
	return true

func pause(paused: bool):
	if local_state.is_empty():
		return
	local_state.offset = AnimationState.playhead(local_state, now())
	local_state.action = "pause" if paused else "play"
	local_state.started = now()
	sequence += 1
	local_state.sequence = sequence
	if is_instance_valid(local_animator):
		local_animator.set_paused(paused)
	_send(local_state.duplicate())

func stop():
	if not local_state.is_empty():
		sequence += 1
		local_state.sequence = sequence
		local_state.action = "stop"
		_send(local_state.duplicate())
	local_state.clear()
	local_handle.clear()
	local_clip.clear()
	outgoing.clear()
	if is_instance_valid(local_animator):
		local_animator.stop()
	changed.emit()

func receive(value: Dictionary):
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
			if previous.get("generation") == value.generation and previous.get("sequence", 0) > value.sequence:
				return
			if previous.get("hash") != value.get("hash") or previous.get("generation") != value.generation:
				incoming.erase(id)
				if not previous.get("hash", "").is_empty():
					assets.erase(previous.hash)
			remote_states[id] = value.duplicate(true)
			_apply_remote(id)
		"request":
			if not local_handle.is_empty() and value.get("hash") == local_handle.get("hash") \
				and AnimationState.integer(value.get("requester"), 0, 255) and _member(int(value.requester)) and outgoing.size() < 4:
				for request in outgoing:
					if request.target == int(value.requester):
						return
				outgoing.append({"target": int(value.requester), "hash": value.hash, "offset": 0})
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
	if value.action == "stop":
		if is_instance_valid(remote_animators.get(id)):
			remote_animators[id].stop()
		return
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
	if not animator.play_clip(clip, value.loop, value.speed, position):
		last_error = animator.last_error
		return
	animator.set_paused(value.action == "pause")
	animator.descriptor = {"generation": value.generation, "sequence": value.sequence}

func _send_chunk():
	var request: Dictionary = outgoing.pop_front()
	if not _member(request.target) or local_handle.is_empty() or request.hash != local_handle.hash:
		return
	var file = FileAccess.open(local_handle.path, FileAccess.READ)
	if file == null:
		return
	file.seek(request.offset)
	var bytes = file.get_buffer(AnimationState.CHUNK_BYTES)
	if bytes.is_empty():
		return
	_send({"op": "chunk", "target": request.target, "hash": request.hash,
		"offset": request.offset, "bytes": Marshalls.raw_to_base64(bytes)})
	request.offset += bytes.size()
	if request.offset < file.get_length():
		outgoing.append(request)

func _receive_chunk(value: Dictionary):
	if not AnimationState.integer(value.get("owner"), 0, 255) or not value.get("bytes") is String or value.bytes.length() > 10924:
		return
	var owner = int(value.owner)
	if not incoming.has(owner) or not _member(owner):
		return
	var request: Dictionary = incoming[owner]
	if value.get("hash") != request.hash or value.get("offset") != request.bytes.size():
		return
	var bytes = Marshalls.base64_to_raw(value.bytes)
	if bytes.is_empty() or bytes.size() > AnimationState.CHUNK_BYTES or request.bytes.size() + bytes.size() > request.size:
		incoming.erase(owner)
		return
	request.bytes.append_array(bytes)
	if request.bytes.size() != request.size:
		return
	incoming.erase(owner)
	var digest = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(request.bytes)
	if digest.finish().hex_encode() != request.hash:
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
	remote_states.erase(id)
	incoming.erase(id)
	outgoing = outgoing.filter(func(item): return item.target != id)
	if is_instance_valid(remote_animators.get(id)):
		_dispose_animator(remote_animators[id])
	remote_animators.erase(id)
	# Parsed motions are live-session data, not an inventory of departed users.
	assets.clear()

func clear():
	for id in remote_states.keys():
		_remove_remote(id)
	remote_states.clear()
	incoming.clear()
	outgoing.clear()
	assets.clear()
	local_state.clear()
	local_handle.clear()
	if is_instance_valid(local_animator):
		local_animator.stop()
	clock_ready = false
	clock_offset = 0
	automatic_motion = true

func _exit_tree():
	clear()
	if transport != null and transport.animation_data.is_connected(receive):
		transport.animation_data.disconnect(receive)
