extends RefCounted

func evaluate(record: Dictionary) -> Dictionary:
	var supported = record.get("format", "").to_lower() in (["vrm", "glb"] if record.get("type") == "avatar" else ["vrma", "glb"])
	var share = record.get("redistribution", false) == true and record.get("license", "") in ["CC0", "CC0-1.0", "CC0 1.0 Universal"]
	return {"can_import": supported, "can_equip": supported and share and record.get("compatibility") == "verified",
		"share": share, "reason": "Import validates the actual humanoid data; Apply is always explicit. Only reviewed CC0 sharing is supported initially."}
