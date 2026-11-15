extends Node
## Headless end-to-end check of phase 2: weapon switching and the lever
## rifle, coach gun and long rifle, including bullet drop and wind drift.
## Run:  godot --headless --path . res://tests/phase2_smoke.tscn

const RANGE := preload("res://modes/free_range.tscn")
const BERM := Vector3(20, 6, -214)

var _failures := 0
var _player: Player
var _zones: Array[StringName] = []


func _ready() -> void:
	Settings.auto_cock = false  # in memory only; work every action by hand
	Wind.set_wind(Vector3.RIGHT, 0.0, 0.0)
	var level := RANGE.instantiate()
	add_child(level)
	_player = level.player
	_player.sway_enabled = false
	for weapon in _player.weapons:
		weapon.data = weapon.data.duplicate()
		weapon.data.spread_deg = 0.0
		weapon.data.ads_spread_deg = 0.0
		weapon.data.move_spread_deg = 0.0
	await _wait(0.3)

	await _test_switching()
	await _test_lever_rifle()
	await _test_coach_gun()
	await _test_sharps()
	await _test_holster()

	print("PHASE 2 SMOKE: %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures else 0)


func _test_switching() -> void:
	_check(_player.weapons.size() == 4, "player carries four weapons")
	_check(_player.weapon is Revolver, "starts with the revolver")
	_player.weapon.start_reload()  # full cylinder: a no-op
	_player.switch_weapon(1)
	_check(not _player.is_weapon_ready(), "weapon is not ready mid-switch")
	await _wait(Player.HOLSTER_TIME * 2.0 + 0.15)
	_check(_player.weapon is LeverRifle and _player.is_weapon_ready(), "switched to the lever rifle")
	_check(not _player.weapons[0].visible and _player.weapon.visible, "only the held weapon is visible")


func _test_lever_rifle() -> void:
	var rifle := _player.weapon as LeverRifle
	var plate := _plate_at(-25.0)
	_listen(plate)
	_check(rifle.get_ammo() == 14, "rifle starts with 14 rounds")
	await _fire_at(_center(plate), 0.3)
	_check(_zones == [&"bullseye"], "rifle bullseye at 25 m (got %s)" % [_zones])
	_check(rifle.chamber == LeverRifle.Chamber.SPENT, "fired case stays in the chamber")
	var shots := GameState.shots_fired
	rifle.pull_trigger()
	await _wait(0.1)
	_check(GameState.shots_fired == shots, "no second shot until the lever is worked")
	_check(rifle.work_action(), "lever accepted")
	await _wait(rifle.data.cock_time + 0.05)
	_check(rifle.chamber == LeverRifle.Chamber.LIVE and rifle.hammer_cocked, "lever chambers a round and cocks")
	_check(rifle.tube == 12, "round came from the tube (%d left)" % rifle.tube)
	_check(not rifle.work_action(), "lever refuses to throw away a ready round")

	rifle.start_reload()
	var d := rifle.data
	await _wait(d.reload_open_time + d.reload_insert_time * 1.5)
	rifle.interrupt_reload()
	await _wait(d.reload_insert_time + d.reload_close_time + 0.1)
	_check(not rifle.is_reloading(), "tube loading can be cut short")
	_check(rifle.tube == 14, "two rounds went into the tube (%d)" % rifle.tube)
	_check(rifle.get_ammo() == 15, "14 in the tube plus one chambered")


func _test_coach_gun() -> void:
	await _switch(2)
	var gun := _player.weapon as CoachGun
	var plate := _plate_at(-15.0)
	_listen(plate)
	var hits := {"pellets": 0}
	plate.hit.connect(func(_z: StringName, _p: int) -> void: hits.pellets += 1)
	var shots := GameState.shots_fired
	await _fire_at(_center(plate), 0.3)
	_check(GameState.shots_fired == shots + 1, "one barrel is one shot")
	_check(hits.pellets == 1, "several pellets on one target score once (%d)" % hits.pellets)
	_check(gun.get_ammo() == 1 and gun.hammers == [false, true], "left barrel fired first")

	# Reload one shell, then give it both barrels.
	gun.start_reload()
	var d := gun.data
	await _wait(d.reload_open_time + d.reload_insert_time + d.reload_close_time + 0.2)
	_check(gun.get_ammo() == 2 and not gun.is_reloading(), "break-action reload replaces the fired shell")
	_check(gun.work_action(), "hammers need cocking after the reload")
	await _wait(d.cock_time + 0.05)
	_check(gun.hammers == [true, true], "both hammers cocked")
	shots = GameState.shots_fired
	_player.aim_at(BERM)
	await get_tree().physics_frame
	gun.alt_fire(true)
	await _wait(d.fire_interval + 0.05)
	_check(GameState.shots_fired == shots + 2 and gun.get_ammo() == 0, "alt-fire lets both barrels go")
	var dry := {"count": 0}
	gun.dry_fired.connect(func() -> void: dry.count += 1)
	gun.work_action()
	await _wait(d.cock_time + 0.05)
	gun.pull_trigger()
	await _wait(0.15)
	_check(dry.count == 1, "empty barrel clicks")


func _test_sharps() -> void:
	await _switch(3)
	var rifle := _player.weapon as SharpsRifle
	_check(rifle.get_zero_distance() == 100.0, "sight starts at 100 m")
	var near := _plate_at(-100.0)
	var far := _plate_at(-200.0)

	_listen(near)
	await _fire_at(_center(near), 0.6)
	_check(_zones == [&"bullseye"], "100 m sight: bullseye at 100 m (got %s)" % [_zones])
	_check(rifle.chamber == SharpsRifle.Chamber.SPENT, "one shot empties the rifle")
	await _reload_sharps(rifle)
	_check(rifle.chamber == SharpsRifle.Chamber.LIVE and rifle.hammer_cocked, "breech reload: extract, load, close, cock")

	# Same sight setting at twice the distance: the bullet lands low.
	_listen(far)
	await _fire_at(_center(far), 1.0)
	_check(_zones == [&"plate"], "100 m sight at 200 m drops out of the bullseye (got %s)" % [_zones])
	await _reload_sharps(rifle)

	_check(rifle.adjust_zero(1) and rifle.get_zero_distance() == 200.0, "sight steps up to 200 m")
	_listen(far)
	await _fire_at(_center(far), 1.0)
	_check(_zones == [&"bullseye"], "200 m sight: bullseye at 200 m (got %s)" % [_zones])
	await _reload_sharps(rifle)

	# A stiff crosswind pushes the same shot off the bullseye.
	Wind.set_wind(Vector3.RIGHT, 7.0, 0.0)
	_listen(far)
	await _fire_at(_center(far), 1.0)
	_check(not _zones.has(&"bullseye"), "7 m/s crosswind drifts the shot (got %s)" % [_zones])
	Wind.set_wind(Vector3.RIGHT, 0.0, 0.0)

	var top := rifle.data.zero_distances.size() - 1
	for i in 10:
		rifle.adjust_zero(1)
	_check(rifle.zero_index == top and not rifle.adjust_zero(1), "sight stops at the top of the staff")


func _test_holster() -> void:
	_player.holster()
	await _wait(Player.HOLSTER_TIME + 0.1)
	_check(not _player.is_weapon_ready() and not _player.weapon.input_enabled, "holstered weapon ignores input")
	_player.draw()
	await _wait(Player.HOLSTER_TIME + 0.1)
	_check(_player.is_weapon_ready() and _player.weapon.input_enabled, "drawn weapon is live again")


# --- Helpers --------------------------------------------------------------

func _reload_sharps(rifle: SharpsRifle) -> void:
	var d := rifle.data
	rifle.start_reload()
	await _wait(
		d.reload_open_time + d.reload_eject_time + d.reload_insert_time
		+ d.reload_close_time + 0.2
	)
	rifle.work_action()
	await _wait(d.cock_time + d.recoil_duration)


func _switch(index: int) -> void:
	_player.switch_weapon(index)
	await _wait(Player.HOLSTER_TIME * 2.0 + 0.15)
	_check(_player.weapon_index == index, "switched to slot %d" % (index + 1))


func _fire_at(point: Vector3, settle: float) -> void:
	_player.aim_at(point)
	await get_tree().physics_frame
	_player.weapon.pull_trigger()
	await _wait(settle)


func _listen(target: Target) -> void:
	_zones = []
	for connection in target.hit.get_connections():
		if connection.callable.get_object() == self and connection.callable.get_method() == &"_on_zone":
			return
	target.hit.connect(_on_zone)


func _on_zone(zone: StringName, _points: int) -> void:
	_zones.append(zone)


func _plate_at(z: float) -> SteelPlateTarget:
	for node in get_tree().get_nodes_in_group(&"targets"):
		if node is SteelPlateTarget and is_equal_approx(node.global_position.z, z):
			return node
	_check(false, "no plate at z=%s" % z)
	return null


func _center(plate: SteelPlateTarget) -> Vector3:
	return plate.global_position + Vector3.UP * (
		plate.frame_height - 0.05 - plate.hang_length - plate.plate_radius
	)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok    ", what)
	else:
		_failures += 1
		printerr("  FAIL  ", what)
