extends Node
## In-game captures of each weapon at the hip, aimed, and at four moments
## after a shot, for judging the hands, the sight picture and the smoke.
##   godot --path . --resolution 1280x720 res://tests/shot_review.tscn -- 0
## The number picks one weapon (0-3); leave it out for all four. Add a time
## of day (noon, sunset, night) to override the saved setting.
## Writes output/review/shot_<weapon>_<stage>.png.

const SMOKE_TIMES := [0.07, 0.4, 1.1, 2.4]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/review")
	var only := -1
	var time_of_day := ""
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			only = int(arg) if int(arg) in range(4) else -1
		else:
			time_of_day = arg
	var range_scene := preload("res://modes/free_range.tscn").instantiate()
	add_child(range_scene)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player: Player = range_scene.player
	player.sway_enabled = false
	if time_of_day:
		range_scene.environment.set_time_of_day(time_of_day)
	for i in 4:
		if only >= 0 and i != only:
			continue
		player.switch_weapon(i)
		await _wait(1.0)
		await _capture(i, "hip")
		Input.action_press("aim")
		await _wait(0.7)
		await _capture(i, "aim")
		Input.action_release("aim")
		await _wait(0.5)
		var weapon: Weapon = player.weapon
		weapon.refill()
		weapon.work_action()
		while not weapon.is_idle():
			await get_tree().process_frame
		weapon.pull_trigger()
		var elapsed := 0.0
		for n in SMOKE_TIMES.size():
			await _wait(SMOKE_TIMES[n] - elapsed)
			elapsed = SMOKE_TIMES[n]
			await _capture(i, "smoke%d" % n)
		await _wait(2.5)
	await AudioManager.shutdown()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _capture(weapon: int, stage: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/review/shot_%d_%s.png" % [weapon, stage])
