extends Node
signal prepared
var hold_prepare := false
var activated := 0

func prepare_world_from_url(url: String, _revision: String = "") -> Dictionary:
	if hold_prepare: await prepared
	return {"url": url}

func activate_world(_staged: Dictionary) -> bool:
	activated += 1
	return true
