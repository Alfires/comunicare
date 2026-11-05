extends RefCounted
## Client-local session policy, keyed by authenticated identity, never asset hash.
signal changed
var session := ""
var account := ""
var hidden: Dictionary = {}

func set_scope(next_session: String, next_account: String):
	if session == next_session and account == next_account: return
	session = next_session
	account = next_account
	hidden.clear()
	changed.emit()

func is_hidden(owner: String) -> bool:
	return hidden.has(owner)

func set_hidden(expected_session: String, owner: String, value: bool) -> bool:
	if session.is_empty() or expected_session != session or owner.is_empty() or owner == account: return false
	if is_hidden(owner) == value: return true
	if value: hidden[owner] = true
	else: hidden.erase(owner)
	changed.emit()
	return true
