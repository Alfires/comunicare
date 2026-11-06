extends RefCounted
## Full-scene assertions opt in; entry tests must never use this helper.
static func complete(world: Node):
	var island = world.get_node("Island")
	island.streaming.load_all = true
	var deadline = Time.get_ticks_msec() + 30000
	while (not island.streaming.jobs.is_empty() or not island.home_loaded) and Time.get_ticks_msec() < deadline:
		await world.get_tree().process_frame
	assert(island.home_loaded and island.streaming.jobs.is_empty(), "streaming completion deadline")
	await world.get_tree().physics_frame
	await world.get_tree().physics_frame
