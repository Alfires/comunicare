extends SceneTree
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ", title)
	if not ok: failed += 1
func run():
	benchmark_animation_binding()
	benchmark_first_person_import()
	var placeholder = load("res://scripts/assets/avatar_placeholder.gd").new()
	root.add_child(placeholder)
	placeholder.hide()
	placeholder._process(1.0)
	check(placeholder.elapsed == 0, "hidden avatar placeholders do no loading animation work")
	placeholder.show()
	placeholder._process(0.01)
	var text = placeholder.indicator.text
	placeholder._process(0.01)
	check(placeholder.indicator.text == text, "loading indicator remains stable between three-Hz animation steps")
	var source = MeshInstance3D.new()
	var target = MeshInstance3D.new()
	root.add_child(source)
	root.add_child(target)
	var sync = load("res://scripts/assets/first_person_avatar.gd").BlendShapeSync.new()
	root.add_child(sync)
	sync.source = source
	sync.target = target
	target.hide()
	source.position.x = 2
	sync._process(0.016)
	check(target.position.x == 0, "hidden first-person derivatives skip per-frame synchronization")
	target.show()
	target.set_meta("first_person_active", true)
	sync._process(0.016)
	check(target.position.x == 2, "visible first-person derivatives immediately catch up")
	placeholder.free()
	sync.free()
	source.free()
	target.free()
	print("Performance workload failures: ", failed)
	quit(1 if failed else 0)

func benchmark_animation_binding():
	var avatar = Node3D.new()
	var rig = Skeleton3D.new()
	rig.name = "Rig"
	avatar.add_child(rig)
	rig.add_bone("Head")
	var rest = Quaternion(Vector3.RIGHT, 0.4)
	rig.set_bone_rest(0, Transform3D(Basis(rest), Vector3.ZERO))
	avatar.set_meta("humanoid_bones", {"head": "Head"})
	var source_rest = Quaternion(Vector3.UP, 0.7)
	var rotation = Quaternion(Vector3.FORWARD, 0.2)
	var keys: Array = []
	for index in 10000: keys.append({"time": index / 1000.0, "rotation": rotation})
	var clip = {"duration": 10.0, "tracks": [{"bone": "head", "source_rest": source_rest, "keys": keys}]}
	var reader = load("res://scripts/assets/humanoid_animation.gd").new()
	var animation: Animation
	var timings: Array[int] = []
	for sample in 21:
		var start = Time.get_ticks_usec()
		animation = reader.bind_clip(clip, avatar)
		if sample > 0: timings.append(Time.get_ticks_usec() - start)
	timings.sort()
	print("BENCH: median retarget 10000 rotation keys (20 samples): ", timings[10], " us")
	var conversion = rest.inverse() * source_rest
	var expected = rest * conversion * rotation * conversion.inverse()
	check(animation != null and animation.track_get_key_count(0) == 10000, "large animation binding retains all rotation samples")
	if animation != null:
		check(animation.track_get_key_value(0, 9999).is_equal_approx(expected), "retargeted samples retain exact rest-axis conversion")
	check(keys[0].rotation == rotation, "binding leaves source key data unchanged")
	avatar.free()

func benchmark_first_person_import():
	var avatar = Node3D.new()
	var rig = Skeleton3D.new()
	avatar.add_child(rig)
	for bone in 64: rig.add_bone("Bone" + str(bone))
	avatar.set_meta("humanoid_bones", {"head": "Bone63"})
	var skin = Skin.new()
	for bone in 64:
		skin.add_bind(bone, Transform3D.IDENTITY)
		skin.set_bind_name(bone, "Bone" + str(bone))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices = PackedVector3Array()
	var bones = PackedInt32Array()
	var weights = PackedFloat32Array()
	for vertex in 30000:
		vertices.append(Vector3(vertex % 3, (vertex / 3) % 2, 0))
		bones.append_array(PackedInt32Array([63 if vertex >= 15000 else 0, 1, 2, 3]))
		weights.append_array(PackedFloat32Array([0.7, 0.1, 0.1, 0.1]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance = MeshInstance3D.new()
	instance.name = "Body"
	instance.mesh = mesh
	instance.skin = skin
	rig.add_child(instance)
	var start = Time.get_ticks_usec()
	var prepared = load("res://scripts/assets/first_person_avatar.gd").prepare(avatar, {}, {mesh: {"arrays": [arrays], "blends": [[]]}})
	print("BENCH: first-person preparation, 30000 vertices / 120000 influences: ", Time.get_ticks_usec() - start, " us")
	var view = rig.get_node_or_null("Body_FirstPerson")
	check(prepared and view != null and view.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 15000, "large named-bind mesh preserves body triangles while filtering head triangles")
	avatar.free()
