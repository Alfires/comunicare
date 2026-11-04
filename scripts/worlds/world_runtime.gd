extends Node
## Trusted event broker for declarative .worldscript data, not attached GDScript.
const Data = preload("res://scripts/worlds/world_data.gd")
const VM = preload("res://scripts/worlds/world_script_vm.gd")
var entities: Dictionary = {}
var programs: Dictionary = {}
var bindings: Dictionary = {}
var capabilities: Array = []
var enabled := false
var world: WeakRef
var tick_elapsed := 0.0
var last_error := ""

func configure(root_node: Node, document: Dictionary) -> Dictionary:
	stop_scripts()
	entities.clear()
	bindings.clear()
	programs = document.get("programs", {}).duplicate(true)
	capabilities = document.get("manifest", {}).get("script_capabilities", []).duplicate()
	world = weakref(root_node)
	for id in document.get("entities", {}):
		var entry: Dictionary = document.entities[id]
		var node = root_node if entry.path == "." else root_node.get_node_or_null(NodePath(entry.path))
		if node == null: return Data.failure("Missing runtime entity")
		entities[id] = weakref(node)
		if not str(entry.get("script", "")).is_empty(): bindings[id] = entry.script
	enabled = true
	last_error = ""
	return {"ok": true}

func dispatch(event: String, entity: String) -> Dictionary:
	if not enabled or world == null or world.get_ref() == null: return Data.failure("World scripts stopped")
	if not event in ["start", "tick", "use", "grab", "release"] or (not entity.is_empty() and not entities.has(entity)):
		return Data.failure("Invalid world event")
	var commands: Array = []
	# One aggregate event invocation and budget across all modules. Replication
	# must order shared callbacks before using this for multiplayer game logic.
	var operations: Array = []
	for id in bindings:
		if not entity.is_empty() and id != entity: continue
		operations.append_array(programs[bindings[id]].events.get(event, []))
	var result = VM.new().run_event(operations, {"capabilities": capabilities, "entities": entities.keys()}, {})
	if not result.ok:
		last_error = result.error
		stop_scripts()
		return result
	commands = result.commands
	# Resolve the whole transaction before mutating any scene state.
	for command in commands:
		var target = entities.get(command.entity)
		if target == null or not target.get_ref() is Node3D:
			stop_scripts()
			return Data.failure("Visual target is unavailable")
	for command in commands:
		entities[command.entity].get_ref().visible = command.value
	return {"ok": true, "commands": commands.size()}

func stop_scripts():
	enabled = false
	tick_elapsed = 0.0

func _process(delta: float):
	if not enabled: return
	tick_elapsed += minf(delta, 0.1)
	if tick_elapsed >= 0.05:
		tick_elapsed = 0.0
		dispatch("tick", "")
