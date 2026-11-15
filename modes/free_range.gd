class_name FreeRange
extends GameMode
## Sandbox: every target type, every gun, no clock and no save. Short range
## props up close, steel out to 200 m for the rifles.

const CUTOUT_INTERVAL := 3.0
const CLAY_INTERVAL := 6.0

var _cutouts: Array[CutoutTarget] = []
var _thrower: ClayThrower
var _cutout_timer := 2.0
var _clay_timer := 4.0


func _setup() -> void:
	environment.add_box(Vector3(1.6, 1.0, 0.6), Vector3(3.5, 0.5, -2.5), RangeEnvironment.TIMBER)
	environment.add_box(Vector3(0.9, 0.9, 0.9), Vector3(-3.5, 0.45, -2.0), RangeEnvironment.TIMBER)

	environment.add_table(Vector3(0, 0, -6.0))
	for i in 4:
		spawn_target(CanTarget, Vector3(-0.9 + i * 0.6, 0.9, -6.0))
	environment.add_fence(Vector3(0, 0, -10.0))
	for i in 7:
		spawn_target(BottleTarget, Vector3(-2.7 + i * 0.9, 1.05, -10.0))

	# Steel: pistol distances first, then rifle country.
	for spot: Array in [
		[Vector3(-4.0, 0, -15.0), 0.3], [Vector3(1.5, 0, -25.0), 0.3],
		[Vector3(6.0, 0, -40.0), 0.4], [Vector3(-5.0, 0, -60.0), 0.4],
		[Vector3(0.0, 0, -100.0), 0.5], [Vector3(7.0, 0, -150.0), 0.6],
		[Vector3(-6.0, 0, -200.0), 0.75],
	]:
		spawn_target(SteelPlateTarget, spot[0], 0.0, {"plate_radius": spot[1]})

	spawn_target(SpinnerTarget, Vector3(5.0, 0, -12.0))
	spawn_target(RailTarget, Vector3(-7.0, 0, -32.0), 0.0, {"travel": 5.0})
	spawn_target(RollingTarget, Vector3(-9.0, 0, -20.0), 0.0, {
		"distance": 18.0, "auto_roll": true, "repeat_delay": 5.0,
	})

	# Pop-ups behind a low wall: bandit, innocent, bandit.
	environment.add_box(Vector3(4.2, 1.1, 0.3), Vector3(-6.5, 0.55, -17.4), RangeEnvironment.TIMBER)
	for i in 3:
		var cutout := spawn_target(CutoutTarget, Vector3(-7.9 + i * 1.4, 0, -18.0), 0.0, {
			"is_innocent": i == 1, "up_time": 3.5,
		}) as CutoutTarget
		_cutouts.append(cutout)

	_thrower = ClayThrower.new()
	_thrower.position = Vector3(9.0, 0, -6.0)
	_thrower.rotation_degrees.y = 55.0
	add_child(_thrower)


func _tick(delta: float) -> void:
	_cutout_timer -= delta
	if _cutout_timer <= 0.0:
		_cutout_timer = CUTOUT_INTERVAL
		_cutouts.pick_random().pop_up()
	_clay_timer -= delta
	if _clay_timer <= 0.0:
		_clay_timer = CLAY_INTERVAL
		_thrower.throw()


func _should_save() -> bool:
	return false


func get_objective() -> String:
	return "No clock. Nothing is saved."


func get_status_text() -> String:
	return "Free Range: no clock, nothing saved. A clay flies every %d s." % int(CLAY_INTERVAL)
