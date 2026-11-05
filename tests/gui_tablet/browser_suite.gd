extends "res://common.gd"
## Parts 11–12: split avatar browser components and shared polish components.
## Components are tested in isolation; discovery/import/OAuth stay covered by
## tests/avatar_discovery and tests/real_ui --suite avatar.

const BROWSER_DIR = "res://scripts/GUI/avatar_browser/"
const RECORDS = [
	{"id": "a", "name": "Alpha", "provider": "osa", "license": "CC0", "thumbnail_url": ""},
	{"id": "b", "name": "Bravo", "provider": "osa", "license": "CC0", "thumbnail_url": ""},
	{"id": "c", "name": "Charlie", "provider": "osa", "license": "CC0", "thumbnail_url": ""},
]

func suite_name() -> String:
	return "browser and polish (parts 11-12)"

func run():
	await test_results()
	await test_detail()
	await test_sidebar()
	test_browser_wiring()
	await test_toasts()
	await test_empty_state()
	test_polish_wiring()

func labels_text(node: Node) -> String:
	var parts: Array = []
	for child in descendants(node):
		if child is Label or child is Button: parts.append(child.text)
	return " ".join(parts)

# --- Part 11 ----------------------------------------------------------------

func test_results():
	if not begin(11): return
	var results = script_component(BROWSER_DIR + "browser_results.gd", ["set_records", "cards", "columns_for_width"])
	if results == null: return
	check(results is Control and results.has_signal("record_selected"), "results grid emits record_selected")
	results.size = Vector2(1000, 800)
	root.add_child(results)
	results.set_records(RECORDS)
	await frames(2)
	var cards: Array = results.cards()
	check(cards.size() == 3 and cards.all(func(card): return card is BaseButton), "one card per record")
	check(cards.all(func(card): return descendants(card).any(func(node): return node is TextureRect)), "cards show a thumbnail")
	check(cards.size() == 3 and labels_text(cards[1]).contains("Bravo"), "cards show the avatar name")
	check(cards.all(func(card): return card.size.x >= 180 and card.size.y >= 220), "cards are at least 180×220 px")
	check(results.columns_for_width(1000) == 4 and results.columns_for_width(200) == 1 and results.columns_for_width(2000) == 9,
		"grid columns adapt to width (220 px per column)")
	var selected: Array = []
	if results.has_signal("record_selected"):
		results.record_selected.connect(func(record): selected.append(record.get("id")))
	if cards.size() == 3:
		activate(cards[1])
	check(selected == ["b"], "clicking a card selects its record")
	results.set_records([])
	await frames()
	var empty = named(results, "EmptyState")
	check(results.cards().is_empty() and empty is Control and empty.visible, "no results shows an empty state")
	results.free()

func test_detail():
	if not begin(11): return
	var detail = script_component(BROWSER_DIR + "browser_detail.gd", ["show_record", "set_progress", "show_error"])
	if detail == null: return
	check(detail.has_signal("apply_requested"), "detail pane emits apply_requested")
	detail.size = Vector2(500, 900)
	root.add_child(detail)
	detail.show_record(RECORDS[0], {"can_import": true, "share": true})
	await frames(2)
	var use = named(detail, "UseButton")
	check(use is BaseButton and use.text == "Use this avatar" and use.theme_type_variation == "PrimaryButton" and not use.disabled,
		"single primary 'Use this avatar' action")
	check(labels_text(detail).contains("CC0"), "license/source info is shown")
	check(find_by_script(detail, "res://scripts/GUI/avatar_preview.gd") != null, "detail pane hosts the avatar preview")
	var applied: Array = []
	if detail.has_signal("apply_requested"):
		detail.apply_requested.connect(func(record): applied.append(record.get("id")))
	activate(use)
	check(applied == ["a"], "Use this avatar requests apply for the shown record")
	detail.set_progress(40.0, "Downloading")
	await frames()
	var progress = named(detail, "Progress")
	check(progress is ProgressBar and progress.visible and is_equal_approx(progress.value, 40.0), "apply progress is inline, not modal")
	check(use is BaseButton and use.disabled, "apply is disabled while in progress")
	check(descendants(root).all(func(node): return not node is AcceptDialog or not node.visible), "no modal dialog during apply")
	detail.show_error("Digest mismatch")
	await frames()
	check(labels_text(detail).contains("Digest mismatch") and use is BaseButton and not use.disabled, "errors show inline and allow retry")
	detail.set_progress(100.0, "Done")
	await frames()
	check(progress is ProgressBar and not progress.visible, "progress hides when complete")
	detail.show_record(RECORDS[1], {"can_import": false, "share": false})
	await frames()
	var reason = named(detail, "Reason")
	check(use is BaseButton and use.disabled and reason is Label and reason.visible and not reason.text.is_empty(),
		"ineligible records explain why they cannot be used")
	detail.free()

