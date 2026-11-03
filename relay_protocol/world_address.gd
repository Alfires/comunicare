class_name WorldAddress
extends RefCounted

static func is_valid(value: Variant) -> bool:
	if not value is String or value.length() > 4096:
		return false
	if value == "default_wold":
		return true
	if value != value.strip_edges() or "\n" in value or "\r" in value:
		return false
	var scheme = "https://" if value.begins_with("https://") else "http://"
	if not value.begins_with(scheme):
		return false
	var authority = value.substr(scheme.length()).split("/")[0].split("?")[0].split("#")[0]
	return not authority.is_empty() and not "@" in authority and not " " in value
