extends SceneTree
## Writes the default input map into project.godot.
## Run:  godot --headless --path . -s tools/setup_input_map.gd
## Re-run after editing the table below. Player remaps are stored separately
## in user:// by the Settings autoload, so this only defines the defaults.


func _init() -> void:
	var actions := {
		"move_forward": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_back": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"look_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"look_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"look_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		"look_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"sprint": [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK)],
		"crouch": [_key(KEY_CTRL), _key(KEY_C), _button(JOY_BUTTON_B)],
		"fire": [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"aim": [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		# Cocking shares RMB with aim on purpose: raising the gun thumbs the hammer.
		"cock_hammer": [
			_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_F),
			_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _button(JOY_BUTTON_Y),
		],
		"alt_fire": [
			_key(KEY_ALT), _mouse(MOUSE_BUTTON_XBUTTON1),
			_button(JOY_BUTTON_RIGHT_SHOULDER),
		],
		"reload": [_key(KEY_R), _button(JOY_BUTTON_X)],
		"weapon_1": [_key(KEY_1)],
		"weapon_2": [_key(KEY_2)],
		"weapon_3": [_key(KEY_3)],
		"weapon_4": [_key(KEY_4)],
		"weapon_next": [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _button(JOY_BUTTON_DPAD_RIGHT)],
		"weapon_prev": [_mouse(MOUSE_BUTTON_WHEEL_UP), _button(JOY_BUTTON_DPAD_LEFT)],
		# Rifle sight elevation. The wheel does the same while aiming.
		"sight_up": [_key(KEY_E), _button(JOY_BUTTON_DPAD_UP)],
		"sight_down": [_key(KEY_Q), _button(JOY_BUTTON_DPAD_DOWN)],
		# Holster / draw. While holstered, fire and aim also draw.
		"holster": [_key(KEY_H), _button(JOY_BUTTON_BACK)],
		"pause": [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)],
	}
	# Drop actions that were renamed or removed from the table.
	for property in ProjectSettings.get_property_list():
		var path: String = property.name
		var is_ours := path.begins_with("input/") and not path.begins_with("input/ui_")
		if is_ours and not actions.has(path.trim_prefix("input/")):
			ProjectSettings.set_setting(path, null)
	for action: String in actions:
		ProjectSettings.set_setting(
			"input/" + action, {"deadzone": 0.25, "events": actions[action]}
		)
	var err := ProjectSettings.save()
	print("input map written: %d actions (err=%d)" % [actions.size(), err])
	quit(0 if err == OK else 1)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = button
	return e


func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = button
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e
