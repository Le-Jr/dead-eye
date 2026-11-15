extends Node
## Visual check: runs the range in a window and saves captures of every
## weapon (hip, aimed, just fired, mid-reload) to user://shots/.
## Run:  godot --path . res://tests/screenshots.tscn

const RANGE := preload("res://modes/free_range.tscn")
const NAMES: Array[String] = ["revolver", "lever", "coach", "sharps"]

var _player: Player


func _ready() -> void:
	Settings.auto_cock = false
	DirAccess.make_dir_recursive_absolute("user://shots")
	var level := RANGE.instantiate()
	add_child(level)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = level.player
	await _wait(0.6)

	for i in _player.weapons.size():
		if i > 0:
			_player.switch_weapon(i)
			await _wait(Player.HOLSTER_TIME * 2.0 + 0.3)
		var weapon := _player.weapon
		_player.aim_at(Vector3(0.0, 1.2, -10.0))
		await _wait(0.3)
		await _capture("%s_1_hip" % NAMES[i])

		Input.action_press("aim")
		weapon.work_action()
		await _wait(0.8)
		await _capture("%s_2_ads" % NAMES[i])
		weapon.pull_trigger()
		await _wait(0.1)
		await _capture("%s_3_fired" % NAMES[i])
		Input.action_release("aim")
		await _wait(0.8)

		weapon.work_action()
		await _wait(weapon.data.cock_time * 0.5)
		await _capture("%s_4_action" % NAMES[i])
		await _wait(weapon.data.cock_time)
		weapon.start_reload()
		await _wait(weapon.data.reload_open_time + weapon.data.reload_insert_time * 0.6)
		await _capture("%s_5_reload" % NAMES[i])
		weapon.interrupt_reload()
		await _wait(2.0)
	get_tree().quit()


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
