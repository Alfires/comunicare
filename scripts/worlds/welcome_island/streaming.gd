extends Node
## Main-thread scene work; bounded threaded I/O. No worker touches the SceneTree.
const MAX_REQUESTS = 1
const RANGE = 38.0
var jobs: Array[Dictionary] = []
var resources: Dictionary = {}
var pending: Dictionary = {}
var failed: Dictionary = {}
var load_all := false
var completed := 0
var last_attachment_usec := 0

func _exit_tree():
	# Drop bound callbacks before scene owners disappear; loader tasks themselves
	# are engine-owned and cannot be cancelled, but cannot attach late nodes.
	jobs.clear()
	resources.clear()

func enqueue(point: Vector3, paths: Array, attach: Callable):
	jobs.append({"point": point, "paths": paths, "attach": attach})

func _process(_delta):
	if is_queued_for_deletion() or get_parent().is_queued_for_deletion(): return
	for path in pending.keys():
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			resources[path] = ResourceLoader.load_threaded_get(path)
			pending.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			failed[path] = true; pending.erase(path)
	var point = Vector3.ZERO
	for player in get_tree().get_nodes_in_group("player"):
		if player is Node3D: point = player.global_position; break
	jobs.sort_custom(func(a, b): return a.point.distance_squared_to(point) < b.point.distance_squared_to(point))
	for job in jobs:
		if not load_all and job.point.distance_to(point) > RANGE: continue
		var ready := true
		var broken := false
		for path in job.paths:
			if failed.has(path): broken = true
			if resources.has(path): continue
			ready = false
			if not pending.has(path) and not failed.has(path) and pending.size() < MAX_REQUESTS:
				if ResourceLoader.load_threaded_request(path) == OK: pending[path] = true
				else: failed[path] = true
		if broken:
			jobs.erase(job)
			push_warning("Home streaming skipped failed asset job at " + str(job.point))
			return
		if not ready: continue
		jobs.erase(job)
		var start = Time.get_ticks_usec()
		job.attach.call()
		last_attachment_usec = Time.get_ticks_usec() - start
		completed += 1
		# One attachment per frame; never drain a ready queue in one frame.
		return
