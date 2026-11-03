extends Node

var requests: Array = []

func prepare_world_from_url(url: String) -> Dictionary:
	requests.append(url)
	return {"url": url}

func activate_world(_staged: Dictionary) -> bool:
	return true

func load_vrm_from_url(_url: String):
	return Node3D.new()

func _load_model_from_buffer(_bytes: PackedByteArray):
	return Node3D.new()
