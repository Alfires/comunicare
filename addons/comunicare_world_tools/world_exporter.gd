@tool
extends RefCounted

func export_package(document: Dictionary, path: String) -> Dictionary:
	var checked = preload("res://addons/comunicare_world_tools/authoring_document.gd").new().validate(document)
	if not checked.ok: return checked
	var manifest = {"format": "comunicare.world", "schema_version": 1, "world_id": document.world_id, "title": document.title, "release": "1.0.0", "requires": {"world_api": 1, "script_api": 1}, "main_scene": "scenes/world.tscn", "script_capabilities": document.capabilities}
	var scene = "[gd_scene format=3]\n"
	for i in document.entities.size():
		var entity = document.entities[i]
		if entity.type != "spawn":
			var size = "Vector3(%s, %s, %s)" % entity.collider.size
			scene += '[sub_resource type="BoxMesh" id="mesh%s"]\nsize = %s\n[sub_resource type="BoxShape3D" id="shape%s"]\nsize = %s\n' % [i, size, i, size]
	scene += '[node name="World" type="Node3D"]\n'
	var files: Dictionary = {"manifest.json": JSON.stringify(manifest)}
	for i in document.entities.size():
		var entity = document.entities[i]
		var type = "Marker3D" if entity.type == "spawn" else "RigidBody3D" if entity.type == "pickup" else "StaticBody3D"
		scene += '[node name="Entity%s" type="%s" parent="."]\nposition = Vector3(%s, %s, %s)\nmetadata/world_entity_id = %s\n' % [i, type, entity.position[0], entity.position[1], entity.position[2], JSON.stringify(entity.id)]
		if entity.type == "spawn": scene += "metadata/world_spawn = true\n"
		if entity.type == "pickup": scene += "metadata/world_pickup = true\n"
		var events: Dictionary = {}
		for behavior in document.behaviors:
			if behavior.entity == entity.id:
				if not events.has(behavior.event): events[behavior.event] = []
				events[behavior.event].append_array(behavior.actions)
		if not events.is_empty():
			var script_path = "logic/entity%s.worldscript" % i
			scene += "metadata/world_script = %s\n" % JSON.stringify(script_path)
			files[script_path] = JSON.stringify({"version": 1, "events": events})
		if entity.type != "spawn":
			scene += '[node name="Mesh" type="MeshInstance3D" parent="Entity%s"]\nmesh = SubResource("mesh%s")\n[node name="Collider" type="CollisionShape3D" parent="Entity%s"]\nshape = SubResource("shape%s")\n' % [i, i, i, i]
	files["scenes/world.tscn"] = scene
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return {"ok": false, "error": "Cannot create export directory"}
	var temporary = path + ".tmp"
	var zip = ZIPPacker.new()
	if zip.open(temporary) != OK: return {"ok": false, "error": "Cannot open export"}
	for name in files:
		if zip.start_file(name) != OK or zip.write_file(files[name].to_utf8_buffer()) != OK or zip.close_file() != OK:
			zip.close()
			return {"ok": false, "error": "Cannot write package"}
	zip.close()
	checked = preload("res://scripts/worlds/world_builder.gd").new().build_package(temporary)
	if not checked.ok:
		DirAccess.remove_absolute(temporary)
		return checked
	if DirAccess.rename_absolute(temporary, path) != OK: return {"ok": false, "error": "Cannot commit export"}
	return {"ok": true, "path": path, "revision": checked.revision}
