extends "res://common.gd"
## Parts 6–7: shared tablet shell, Quick page and the PC 2D overlay host.

const SHELL = "res://scenes/GUI/tablet_shell.tscn"
const SHELL_SCRIPT = "res://scripts/GUI/tablet_shell.gd"
const QUICK = ["mute", "emotes", "avatar", "invite", "home", "hide_avatars", "mirror", "camera"]
const SCENE_PATHS = {
	"quick": "res://scenes/GUI/quick_page.tscn", "friends": "res://scenes/GUI/friends_menue.tscn",
	"worlds": "res://scenes/GUI/world_explorer.tscn", "avatars": "res://scenes/GUI/avatar_browser.tscn",
	"instance": "res://scenes/GUI/share_session_menue.tscn", "settings": "res://scenes/GUI/settings_menue.tscn",
}
const SHELL_METHODS = ["open_page", "push_page", "back", "reset", "current_page", "page_ids",
	"page_scene_paths", "set_compact", "update_status", "handle_quick_action"]

var created: Dictionary = {}

func suite_name() -> String:
	return "shell (parts 6-7)"

func run():
	await test_shell()
	await test_quick_page()
	test_menu_wrapper()
	await test_overlay()

## Lightweight page factories keep heavy production pages (network, discovery,
## OAuth) out of shell behavior tests; their scene paths are checked separately.
func stub_factories(shell: Node):
	created.clear()
	var factories = shell.get("page_factories")
	if not factories is Dictionary: return false
	for id in PAGES:
		if id == "quick": continue
		factories[id] = func():
			created[id] = created.get(id, 0) + 1
			var page = Control.new()
			page.name = id
			page.set_meta("page_id", id)
			return page
	return true

func new_shell() -> Node:
	var shell = scene_component(SHELL, SHELL_METHODS)
	if shell == null: return null
	check(stub_factories(shell), "shell exposes page_factories prefilled with default page loaders")
	shell.size = Vector2(1600, 1200)
	root.add_child(shell)
	await frames(3)
	return shell

func visible_pages(shell: Node) -> Array:
	var content = named(shell, "Content")
	if content == null: return []
	return content.get_children().filter(func(child): return child is Control and child.visible)

# --- Part 6 -----------------------------------------------------------------

