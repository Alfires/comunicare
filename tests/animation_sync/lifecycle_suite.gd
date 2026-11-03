extends SceneTree

var failed := 0

class StartupPlayer extends Node:
	var network: Node
	var controller: Node
	func _enter_tree():
		# Production startup adds the player directly under root. Root is locked
		# while this callback runs; the controller factory must handle that.
		controller = network.get_animation_controller()

func _initialize():
	call_deferred("run")

func check(value: bool, title: String):
	print(("PASS: " if value else "FAIL: ") + title)
	if not value: failed += 1

func run():
	check(load("res://scripts/player/player_desktop_movment.gd") != null, "production desktop player script compiles against startup services")
	check(load("res://scripts/player/player_vr.gd") != null, "production VR player script compiles against startup services")
	var network = load("res://scripts/multiplayer/network_handler.gd").new()
	root.add_child(network)
	var player = StartupPlayer.new()
	player.network = network
	# Startup also requests the factory during root child-entry notifications,
	# while root is still changing its children.
	var on_enter = func(child):
		if child == player: player.controller = network.get_animation_controller()
	root.child_entered_tree.connect(on_enter)
	root.add_child(player)
	root.child_entered_tree.disconnect(on_enter)
	await process_frame
	var controller = network.get_animation_controller()
	check(controller == player.controller and controller.is_inside_tree(), "production startup factory returns one attached controller after root-ready lock")
	# The reported Home callback must work after startup, without a relay.
	if controller.is_inside_tree():
		controller.toggle_emote_menu()
		check(is_instance_valid(controller.wheel) and controller.wheel.visible, "production controller opens Home emote wheel offline")
		controller.toggle_emote_menu()
		check(not controller.wheel.visible, "Home callback toggles wheel closed")
	# Reproduce the reported state directly: the cached controller exists but
	# has no SceneTree (for example after failed/deferred startup attachment).
	controller.get_parent().remove_child(controller)
	controller.toggle_emote_menu()
	check(not controller.is_inside_tree(), "detached controller menu request is safely ignored")
	var recovered = network.get_animation_controller()
	await process_frame
	check(recovered.is_inside_tree(), "production factory repairs a detached cached controller")
	if recovered.is_inside_tree():
		recovered.toggle_emote_menu()
		check(recovered.wheel.visible, "Home menu opens after controller attachment recovery")
	# Home/player callbacks may occur in the frame an old controller is retiring.
	recovered.queue_free()
	var replacement = network.get_animation_controller()
	check(replacement != recovered and not replacement.is_queued_for_deletion(), "factory never returns a controller already queued for deletion")
	await process_frame
	check(is_instance_valid(network.animation_controller) and network.animation_controller.is_inside_tree(), "replacement survives old controller deferred cleanup")
	if is_instance_valid(replacement) and not replacement.is_queued_for_deletion():
		replacement.toggle_emote_menu()
		check(is_instance_valid(replacement.wheel) and replacement.wheel.visible, "Home callback works after retiring controller replacement")
		# A UI layer can be removed during teardown independently of the service.
		# Reopening must recreate both layer and wheel, not touch freed references.
		replacement.wheel_layer.queue_free()
		await process_frame
		replacement.toggle_emote_menu()
		check(is_instance_valid(replacement.wheel) and replacement.wheel.is_inside_tree() and replacement.wheel.visible,
			"Home callback recreates externally removed overlay and wheel")
		replacement.wheel.dismiss()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var initial_mode = Input.mouse_mode
		replacement.toggle_emote_menu()
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "opening wheel releases captured desktop mouse")
		replacement.wheel_layer.queue_free()
		await process_frame
		await process_frame
		check(Input.mouse_mode == initial_mode, "overlay teardown restores desktop capture without requiring Cancel")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		replacement.toggle_emote_menu()
		var removed_wheel = replacement.wheel
		removed_wheel.get_parent().remove_child(removed_wheel)
		check(not removed_wheel.input_owned, "detached wheel releases input ownership even without dismiss")
		removed_wheel.free()
	player.queue_free()
	if is_instance_valid(replacement): replacement.queue_free()
	network.queue_free()
	await process_frame
	print("Lifecycle failures: ", failed)
	quit(1 if failed else 0)
