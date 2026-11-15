extends Node
## Headless end-to-end check of phase 3: scoring rules, the new target
## types, ricochets, the Gallery and Quick Draw modes, and saving.
## Run:  godot --headless --path . res://tests/phase3_smoke.tscn

const GALLERY := preload("res://modes/gallery.tscn")
const QUICK_DRAW := preload("res://modes/quick_draw.tscn")
const SAVE_PATH := "user://test_save.json"

var _failures := 0
var _mode: GameMode
var _player: Player
var _gun: Revolver
var _events: Array[Dictionary] = []


func _ready() -> void:
	Settings.auto_cock = false  # in memory only
	Wind.set_wind(Vector3.RIGHT, 0.0, 0.0)
	SaveSystem.path = SAVE_PATH  # never touch the real save
	SaveSystem.clear()
	GameState.scored.connect(func(event: Dictionary) -> void: _events.append(event))

	_test_scoring_rules()
	await _test_targets()
	await _test_gallery()
	await _test_quick_draw()
	_test_save_file()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("PHASE 3 SMOKE: %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures else 0)


func _test_scoring_rules() -> void:
	GameState.reset()
	for i in 4:
		GameState.register_hit(null, &"body", 100)
	_check(GameState.score == 400 and GameState.combo == 4, "four plain hits: 400 points, combo 4")
	GameState.register_hit(null, &"body", 100)
	_check(GameState.score == 550, "fifth hit in a row is worth x1.5 (%d)" % GameState.score)
	GameState.register_miss()
	_check(GameState.combo == 0 and GameState.max_combo == 5, "a miss breaks the combo, max combo kept")

	_events.clear()
	GameState.register_hit(null, &"juggle", 100)
	var tags: PackedStringArray = _events[0].tags
	_check(tags.has("TRICK SHOT!") and tags.has("JUGGLE"), "juggle is tagged as a trick shot")
	_check(is_equal_approx(GameState.style, 1.25), "trick shots raise the style multiplier")
	_check(_events[0].points == 125 + GameState.TRICK_BONUS, "trick: base x style + flat bonus (%d)" % _events[0].points)

	var long := BulletHit.new()
	long.distance = 150.0
	long.aimed = true
	_events.clear()
	GameState.register_hit(null, &"bullseye", 200, long)
	tags = _events[0].tags
	_check(tags.has("BULLSEYE!") and tags.has("LONG SHOT"), "150 m bullseye: BULLSEYE! + LONG SHOT")

	var before := GameState.score
	GameState.register_hit(null, &"body", -250)
	_check(GameState.score == before - 250, "an innocent costs points")
	_check(GameState.combo == 0 and GameState.style == 1.0 and GameState.innocents_hit == 1, "...and wipes combo and style")
	_check(GameState.get_accuracy() == 0.0, "accuracy is 0 with no shots fired")


func _test_targets() -> void:
	# A bare mode: environment and player, no targets of its own.
	_mode = GameMode.new()
	_mode.countdown = 0.0
	await _enter(_mode)

	# --- Cutouts ---
	var bandit := _mode.spawn_target(CutoutTarget, Vector3(0, 0, -8)) as CutoutTarget
	var innocent := _mode.spawn_target(CutoutTarget, Vector3(2, 0, -8), 0.0, {
		"is_innocent": true, "starts_up": true,
	}) as CutoutTarget
	var shy := _mode.spawn_target(CutoutTarget, Vector3(-2, 0, -8), 0.0, {"up_time": 0.4}) as CutoutTarget
	await _wait(0.2)
	_check(not bandit.is_up and not bandit.is_active, "cutout starts ducked")
	var hits := GameState.shots_hit
	await _fire_at(Vector3(0, 1.0, -8))
	_check(GameState.shots_hit == hits, "a ducked cutout cannot be hit")
	bandit.pop_up()
	await _wait(0.3)
	_events.clear()
	await _fire_at(Vector3(0, 1.52, -8))
	_check(_last_zone() == &"head" and _events[0].base == 200, "bandit headshot scores double")
	_check(not bandit.is_up, "a shot bandit goes down")

	var score := GameState.score
	await _fire_at(Vector3(2, 1.0, -8))
	_check(GameState.score == score - innocent.innocent_penalty, "shooting the innocent costs %d" % innocent.innocent_penalty)

	var timed_out := {"value": false}
	shy.dropped.connect(func(was_hit: bool) -> void: timed_out.value = not was_hit)
	shy.pop_up()
	await _wait(0.8)
	_check(not shy.is_up and timed_out.value, "a cutout ducks again after its up-time")

	# --- Rail target (parked, so the rings can be checked exactly) ---
	var rail := _mode.spawn_target(RailTarget, Vector3(5, 0, -12), 0.0, {"travel": 0.0}) as RailTarget
	await _wait(0.2)
	var center := Vector3(5, rail.height, -12)
	for ring: Array in [[0.0, &"bullseye"], [0.45, &"inner"], [0.85, &"outer"]]:
		_events.clear()
		await _fire_at(center + Vector3.RIGHT * rail.radius * ring[0])
		_check(_last_zone() == ring[1], "rail target ring at %.0f%% radius is '%s'" % [ring[0] * 100.0, ring[1]])
	rail.travel = 4.0
	await _wait(0.5)
	var disc: Node3D = rail.find_children("*", "AnimatableBody3D", true, false)[0]
	_check(absf(disc.global_position.x - 5.0) > 0.1, "rail target moves along its rail")

	# --- Spinner: synthetic heavy hit on the big paddle sends it over ---
	var spinner := _mode.spawn_target(SpinnerTarget, Vector3(-5, 0, -8)) as SpinnerTarget
	await _wait(0.2)
	var spun := {"value": false}
	spinner.spun_over.connect(func() -> void: spun.value = true)
	var paddle := Vector3(-5, spinner.axle_height - spinner.arm_length, -8)
	await _fire_at(paddle)
	_check(spinner.angular_velocity > 1.0, "a hit on the low paddle kicks the spinner round")
	_check(not spun.value, "one revolver hit is not enough to send it over the top")
	var heavy := BulletHit.new()
	heavy.position = spinner.to_global(Vector3(0, spinner.axle_height - spinner.arm_length, 0))
	heavy.direction = Vector3.FORWARD
	heavy.damage = 250.0
	heavy.ricochet = true  # keep this one from bouncing into other targets
	var tricks := GameState.trick_shots
	spinner.take_hit(heavy)
	await _wait(1.2)
	_check(spun.value and GameState.trick_shots > tricks, "going all the way round pays a trick-shot bonus")

	# --- Rolling target ---
	var roller := _mode.spawn_target(RollingTarget, Vector3(-4, 0, -14), 0.0, {
		"distance": 8.0, "speed": 3.0,
	}) as RollingTarget
	await _wait(0.2)
	_check(not roller.is_active, "the wheel is not a target until it is rolled")
	roller.roll()
	await _wait(0.5)
	var wheel := roller.get_child(0) as Node3D
	_check(wheel.global_position.x > -3.5, "the wheel rolls along its lane")
	var knocked := {"value": false}
	roller.destroyed.connect(func() -> void: knocked.value = true)
	await _prepare_shot()
	_player.aim_at(wheel.global_position)
	_gun.pull_trigger()
	await _wait(_gun.data.fire_interval + 0.05)
	_check(knocked.value and not roller.is_rolling, "a rolling wheel can be shot down")
	var out := {"value": false}
	roller.rolled_out.connect(func() -> void: out.value = true)
	roller.roll()
	await _wait(3.0)
	_check(out.value, "an unhit wheel rolls out of the lane")

	# --- Clay ---
	var thrower := ClayThrower.new()
	thrower.position = Vector3(6, 0, -8)
	thrower.rotation_degrees.y = 60.0
	thrower.scatter_deg = 0.0
	_mode.add_child(thrower)
	await _prepare_shot()
	var clay := thrower.throw()
	await _wait(0.45)
	_check(clay.global_position.y > 2.0, "the clay climbs out of the trap")
	_events.clear()
	_player.aim_at(clay.global_position)
	_gun.pull_trigger()
	await _wait(0.1)
	var tags: PackedStringArray = _events[0].tags if not _events.is_empty() else PackedStringArray()
	_check(tags.has("MID-AIR") and tags.has("TRICK SHOT!"), "a clay hit in flight is a mid-air trick shot (%s)" % [tags])
	_check(not is_instance_valid(clay) or clay.is_queued_for_deletion(), "the clay breaks")
	var missed := {"value": false}
	var second := thrower.throw()
	second.missed.connect(func() -> void: missed.value = true)
	await _wait(4.0)
	_check(missed.value, "an unhit clay breaks on the ground as a miss")

	# --- Ricochet: a bullet glancing off one plate into another ---
	var plate_a := _mode.spawn_target(SteelPlateTarget, Vector3(9, 0, -20)) as SteelPlateTarget
	var plate_b := _mode.spawn_target(SteelPlateTarget, Vector3(9, 0, -17)) as SteelPlateTarget
	await _wait(0.2)
	var b_center := plate_b.global_position + Vector3.UP * (plate_b.frame_height - 0.05 - plate_b.hang_length - plate_b.plate_radius)
	var glance := BulletHit.new()
	glance.position = b_center + Vector3(0, 0, -3.0)
	glance.normal = Vector3.BACK
	glance.direction = Vector3.FORWARD  # bounces straight back along +Z
	glance.damage = 40.0
	glance.distance = 20.0
	glance.collider = plate_a.find_children("*", "AnimatableBody3D", true, false)[0]
	_events.clear()
	Weapon.ricochet(_mode, glance)
	tags = _events[0].tags if not _events.is_empty() else PackedStringArray()
	_check(_events.size() == 1 and _events[0].target == plate_b, "a ricochet carries to the next target")
	_check(tags.has("RICOCHET"), "...and scores as a RICOCHET trick shot (%s)" % [tags])

	await _leave()


func _test_gallery() -> void:
	var gallery := GALLERY.instantiate() as Gallery
	gallery.time_limit = 4.0
	gallery.countdown = 0.3
	gallery.pop_interval_start = 0.5
	gallery.pop_interval_end = 0.5
	gallery.roller_interval = 1.0
	gallery.clay_schedule = {1.0: 2}
	gallery.star_thresholds = [50.0, 1.0e6, 2.0e6]
	_mode = gallery
	await _enter(gallery)
	_check(gallery.state == GameMode.State.COUNTDOWN and _player.weapons_locked, "gallery: guns locked during the countdown")
	await _until(func() -> bool: return gallery.state == GameMode.State.PLAYING, 2.0)
	_check(not _player.weapons_locked, "gallery: guns free when the clock starts")
	var bottle := _first(BottleTarget)
	await _fire_at(bottle.global_position + Vector3.UP * 0.12)
	_check(GameState.score >= 100, "gallery: a bottle scores")
	await _until(func() -> bool: return gallery.state == GameMode.State.FINISHED, 6.0)
	_check(gallery.state == GameMode.State.FINISHED, "gallery: ends when the clock runs out")
	var result := gallery.result
	_check(result.score == GameState.score and result.score >= 100, "gallery: result carries the score (%s)" % result.score)
	_check(result.stars == 1, "gallery: star rating from thresholds (%s)" % result.stars)
	_check(gallery.cutouts_popped >= 3, "gallery: director popped cutouts (%d)" % gallery.cutouts_popped)
	_check(gallery.clays_thrown == 2, "gallery: director threw the scheduled clays (%d)" % gallery.clays_thrown)
	_check(gallery.rollers_sent >= 1, "gallery: director sent a wheel (%d)" % gallery.rollers_sent)
	_check(gallery.is_new_best, "gallery: first run is a new best")
	_check(int(SaveSystem.get_record(&"gallery").score) == result.score, "gallery: best score saved")
	_check(_player.weapons_locked, "gallery: guns locked after the finish")
	await _leave()

	# A worse run must not replace the record, but still counts as a play.
	SaveSystem.submit(&"gallery", {"score": 10, "stars": 0})
	var record := SaveSystem.get_record(&"gallery")
	_check(int(record.score) == result.score and int(record.plays) == 2, "a lower score keeps the old record (plays %s)" % record.get("plays"))
	_check(SaveSystem.get_stars(&"gallery") == 1, "best star rating is kept")


func _test_quick_draw() -> void:
	var duel := QUICK_DRAW.instantiate() as QuickDraw
	duel.countdown = 0.2
	duel.rounds = 3
	duel.min_wait = 0.4
	duel.max_wait = 0.4
	duel.shot_limit = 1.3
	duel.pause_between_rounds = 0.3
	_mode = duel
	await _enter(duel)
	var times: Array[float] = []
	duel.round_finished.connect(func(_n: int, ms: float) -> void: times.append(ms))
	var chest := Vector3(0, 1.0, -duel.opponent_distance)

	# Round 1: clean draw.
	await _until(func() -> bool: return duel.phase == QuickDraw.Phase.STEADY, 3.0)
	_check(_player.is_fully_holstered() and not _gun.input_enabled, "duel: gun holstered while waiting")
	_check(duel.opponent.is_up, "duel: the other man is standing")
	await _until(func() -> bool: return duel.phase == QuickDraw.Phase.DRAW, 3.0)
	await _draw_and_fire(chest)
	_check(times.size() == 1 and times[0] > 250.0 and times[0] < 1300.0, "duel: reaction time measured (%s ms)" % [times])

	# Round 2: jump the bell, then shoot clean. The foul adds 500 ms.
	await _until(func() -> bool: return duel.round_number == 2 and duel.phase == QuickDraw.Phase.STEADY, 3.0)
	_player.draw()
	_check(duel.fouls == 1 and duel.phase == QuickDraw.Phase.HOLSTERING, "duel: drawing before the bell is a foul")
	await _until(func() -> bool: return duel.phase == QuickDraw.Phase.DRAW, 4.0)
	await _draw_and_fire(chest)
	_check(times.size() == 2 and times[1] > times[0] + 300.0, "duel: the foul penalty is added to the round (%s ms)" % [times])

	# Round 3: freeze. He shoots first.
	await _until(func() -> bool: return duel.round_number == 3 and duel.phase == QuickDraw.Phase.DRAW, 4.0)
	await _until(func() -> bool: return duel.state == GameMode.State.FINISHED, 4.0)
	_check(times.size() == 3 and not is_finite(times[2]), "duel: too slow loses the round")
	var result := duel.result
	_check(result.rounds == 3 and result.wins == 2 and result.fouls == 1, "duel: result %s" % result)
	_check(result.best_ms == roundi(times[0]), "duel: best reaction reported")
	_check(int(SaveSystem.get_record(&"quick_draw").score) == result.score, "duel: rated time saved")
	SaveSystem.submit(&"quick_draw", {"score": result.score + 400}, true)
	_check(int(SaveSystem.get_record(&"quick_draw").score) == result.score, "duel: a slower run keeps the record (lower is better)")
	await _leave()


func _test_save_file() -> void:
	var gallery_score := int(SaveSystem.get_record(&"gallery").score)
	SaveSystem.load_save()
	_check(int(SaveSystem.get_record(&"gallery").score) == gallery_score, "records survive a reload from disk")
	_check(SaveSystem.get_record(&"nonexistent").is_empty(), "unknown challenge has no record")


# --- Helpers --------------------------------------------------------------

func _enter(mode: GameMode) -> void:
	add_child(mode)
	_player = mode.player
	_player.sway_enabled = false
	_gun = _player.weapon as Revolver
	_gun.data = _gun.data.duplicate()
	_gun.data.spread_deg = 0.0
	_gun.data.move_spread_deg = 0.0
	await _wait(0.2)


func _leave() -> void:
	_mode.queue_free()
	await _wait(0.2)


## Cock, let the recoil settle, and wait until the gun can fire.
func _prepare_shot() -> void:
	if not _gun.hammer_cocked:
		_gun.work_action()
		await _wait(_gun.data.cock_time + 0.03)
	await _wait(_gun.data.recoil_duration)
	if _gun.get_ammo() == 0:
		_gun.refill()
		_gun.work_action()
		await _wait(_gun.data.cock_time + 0.03)


func _fire_at(point: Vector3) -> void:
	await _prepare_shot()
	_player.aim_at(point)
	await get_tree().physics_frame
	_gun.pull_trigger()
	await _wait(_gun.data.fire_interval + 0.05)


func _draw_and_fire(point: Vector3) -> void:
	_player.draw()
	await _wait(Player.HOLSTER_TIME + _gun.data.cock_time + 0.1)
	_player.aim_at(point)
	await get_tree().physics_frame
	_gun.pull_trigger()
	await _wait(0.1)


func _last_zone() -> StringName:
	return _events[-1].zone if not _events.is_empty() else &""


func _first(type: Variant) -> Node3D:
	for node in get_tree().get_nodes_in_group(&"targets"):
		if is_instance_of(node, type) and _mode.is_ancestor_of(node):
			return node
	return null


func _until(condition: Callable, timeout: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok    ", what)
	else:
		_failures += 1
		printerr("  FAIL  ", what)
