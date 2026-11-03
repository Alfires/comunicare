extends RefCounted
var strength := 0.0

func reset():
	strength = 0

func update_vignette(speed_mps: float, turn_dps: float, delta: float, enabled: bool) -> float:
	if not enabled:
		reset()
		return 0
	var target = clampf(maxf(absf(speed_mps) / 4, absf(turn_dps) / 180), 0, 0.65)
	strength = move_toward(strength, target, maxf(delta, 0) * 2)
	return strength
