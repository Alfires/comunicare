extends RefCounted
## Pure role policy; existing relay admission remains the enforcement boundary.
var members: Array = []
var admins: Array = []
var policy_ready: Dictionary = {}
var moderated := false

func configure(config: Dictionary):
	members = config.get("members", []).duplicate(true)
	admins = config.get("admins", []).duplicate(true)
	policy_ready = config.get("policy_ready", {}).duplicate(true)
	moderated = config.get("moderated", false) == true

func _current(id: String, generation: String) -> bool:
	for member in members:
		if member.id == id and member.generation == generation: return true
	return false

func authorize(id: String, generation: String, action: String) -> bool:
	return _current(id, generation) and id in admins and action in ["kick", "ban"]

func disconnect_member(id: String, generation: String):
	if not _current(id, generation): return
	for index in range(members.size() - 1, -1, -1):
		if members[index].id == id: members.remove_at(index)
	admins.erase(id)
	policy_ready.erase(id)
	if admins.is_empty() and not members.is_empty():
		var successor: Dictionary = members[0]
		for member in members:
			if member.order < successor.order: successor = member
		admins.append(successor.id)

func can_admit() -> bool:
	if members.is_empty() or admins.is_empty(): return false
	if moderated:
		for admin in admins:
			if policy_ready.get(admin, false) != true: return false
	return true

func snapshot() -> Dictionary:
	return {"members": members.duplicate(true), "admins": admins.duplicate(), "moderated": moderated}
