extends RefCounted
const Guard = preload("res://scripts/multiplayer/federation/relay_validation.gd")
var user_blocks: Array = []
var operator_blocks: Array = []
var epoch := 0
var max_hops := 4

func configure(users: Array, operators: Array, policy_epoch: int, hops: int):
	user_blocks = users.duplicate()
	operator_blocks = operators.duplicate()
	epoch = policy_epoch
	max_hops = clampi(hops, 1, 4)

func set_user_blocked(id: String, blocked: bool):
	if blocked and not id in user_blocks: user_blocks.append(id)
	elif not blocked: user_blocks.erase(id)
	epoch += 1

func set_operator_blocked(id: String, blocked: bool):
	if blocked and not id in operator_blocks: operator_blocks.append(id)
	elif not blocked: operator_blocks.erase(id)
	epoch += 1

func authorize(route: Dictionary) -> Dictionary:
	if route.get("verified") != true or route.get("policy_epoch") != epoch or not Guard.identity(route.get("origin")) or not Guard.identity(route.get("ingress")):
		return Guard.failure("Unverified or stale relay route")
	var path = route.get("path")
	if not path is Array or path.is_empty() or path.size() > max_hops or path.back() != route.origin or path.front() != route.ingress:
		return Guard.failure("Invalid relay path")
	var seen: Dictionary = {}
	for id in path:
		if not Guard.identity(id) or seen.has(id) or id in user_blocks or id in operator_blocks: return Guard.failure("Blocked, invalid or looping relay route")
		seen[id] = true
	return {"ok": true}
