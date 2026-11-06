extends VBoxContainer
## Avatar browser sidebar: navigation, search field and filters. It only reports
## user intent; avatar_browser.gd owns the search state and network requests.

signal navigate(id: String)
signal search_submitted(query: String)
signal filters_changed(state: Dictionary)

const FILTERS = [["type", ["all", "avatar", "animation"]], ["format", ["all", "vrm", "vrma", "glb"]],
	["sort", ["provider", "title"]], ["license", ["all", "CC0", "attribution", "unknown"]],
	["compatibility", ["all", "unknown", "verified", "incompatible"]], ["shareable", ["all", "yes"]], ["loop", ["all", "yes", "no"]]]
const NAVIGATION = [["home", "Home"], ["search", "Search"], ["configuration", "My avatar"], ["providers", "Providers"]]

var search: LineEdit
var filter_controls: Dictionary = {}
var tag_field: LineEdit
var source_filter: OptionButton
var advanced_filters: Control

func _init():
	custom_minimum_size.x = 220
	for entry in NAVIGATION:
		var button = Button.new()
		button.text = entry[1]
		button.theme_type_variation = "NavButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 44
		button.pressed.connect(func(): navigate.emit(entry[0]))
		add_child(button)
	add_child(HSeparator.new())
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Search avatars and animations"
	search.max_length = 200
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 44
	search.set_meta("blocks_global_shortcuts", true)
	search.text_changed.connect(func(_text): filters_changed.emit(state()))
	search.text_submitted.connect(func(text): search_submitted.emit(text))
	add_child(search)
	source_filter = OptionButton.new()
	source_filter.tooltip_text = "Provider"
	source_filter.item_selected.connect(func(_index): filters_changed.emit(state()))
	add_child(source_filter)
	var advanced = CheckButton.new()
	advanced.text = "Advanced filters"
	add_child(advanced)
	var filters = VBoxContainer.new()
	filters.visible = false
	advanced.toggled.connect(func(enabled): filters.visible = enabled)
	advanced_filters = filters
	add_child(filters)
	for definition in FILTERS:
		var label = Label.new()
		label.text = str(definition[0]).capitalize()
		label.theme_type_variation = "CaptionLabel"
		filters.add_child(label)
		var selector = OptionButton.new()
		selector.tooltip_text = label.text
		for item in definition[1]: selector.add_item(item)
		selector.item_selected.connect(func(_index): filters_changed.emit(state()))
		filter_controls[definition[0]] = selector
		filters.add_child(selector)
	tag_field = LineEdit.new()
	tag_field.placeholder_text = "Filter tags"
	tag_field.max_length = 80
	tag_field.set_meta("blocks_global_shortcuts", true)
	tag_field.text_submitted.connect(func(_text): filters_changed.emit(state()))
	filters.add_child(tag_field)
	set_sources([])

## sources: Array of {id, name}.
func set_sources(sources: Array):
	source_filter.clear()
	source_filter.add_item("All providers")
	source_filter.set_item_metadata(0, "")
	for source in sources:
		source_filter.add_item(str(source.get("name", source.get("id", ""))))
		source_filter.set_item_metadata(source_filter.item_count - 1, str(source.get("id", "")))

func state() -> Dictionary:
	var result := {"query": search.text.left(200), "tag": tag_field.text, "source": str(source_filter.get_selected_metadata())}
	for definition in FILTERS:
		var selector: OptionButton = filter_controls[definition[0]]
		result[definition[0]] = definition[1][maxi(0, selector.selected)]
	return result
