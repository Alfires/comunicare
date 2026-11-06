extends RefCounted
## Stand-in friend service with the methods the Friends page calls; real accounts
## would need one RSA key per contact. Exercises the UI, not the service.

signal changed
var owner := "fake-friends-owner"
var last_error := ""
var connected := true
var supported := true
var state := {"preferred_status": "online"}
var people := {}

## long_names: every other contact gets a long name to test truncation and layout.
func _init(count: int, long_names := false):
	var kinds = ["friends", "friends", "friends", "incoming", "outgoing", "blocked"]
	for i in count:
		var id = "%064x" % (i * 2654435761 + 1)
		var name = "Player %03d" % i
		if long_names and i % 2 == 0:
			name = "Alexandria-Maximiliane von Hohenzollern-Sigmaringen %03d" % i
		people[id] = {"name": name, "kind": kinds[i % kinds.size()], "status": ["online", "offline", "do_not_disturb"][i % 3]}

func contacts() -> Dictionary:
	var result := {}
	for id in people: result[id] = {"blocked": people[id].kind == "blocked"}
	return result

func relationship(id: String) -> Dictionary:
	return {"status": people[id].kind} if not people[id].kind in ["contact", "blocked"] else {}

func status(id: String) -> String: return people[id].status
func label(id: String) -> String: return people[id].name
func relationship_label(_id: String) -> String: return "Saved contact"

func friend_session(id: String) -> Dictionary:
	if people[id].kind != "friends" or people[id].status != "online": return {}
	return {"session_id": "s-" + id.left(6), "world_url": "default_wold", "name": "Room " + id.left(4)}

func set_status(value: String): state.preferred_status = value
func refresh(): pass
func act(_id, _kind): return true
func block(_id, _value = true): return true
func remove_contact(_id): return true
func send_request(_id): return true
func add_contact(_key, _nick): return false
