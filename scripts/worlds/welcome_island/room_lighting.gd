extends Node3D
## Client-local room state. No settings-store/renderer preference writes.
var zones: Dictionary = {}
signal zone_changed(zone: String)

func _ready():
	add_to_group("home_lighting")
	for name in {"Lounge": Vector3(-4.5, 2.6, 2.5), "Bedroom": Vector3(-3.5, 2.6, -4), "Kitchen": Vector3(5, 2.6, -3)}:
		var light = OmniLight3D.new()
		light.name = name + "Light"
		light.position = {"Lounge": Vector3(-4.5, 2.6, 2.5), "Bedroom": Vector3(-3.5, 2.6, -4), "Kitchen": Vector3(5, 2.6, -3)}[name]
		light.omni_range = 7
		light.shadow_enabled = false
		add_child(light)
		zones[name] = {"light": light, "enabled": true, "brightness": 0.6, "temperature": "warm"}
		set_zone(name, true, 0.6, "warm")

func set_zone(zone: String, enabled: bool, brightness: float, temperature: String) -> bool:
	if not zones.has(zone) or not is_finite(brightness) or brightness < 0.1 or brightness > 1 or temperature not in ["warm", "neutral"]: return false
	var state: Dictionary = zones[zone]
	state.enabled = enabled
	state.brightness = brightness
	state.temperature = temperature
	state.light.light_energy = brightness * 2 if enabled else 0.0
	state.light.light_color = Color(1, 0.78, 0.52) if temperature == "warm" else Color(1, 0.96, 0.89)
	zone_changed.emit(zone)
	return true

func make_controls() -> VBoxContainer:
	var panel = VBoxContainer.new()
	var notice = Label.new()
	notice.text = "Home room lighting (local; resets when home reloads)"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(notice)
	for zone in zones:
		var state: Dictionary = zones[zone]
		var toggle = CheckButton.new()
		toggle.text = zone
		toggle.custom_minimum_size.y = 44
		toggle.set_pressed_no_signal(state.enabled)
		panel.add_child(toggle)
		var brightness = HSlider.new()
		brightness.min_value = 0.1; brightness.max_value = 1; brightness.step = 0.05
		brightness.value = state.brightness; brightness.custom_minimum_size = Vector2(200, 44)
		brightness.tooltip_text = zone + " brightness (10–100%)"
		panel.add_child(brightness)
		var temperature = OptionButton.new()
		temperature.add_item("Warm"); temperature.add_item("Neutral")
		temperature.select(0 if state.temperature == "warm" else 1)
		temperature.custom_minimum_size.y = 44
		panel.add_child(temperature)
		var update = func():
			if is_instance_valid(self): set_zone(zone, toggle.button_pressed, brightness.value, "warm" if temperature.selected == 0 else "neutral")
		toggle.toggled.connect(func(_value): update.call())
		brightness.value_changed.connect(func(_value): update.call())
		temperature.item_selected.connect(func(_value): update.call())
	return panel
