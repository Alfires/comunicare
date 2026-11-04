extends RefCounted
## Verified profile appearance deduplication, scoped to actual remote node lifetime.
var appearances: Dictionary = {}

func apply_profile(player: Node, fingerprint: String, profile: Dictionary):
	var key = player.get_instance_id()
	var previous: Dictionary = appearances.get(key, {})
	var url: String = profile.get("profile.avatar_url", "")
	player.user_name = str(profile.get("profile.username", "User"))
	var label = player.get_node_or_null("user_name")
	if label != null: label.text = player.user_name
	if previous.get("owner") != fingerprint or previous.get("url") != url:
		appearances[key] = {"node": weakref(player), "owner": fingerprint, "url": url}
		if not url.is_empty() and player.has_method("load_player_model"):
			player.load_player_model(url)
	for id in appearances.keys():
		if appearances[id].node.get_ref() == null: appearances.erase(id)

func clear():
	appearances.clear()
