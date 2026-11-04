extends "res://scripts/GUI/world_explorer.gd"
var catalog_calls := 0

func _request_catalog():
	catalog_calls += 1 # Never contact the real external catalog.

func _show_error(_message: String):
	pass # Error-state assertions do not open modal windows in this fixture.

func _on_reload_pressed():
	# Only replace ENet send. Production process/deadline/refresh policy runs.
	if refreshing: return
	refreshing = true
	refresh_started = Time.get_ticks_msec()
