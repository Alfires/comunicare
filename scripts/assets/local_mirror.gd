extends Node3D
## Client-only planar reflection. No CollisionObject, item ID, RPC or relay state.
const MIRROR_LAYER = 1 << 17
var viewport: SubViewport
var reflection_camera: Camera3D
var source_camera: Camera3D
var panel: MeshInstance3D
var handle: MeshInstance3D
var dimensions := Vector2(1.0, 1.5)
var held_grip := ""
var anchor: Node3D
var grab_offset := Transform3D.IDENTITY
var notice: Label3D
var quality := "medium"
var settings: Node

func _ready():
	viewport = SubViewport.new()
	viewport.size = Vector2i(768, 768)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)
	viewport.world_3d = get_world_3d()
	reflection_camera = Camera3D.new()
	viewport.add_child(reflection_camera)
	reflection_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	reflection_camera.current = true
	reflection_camera.cull_mask = 0xfffff & ~MIRROR_LAYER & ~(1 << 18)
	panel = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = dimensions
	panel.mesh = quad
	panel.layers = MIRROR_LAYER
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader = Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform sampler2D reflection_texture : source_color; void fragment(){ ALBEDO = texture(reflection_texture, vec2(1.0-UV.x, UV.y)).rgb; }"
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("reflection_texture", viewport.get_texture())
	panel.material_override = material
	add_child(panel)
	handle = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	handle.mesh = sphere
	handle.layers = MIRROR_LAYER
	var grip_material = StandardMaterial3D.new()
	grip_material.albedo_color = Color("62b5e5")
	handle.material_override = grip_material
	add_child(handle)
	notice = Label3D.new()
	notice.text = "Local mirror · grab blue handle"
	notice.font_size = 24
	notice.pixel_size = 0.002
	notice.layers = MIRROR_LAYER
	add_child(notice)
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("store") != null:
		settings = save.store
		settings.setting_changed.connect(_setting_changed)
		for id in ["interface.mirror_quality", "interface.mirror_width", "interface.mirror_height"]:
			_setting_changed(id, settings.get_value(id))
	set_dimensions(dimensions)

func place_in_front(camera: Camera3D):
	if not is_instance_valid(camera): return
	source_camera = camera
	global_position = camera.global_position - camera.global_basis.z * 1.5
	look_at(camera.global_position, Vector3.UP, true)

func resize_by(factor: float):
	set_dimensions(dimensions * factor)

func set_dimensions(size: Vector2):
	if not size.is_finite(): return
	dimensions = Vector2(clampf(size.x, 0.4, 3.0), clampf(size.y, 0.6, 4.5))
	if panel == null: return
	panel.mesh.size = dimensions
	handle.position = Vector3(0, -dimensions.y * 0.5 - 0.1, 0.04)
	notice.position = Vector3(0, dimensions.y * 0.5 + 0.08, 0.03)
	_update_resolution()

func set_quality(value: String):
	quality = value if value in ["low", "medium", "high"] else "medium"
	_update_resolution()

func _update_resolution():
	if viewport == null: return
	var pixels = {"low": 384, "medium": 768, "high": 1536}[quality]
	var scale = float(pixels) / maxf(dimensions.x, dimensions.y)
	viewport.size = Vector2i(maxi(1, roundi(dimensions.x * scale)), maxi(1, roundi(dimensions.y * scale)))

func _setting_changed(id: String, value: Variant):
	if value == null: return
	if id == "interface.mirror_quality": set_quality(str(value))
	elif id == "interface.mirror_width": set_dimensions(Vector2(float(value), dimensions.y))
	elif id == "interface.mirror_height": set_dimensions(Vector2(dimensions.x, float(value)))

func _exit_tree():
	if is_instance_valid(settings) and settings.setting_changed.is_connected(_setting_changed): settings.setting_changed.disconnect(_setting_changed)

func try_grab(node: Node3D, grip: String, distance: float) -> bool:
	if not held_grip.is_empty() or not is_instance_valid(node) or node.global_position.distance_to(handle.global_position) > distance: return false
	anchor = node
	held_grip = grip
	grab_offset = node.global_transform.affine_inverse() * global_transform
	return true

func release(grip: String) -> bool:
	if held_grip != grip: return false
	held_grip = ""
	anchor = null
	return true

func _process(_delta):
	if not visible:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		release(held_grip)
		return
	if not held_grip.is_empty():
		if is_instance_valid(anchor): global_transform = anchor.global_transform * grab_offset
		else: release(held_grip)
	if not is_instance_valid(source_camera):
		source_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(source_camera): return
	var normal = global_basis.z.normalized()
	var eye = source_camera.global_position
	var distance = normal.dot(eye - global_position)
	if distance <= 0.02:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var reflected = eye - 2.0 * distance * normal
	reflection_camera.global_transform = Transform3D(global_basis.orthonormalized(), reflected)
	# Camera faces the plane from behind. Off-axis frustum follows the real eye,
	# producing planar parallax rather than a screen-space camera feed.
	reflection_camera.global_basis = Basis(-global_basis.x, global_basis.y, -normal).orthonormalized()
	var relative = reflection_camera.global_basis.inverse() * (global_position - reflected)
	var near_plane = distance + 0.005
	var scale = near_plane / distance
	reflection_camera.set_frustum(dimensions.y * scale, Vector2(relative.x, relative.y) * scale, near_plane, maxf(1000.0, source_camera.far))
	reflection_camera.environment = source_camera.environment

func _input(event: InputEvent):
	if not visible: return
	var save = get_node_or_null("/root/SaveData")
	if save != null and save.get("voice") != null and save.voice.input_blocked: release(held_grip); return
	if event.is_action_pressed("world_grab") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if held_grip == "virtual":
			release("virtual")
			get_viewport().set_input_as_handled()
		elif is_instance_valid(source_camera):
			var ray = -source_camera.global_basis.z
			var along = ray.dot(handle.global_position - source_camera.global_position)
			if along > 0 and along < 2.0 and (source_camera.global_position + ray * along).distance_to(handle.global_position) < 0.15:
				anchor = source_camera
				held_grip = "virtual"
				grab_offset = source_camera.global_transform.affine_inverse() * global_transform
				get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release(held_grip)
