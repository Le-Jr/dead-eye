extends Control
## Main menu: a wanted poster nailed to a plank wall. Lists the modes with
## the player's best run in each, and opens the settings.

const MODES := [
	{
		"id": &"free_range", "title": "Free Range",
		"blurb": "Every gun, every target. No clock, nothing saved.",
	},
	{
		"id": &"gallery", "title": "Gallery",
		"blurb": "Ninety seconds of bottles, bandits and clays. Chain your hits.",
	},
	{
		"id": &"quick_draw", "title": "Quick Draw", "unit": "ms",
		"blurb": "Five duels. Holster, wait for the bell, draw.",
	},
	{
		"id": &"long_shot", "title": "Long Shot",
		"blurb": "The Sharps from 100 to 500 metres. Set the sight, read the wind.",
	},
]

## The column of the poster; pages are built into it.
var pages: VBoxContainer
var mode_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = FrontierUI.make_theme()
	FrontierUI.backdrop(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	pages = FrontierUI.poster(center, 780, 44)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MusicDirector.play("menu")
	show_home()


func clear_page() -> void:
	mode_buttons.clear()
	for child in pages.get_children():
		pages.remove_child(child)
		child.queue_free()


func show_home() -> void:
	clear_page()
	FrontierUI.caption(pages, "Est. 1878   ·   Frontier Territory")
	FrontierUI.title(pages, "DEAD EYE RANGE", 78)
	FrontierUI.caption(pages, "Precision   ·   Rhythm   ·   Style", FrontierUI.RED)
	FrontierUI.rule(pages)
	for entry: Dictionary in MODES:
		mode_buttons.append(_mode_button(entry))
	FrontierUI.rule(pages)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pages.add_child(row)
	FrontierUI.button(row, "SETTINGS", show_settings).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FrontierUI.button(row, "QUIT", AudioManager.quit_game).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FrontierUI.focus(mode_buttons[0])


func show_settings() -> void:
	clear_page()
	var page := SettingsPage.new()
	page.closed.connect(show_home)
	pages.add_child(page)


func launch(id: StringName) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GameMode.SCENES[id])


## One row of the poster: name and blurb on the left, the record on the right.
func _mode_button(entry: Dictionary) -> Button:
	var id: StringName = entry.id
	var b := FrontierUI.button(pages, "", launch.bind(id))
	b.custom_minimum_size.y = 96
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -26
	b.add_child(row)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	FrontierUI.title(text, entry.title, 34).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	FrontierUI.label(text, entry.blurb, 19, FrontierUI.INK_SOFT).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var record := SaveSystem.get_record(id)
	if not record.is_empty():
		var best := VBoxContainer.new()
		best.mouse_filter = Control.MOUSE_FILTER_IGNORE
		best.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(best)
		var stars := FrontierUI.Stars.new(int(record.get("stars", 0)), 3, 26)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_END
		best.add_child(stars)
		var score := "%d ms" % int(record.get("score", 0)) if entry.has("unit") else "$" + GameMode.HUD._thousands(int(record.get("score", 0)))
		var value := FrontierUI.label(best, score, 22)
		value.add_theme_font_override("font", FrontierUI.text_font(700))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return b