func test_shell():
	if not begin(6): return
	var shell = await new_shell()
	if shell == null: return
	check(Array(shell.page_ids()) == PAGES, "rail pages are Quick, Friends, Worlds, Avatars, Instance, Settings")
	var paths = shell.page_scene_paths()
	check(paths == SCENE_PATHS, "pages map to the existing production scenes (public names stay reachable)")
	check(SCENE_PATHS.values().all(func(path): return ResourceLoader.exists(path)), "every page scene exists")
	check(shell.current_page() == "quick", "the tablet opens on the Quick page")
	var nodes: Array = []
	for name in ["StatusBar", "NavRail", "PageHeader", "Content", "InstanceLabel", "PeopleLabel", "MicButton",
		"Clock", "CloseButton", "BackButton", "PageTitle"]:
		if shell.get_node_or_null("%" + name) == null: nodes.append(name)
	check(nodes.is_empty(), "shell has status bar, nav rail, header and content nodes %s" % [nodes])
	if not nodes.is_empty():
		shell.free()
		return
	var frame_ok = shell.theme_type_variation == "TabletFrame" or named(shell, "Frame") != null and named(shell, "Frame").theme_type_variation == "TabletFrame"
	check(frame_ok, "shell is drawn in a TabletFrame")
	check(shell.get_node("%StatusBar").theme_type_variation == "StatusBar", "status bar uses the StatusBar variation")
	var nav: Array = find_by_meta(shell.get_node("%NavRail"), "page_id").filter(func(node): return node is BaseButton)
	check(nav.map(func(button): return button.get_meta("page_id")) == PAGES, "one nav button per page, in order")
	check(nav.all(func(b): return b.theme_type_variation == "NavButton" and b.icon != null and not b.text.is_empty()),
		"nav buttons use NavButton with icon above label")
	var rail_width = shell.get_node("%NavRail").size.x
	check(rail_width >= 88 and rail_width <= 104, "nav rail is about 96 px wide (got %s)" % rail_width)
	check(created.is_empty(), "pages other than Quick are created lazily")
	if nav.size() == PAGES.size():
		activate(nav[1])
		await frames()
		check(shell.current_page() == "friends", "pressing a nav button opens its page")
	shell.open_page("settings")
	shell.open_page("quick")
	shell.open_page("settings")
	await frames()
	check(created.get("settings", 0) == 1, "reopening a page reuses its instance")
	var shown = visible_pages(shell)
	check(shown.size() == 1 and shown[0].get_meta("page_id", "") == "settings", "exactly one page is visible")
	var back: BaseButton = shell.get_node("%BackButton")
	check(not back.visible, "back is hidden on top-level pages")
	var nested = Control.new()
	shell.push_page(nested, "Profile")
	await frames()
	check(shell.get_node("%PageTitle").text == "Profile" and back.visible, "pushing a nested page shows its title and back")
	check(shell.back() and not back.visible and shell.current_page() == "settings", "back returns to the page below")
	check(not shell.back(), "back on a top-level page returns false so the host can close")
	shell.push_page(Control.new(), "Nested")
	shell.open_page("worlds")
	await frames()
	check(not back.visible, "switching rail page clears the nested stack")
	shell.push_page(Control.new(), "Nested")
	shell.reset()
	await frames()
	check(shell.current_page() == "quick" and not back.visible, "reset returns to Quick with an empty stack")
	shell.update_status({"instance": "Welcome Island", "people": 7})
	await frames()
	check(shell.get_node("%InstanceLabel").text.contains("Welcome Island") and shell.get_node("%PeopleLabel").text.contains("7"),
		"status bar shows instance name and people count")
	shell.update_status({})
	await frames()
	check(not shell.get_node("%InstanceLabel").text.is_empty(), "status bar shows a clear text when not in an instance")
	check(RegEx.create_from_string("^\\d{1,2}:\\d{2}$").search(shell.get_node("%Clock").text) != null, "status bar clock shows H:MM")
	var voice = autoload("SaveData").voice
	var mic: BaseButton = shell.get_node("%MicButton")
	voice.set_muted(true)
	await frames()
	check(mic.icon != null and mic.icon.resource_path.ends_with("microphone_muted.svg"), "mic button shows muted state from SaveData.voice")
	activate(mic)
	await frames()
	check(not voice.is_muted() and mic.icon != null and mic.icon.resource_path.ends_with("microphone.svg"),
		"mic button toggles the shared SaveData.voice owner")
	voice.set_muted(true)
	var closed = [0]
	if shell.has_signal("close_requested"):
		shell.close_requested.connect(func(): closed[0] += 1)
	activate(shell.get_node("%CloseButton"))
	check(closed[0] == 1, "close button emits close_requested once")
	shell.handle_quick_action("avatar")
	check(shell.current_page() == "avatars", "Quick 'Change avatar' opens the Avatars page")
	shell.handle_quick_action("invite")
	check(shell.current_page() == "instance", "Quick 'Invite' opens the Instance page")
	var forwarded: Array = []
	if shell.has_signal("quick_action"):
		shell.quick_action.connect(func(id): forwarded.append(id))
	shell.handle_quick_action("emotes")
	check(forwarded == ["emotes"], "host-level quick actions are forwarded via quick_action")
	await frames()
	var small: Array = []
	for container in ["%StatusBar", "%NavRail", "%PageHeader"]:
		for node in descendants(shell.get_node(container)):
			if node is BaseButton and node.is_visible_in_tree() and (node.size.x < 48 or node.size.y < 48):
				small.append("%s %s" % [node.name, node.size])
	check(small.is_empty(), "chrome hit targets are at least 48×48 px %s" % [small.slice(0, 4)])
	shell.set_compact(true)
	await frames()
	check(nav.all(func(b): return b.text.is_empty() and not b.tooltip_text.is_empty()) and shell.get_node("%NavRail").size.x <= 72,
		"compact mode collapses the rail to icons with tooltips")
	shell.set_compact(false)
	await frames()
	check(nav.all(func(b): return not b.text.is_empty()), "leaving compact mode restores labels")
	shell.free()

