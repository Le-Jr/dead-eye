extends Node
## User settings, persisted to user://settings.cfg.
## Read properties directly; write through set_value() so listeners and the
## file stay in sync.

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const SECTION := "settings"
const KEYS: Array[StringName] = [
	&"mouse_sensitivity", &"invert_y", &"fov", &"gamepad_look_speed",
	&"auto_cock", &"auto_cock_delay", &"toggle_crouch",
	&"master_volume", &"music_volume", &"sfx_volume", &"ui_volume", &"ambience_volume", &"shadows",
	&"time_of_day", &"fullscreen",
]

## Radians of rotation per pixel of mouse movement.
var mouse_sensitivity := 0.0022
var invert_y := false
## Vertical hip-fire field of view, in degrees.
var fov := 80.0
## Radians per second at full stick deflection.
var gamepad_look_speed := 2.8
## Re-cock the revolver automatically after each shot (slower than by hand).
var auto_cock := true
var auto_cock_delay := 0.35
var toggle_crouch := false
var master_volume := .8
var music_volume := .55
var sfx_volume := .8
var ui_volume := .7
var ambience_volume := .45
var shadows := true
var time_of_day := "sunset"
var fullscreen := false


func _ready() -> void:
	_add_dead_eye_action()
	load_settings()
	_apply_window()
	_load_bindings()


func _add_dead_eye_action() -> void:
	if not InputMap.has_action("dead_eye"):
		InputMap.add_action("dead_eye")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_V
		InputMap.action_add_event("dead_eye",key)
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_RIGHT_STICK
		InputMap.action_add_event("dead_eye",button)


func _load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for action in cfg.get_section_keys("bindings") if cfg.has_section("bindings") else PackedStringArray():
			var event: Variant = cfg.get_value("bindings", action)
			if InputMap.has_action(action):
				if event is InputEvent:
					_replace_binding(action, event)
				elif event is Array and not event.is_empty():
					InputMap.action_erase_events(action)
					for binding in event:
						if binding is InputEvent:
							InputMap.action_add_event(action,binding)

func _replace_binding(action: String, event: InputEvent) -> void:
	# Keyboard and mouse share one slot per action, the gamepad has its own.
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	for old in InputMap.action_get_events(action):
		if (old is InputEventJoypadButton or old is InputEventJoypadMotion) == is_pad:
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, event)

func bind_action(action: String, event: InputEvent) -> void:
	_replace_binding(action, event)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("bindings", action, InputMap.action_get_events(action))
	cfg.save(PATH)


## Puts every action back to the project defaults and forgets saved bindings.
func reset_bindings() -> void:
	InputMap.load_from_project_settings()
	_add_dead_eye_action()
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	if cfg.has_section("bindings"):
		cfg.erase_section("bindings")
	cfg.save(PATH)


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted and (fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
		DisplayServer.window_set_mode(wanted)


func set_value(key: StringName, value: Variant) -> void:
	if key not in KEYS:
		push_warning("Settings: unknown key '%s'" % key)
		return
	set(key, value)
	if key == &"fullscreen":
		_apply_window()
	changed.emit(key)
	save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in KEYS:
		if cfg.has_section_key(SECTION, key):
			var value: Variant = cfg.get_value(SECTION, key)
			if typeof(value) == typeof(get(key)):
				set(key, value)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for key in KEYS:
		cfg.set_value(SECTION, key, get(key))
	cfg.save(PATH)
