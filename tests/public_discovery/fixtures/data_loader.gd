extends Node

var loaded_urls: Array = []
var activated: int = 0
var fail_prepare := false
var fail_activate := false

func load_world_from_url(url: String) -> bool:
	loaded_urls.append(url)
	return true

func prepare_world_from_url(url: String) -> Dictionary:
	loaded_urls.append(url)
	return {} if fail_prepare else {"url": url}

func activate_world(_staged: Dictionary) -> bool:
	activated += 1
	return not fail_activate
