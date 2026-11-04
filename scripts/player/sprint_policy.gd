extends RefCounted
## Device-independent hold-to-sprint policy. Suppression requires release to rearm.
const MULTIPLIER := 1.5
var release_required := false

func suppress():
	release_required = true

func target_speed(walk_speed: float, pressed: bool, blocked: bool) -> float:
	if blocked:
		suppress()
	elif not pressed:
		release_required = false
	var speed = maxf(walk_speed, 0.0) if is_finite(walk_speed) else 0.0
	return speed * MULTIPLIER if pressed and not blocked and not release_required else speed
