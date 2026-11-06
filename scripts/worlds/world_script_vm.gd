extends RefCounted
## Bounded data interpreter. No dynamic engine calls, expressions or object handles.
const Data = preload("res://scripts/worlds/world_data.gd")
const MAX_FUEL = 100000
const MAX_HEAP = 8 * 1024 * 1024
const MAX_COMMANDS = 256

func run_event(operations: Variant, context: Dictionary, limits: Dictionary = {}) -> Dictionary:
	if not Data.bounded(operations, 0, [16384]) or not Data.bounded(context, 0, [16384]):
		return Data.failure("Script input exceeds data limits")
	for key in limits:
		if not key in ["fuel", "heap_bytes", "max_commands"] or not Data.integer(limits[key], 0, MAX_HEAP):
			return Data.failure("Invalid VM limits")
	var state = {"fuel": mini(int(limits.get("fuel", MAX_FUEL)), MAX_FUEL),
		"heap": mini(int(limits.get("heap_bytes", MAX_HEAP)), MAX_HEAP),
		"max_commands": mini(int(limits.get("max_commands", MAX_COMMANDS)), MAX_COMMANDS), "commands": []}
	var error = _execute(operations, context, state, 0)
	return Data.failure(error) if not error.is_empty() else {"ok": true, "commands": state.commands}

func _execute(operations: Variant, context: Dictionary, state: Dictionary, depth: int) -> String:
	if not operations is Array or depth > 16: return "Invalid script block or nesting depth"
	for operation in operations:
		state.fuel -= 1
		if state.fuel < 0: return "Script fuel exhausted"
		if not operation is Dictionary: return "Invalid instruction"
		match operation.get("op", ""):
			"menu":
				if not "ui.local" in context.get("capabilities", []) or not Data.keys_only(operation, ["op", "page"]) or not operation.get("page") is String or operation.page.length() > 64: return "Invalid/denied world menu"
				if state.commands.size() >= state.max_commands: return "Script command budget exhausted"
				state.commands.append(operation.duplicate(true))
			"state_set", "state_add":
				if not "state.local" in context.get("capabilities", []) or not Data.keys_only(operation, ["op", "key", "value"]) or not operation.get("key") is String or operation.key.is_empty() or operation.key.length() > 64: return "Invalid/denied run state"
				if operation.op == "state_add" and not (operation.get("value") is int or operation.get("value") is float): return "Invalid run counter"
				if state.commands.size() >= state.max_commands: return "Script command budget exhausted"
				state.commands.append(operation.duplicate(true))
			"checkpoint":
				if not "player.checkpoint" in context.get("capabilities", []) or not Data.keys_only(operation, ["op", "entity"]): return "Denied checkpoint capability"
				if not operation.get("entity") is String or not operation.entity in context.get("entities", []): return "Invalid checkpoint entity"
				if state.commands.size() >= state.max_commands: return "Script command budget exhausted"
				state.commands.append(operation.duplicate(true))
			"save_set", "save_add", "save_delete":
				if not "storage.local" in context.get("capabilities", []): return "Denied local storage capability"
				if not Data.keys_only(operation, ["op", "key", "value"]) or not operation.get("key") is String or operation.key.is_empty() or operation.key.length() > 64: return "Invalid save key"
				if operation.op == "save_add" and not (operation.get("value") is int or operation.get("value") is float): return "Invalid save increment"
				if state.commands.size() >= state.max_commands: return "Script command budget exhausted"
				state.commands.append(operation.duplicate(true))
			"if_saved":
				if not "storage.local" in context.get("capabilities", []) or not Data.keys_only(operation, ["op", "key", "equals", "then", "else"]) or not operation.get("key") is String: return "Invalid saved-data condition"
				# Validate both branches even when one is not selected. Package
				# inspection must not hide forbidden instructions behind saved state.
				for branch_name in ["then", "else"]:
					var checked = {"fuel": state.fuel, "heap": state.heap, "max_commands": state.max_commands, "commands": []}
					var branch_error = _execute(operation.get(branch_name, []), context, checked, depth + 1)
					if not branch_error.is_empty(): return branch_error
					state.fuel = checked.fuel
				var branch = operation.get("then", []) if context.get("saved", {}).get(operation.key) == operation.get("equals") else operation.get("else", [])
				var error = _execute(branch, context, state, depth + 1)
				if not error.is_empty(): return error
			"repeat":
				if not Data.keys_only(operation, ["op", "count", "body"]) or not Data.integer(operation.get("count"), 0, 2147483647): return "Invalid repeat"
				if operation.count == 0:
					var checked = {"fuel": state.fuel, "heap": state.heap, "max_commands": state.max_commands, "commands": []}
					var error = _execute(operation.get("body"), context, checked, depth + 1)
					if not error.is_empty(): return error
					state.fuel = checked.fuel
				if operation.count > state.fuel: return "Script fuel exhausted"
				for iteration in int(operation.count):
					state.fuel -= 1
					var error = _execute(operation.get("body"), context, state, depth + 1)
					if not error.is_empty(): return error
			"allocate":
				if not Data.keys_only(operation, ["op", "bytes"]) or not Data.integer(operation.get("bytes"), 0, MAX_HEAP): return "Invalid allocation"
				state.heap -= int(operation.bytes)
				if state.heap < 0: return "Script heap budget exhausted"
			"command":
				if not Data.keys_only(operation, ["op", "capability", "entity", "property", "value"]): return "Invalid command fields"
				if operation.get("capability") != "entity.visual" or not "entity.visual" in context.get("capabilities", []): return "Denied script capability"
				if not operation.get("entity") is String or not operation.entity in context.get("entities", []): return "Invalid world entity"
				if operation.get("property") != "visible" or not operation.get("value") is bool: return "Unsupported visual property or value"
				if state.commands.size() >= state.max_commands: return "Script command budget exhausted"
				state.heap -= 128 + operation.entity.length()
				if state.heap < 0: return "Script heap budget exhausted"
				state.commands.append(operation.duplicate(true))
			_:
				return "Unknown script instruction"
	return ""
