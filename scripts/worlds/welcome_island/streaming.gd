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
var last_job := ""
var priority_dirty := true
var priority_point := Vector3.INF
var material_thread: Thread
var material_path := ""
var surface_variants: Array[Material] = []

func _exit_tree():
	if material_thread != null: material_thread.wait_to_finish()
	# Drop bound callbacks before scene owners disappear; loader tasks themselves
	# are engine-owned and cannot be cancelled, but cannot attach late nodes.
	jobs.clear()
	resources.clear()
	surface_variants.clear()

func enqueue(point: Vector3, paths: Array, attach: Callable):
	jobs.append({"point": point, "paths": paths, "attach": attach})
	priority_dirty = true

func _process(_delta):
	if is_queued_for_deletion() or get_parent().is_queued_for_deletion(): return
	if material_thread != null and not material_thread.is_alive():
		resources[material_path] = material_thread.wait_to_finish()
		pending.erase(material_path)
		material_thread = null
	for path in pending.keys():
		if material_thread != null and path == material_path: continue
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource = ResourceLoader.load_threaded_get(path)
			material_path = path
			material_thread = Thread.new()
			var error = material_thread.start(_prepare_materials.bind(resource), Thread.PRIORITY_LOW)
			if error != OK:
				material_thread = null
				failed[path] = true; pending.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			failed[path] = true; pending.erase(path)
	var point = Vector3.ZERO
	for player in get_tree().get_nodes_in_group("player"):
		if player is Node3D: point = player.global_position; break
	if priority_dirty or point.distance_squared_to(priority_point) > 0.25:
		jobs.sort_custom(func(a, b): return a.point.distance_squared_to(point) < b.point.distance_squared_to(point))
		priority_point = point
		priority_dirty = false
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
		last_job = str(job.attach)
		job.attach.call()
		last_attachment_usec = Time.get_ticks_usec() - start
		completed += 1
		# One attachment per frame; never drain a ready queue in one frame.
		return

func _prepare_materials(resource: Resource) -> Resource:
	if resource is Texture2D and surface_variants.is_empty():
		# Match layout/house/boat runtime flags before any resource is published.
		# Retain these immutable variants so the shader cache stays alive.
		for variant in 4:
			var material = StandardMaterial3D.new()
			material.albedo_texture = resource
			material.normal_enabled = true; material.normal_texture = resource
			material.uv1_triplanar = true
			material.uv1_world_triplanar = variant != 3
			if variant < 2:
				material.roughness_texture = resource
				material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.get_rid()
			_warm_pipeline(material)
			surface_variants.append(material)
	var seen := {}
	_visit_materials(resource, seen)
	return resource

func _visit_materials(resource: Resource, seen: Dictionary):
	if resource == null or seen.has(resource.get_instance_id()): return
	seen[resource.get_instance_id()] = true
	if resource is Shader:
		resource.get_shader_uniform_list()
		var prepared = ShaderMaterial.new()
		prepared.shader = resource
		prepared.get_rid()
		_warm_pipeline(prepared)
	if resource is Material:
		resource.get_rid()
		_warm_pipeline(resource)
	if resource is PackedScene:
		var state = resource.get_state()
		for node in state.get_node_count():
			for property in state.get_node_property_count(node):
				var value = state.get_node_property_value(node, property)
				if value is Resource: _visit_materials(value, seen)
	elif resource is Mesh:
		for surface in resource.get_surface_count(): _visit_materials(resource.surface_get_material(surface), seen)

func _warm_pipeline(material: Material):
	# Creating a mesh with its material already on the surface invokes Godot's
	# load-time pipeline preparation on this worker, rather than the first draw.
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1,0,0,1, 1,0,0,1, 1,0,0,1])
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	surface["material"] = material.get_rid()
	var prepared = RenderingServer.mesh_create_from_surfaces([surface])
	RenderingServer.free_rid(prepared)
