extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var contract = load("res://scripts/worlds/welcome_island/home_contract.gd")
	var expected = OS.get_environment("ISLAND_EXPECTED_REVISION")
	var revision = contract.revision()
	var ok = revision.length() == 64 and revision == expected
	change_scene_to_file("res://scenes/world.tscn")
	await process_frame
	await process_frame
	ok = ok and current_scene != null and current_scene.get_node_or_null("Island") != null
	current_scene.queue_free()
	await process_frame
	await process_frame
	print("Exported pack home: ", "PASS" if ok else "FAIL", " revision=", revision)
	quit(0 if ok else 1)
