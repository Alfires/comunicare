@tool
extends "res://addons/comunicare_world_tools/plugin.gd"
var failures := 0

func _enter_tree():
	super._enter_tree()
	call_deferred("_probe")

func _check(value: bool, label: String):
	print("PASS: " if value else "FAIL: ", label)
	if not value: failures += 1

func _probe():
	_new_world()
	selection = "floor"
	_refresh()
	# Raw JSON reordering followed by removal forces a different fallback index.
	document.entities.reverse()
	selection = "missing"
	_refresh()
	_check(str(entity_list.get_selected_metadata()) == selection, "fallback dropdown and inspector reference same entity")
	_new_world()
	selection = "floor"
	_refresh()
	while document.entities.size() < 256:
		var entity = document.entities[1].duplicate(true)
		entity.id = "entity-%s" % document.entities.size()
		document.entities.append(entity)
	_refresh()
	_add_entity("pickup")
	_check(selection == "floor", "rejected Add does not lose current selection")
	_new_world()
	selection = "floor"
	_refresh()
	_add_entity("pickup")
	_undo()
	var edited = document.duplicate(true)
	edited.title = "Manual branch"
	text.text = JSON.stringify(edited)
	_validate()
	_check(future.is_empty(), "manual JSON branch invalidates obsolete redo history")
	print("Plugin dock probe failures: ", failures)
	get_tree().quit(1 if failures else 0)
