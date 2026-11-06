extends "res://scripts/startup/data_loader.gd"

func _build_world_job(path: String, build: bool) -> Dictionary:
	OS.delay_msec(180)
	return {"ok": true, "worker": not Thread.is_main_thread(), "path": path}

func _build_avatar(bytes: PackedByteArray, path: String) -> Node3D:
	# Deterministic expensive import; production scheduling/join remains real.
	OS.delay_msec(180)
	var model = super._build_avatar(bytes, path)
	if model != null:
		model.set_meta("worker_thread", not Thread.is_main_thread())
	return model
