extends Node3D
## Stable world-space wheel. No camera/root motion or per-frame reparenting.

var wheel: Control
var viewport: SubViewport
var hand: XRController3D
var camera: XRCamera3D
var holding := false
var needs_rearm := false
var previous_pressed := false
var previous_trigger := false
var action := "by_button"
var previous_sector := -1
var diameter := 0.42

func open(controller: XRController3D, view: XRCamera3D, layout, catalog: Dictionary, hold: bool):
	hand = controller
	camera = view
	holding = hold
	previous_pressed = hold
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("store") != null:
		action = str(save.store.get_value("input.xr_emote_action"))
		diameter = float(save.store.get_value("interface.emote_wheel_size"))
	viewport = SubViewport.new()
	viewport.size = Vector2i(768, 768)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	wheel = preload("res://scripts/GUI/emote_wheel.gd").new()
	viewport.add_child(wheel)
	wheel.open(layout, catalog, false)
	wheel.closed.connect(queue_free)
	wheel.navigated.connect(func(): needs_rearm = true)
	var mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE * diameter
	mesh.mesh = quad
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = viewport.get_texture()
	mesh.material_override = material
	add_child(mesh)
	global_position = hand.global_position - camera.global_basis.z * 0.18
	look_at(camera.global_position, Vector3.UP, true)
	add_to_group("emote_wheel_input")
	set_meta("hand", hand)

func _process(_delta: float):
	if not is_instance_valid(hand) or not hand.get_is_active() or not is_instance_valid(camera):
		queue_free()
		return
	var local = global_transform.affine_inverse() * hand.global_position
	var direction = Vector2(local.x, -local.y) / (diameter * 0.5)
	if not holding:
		var origin = hand.global_position
		var ray = -hand.global_basis.z
		var hit = Plane(global_basis.z, global_position).intersects_ray(origin, ray)
		if hit != null:
			local = global_transform.affine_inverse() * hit
			direction = Vector2(local.x, -local.y) / (diameter * 0.5)
	wheel.select_direction(direction)
	if wheel.hovered != previous_sector:
		previous_sector = wheel.hovered
		var save = get_node_or_null("/root/SaveData")
		if previous_sector >= 0 and save != null and save.get("store") != null and save.store.get_value("interface.emote_haptics"):
			hand.trigger_haptic_pulse("haptic", 0, 0.12, 0.02, 0)
	if needs_rearm and direction.length() < wheel.inner:
		needs_rearm = false
	var pressed = hand.is_button_pressed(action)
	var trigger = hand.is_button_pressed("trigger_click")
	if wheel.size_popup:
		holding = false
		if trigger and not previous_trigger: wheel.size_pointer(true)
		elif not trigger and previous_trigger: wheel.size_pointer(false)
		if pressed and not previous_pressed: wheel.back()
		previous_pressed = pressed
		previous_trigger = trigger
		return
	if not holding and pressed and not previous_pressed:
		wheel.back()
		previous_pressed = pressed
		previous_trigger = trigger
		return
	if holding and previous_pressed and not pressed:
		if needs_rearm: holding = false
		elif wheel.hovered < 0: wheel.back()
		else:
			wheel.activate_sector(wheel.hovered)
			if wheel.visible:
				holding = false
				needs_rearm = false # Next trigger press is a fresh confirmation.
	elif not holding and trigger and not previous_trigger:
		if not needs_rearm:
			if wheel.hovered < 0: wheel.back()
			else: wheel.activate_sector(wheel.hovered)
	previous_pressed = pressed
	previous_trigger = trigger

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		queue_free()
