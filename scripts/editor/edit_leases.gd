extends RefCounted
var leases: Dictionary = {}
func acquire(session: String, entity: String, member: String, now: int, duration: int) -> Dictionary:
	if session.is_empty() or entity.is_empty() or member.is_empty() or now < 0 or duration < 1 or duration > 10000 or now > 9223372036854775807 - duration: return {"ok": false}
	expire(now)
	var key = JSON.stringify([session, entity])
	if leases.has(key) or leases.size() >= 1024: return {"ok": false}
	leases[key] = {"member": member, "expires": now + duration}
	return {"ok": true}
func release(session: String, entity: String, member: String) -> Dictionary:
	var key = JSON.stringify([session, entity])
	if not leases.has(key) or leases[key].member != member: return {"ok": false}
	leases.erase(key)
	return {"ok": true}
func disconnect_member(member: String):
	for key in leases.keys():
		if leases[key].member == member: leases.erase(key)
func expire(now: int):
	for key in leases.keys():
		if leases[key].expires <= now: leases.erase(key)
