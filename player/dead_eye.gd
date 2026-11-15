class_name DeadEye
extends Node
## Marks store collider-local points, so moving targets remain tracked.
## Executes the normal weapon action state machine; never refills ammunition.
var player: Player
var meter := 0.0
var active := false
var executing := false
var marks: Array[Dictionary] = []
var seconds_left := 0.0
var enabled := true
var _old_time := 1.0
var _old_switch := true
var _old_controls := true
var _old_lock := false
var _generation := 0

func _ready() -> void:
	GameState.scored.connect(_earn)

func _earn(event: Dictionary) -> void:
	if enabled and not active and not executing and event.points > 0 and event.zone in [&"bullseye", &"head", &"midair", &"juggle"]:
		meter = minf(100, meter + 25)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dead_eye"):
		if active:
			release_marks()
		elif not executing:
			activate()
		get_viewport().set_input_as_handled()
	elif active and event.is_action_pressed("fire"):
		paint()
		get_viewport().set_input_as_handled()

func activate() -> bool:
	if not enabled or meter < 100 or active or executing or player.is_holstered or player.weapons_locked or not player.weapon.is_idle() or player.weapon.get_ammo() == 0:
		return false
	meter = 0
	marks.clear()
	active = true
	seconds_left = 4
	_old_time = Engine.time_scale
	_old_switch = player.weapon_switch_enabled
	_old_controls = player.controls_enabled
	_old_lock = player.weapons_locked
	player.weapon_switch_enabled = false
	player.weapons_locked = true
	player.weapon.input_enabled = false
	Engine.time_scale = .2
	AudioManager.warp(true)
	return true

func _process(delta: float) -> void:
	if active:
		seconds_left -= delta / maxf(Engine.time_scale, .001)
		if seconds_left <= 0:
			release_marks()

func paint() -> bool:
	if not active or marks.size() >= mini(6, player.weapon.get_ammo()):
		return false
	var from := player.camera.global_position
	var to := from - player.get_aim_basis().z * player.weapon.data.max_range
	var query := PhysicsRayQueryParameters3D.create(from, to, Weapon.HIT_MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var target := Target.find_from(hit.collider)
	if target == null or not target.is_active:
		return false
	for mark in marks:
		if mark.body.get_ref() == hit.collider:
			return false
	marks.append({"body": weakref(hit.collider), "target": weakref(target), "point": hit.collider.to_local(hit.position)})
	AudioManager.play_ui(&"hammer")
	return true

func release_marks() -> void:
	if not active:
		return
	active = false
	Engine.time_scale = _old_time
	AudioManager.warp(false)
	executing = true
	player.controls_enabled = false
	_generation += 1
	_execute(_generation)

func _execute(generation: int) -> void:
	var gun := player.weapon
	while not marks.is_empty() and generation == _generation:
		var mark := marks.pop_front() as Dictionary
		var body = mark.body.get_ref()
		var target = mark.target.get_ref()
		if not is_instance_valid(body) or not is_instance_valid(target) or not target.is_active or gun.get_ammo() == 0:
			continue
		while not gun.is_idle():
			await get_tree().process_frame
			if generation != _generation:
				return
		gun.work_action()
		while not gun.is_idle():
			await get_tree().process_frame
			if generation != _generation:
				return
		if not is_instance_valid(body) or not is_instance_valid(target) or not target.is_active:
			continue
		var point: Vector3 = body.to_global(mark.point)
		var origin := player.camera.global_position
		var query := PhysicsRayQueryParameters3D.create(origin, point + (point-origin).normalized()*.03, Weapon.HIT_MASK, [player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or Target.find_from(hit.collider) != target:
			continue
		# Compensate flight drop/wind, but leave normal weapon spread intact.
		if gun.data.muzzle_velocity > 0:
			var distance := origin.distance_to(point)
			var flight := distance / gun.data.muzzle_velocity
			point += Vector3.UP * (.5 * 9.8 * gun.data.gravity_scale * flight * flight - tan(gun.get_zero_angle()) * distance)
			point -= Wind.get_velocity() * gun.data.wind_drift * flight * flight * .5
		player.aim_at(point)
		await get_tree().physics_frame
		if generation != _generation:
			return
		gun.pull_trigger()
		await get_tree().create_timer(maxf(gun.data.fire_interval, gun.data.recoil_duration), false).timeout
		if generation != _generation:
			return
	cancel()

func cancel() -> void:
	_generation += 1
	if active or executing:
		Engine.time_scale = _old_time
		AudioManager.warp(false)
		player.weapons_locked = _old_lock
		player.weapon_switch_enabled = _old_switch
		player.controls_enabled = _old_controls
	active = false
	executing = false
	marks.clear()

func _exit_tree() -> void:
	cancel()
