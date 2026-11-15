class_name SettingsPage
extends VBoxContainer
## Settings and key bindings, as one column that fits in any poster. Used by
## the main menu and by the pause screen. Everything writes straight through
## the Settings autoload, so changes apply and save as they are made.

signal closed

const ACTION_NAMES := {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left",
	"move_right": "Move right", "sprint": "Sprint", "crouch": "Crouch",
	"fire": "Fire", "aim": "Aim", "cock_hammer": "Work the action", "alt_fire": "Fan / both barrels (hold)",
	"reload": "Reload", "holster": "Holster / draw", "dead_eye": "Dead Eye",
	"sight_up": "Raise sight", "sight_down": "Lower sight",
	"weapon_1": "Revolver", "weapon_2": "Lever rifle", "weapon_3": "Coach gun", "weapon_4": "Sharps rifle",
	"weapon_next": "Next weapon", "weapon_prev": "Previous weapon", "pause": "Pause",
}
const TIMES := ["sunset", "noon", "night"]

var _sections := {}
var _tabs := {}
var _binding_action := ""
var _binding_button: Button


func _init() -> void:
	add_theme_constant_override("separation", 14)
	FrontierUI.title(self, "THE GUNSLINGER'S HANDBOOK", 34)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	for section: String in ["Game", "Sound", "Picture", "Controls"]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(column)
		_sections[section] = column
		var tab := FrontierUI.button(tabs, section.to_upper(), _show.bind(section))
		tab.toggle_mode = true
		_tabs[section] = tab
	_build_game(_sections["Game"])
	_build_sound(_sections["Sound"])
	_build_picture(_sections["Picture"])
	_build_controls()
	FrontierUI.button(self, "BACK", func() -> void: closed.emit())
	_show("Game")


func _show(section: String) -> void:
	_binding_action = ""
	for key: String in _sections:
		_sections[key].visible = key == section
		_tabs[key].set_pressed_no_signal(key == section)


func _build_game(column: VBoxContainer) -> void:
	_slider(column, "Mouse sensitivity", &"mouse_sensitivity", 0.0005, 0.008, 0.0001,
		func(v: float) -> String: return "%.2fx" % (v / 0.0022))
	_slider(column, "Gamepad look speed", &"gamepad_look_speed", 1.0, 6.0, 0.1,
		func(v: float) -> String: return "%.1f" % v)
	_slider(column, "Field of view", &"fov", 60, 110, 1, func(v: float) -> String: return "%d°" % int(v))
	_toggle(column, "Invert vertical look", &"invert_y")
	_toggle(column, "Cock the revolver automatically after a shot", &"auto_cock")
	_toggle(column, "Crouch is a toggle", &"toggle_crouch")


func _build_sound(column: VBoxContainer) -> void:
	for bus: String in ["Master", "Music", "SFX", "UI", "Ambience"]:
		var caption: String = {"SFX": "Guns and impacts", "UI": "Interface", "Ambience": "Wind"}.get(bus, bus)
		_slider(column, caption, StringName(bus.to_lower() + "_volume"), 0, 1, 0.05,
			func(v: float) -> String: return "%d%%" % roundi(v * 100))


func _build_picture(column: VBoxContainer) -> void:
	_toggle(column, "Full screen", &"fullscreen")
	_toggle(column, "Shadows", &"shadows")
	var row := _row(column, "Time of day")
	var choice := OptionButton.new()
	for caption: String in ["Sunset", "High noon", "Night, by lantern"]:
		choice.add_item(caption)
	choice.selected = maxi(TIMES.find(Settings.time_of_day), 0)
	choice.item_selected.connect(func(i: int) -> void: Settings.set_value(&"time_of_day", TIMES[i]))
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(choice)


func _build_controls() -> void:
	var column: VBoxContainer = _sections["Controls"]
	for child in column.get_children():
		child.queue_free()
	var note := FrontierUI.label(column, "Pick an action, then press a key, mouse button or gamepad button. Esc cancels.", 20, FrontierUI.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for action: String in ACTION_NAMES:
		if not InputMap.has_action(action):
			continue
		var name_label := FrontierUI.label(grid, ACTION_NAMES[action], 22)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := FrontierUI.button(grid, FrontierUI.action_text(action), func() -> void: pass)
		b.custom_minimum_size.x = 380
		b.clip_text = true
		b.pressed.connect(_listen.bind(action, b))
	FrontierUI.button(column, "RESTORE DEFAULT CONTROLS", func() -> void:
		Settings.reset_bindings()
		_build_controls()
	)


func _listen(action: String, button: Button) -> void:
	if _binding_button and _binding_action != "":
		_binding_button.text = FrontierUI.action_text(_binding_action)
	_binding_action = action
	_binding_button = button
	button.text = "Press a key..."


func _input(event: InputEvent) -> void:
	if _binding_action == "" or not event.is_pressed() or not is_visible_in_tree():
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if not (event is InputEventKey and event.keycode == KEY_ESCAPE):
			Settings.bind_action(_binding_action, event)
		_binding_button.text = FrontierUI.action_text(_binding_action)
		_binding_action = ""
		get_viewport().set_input_as_handled()


func _row(column: VBoxContainer, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var l := FrontierUI.label(row, caption, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size.x = 300
	return row


func _slider(column: VBoxContainer, caption: String, key: StringName, low: float, high: float, step: float, format: Callable) -> void:
	var row := _row(column, caption)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = Settings.get(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := FrontierUI.label(row, format.call(slider.value), 22)
	value.custom_minimum_size.x = 90
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		value.text = format.call(v)
	)


func _toggle(column: VBoxContainer, caption: String, key: StringName) -> void:
	var toggle := CheckButton.new()
	toggle.text = caption
	toggle.button_pressed = Settings.get(key)
	toggle.toggled.connect(func(on: bool) -> void:
		Settings.set_value(key, on)
		AudioManager.play_ui(&"ui")
	)
	column.add_child(toggle)
