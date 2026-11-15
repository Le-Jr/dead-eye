class_name Gallery
extends GameMode
## The timed course. Bottles, cans and steel are always there to keep a combo
## alive; on top of that a director pops bandits (and innocents) from behind
## cover, bowls wagon wheels across the lane and throws clays, all faster as
## the clock runs down. Score is everything: combo, style and trick shots.

## 0 = a different course every run.
@export var course_seed := 0
## Seconds between pop-ups at the start and at the end of the run.
@export var pop_interval_start := 2.2
@export var pop_interval_end := 1.1
@export var pop_up_time := 2.4
@export var roller_interval := 14.0
## Times (seconds into the run) and how many clays fly at each.
@export var clay_schedule := {20.0: 1, 32.0: 2, 46.0: 2, 60.0: 2, 72.0: 3, 84.0: 2}

## How many of each the director has sent, for the results.
var cutouts_popped := 0
var clays_thrown := 0
var rollers_sent := 0

var _rng := RandomNumberGenerator.new()
var _cutouts: Array[CutoutTarget] = []
var _roller: RollingTarget
var _throwers: Array[ClayThrower] = []
var _pop_timer := 1.0
var _roller_timer := 0.0
var _clays_due: Array[float] = []
var _clay_queue := 0
var _clay_gap := 0.0


func _setup() -> void:
	if course_seed != 0:
		_rng.seed = course_seed
	var timber := RangeEnvironment.TIMBER

	environment.add_table(Vector3(0, 0, -5.0))
	for i in 4:
		spawn_target(CanTarget, Vector3(-0.9 + i * 0.6, 0.9, -5.0))
	environment.add_fence(Vector3(0, 0, -9.0))
	for i in 7:
		spawn_target(BottleTarget, Vector3(-2.7 + i * 0.9, 1.05, -9.0), 0.0, {"respawn_time": 6.0})

	# Front cover: three crates, two figures behind each. "I" = innocent.
	var front := "BIBBIB"
	for i in 3:
		var x := -5.0 + i * 5.0
		environment.add_box(Vector3(1.9, 1.1, 0.5), Vector3(x, 0.55, -14.0), timber)
		for j in 2:
			_add_cutout(Vector3(x - 0.45 + j * 0.9, 0, -14.7), front[i * 2 + j] == "I")
	# Back cover: four crates, one figure each.
	var back := "BBIB"
	for i in 4:
		var x := -7.5 + i * 5.0
		environment.add_box(Vector3(1.2, 1.1, 0.5), Vector3(x, 0.55, -24.0), timber)
		_add_cutout(Vector3(x, 0, -24.7), back[i] == "I")

	spawn_target(SteelPlateTarget, Vector3(-9.0, 0, -18.0), 0.0, {"plate_radius": 0.3})
	spawn_target(SteelPlateTarget, Vector3(9.0, 0, -30.0), 0.0, {"plate_radius": 0.35})
	spawn_target(SpinnerTarget, Vector3(8.0, 0, -11.0))
	spawn_target(RailTarget, Vector3(0, 0, -34.0), 0.0, {"travel": 10.0, "speed": 2.6})
	_roller = spawn_target(RollingTarget, Vector3(-10.0, 0, -19.0), 0.0, {"distance": 20.0}) as RollingTarget

	for side: float in [-1.0, 1.0]:
		var thrower := ClayThrower.new()
		thrower.position = Vector3(side * 10.0, 0, -7.0)
		thrower.rotation_degrees.y = side * 55.0
		add_child(thrower)
		_throwers.append(thrower)

	# First wheel a little early, so the lane is not dead for a full interval.
	_roller_timer = roller_interval * 0.7
	for time: float in clay_schedule:
		_clays_due.append(time)
	_clays_due.sort()


func _tick(delta: float) -> void:
	var progress := clampf(elapsed / maxf(time_limit, 1.0), 0.0, 1.0)

	_pop_timer -= delta
	if _pop_timer <= 0.0:
		_pop_timer = lerpf(pop_interval_start, pop_interval_end, progress)
		_pop_random_cutout()

	_roller_timer -= delta
	if _roller_timer <= 0.0:
		_roller_timer = roller_interval
		if not _roller.is_rolling:
			_roller.roll()
			rollers_sent += 1

	if not _clays_due.is_empty() and elapsed >= _clays_due[0]:
		_clay_queue += int(clay_schedule[_clays_due.pop_front()])
	if _clay_queue > 0:
		_clay_gap -= delta
		if _clay_gap <= 0.0:
			# Alternate sides so a pair crosses in front of the shooter.
			_throwers[clays_thrown % _throwers.size()].throw()
			clays_thrown += 1
			_clay_queue -= 1
			_clay_gap = 0.7


func _build_result() -> Dictionary:
	var stats := super()
	stats["cutouts_popped"] = cutouts_popped
	stats["clays_thrown"] = clays_thrown
	stats["rollers_sent"] = rollers_sent
	return stats


func get_objective() -> String:
	return "Spare the innocent" if state == State.PLAYING else "90 seconds. Chain your hits."


func get_status_text() -> String:
	match state:
		State.COUNTDOWN:
			return "%s starts in %d..." % [display_name, ceili(get_countdown())]
		State.PLAYING:
			return "%s   %.0f s left" % [display_name, time_left]
	return display_name


func _add_cutout(at: Vector3, innocent: bool) -> void:
	var cutout := spawn_target(CutoutTarget, at, 0.0, {
		"is_innocent": innocent, "up_time": pop_up_time,
	}) as CutoutTarget
	_cutouts.append(cutout)


func _pop_random_cutout() -> void:
	var down: Array[CutoutTarget] = []
	for cutout in _cutouts:
		if not cutout.is_up:
			down.append(cutout)
	if down.is_empty():
		return
	down[_rng.randi() % down.size()].pop_up()
	cutouts_popped += 1
