extends Node
func _ready(): call_deferred("run")
func run():
	var contract = load("res://scripts/worlds/welcome_island/home_contract.gd")
	var expected = OS.get_environment("ISLAND_EXPECTED_REVISION")
	var revision = contract.revision()
	var ok = revision.length() == 64 and revision == expected
	var world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	ok = ok and world.get_node_or_null("Island") != null
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Exported pack home: ", "PASS" if ok else "FAIL", " revision=", revision)
	get_tree().quit(0 if ok else 1)
