extends Node
## No network or importer: previews in this suite inject their own loaders.

signal asset_revision_available(url: String, previous: String, revision: String)

func load_vrm_from_url(_url: String):
	return null

func _load_model_from_buffer(_bytes: PackedByteArray):
	return null
