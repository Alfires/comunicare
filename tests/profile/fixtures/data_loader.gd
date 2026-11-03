extends Node

var avatar_requests: Array = []

func load_vrm_from_url(url: String):
	avatar_requests.append(url)
	return Node3D.new()
