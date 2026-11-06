extends RefCounted
## Declarative reviewed widgets only. No node classes, paths, URLs or callbacks.
const Data = preload("res://scripts/worlds/world_data.gd")
static func validate(value: Variant, entities: Array, capabilities: Array) -> Dictionary:
	if not value is Dictionary or not Data.bounded(value, 0, [4096]) or not Data.keys_only(value, ["version", "pages"]) or value.get("version") != 1 or not value.get("pages") is Dictionary or value.pages.size() > 16:
		return Data.failure("Invalid world UI document")
	var count := 0
	for id in value.pages:
		var page = value.pages[id]
		if id.is_empty() or id.length() > 64 or not page is Dictionary or not Data.keys_only(page, ["title", "widgets"]) or not page.get("title") is String or page.title.length() > 128 or not page.get("widgets") is Array: return Data.failure("Invalid UI page")
		var ids: Array = []
		for widget in page.widgets:
			count += 1
			if count > 128 or not widget is Dictionary or not Data.keys_only(widget, ["id", "type", "text", "bind", "enabled_bind", "max", "entity", "actions"]): return Data.failure("Invalid UI widget")
			if not widget.get("id") is String or widget.id.is_empty() or widget.id in ids: return Data.failure("Duplicate/missing UI widget ID")
			ids.append(widget.id)
			if widget.get("type") not in ["text", "button", "progress", "list"]: return Data.failure("Unsupported UI widget")
			for field in ["text", "bind", "enabled_bind"]:
				if widget.has(field) and (not widget[field] is String or widget[field].length() > (2048 if field == "text" else 64)): return Data.failure("Invalid widget text/binding")
			if widget.type == "progress" and not (Data.integer(widget.get("max", 100), 1, 1000000)): return Data.failure("Invalid progress maximum")
			if widget.type == "button":
				if widget.get("entity") not in entities: return Data.failure("UI action targets unknown entity")
				var checked = preload("res://scripts/worlds/world_script_vm.gd").new().run_event(widget.get("actions", []), {"entities": entities, "capabilities": capabilities})
				if not checked.ok: return checked
	return {"ok": true}
