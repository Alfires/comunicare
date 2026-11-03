extends Node
signal asset_revision_available(source: String, previous: String, revision: String)

func load_vrm_from_url(_url: String):
	return null

func prepare_world_from_url(_url: String, _revision: String = "") -> Dictionary:
	return {}

func activate_world(_staged: Dictionary) -> bool:
	return false
