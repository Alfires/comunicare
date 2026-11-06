extends RefCounted
var path := ""
var account := ""
var avatar_hash := ""
var blocked := false
var last_error := ""

func configure(file_path: String, owner: String, revision: String):
	path = file_path
	account = owner
	avatar_hash = revision
	blocked = false
	last_error = ""
	if FileAccess.file_exists(path): load_calibration()

func _valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema") != 1: return false
	for field in ["eye_height", "scale"]:
		var value = data.get(field)
		if not (value is int or value is float) or not is_finite(value) or value < 0.1 or value > 4: return false
	for field in ["head_offset", "left_grip_offset", "right_grip_offset"]:
		var values = data.get(field)
		if not values is Array or values.size() != 3: return false
		for value in values:
			if not (value is int or value is float) or not is_finite(value) or absf(value) > 1: return false
		if Vector3(values[0], values[1], values[2]).length() > 1: return false
	var offsets = data.get("role_offsets", {})
	if not offsets is Dictionary or offsets.size() > 6: return false
	for role in offsets:
		if role not in ["head", "leftHand", "rightHand", "hips", "leftFoot", "rightFoot"] or not _valid_offset(offsets[role]): return false
	return true

func _valid_offset(values: Variant) -> bool:
	if not values is Array or values.size() != 7: return false
	for value in values:
		if not (value is int or value is float) or not is_finite(value) or absf(value) > 2: return false
	var q = Quaternion(values[3], values[4], values[5], values[6])
	return absf(q.length_squared() - 1) < 0.01 and Vector3(values[0], values[1], values[2]).length() <= 1

func capture_roles(samples: Dictionary, desired: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for role in desired:
		if role not in ["head", "leftHand", "rightHand", "hips", "leftFoot", "rightFoot"]: continue
		if not samples.get(role) is Transform3D or not desired[role] is Transform3D: continue
		if not samples[role].is_finite() or not desired[role].is_finite(): continue
		if absf(samples[role].basis.determinant()) < 0.000001 or absf(desired[role].basis.determinant()) < 0.000001: continue
		var offset: Transform3D = samples[role].affine_inverse() * desired[role]
		var q = offset.basis.orthonormalized().get_rotation_quaternion()
		var values = [offset.origin.x, offset.origin.y, offset.origin.z, q.x, q.y, q.z, q.w]
		if _valid_offset(values): result[role] = values
	return result

func calibrated_targets(samples: Dictionary, offsets: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for role in samples:
		if role not in ["head", "leftHand", "rightHand", "hips", "leftFoot", "rightFoot"]: continue
		if not samples[role] is Transform3D or not samples[role].is_finite(): continue
		if absf(samples[role].basis.determinant()) < 0.000001: continue
		if not offsets.has(role): continue # New assignments need explicit calibration.
		var v = offsets[role]
		if not _valid_offset(v): continue
		result[role] = samples[role] * Transform3D(Basis(Quaternion(v[3], v[4], v[5], v[6])), Vector3(v[0], v[1], v[2]))
	return result

func load_calibration() -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parser = JSON.new()
	if file == null or file.get_length() > 65536 or parser.parse(file.get_as_text()) != OK:
		blocked = true
		last_error = "Calibration unreadable; original preserved."
		return {}
	var value = parser.data
	if not value is Dictionary or value.get("account") != account or value.get("avatar_hash") != avatar_hash or not _valid(value.get("data")):
		blocked = true
		last_error = "Calibration incompatible or invalid; original preserved."
		return {}
	return value.data.duplicate(true)

func save_calibration(data: Dictionary) -> bool:
	if blocked or account.is_empty() or not _valid(data): return false
	if FileAccess.file_exists(path) and load_calibration().is_empty(): return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"account": account, "avatar_hash": avatar_hash, "data": data}))
	file.flush()
	var error = file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK
