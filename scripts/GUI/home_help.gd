extends VBoxContainer
## Optional menu text only: never starts a tour, progress tracker or network action.
var details: Label
var toggle: Button
static var expanded := false

func _ready():
	toggle = Button.new()
	toggle.text = "Help / current controls"
	toggle.custom_minimum_size.y = 44
	add_child(toggle)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 18)
	details.visible = expanded
	add_child(details)
	var hints = CheckButton.new()
	hints.text = "Show reachable-object highlights"
	hints.custom_minimum_size.y = 44
	hints.set_pressed_no_signal(get_tree().root.get_meta("home_action_hints", true))
	hints.toggled.connect(func(value): get_tree().root.set_meta("home_action_hints", value))
	add_child(hints)
	toggle.pressed.connect(func():
		expanded = not details.visible
		details.visible = expanded
		if expanded: refresh_help())
	var save = get_node_or_null("/root/SaveData")
	if save != null and not save.store.setting_changed.is_connected(_setting_changed):
		save.store.setting_changed.connect(_setting_changed)
	refresh_help()

func _setting_changed(_id: String, _value: Variant): refresh_help()

func refresh_help(store = null):
	if details == null or not is_inside_tree(): return
	if store == null:
		var save = get_node_or_null("/root/SaveData")
		if save == null: return
		store = save.store
	var grab = OS.get_keycode_string(int(store.get_value("input.world_grab")))
	var sprint = OS.get_keycode_string(int(store.get_value("input.sprint")))
	var emote = OS.get_keycode_string(int(store.get_value("input.toggle_animation_menu")))
	var mic = OS.get_keycode_string(int(store.get_value("input.toggle_microphone")))
	var mode = str(store.get_value("vr.locomotion_mode"))
	var menu_action = str(store.get_value("input.xr_main_menu_action"))
	var menu_button = "A/X" if menu_action == "ax_button" else "Menu"
	details.text = "Explore at your own pace. There is no task order or tutorial to finish.\n\n" \
		+ grab + " — Pick up / drop a reachable object; activate a reachable switch when no pickup is selected.\n" \
		+ sprint + " — Hold to sprint while walking.\n" + emote + " — Emote menu.\n" + mic + " — Microphone toggle (only when you choose).\n\n" \
		+ "VR: left stick movement; right stick turning. Current locomotion: " + mode + ". In teleport mode, aim with left stick forward and release to neutral on a valid surface. Controller grip picks up/releases nearby objects. Main menu: " + menu_button + ".\n\n" \
		+ "House lighting and kitchen controls are available below. At the dock, explicitly confirm boarding; movement steers/throttles the boat. Stop, leave at dock or return through these controls.\n\n" \
		+ "Offline home works without a relay. Home objects, lights, kitchen and boat are local-only, even when home content is used online. Meeting other people requires a connection and an admitted instance.\n\n" \
		+ "Hide this help whenever you like. All places and actions stay available."