func test_sidebar():
	if not begin(11): return
	var sidebar = script_component(BROWSER_DIR + "browser_sidebar.gd", ["set_sources", "state"])
	if sidebar == null: return
	check(sidebar.has_signal("filters_changed"), "sidebar emits filters_changed")
	root.add_child(sidebar)
	sidebar.set_sources([{"id": "osa", "name": "100Avatars R1 · CC0"}])
	await frames()
	var search = named(sidebar, "Search")
	check(search is LineEdit and search.get_meta("blocks_global_shortcuts", false), "search field blocks global shortcuts")
	var changes: Array = []
	if sidebar.has_signal("filters_changed"):
		sidebar.filters_changed.connect(func(state): changes.append(state))
	if search is LineEdit:
		search.text = "robot"
		search.text_changed.emit("robot")
		await frames()
	check(not changes.is_empty() and changes.back().get("query") == "robot" and sidebar.state().get("query") == "robot",
		"typing updates the filter state")
	sidebar.free()

func test_browser_wiring():
	if not begin(11): return
	var text = source("res://scripts/GUI/avatar_browser.gd")
	check(text.split("\n").size() <= 400, "avatar_browser.gd is split (≤ 400 lines, was 806)")
	check(not text.contains("AcceptDialog.new()"), "apply no longer opens a modal AcceptDialog (wiring check)")
	check(not text.contains("results.add_child(preview)"), "preview is no longer appended to the results list (wiring check)")
	check(["browser_results", "browser_detail", "browser_sidebar"].all(func(name): return text.contains(name)),
		"browser composes results, detail and sidebar (wiring check)")

# --- Part 12 ----------------------------------------------------------------

func test_toasts():
	if not begin(12): return
	var host = script_component("res://scripts/GUI/toast_host.gd", ["show_message", "visible_toasts"])
	if host == null: return
	root.add_child(host)
	host.show_message("Settings saved.", "success", 0.2)
	await frames()
	var toasts: Array = host.visible_toasts()
	check(toasts.size() == 1 and toasts[0].theme_type_variation == "Toast" and labels_text(toasts[0]).contains("Settings saved."),
		"toast shows the message in the Toast style")
	check(toasts.size() == 1 and toasts[0].focus_mode == Control.FOCUS_NONE and toasts[0].mouse_filter != Control.MOUSE_FILTER_STOP,
		"toasts never steal focus or block clicks")
	host.show_message("Unknown kind falls back.", "bogus", 0.2)
	for index in 3:
		host.show_message("Message %d." % index, "info", 0.2)
	await frames()
	toasts = host.visible_toasts()
	check(toasts.size() == 3 and labels_text(toasts[2]).contains("Message 2."), "at most three toasts, newest last")
	await create_timer(0.5).timeout
	await frames()
	check(host.visible_toasts().is_empty(), "toasts disappear after their duration")
	host.free()

func test_empty_state():
	if not begin(12): return
	var empty = script_component("res://scripts/GUI/empty_state.gd", ["configure"])
	if empty == null: return
	root.add_child(empty)
	var calls = [0]
	empty.configure(load("res://themes/icons/profile.svg"), "No friends online yet.", "Find people", func(): calls[0] += 1)
	await frames()
	var message = named(empty, "Message")
	var action = named(empty, "Action")
	check(message is Label and message.text == "No friends online yet.", "empty state shows one sentence")
	check(action is BaseButton and action.visible and action.text == "Find people", "empty state offers one action")
	activate(action)
	check(calls[0] == 1, "empty state action runs its callback")
	empty.configure(null, "Nothing here yet.")
	await frames()
	check(action is BaseButton and not action.visible, "action is hidden when not provided")
	empty.free()

func test_polish_wiring():
	if not begin(12): return
	var modal: Array = []
	var toast_users := 0
	var directory = DirAccess.open("res://scripts/GUI")
	if directory != null:
		for file in directory.get_files():
			if file.get_extension() != "gd": continue
			var text = source("res://scripts/GUI/" + file)
			if text.contains("AcceptDialog.new()"): modal.append(file)
			if text.contains("show_message("): toast_users += 1
	check(modal.is_empty(), "no informational AcceptDialogs remain in GUI scripts %s" % [modal])
	check(toast_users >= 3, "pages use toasts for non-blocking messages (wiring check)")
	var missing: Array = []
	for file in ["friends_menue.gd", "world_explorer.gd", "share_session_menue.gd"]:
		if not source("res://scripts/GUI/" + file).contains("empty_state"): missing.append(file)
	check(missing.is_empty(), "list pages use the shared empty state %s (wiring check)" % [missing])
