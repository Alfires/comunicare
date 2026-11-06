extends RefCounted
## Byte limits are separate from animation/rig compatibility and GPU memory use.
const MIB = 1024 * 1024
const MAX_BYTES = 1024 * MIB
static var approved: Dictionary = {}
static var pending: Dictionary = {}

static func store_for(host: Node):
	var save = host.get_node_or_null("/root/SaveData")
	return save.get("store") if save != null else null

static func file_size(path: String) -> int:
	var file = FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else 0

static func file_identity(path: String) -> String:
	return FileAccess.get_sha256(path)

static func buffer_identity(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func limits(store = null) -> Dictionary:
	var hard := 1024.0
	var warning := 256.0
	if store != null:
		var configured = store.get_value("assets.avatar_limit_mib")
		if configured is float or configured is int:
			if is_finite(configured): hard = clampf(configured, 64, 1024)
		configured = store.get_value("assets.avatar_warning_mib")
		if configured is float or configured is int:
			if is_finite(configured): warning = clampf(configured, 32, 1024)
	return {"hard": int(hard * MIB), "warning": int(minf(warning, hard) * MIB)}

static func classify(size: int, store = null) -> String:
	var budget = limits(store)
	if size <= 0: return "invalid"
	if size > budget.hard: return "blocked"
	return "warn" if size > budget.warning else "allow"

static func confirm(host: Node, size: int, identity: String = "") -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree(): return false
	var store = store_for(host)
	var state = classify(size, store)
	if state == "allow": return true
	if state != "warn": return false
	var key = "%s:%s:%s" % [identity, size, limits(store).warning]
	if not identity.is_empty() and approved.has(key): return true
	# Headless/server jobs cannot obtain informed confirmation: fail closed.
	if DisplayServer.get_name() == "headless": return false
	var tree = host.get_tree()
	if pending.has(key):
		var existing: Dictionary = pending[key]
		while not existing.done: await tree.process_frame
		return existing.accepted and is_instance_valid(host) and host.is_inside_tree() and classify(size, store_for(host)) in ["allow", "warn"]
	var dialog = ConfirmationDialog.new()
	dialog.title = "Large avatar"
	dialog.dialog_text = "This avatar is %.1f MiB. Loading it may take time and use much more RAM/VRAM than the file size. Continue?" % (float(size) / MIB)
	dialog.ok_button_text = "Load avatar"
	var decision = {"done": false, "accepted": false}
	pending[key] = decision
	dialog.confirmed.connect(func(): decision.accepted = true; decision.done = true)
	dialog.canceled.connect(func(): decision.done = true)
	dialog.close_requested.connect(func(): decision.done = true)
	dialog.tree_exiting.connect(func(): decision.done = true)
	host.add_child(dialog)
	dialog.popup_centered(Vector2i(440, 180))
	while not decision.done: await tree.process_frame
	if is_instance_valid(dialog): dialog.queue_free()
	pending.erase(key)
	if decision.accepted and not identity.is_empty():
		if approved.size() >= 128: approved.erase(approved.keys()[0])
		approved[key] = true
	return decision.accepted and is_instance_valid(host) and host.is_inside_tree() and classify(size, store_for(host)) in ["allow", "warn"]
