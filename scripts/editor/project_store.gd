extends RefCounted
const Document = preload("res://addons/comunicare_world_tools/authoring_document.gd")
func save_project(document: Dictionary, path: String) -> Dictionary:
	return Document.new().save_project(document, path)
func load_project(path: String) -> Dictionary:
	return Document.new().load_project(path)
func recover_project(path: String) -> Dictionary:
	return load_project(path) # Never prefer an uncommitted temporary file.
