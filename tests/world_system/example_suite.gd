extends SceneTree
## Actual checked-in author project → manual ZIP → production world components.
const Builder = preload("res://scripts/worlds/world_builder.gd")
const Runtime = preload("res://scripts/worlds/world_runtime.gd")
const Pickups = preload("res://scripts/worlds/world_pickup_controller.gd")
var passed := 0
var failed := 0

class PeerFixture extends RefCounted:
	signal world_data(value: Dictionary)
	var world_supported := true
	var world_peer_id := 1
	var current_session_id := "example-instance"
	var sent: Array = []
	func send_world(value: Dictionary): sent.append(value.duplicate(true))

class NetworkFixture extends Node:
	var peer = PeerFixture.new()
	var current_session_id := "example-instance"

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func run():
	var built = Builder.new().build_package("res://packages/simple-world.cworld")
	check(built.ok, "actual example Godot project package passes production builder")
	if not built.ok:
		print(built.error)
		finish()
		return
	check(built.revision == FileAccess.get_sha256("res://packages/simple-world.cworld"), "example revision pins complete packaged bytes")
	check(built.spawn_point == [0.0, 1.0, 2.0], "example spawn survives package loading")
	var world = built.scene.instantiate()
	root.add_child(world)
	var cube = world.get_node("PickupCube")
	check(cube is RigidBody3D and cube.get_meta("world_pickup", false), "example cube is a real pickup-enabled rigid body")
	var material = world.get_node("Floor/Mesh").mesh.material
	check(material is StandardMaterial3D and material.albedo_texture.get_width() == 16, "example floor decodes checked-in checkerboard texture")
	check(material.uv1_scale.is_equal_approx(Vector3(6, 6, 1)), "example checkerboard floor preserves UV repeat")
	check(world.get_node("Sun") is DirectionalLight3D, "example lighting reconstructs from native node data")
	var runtime = Runtime.new()
	world.add_child(runtime)
	check(runtime.configure(world, built.document).ok, "example script resolves scene entity bindings")
	check(not world.get_node("Beacon").visible, "example source beacon is initially hidden")
	check(runtime.dispatch("start", "").ok and world.get_node("Beacon").visible, "example restricted start event makes beacon visible")
	check(runtime.dispatch("use", "beacon").ok and not world.get_node("Beacon").visible, "example restricted use event hides beacon")
	# Drive actual physics, not only presence of CollisionShape nodes.
	for frame in 90: await physics_frame
	check(cube.global_position.y > 0.1 and cube.global_position.y < 0.22, "example floor collision catches falling pickup cube")
	var ray = PhysicsRayQueryParameters3D.create(Vector3(2, 2, 2), Vector3(2, -1, 2))
	var hit = world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == world.get_node("Floor"), "example floor participates in real physics ray queries")
	var network = NetworkFixture.new()
	var loader = Node.new()
	var adapter = Pickups.new()
	adapter.configure(network, loader)
	adapter.activate(world, built.document, built.revision)
	var hand = Node3D.new()
	world.add_child(hand)
	hand.position = cube.position + Vector3(0, 0.1, 0)
	check(adapter.request_grab("pickup-cube", "virtual", hand), "example desktop virtual hand requests nearby cube")
	var accepted = {"op": "item", "session_id": "example-instance", "revision": built.revision, "entity": "pickup-cube", "holder": 1, "generation": "local", "grip": "virtual", "epoch": 1, "sequence": 1, "position": [], "rotation": []}
	adapter.receive(accepted)
	hand.position = Vector3(0.5, 1.2, 1)
	adapter._process(0.05)
	check(cube.freeze and cube.global_position.is_equal_approx(hand.global_position), "loaded example cube follows acknowledged local grip")
	check(network.peer.sent.back().op == "pose", "example held cube publishes network pose intent")
	var remote = accepted.duplicate(true)
	remote.holder = 2
	remote.generation = "remote"
	remote.grip = "left"
	remote.sequence = 2
	remote.position = [-1.0, 1.5, 0.0]
	remote.rotation = [0.0, 0.0, 0.0, 1.0]
	adapter.receive(remote)
	adapter._process(0.05)
	check(cube.global_position.is_equal_approx(Vector3(-1, 1.5, 0)), "loaded example cube moves to remote VR held pose")
	adapter.reset()
	check(not cube.freeze and cube.collision_layer == 1, "example reset restores original rigidbody collision/freeze state")
	runtime.stop_scripts()
	check(not runtime.dispatch("start", "").ok, "trusted script stop disables example callbacks")
	adapter.free()
	network.free()
	loader.free()
	world.free()
	finish()

func finish():
	print("\nExample world: %s passed, %s failed" % [passed, failed])
	print("Pickup acknowledgements are synthetic here; real relay transport is tested separately by animation_sync.")
	quit(1 if failed else 0)
