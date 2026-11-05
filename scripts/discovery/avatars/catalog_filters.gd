extends RefCounted

func apply(records: Array, query: Dictionary) -> Array:
	var result: Array = []
	for record in records:
		if not record is Dictionary: continue
		if query.get("type", "all") != "all" and record.get("type") != query.type: continue
		if query.get("format", "all") != "all" and record.get("format") != query.format: continue
		var term = str(query.get("query", "")).strip_edges().to_lower()
		var text = (str(record.get("title", "")) + " " + str(record.get("author", "")) + " " + str(record.get("tags", []))).to_lower()
		if not term.is_empty() and not term in text: continue
		var tag = str(query.get("tag", "")).strip_edges().to_lower()
		if not tag.is_empty() and not tag in str(record.get("tags", [])).to_lower(): continue
		var category = str(query.get("asset_category", query.get("category", "all")))
		if category not in ["", "all", "Humanoid avatars", "Robots", "Animations and emotes"] and record.get("category") != category: continue
		var license_filter = str(query.get("license", "all"))
		var license_name = str(record.get("license", ""))
		if license_filter == "CC0" and not license_name.begins_with("CC0"): continue
		if license_filter == "attribution" and not license_name.begins_with("CC-BY"): continue
		if license_filter == "unknown" and not license_name in ["", "Unknown"]: continue
		if query.get("compatibility", "all") != "all" and record.get("compatibility", "unknown") != query.compatibility: continue
		if query.get("shareable", "all") == "yes" and not record.get("redistribution", false): continue
		if query.get("loop", "all") != "all":
			if not record.has("loop") or record.loop != (query.loop == "yes"): continue
		result.append(record.duplicate(true))
	if query.get("sort") == "title": result.sort_custom(func(a, b): return str(a.get("title", "")).naturalnocasecmp_to(str(b.get("title", ""))) < 0)
	return result
