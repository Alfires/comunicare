extends Node
## No sockets, HTTP, DNS or relay. Completion is controlled by the suite.
signal completed
var started := 0
var pending := false
var failed := false

func connect_initial_relay():
	started += 1
	pending = true
	await completed
	pending = false
	failed = true