func test_quick_page():
	if not begin(6): return
	var quick = scene_component("res://scenes/GUI/quick_page.tscn", [])
	if quick == null: return
	check(quick.has_signal("action_requested"), "Quick page emits action_requested(id)")
	quick.size = Vector2(1400, 1100)
	root.add_child(quick)
	await frames(3)
	var tiles: Array = find_by_meta(quick, "quick_action").filter(func(node): return node is BaseButton)
	check(tiles.map(func(tile): return tile.get_meta("quick_action")) == QUICK, "Quick tiles: %s" % [QUICK])
	check(tiles.all(func(t): return t.theme_type_variation == "QuickTile" and t.icon != null and not t.text.is_empty()),
		"tiles use QuickTile with icon and short label")
	check(tiles.all(func(t): return t.size.x >= 160 and t.size.y >= 120), "tiles are at least 160×120 px")
	check(named(quick, "OnlineFriends") != null, "Quick page has an online friends strip")
	var voice = autoload("SaveData").voice
	var mute = tiles.filter(func(t): return t.get_meta("quick_action") == "mute")
	if not mute.is_empty():
		voice.set_muted(false)
		activate(mute[0])
		await frames()
		check(voice.is_muted(), "mute tile toggles SaveData.voice directly")
		voice.set_muted(false)
		await frames()
		check(mute[0].icon != null and mute[0].icon.resource_path.ends_with("microphone.svg"), "mute tile follows external mute changes")
		voice.set_muted(true)
	var requested: Array = []
	if quick.has_signal("action_requested"):
		quick.action_requested.connect(func(id): requested.append(id))
	var avatar = tiles.filter(func(t): return t.get_meta("quick_action") == "avatar")
	if not avatar.is_empty():
		activate(avatar[0])
		check(requested == ["avatar"], "non-local tiles emit action_requested")
	quick.free()
	var shell = await new_shell()
	if shell == null: return
	var hosted = find_by_script(shell, "res://scripts/GUI/quick_page.gd")
	check(hosted != null, "shell hosts the production Quick page")
	if hosted != null and hosted.has_signal("action_requested"):
		hosted.action_requested.emit("avatar")
		await frames()
		check(shell.current_page() == "avatars", "Quick page actions are routed through the shell")
	shell.free()

func test_menu_wrapper():
	if not begin(6): return
	var state: SceneState = load("res://scenes/GUI/menue.tscn").get_state()
	check(state.get_node_type(0) != "TabContainer", "menue.tscn is no longer a bottom TabContainer")
	var wraps := false
	for index in state.get_node_count():
		var instance = state.get_node_instance(index)
		if instance != null and instance.resource_path == SHELL: wraps = true
	check(wraps, "menue.tscn keeps its path/UID and wraps the tablet shell")

# --- Part 7 -----------------------------------------------------------------

