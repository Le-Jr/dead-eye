extends Node

var failures := 0

func _ready() -> void:
	SaveSystem.path = "user://phase7_test_save.json"
	var level := preload("res://modes/free_range.tscn").instantiate()
	add_child(level)
	var p: Player = level.player
	p.sway_enabled = false
	p.controls_enabled = false
	Settings.auto_cock = false
	await get_tree().create_timer(.5).timeout
	var target := level.spawn_target(SteelPlateTarget,Vector3(0,0,-4)) as SteelPlateTarget
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.aim_at(target._plate.global_position)
	p.weapon.data = p.weapon.data.duplicate()
	p.weapon.data.spread_deg = 0
	p.weapon.data.ads_spread_deg = 0
	p.dead_eye.meter = 100
	check(p.dead_eye.activate() and Engine.time_scale == .2,"Dead Eye activates and slows time")
	check(p.dead_eye.paint(),"visible target can be marked")
	check(not p.dead_eye.paint(),"duplicate mark rejected")
	var ammo := p.weapon.get_ammo()
	var hits := GameState.shots_hit
	p.dead_eye.release_marks()
	await get_tree().create_timer(2).timeout
	check(p.weapon.get_ammo() == ammo-1 and GameState.shots_hit > hits,"marked sequence uses normal ammo and hits")
	check(Engine.time_scale == 1 and not AudioManager.warped and not p.dead_eye.executing,"time and audio restored")
	p.dead_eye.meter = 100
	p.dead_eye.activate()
	level.queue_free()
	await get_tree().process_frame
	check(Engine.time_scale == 1,"leaving slow motion restores global time")
	var long := preload("res://modes/long_shot.tscn").instantiate() as LongShot
	long.countdown = .8
	add_child(long)
	await get_tree().create_timer(1).timeout
	check(long.player.weapon_index == 3 and not long.player.dead_eye.enabled,"Long Shot equips Sharps; Dead Eye disabled")
	check(long.environment.depth >= 550,"500 m range has ground and backstop")
	# Exercise real rifle flight at 500 m, not just the challenge director.
	for plate in long.plates:
		long._set_plate_enabled(plate,false)
	long._set_plate_enabled(long.plates[4],true)
	Wind.set_wind(Vector3.RIGHT,0,0)
	var rifle: Weapon = long.player.weapon
	rifle.data = rifle.data.duplicate()
	rifle.data.spread_deg = 0
	rifle.data.ads_spread_deg = 0
	long.player.sway_enabled = false
	long.player.controls_enabled = false
	rifle.adjust_zero(4)
	rifle.work_action()
	await get_tree().create_timer(.5).timeout
	long.player.aim_at(long.plates[4]._plate.global_position)
	await get_tree().physics_frame
	var before := GameState.shots_hit
	rifle.pull_trigger()
	await get_tree().create_timer(1.5).timeout
	check(GameState.shots_hit == before+1,"real Sharps bullet reaches target at 500 m")
	long._set_plate_enabled(long.plates[4],false)
	long._set_plate_enabled(long.plates[0],true)
	for i in 5:
		check(long.plates[i].is_active,"current distance active")
		for j in 2:
			var hit := BulletHit.new()
			hit.position = long.plates[i]._plate.global_position
			hit.direction = Vector3.FORWARD
			hit.distance = LongShot.DISTANCES[i]
			long.plates[i].take_hit(hit)
		await get_tree().process_frame
	check(long.state == GameMode.State.FINISHED and long.result.score == GameState.score,"ten hits finish and include final score")
	long.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(SaveSystem.path)
	print("PHASE 7 SMOKE: ","PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)

func check(ok: bool, message: String) -> void:
	print("  ","ok " if ok else "FAIL ",message)
	if not ok:
		failures += 1
