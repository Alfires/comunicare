extends RefCounted
var hits: Dictionary = {}
var captured := ""
var captured_position := Vector2.ZERO
var events: Array = []

func hover(hand: String, pixels: Vector2, hit_valid: bool):
	if hand.is_empty(): return
	hits[hand] = {"position": pixels, "valid": hit_valid and pixels.is_finite() and pixels.x >= 0 and pixels.y >= 0}
	if captured == hand and hits[hand].valid: captured_position = pixels

func press(hand: String):
	if hand.is_empty() or not captured.is_empty() or not hits.get(hand, {}).get("valid", false): return
	captured = hand
	captured_position = hits[hand].position
	events.append({"hand": hand, "position": captured_position, "pressed": true})

func release(hand: String):
	if captured.is_empty() or captured != hand: return
	var position = captured_position if hits.get(hand, {}).get("valid", false) else Vector2(-1, -1)
	events.append({"hand": hand, "position": position, "pressed": false})
	captured = ""

func cancel():
	if not captured.is_empty():
		events.append({"hand": captured, "position": Vector2(-1, -1), "pressed": false})
	captured = ""
	hits.clear()

func drain_events() -> Array:
	var result = events
	events = []
	return result
