extends SceneTree
## Screenshot capture of the production menu for manual visual comparison.
## Not a pass/fail gate. Uses the real autoloads with the disposable account
## created by run.py. The Avatars page is skipped because it requests public
## catalogs over the internet.

const SIZES = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const PAGES = ["quick", "friends", "worlds", "instance", "settings"]
const LEGACY_TABS = {"quick": 0, "friends": 1, "worlds": 2, "settings": 3}

func _initialize():
	call_deferred("run")

func show_page(menu: Node, id: String) -> bool:
	if menu.has_method("open_page"):
		menu.open_page(id)
		return true
	if LEGACY_TABS.has(id):
		menu.current_tab = LEGACY_TABS[id]
		return true
	return false

func run():
	var directory = OS.get_environment("COMUNICARE_UI_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		print("Capture requires --rendered and COMUNICARE_UI_CAPTURE_DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var save = root.get_node("SaveData")
	save.load_acount()
	save.store.set_value("network.lan_discovery", false)
	var images := 0
	for preset in ["graphite", "paper"]:
		if not save.registry.get_definition("interface.theme_preset").is_empty():
			save.store.set_value("interface.theme_preset", preset)
		for window_size in SIZES:
			root.size = window_size
			var menu = load("res://scenes/GUI/menue.tscn").instantiate()
			root.add_child(menu)
			if menu is Control:
				menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for id in PAGES:
				if not show_page(menu, id):
					continue
				await create_timer(0.4).timeout
				var image = root.get_texture().get_image()
				if image.is_empty():
					continue
				var name = "%s-%dx%d-%s.png" % [preset, window_size.x, window_size.y, id]
				image.save_png(directory.path_join(name))
				images += 1
			menu.free()
			await process_frame
	print("Captured %d screenshots into %s" % [images, directory])
	quit(0 if images > 0 else 1)
