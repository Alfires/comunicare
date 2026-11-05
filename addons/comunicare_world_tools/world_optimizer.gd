@tool
extends RefCounted
func analyze(document: Dictionary) -> Dictionary:
	var checked = preload("res://addons/comunicare_world_tools/authoring_document.gd").new().validate(document)
	if not checked.ok: return checked
	var pickups := 0
	for entity in document.entities:
		if entity.type == "pickup": pickups += 1
	return {"ok": true, "entities": document.entities.size(), "dynamic_bodies": pickups, "recommendations": ["Keep dynamic pickups separate from static scenery", "Consider sharing identical primitive resources in a future export optimization pass"], "measured_fps": null}

func optimize(document: Dictionary, options: Dictionary) -> Dictionary:
	if options.get("preset") not in ["balanced", "quality"]: return {"ok": false, "error": "Unknown preset"}
	var report = analyze(document)
	if not report.ok: return report
	# Canonical ordering is lossless; never merge independently interactive entities.
	var copy = document.duplicate(true)
	copy.entities.sort_custom(func(a, b): return a.id < b.id)
	return {"ok": true, "document": copy, "report": report, "notice": "Lossless ordering only; no visual simplification or FPS guarantee"}
