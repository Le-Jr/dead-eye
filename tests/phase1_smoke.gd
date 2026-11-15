extends Node
## Headless end-to-end check of phase 1. Loads the greybox range and drives
## the revolver through its public API.
## Run:  godot --headless --path . res://tests/phase1_smoke.tscn

const RANGE := preload("res://modes/free_range.tscn")

var _failures := 0
var _level: Node3D
var _player: Player
var _gun: Revolver


func _ready() -> void:
	Settings.auto_cock = false  # in memory only; drive the hammer by hand
	_level = RANGE.instantiate()
	add_child(_level)
	_player = _level.player
	_gun = _player.weapon as Revolver
	_player.sway_enabled = false
	_gun.data = _gun.data.duplicate()
	_gun.data.spread_deg = 0.0
	_gun.data.move_spread_deg = 0.0
	await _wait(0.3)

	await _test_single_action()
	await _test_bottle()
	await _test_steel_plate()
	await _test_can_juggle()
	await _test_empty_and_reload()
	await _test_fanning()
	await _test_auto_cock()
	await _test_crouch()

	print("PHASE 1 SMOKE: %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures else 0)


func _test_single_action() -> void:
	_check(_gun.get_ammo() == 6, "starts with 6 rounds")
	_check(not _gun.hammer_cocked, "hammer starts down")
	var shots := GameState.shots_fired
	_gun.pull_trigger()
	await _wait(0.1)
	_check(GameState.shots_fired == shots, "trigger does nothing with the hammer down")
	var index := _gun.chamber_index
	_check(_gun.work_action(), "work_action() accepted")
	await _wait(_gun.data.cock_time + 0.05)
	_check(_gun.hammer_cocked, "hammer cocked after cock_time")
	_check(_gun.chamber_index == (index + 1) % 6, "cocking advanced the cylinder")
	_check(not _gun.work_action(), "cannot cock twice")


func _test_bottle() -> void:
	var bottle := _first(BottleTarget) as BottleTarget
	var result := {"zone": &"", "destroyed": false}
	bottle.hit.connect(func(zone: StringName, _p: int) -> void: result.zone = zone)
	bottle.destroyed.connect(func() -> void: result.destroyed = true)
	var score := GameState.score
	await _aim_and_fire(bottle.global_position + Vector3.UP * 0.12, false)
	_check(result.destroyed, "bottle shattered")
	_check(GameState.score == score + bottle.base_points, "bottle scored %d" % bottle.base_points)
	_check(_gun.get_ammo() == 5, "one round spent")
	_check(not _gun.hammer_cocked, "hammer down after firing")
	_check(not bottle.is_active, "bottle inactive until respawn")


func _test_steel_plate() -> void:
	var plate := _first(SteelPlateTarget) as SteelPlateTarget
	var zones: Array[StringName] = []
	plate.hit.connect(func(zone: StringName, _p: int) -> void: zones.append(zone))
	var center := plate.global_position + Vector3.UP * (
		plate.frame_height - 0.05 - plate.hang_length - plate.plate_radius
	)
	await _aim_and_fire(center)
	_check(zones == [&"bullseye"], "plate center is a bullseye (got %s)" % [zones])
	_check(plate.swing_velocity > 0.5, "plate swings away from the shooter")
	await _aim_and_fire(center + Vector3.RIGHT * plate.plate_radius * 0.7)
	_check(zones.size() == 2 and zones[1] == &"plate", "plate edge is a plain hit (got %s)" % [zones])
	var hits := GameState.shots_hit
	await _aim_and_fire(plate.global_position + Vector3(plate.plate_radius + 0.3, 1.0, 0.0))
	_check(GameState.shots_hit == hits, "frame post is not a target hit")


func _test_can_juggle() -> void:
	var can := _first(CanTarget) as CanTarget
	var zones: Array[StringName] = []
	can.hit.connect(func(zone: StringName, _p: int) -> void: zones.append(zone))
	await _aim_and_fire(can.get_body().global_position)
	await _wait(0.15)
	_check(zones == [&"body"], "resting can hit scores as body")
	_check(can.get_body().linear_velocity.y > 1.0, "can pops upward")
	# Track it in the air and hit it again.
	_gun.work_action()
	await _wait(_gun.data.cock_time + 0.03)
	_player.aim_at(can.get_body().global_position)
	await get_tree().physics_frame
	_player.aim_at(can.get_body().global_position)
	_gun.pull_trigger()
	await _wait(_gun.data.fire_interval + 0.05)
	_check(zones.size() == 2 and zones[1] == &"juggle", "mid-air hit scores as juggle (got %s)" % [zones])
	_check(can.juggle_count == 1, "juggle count is 1")


func _test_empty_and_reload() -> void:
	# Fire whatever is left into the berm, then check the dry fire.
	var guard := 0
	while _gun.get_ammo() > 0 and guard < 12:
		await _aim_and_fire(Vector3(0, 3, -60))
		guard += 1
	_check(_gun.get_ammo() == 0, "cylinder emptied")
	var dry := {"count": 0}
	_gun.dry_fired.connect(func() -> void: dry.count += 1)
	var shots := GameState.shots_fired
	await _aim_and_fire(Vector3(0, 3, -60))
	_check(dry.count == 1 and GameState.shots_fired == shots, "empty chamber clicks, no shot")

	_gun.start_reload()
	_check(_gun.is_reloading(), "reload started")
	_check(not _gun.can_ads(), "no ADS while reloading")
	var d := _gun.data
	var per_round := d.reload_eject_time + d.reload_insert_time
	await _wait(d.reload_open_time + per_round * 2.0 + 0.1)
	_gun.interrupt_reload()
	await _wait(per_round + d.reload_close_time + 0.2)
	_check(not _gun.is_reloading(), "interrupted reload closes the gate")
	var partial := _gun.get_ammo()
	_check(partial >= 2 and partial <= 4, "interrupt kept the rounds already loaded (%d)" % partial)
	await _aim_and_fire(Vector3(0, 3, -60))
	_check(_gun.get_ammo() == partial - 1, "first cock after a partial reload finds a live round")

	_gun.start_reload()
	await _wait(d.reload_open_time + per_round * 6.0 + d.reload_close_time + 0.3)
	_check(_gun.get_ammo() == 6 and not _gun.is_reloading(), "full reload gives 6 rounds")
	_check(_gun.chambers.count(Revolver.Chamber.SPENT) == 0, "no spent cases left")


func _test_fanning() -> void:
	var shots := GameState.shots_fired
	for i in 3:
		_gun.alt_fire(true)
		await _wait(_gun.data.fan_interval + 0.05)
	_check(GameState.shots_fired == shots + 3, "three fanned shots")
	_check(_gun.get_ammo() == 3, "fanning used three rounds")


func _test_auto_cock() -> void:
	Settings.auto_cock = true
	_gun.pull_trigger()  # hammer down: auto-cock thumbs it back
	await _wait(_gun.data.cock_time + 0.05)
	_check(_gun.hammer_cocked, "auto-cock: trigger on a lowered hammer cocks it")
	_gun.pull_trigger()
	await _wait(_gun.data.fire_interval + Settings.auto_cock_delay + _gun.data.cock_time + 0.1)
	_check(_gun.hammer_cocked, "auto-cock: hammer re-cocked after the shot")
	Settings.auto_cock = false


func _test_crouch() -> void:
	var eye := _player.camera.global_position.y
	_player.controls_enabled = false
	_player.is_crouching = true
	await _wait(0.5)
	_check(_player.camera.global_position.y < eye - 0.5, "crouching lowers the camera")
	_check(_player.is_on_floor(), "player stands on the ground")
	_player.is_crouching = false


# --- Helpers --------------------------------------------------------------

func _aim_and_fire(point: Vector3, cock_first := true) -> void:
	if cock_first and not _gun.hammer_cocked:
		_gun.work_action()
		await _wait(_gun.data.cock_time + 0.03)
	# Let earlier recoil settle so the shot goes exactly where we aim.
	await _wait(_gun.data.recoil_duration)
	_player.aim_at(point)
	await get_tree().physics_frame
	_gun.pull_trigger()
	await _wait(_gun.data.fire_interval + 0.05)


func _first(type: Variant) -> Node:
	for node in get_tree().get_nodes_in_group(&"targets"):
		if is_instance_of(node, type):
			return node
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok    ", what)
	else:
		_failures += 1
		printerr("  FAIL  ", what)
