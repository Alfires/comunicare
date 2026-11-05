extends RefCounted

func apply(records: Array, query: Dictionary) -> Array:
	var result: Array = []
	# Normalize query once per search, not once for every catalog entry.
	var term = str(query.get("query", "")).strip_edges().to_lower()
	var tag = str(query.get("tag", "")).strip_edges().to_lower()
	var category = str(query.get("asset_category", query.get("category", "all")))
	var license_filter = str(query.get("license", "all"))
	for record in records:
		if not record is Dictionary: continue
		if query.get("type", "all") != "all" and record.get("type") != query.type: continue
		if query.get("format", "all") != "all" and record.get("format") != query.format: continue
		if not term.is_empty():
			var text = (str(record.get("title", "")) + " " + str(record.get("author", "")) + " " + str(record.get("tags", []))).to_lower()
			if not term in text: continue
		if not tag.is_empty():
			var tags = record.get("tags", [])
			if not tags is Array or not tags.any(func(value): return value is String and value.strip_edges().to_lower() == tag): continue
		if category not in ["", "all", "Humanoid avatars", "Robots", "Animations and emotes"] and record.get("category") != category: continue
		var license_name = str(record.get("license", ""))
		if license_filter == "CC0" and license_name not in ["CC0", "CC0-1.0", "CC0 1.0 Universal"]: continue
		if license_filter == "attribution" and not _attribution_license(license_name): continue
		if license_filter == "unknown" and not license_name.strip_edges().to_lower() in ["", "unknown"]: continue
		if query.get("compatibility", "all") != "all" and record.get("compatibility", "unknown") != query.compatibility: continue
		if query.get("shareable", "all") == "yes" and not (record.get("redistribution") is bool and record.redistribution): continue
		if query.get("loop", "all") != "all":
			if not record.has("loop") or record.loop != (query.loop == "yes"): continue
		result.append(record.duplicate(true))
	if query.get("sort") == "title": result.sort_custom(func(a, b): return str(a.get("title", "")).naturalnocasecmp_to(str(b.get("title", ""))) < 0)
	return result

func _attribution_license(value: String) -> bool:
	for family in ["CC-BY", "CC-BY-SA", "CC-BY-NC", "CC-BY-ND", "CC-BY-NC-SA", "CC-BY-NC-ND"]:
		if value == family: return true
		for version in ["1.0", "2.0", "2.5", "3.0", "4.0"]:
			if value == family + "-" + version: return true
	return false
