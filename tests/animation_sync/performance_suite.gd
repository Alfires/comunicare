extends SceneTree
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ", title)
	if not ok: failed += 1
func run():
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