func test_overlay():
	if not begin(7): return
	var overlay = scene_component("res://scenes/GUI/desktop_overlay.tscn",
		["open", "close", "toggle", "is_open", "layout_for", "apply_layout", "handle_input"])
	if overlay == null: return
	check(overlay is CanvasLayer, "PC menu is a 2D CanvasLayer overlay")
	var shell = named(overlay, "Shell")
	var dim = named(overlay, "Dim")
	check(shell != null and shell.get_script() != null and shell.get_script().resource_path == SHELL_SCRIPT, "overlay hosts the shared tablet shell")
	check(dim is ColorRect and dim.color.a >= 0.3 and dim.color.a <= 0.75 and dim.material == null,
		"game is dimmed behind the menu without blur shaders")
	check(descendants(overlay).all(func(node): return not node is BackBufferCopy), "no back-buffer blur")
	if shell == null or not shell.has_method("current_page"):
		overlay.free()
		return
	stub_factories(shell)
	var events: Array = []
	if overlay.has_signal("opened"): overlay.opened.connect(func(): events.append("opened"))
	if overlay.has_signal("closed"): overlay.closed.connect(func(): events.append("closed"))
	root.add_child(overlay)
	await frames()
	check(not overlay.is_open() and not shell.is_visible_in_tree(), "overlay starts closed")
	for size in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(1024, 768), Vector2(2560, 1440)]:
		var layout = overlay.layout_for(size)
		var rect: Rect2 = layout.get("rect", Rect2())
		var centered = (rect.get_center() - size / 2).length() < 1.0
		check(not layout.get("compact", true) and absf(rect.size.x / maxf(rect.size.y, 1) - 4.0 / 3.0) < 0.01
			and rect.size.y <= size.y * 0.86 + 1 and centered and Rect2(Vector2.ZERO, size).encloses(rect),
			"%dx%d: centered 4:3 tablet up to 86%% height" % [size.x, size.y])
	for size in [Vector2(800, 600), Vector2(700, 900)]:
		var layout = overlay.layout_for(size)
		var rect: Rect2 = layout.get("rect", Rect2())
		check(layout.get("compact", false) and is_equal_approx(rect.size.y, size.y) and rect.position.y == 0 and rect.size.x <= size.x,
			"%dx%d: compact full-height layout" % [size.x, size.y])
	overlay.apply_layout(Vector2(800, 600))
	await frames()
	check(shell.get("compact") == true, "compact layout collapses the shell rail")
	overlay.apply_layout(Vector2(1920, 1080))
	var escape = action_event("open_menue")
	check(overlay.handle_input(escape) and overlay.is_open() and shell.current_page() == "quick", "Esc opens the menu on Quick")
	check(events == ["opened"], "overlay emits opened for the host to release the mouse")
	shell.push_page(Control.new(), "Nested")
	check(overlay.handle_input(escape) and overlay.is_open() and not shell.get_node("%BackButton").visible, "Esc first goes back")
	check(overlay.handle_input(escape) and not overlay.is_open() and events.size() == 2 and events[1] == "closed", "second Esc closes the menu")
	overlay.open()
	shell.open_page("settings")
	overlay.close()
	overlay.toggle()
	check(overlay.is_open() and shell.current_page() == "quick", "reopening resets the shell like the old _reset_menu")
	check(overlay.handle_input(key_event(KEY_2)) and shell.current_page() == "friends", "number key 2 opens Friends")
	overlay.handle_input(key_event(KEY_6))
	check(shell.current_page() == "settings", "number key 6 opens Settings")
	check(not overlay.handle_input(key_event(KEY_7)), "number keys outside 1–6 are ignored")
	var field = LineEdit.new()
	shell.get_node("%Content").add_child(field)
	field.grab_focus()
	await frames()
	check(not overlay.handle_input(key_event(KEY_2)) and shell.current_page() == "settings", "number keys type text while a field has focus")
	field.set_meta("blocks_global_shortcuts", true)
	check(not overlay.handle_input(escape) and overlay.is_open(), "blocks_global_shortcuts keeps Esc for the focused control")
	field.queue_free()
	await frames()
	var before = shell.global_position
	var drag = InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(80, 60)
	shell.get_node("%StatusBar").gui_input.emit(drag)
	await frames()
	check(shell.global_position == before, "the PC overlay is not movable")
	check(evidence("player_desktop.tscn").contains("desktop_overlay.tscn"), "desktop player instances the overlay (wiring check)")
	overlay.free()
