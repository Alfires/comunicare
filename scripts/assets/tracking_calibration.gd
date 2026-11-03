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
	return true

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
