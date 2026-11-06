extends RefCounted
var document: Dictionary = {}
var owner := ""
var generation := ""
var roles: Dictionary = {}
var seen: Dictionary = {}
func configure(source: Dictionary, account: String, session: String):
	document.clear()
	owner = ""
	generation = ""
	roles.clear()
	seen.clear()
	if account.is_empty() or session.is_empty() or not preload("res://addons/comunicare_world_tools/authoring_document.gd").new().validate(source).ok: return
	document = source.duplicate(true)
	owner = account
	generation = session
	roles = {owner: "owner"}
	seen.clear()
func admit(actor: String, member: String, role: String) -> Dictionary:
	if owner.is_empty() or actor != owner or member.is_empty() or member == owner or role not in ["editor", "viewer"]: return _fail("Only owner can grant editor/viewer access")
	roles[member] = role
	return {"ok": true}
func revoke(actor: String, member: String) -> Dictionary:
	if owner.is_empty() or actor != owner or member == owner: return _fail("Only owner can revoke access")
	roles.erase(member)
	return {"ok": true}
func submit(sender: String, operation: Dictionary) -> Dictionary:
	if roles.get(sender, "") not in ["owner", "editor"]: return _fail("Editing access denied")
	if operation.get("generation") != generation or not operation.get("id") is String or operation.id.is_empty(): return _fail("Invalid edit session/operation ID")
	if seen.has(operation.id): return _fail("Duplicate operation")
	if seen.size() >= 4096: return _fail("Session operation budget reached; save and reopen")
	var result = preload("res://scripts/editor/edit_commands.gd").new().apply_operation(document, operation)
	if result.ok:
		document = result.document.duplicate(true)
		seen[operation.id] = true
	return result
func snapshot(recipient: String) -> Dictionary:
	return {"ok": true, "document": document.duplicate(true)} if roles.has(recipient) else _fail("Project access denied")
func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
