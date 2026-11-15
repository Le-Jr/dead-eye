class_name Player
extends CharacterBody3D
## First-person controller: look, move, sprint, crouch, ADS, camera recoil,
## and the weapon rig's sway and bob.
##
## Node chain: Head (pitch) > RecoilPivot (camera kick) > Camera3D >
## AimPivot (breathing sway; bullets follow it) > WeaponRig (cosmetic bob and
## look lag) > Weapon.

signal weapon_changed(weapon: Weapon)
## The hand has started for the gun (Quick Draw listens for this).
signal draw_started

const WALK_SPEED := 4.2
const SPRINT_SPEED := 6.8
const CROUCH_SPEED := 2.0
const GROUND_ACCEL := 12.0
const AIR_ACCEL := 2.5
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const EYE_DROP := 0.12  # eyes below the top of the capsule
const PITCH_LIMIT := 1.53
const HOLSTER_TIME := 0.22

## One scene per carried weapon, in slot order.
@export var weapon_scenes: Array[PackedScene] = []

## The weapon in hand.
var weapon: Weapon
var dead_eye: DeadEye
var weapons: Array[Weapon] = []
var weapon_index := -1
## Lowered and unusable until draw() (Quick Draw, cutscenes).
var is_holstered := false
## Modes set this to freeze the guns (countdowns, results) while the player
## can still look and move.
var weapons_locked := false
var weapon_switch_enabled := true
## 0 = hip, 1 = fully aimed down sights.
var ads_amount := 0.0
var is_sprinting := false
var is_crouching := false
var controls_enabled := true
## Turn off for deterministic aiming (tests, scripted shots).
var sway_enabled := true

var _yaw := 0.0
var _pitch := 0.0
var _height := STAND_HEIGHT
var _recoil: Array[Dictionary] = []
var _look_lag := Vector2.ZERO
var _sway_time := 0.0
var _bob_time := 0.0
var _sprint_blend := 0.0
var _holster_blend := 0.0  # 1 = fully lowered
var _pending_index := -1
var _cock_on_draw := false
var _step_distance := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var collision: CollisionShape3D = $Collision
@onready var head: Node3D = $Head
@onready var recoil_pivot: Node3D = $Head/RecoilPivot
@onready var camera: Camera3D = $Head/RecoilPivot/Camera3D
@onready var aim_pivot: Node3D = $Head/RecoilPivot/Camera3D/AimPivot
@onready var weapon_rig: Node3D = $Head/RecoilPivot/Camera3D/AimPivot/WeaponRig


func _ready() -> void:
	# The capsule is resized when crouching; don't share it between instances.
	collision.shape = collision.shape.duplicate()
	_yaw = rotation.y
	camera.fov = Settings.fov
	for scene in weapon_scenes:
		var new_weapon := scene.instantiate() as Weapon
		new_weapon.player = self
		weapon_rig.add_child(new_weapon)
		_set_weapon_active(new_weapon, false)
		weapons.append(new_weapon)
	if not weapons.is_empty():
		_activate(0)
	dead_eye = DeadEye.new()
	dead_eye.player = self
	add_child(dead_eye)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if is_holstered and (
		event.is_action_pressed("fire") or event.is_action_pressed("aim")
		or event.is_action_pressed("holster")
	):
		draw()
	elif event.is_action_pressed("holster"):
		holster()
	elif event is InputEventMouseMotion:
		# Scale with zoom so a target crosses the screen at the same hand speed.
		var sens := Settings.mouse_sensitivity * camera.fov / Settings.fov
		_look(event.relative * sens)
	elif event.is_action_pressed("crouch") and Settings.toggle_crouch:
		is_crouching = not is_crouching
	elif event.is_action_pressed("sight_up"):
		weapon.adjust_zero(1)
	elif event.is_action_pressed("sight_down"):
		weapon.adjust_zero(-1)
	elif event.is_action_pressed("weapon_next") or event.is_action_pressed("weapon_prev"):
		# The wheel dials the sight while aiming a rifle that has one.
		var step := 1 if event.is_action_pressed("weapon_next") else -1
		if ads_amount > 0.5 and weapon.data.zero_distances.size() > 1:
			weapon.adjust_zero(-step)
		else:
			switch_weapon(posmod(weapon_index + step, weapons.size()))
	else:
		for i in weapons.size():
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				switch_weapon(i)


func _process(delta: float) -> void:
	if controls_enabled:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if stick != Vector2.ZERO:
			_look(stick * Settings.gamepad_look_speed * delta * camera.fov / Settings.fov)

	_update_holster(delta)
	var wants_ads := (
		controls_enabled and weapon != null and weapon.can_ads() and _holster_blend <= 0.0
		and not is_sprinting and Input.is_action_pressed("aim")
	)
	var ads_time := weapon.data.ads_time if weapon else 0.2
	ads_amount = move_toward(ads_amount, 1.0 if wants_ads else 0.0, delta / ads_time)
	var ads := smoothstep(0.0, 1.0, ads_amount)
	var ads_fov := weapon.data.ads_fov if weapon else Settings.fov
	camera.fov = lerpf(Settings.fov, minf(ads_fov, Settings.fov), ads)

	_update_recoil(delta)
	_update_rig(delta, ads)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if not Settings.toggle_crouch:
			is_crouching = Input.is_action_pressed("crouch")
	_update_crouch(delta)

	is_sprinting = (
		controls_enabled and is_on_floor() and not is_crouching and input.y < -0.5
		and Input.is_action_pressed("sprint")
		and not Input.is_action_pressed("aim") and not Input.is_action_pressed("fire")
	)
	var speed := WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif is_sprinting:
		speed = SPRINT_SPEED
	# Walking slows while aiming: deliberate shots, not run-and-gun.
	speed *= lerpf(1.0, 0.55, ads_amount)

	var wish := global_basis * Vector3(input.x, 0.0, input.y) * speed
	var blend := 1.0 - exp(-(GROUND_ACCEL if is_on_floor() else AIR_ACCEL) * delta)
	velocity.x = lerpf(velocity.x, wish.x, blend)
	velocity.z = lerpf(velocity.z, wish.z, blend)
	move_and_slide()
	if is_on_floor() and controls_enabled:
		_step_distance += Vector2(velocity.x, velocity.z).length() * delta
		if _step_distance >= (2.0 if is_sprinting else 1.6):
			_step_distance = 0
			var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * .1, global_position - Vector3.UP * .3, 1)
			var ground := get_world_3d().direct_space_state.intersect_ray(query)
			var wood_floor: bool = not ground.is_empty() and ground.collider.has_meta("wood_floor")
			AudioManager.play_at(&"step_wood" if wood_floor else &"step_dirt", global_position, -14)
			if is_sprinting:
				AudioManager.play_at(&"spurs", global_position, -23)


# --- Public API -----------------------------------------------------------

## Swaps to the weapon in `index` once the current one finishes what it is
## doing (a reload in progress is cut short).
func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == weapon_index:
		return
	if not weapon_switch_enabled or is_holstered:
		return
	_pending_index = index
	weapon.interrupt_reload()


func holster() -> void:
	is_holstered = true


## Brings the gun up. Thumbing the hammer is part of the draw stroke, so the
## action is worked as the gun levels (unless `cock` is false).
func draw(cock := true) -> void:
	if not is_holstered:
		return
	is_holstered = false
	_cock_on_draw = cock
	draw_started.emit()


## True once the gun is all the way down in the leather.
func is_fully_holstered() -> bool:
	return is_holstered and _holster_blend >= 1.0


## True when the gun is up and will respond to the trigger.
func is_weapon_ready() -> bool:
	return _holster_blend <= 0.0 and _pending_index < 0 and not is_holstered


## Kicks the camera by `kick` degrees (x = up, y = sideways). The kick follows
## `curve` over `duration` seconds and always returns to the original aim.
func apply_recoil(kick: Vector2, duration: float, curve: Curve = null) -> void:
	_recoil.append({"kick": kick, "time": 0.0, "duration": maxf(duration, 0.01), "curve": curve})


## Orientation bullets leave along: the camera plus recoil and weapon sway.
func get_aim_basis() -> Basis:
	return aim_pivot.global_basis


## Horizontal speed as a fraction of full sprint.
func get_speed_fraction() -> float:
	return clampf(Vector2(velocity.x, velocity.z).length() / SPRINT_SPEED, 0.0, 1.0)


## Snaps the view to look at a world position.
func aim_at(point: Vector3) -> void:
	var to := point - camera.global_position
	_yaw = atan2(-to.x, -to.z)
	_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -PITCH_LIMIT, PITCH_LIMIT)
	rotation.y = _yaw
	head.rotation.x = _pitch


# --- Internals ------------------------------------------------------------

func _update_holster(delta: float) -> void:
	if weapon == null:
		return
	var lowering := is_holstered or (_pending_index >= 0 and weapon.is_idle())
	_holster_blend = move_toward(_holster_blend, 1.0 if lowering else 0.0, delta / HOLSTER_TIME)
	if _pending_index >= 0 and _holster_blend >= 1.0:
		_activate(_pending_index)
		_pending_index = -1
	if _cock_on_draw and _holster_blend <= 0.0:
		_cock_on_draw = false
		weapon.work_action()
	weapon.input_enabled = controls_enabled and not weapons_locked and _holster_blend <= 0.0


func _activate(index: int) -> void:
	if weapon:
		_set_weapon_active(weapon, false)
	weapon_index = index
	weapon = weapons[index]
	_set_weapon_active(weapon, true)
	ads_amount = 0.0
	weapon_changed.emit(weapon)


func _set_weapon_active(target: Weapon, active: bool) -> void:
	target.visible = active
	target.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _look(amount: Vector2) -> void:
	_yaw -= amount.x
	_pitch = clampf(
		_pitch + (amount.y if Settings.invert_y else -amount.y), -PITCH_LIMIT, PITCH_LIMIT
	)
	rotation.y = _yaw
	head.rotation.x = _pitch
	_look_lag = (_look_lag + amount * 0.35).limit_length(0.06)


func _update_crouch(delta: float) -> void:
	var target := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	if is_equal_approx(_height, target):
		return
	_height = move_toward(_height, target, delta * 4.0)
	(collision.shape as CapsuleShape3D).height = _height
	collision.position.y = _height * 0.5
	head.position.y = _height - EYE_DROP


func _update_recoil(delta: float) -> void:
	var total := Vector2.ZERO
	for i in range(_recoil.size() - 1, -1, -1):
		var impulse := _recoil[i]
		impulse.time += delta
		var t: float = impulse.time / impulse.duration
		if t >= 1.0:
			_recoil.remove_at(i)
			continue
		var curve: Curve = impulse.curve
		var weight := curve.sample_baked(t) if curve else 1.0 - t
		total += impulse.kick * weight
	recoil_pivot.rotation = Vector3(deg_to_rad(total.x), deg_to_rad(total.y), 0.0)


func _update_rig(delta: float, ads: float) -> void:
	var moving := get_speed_fraction()

	# Breathing / unsteady-hands sway. This one is "real": shots follow it.
	# It shrinks while aiming and crouching and grows with movement.
	_sway_time += delta
	var sway := Vector3.ZERO
	if sway_enabled:
		var amplitude := deg_to_rad(lerpf(0.3, 0.05, ads))
		amplitude *= (0.6 if is_crouching else 1.0) * (1.0 + moving * 2.5)
		sway = Vector3(
			sin(_sway_time * 1.1) * amplitude,
			sin(_sway_time * 0.7 + 1.3) * amplitude * 1.4,
			0.0
		)
	aim_pivot.rotation = sway

	# Everything below is cosmetic weight on the viewmodel.
	_look_lag = _look_lag.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
	_sprint_blend = move_toward(_sprint_blend, 1.0 if is_sprinting else 0.0, delta * 5.0)
	if is_on_floor() and moving > 0.05:
		_bob_time += delta * (5.0 + moving * 9.0)
	var bob_scale := lerpf(1.0, 0.15, ads) * moving
	var bob := Vector3(cos(_bob_time * 0.5) * 0.012, -absf(sin(_bob_time * 0.5)) * 0.014, 0.0)

	var hip := weapon.data.hip_position if weapon else Vector3.ZERO
	var aimed := weapon.get_ads_transform() if weapon else Transform3D.IDENTITY
	var lower := smoothstep(0.0, 1.0, _holster_blend)
	var lag_scale := lerpf(1.0, 0.25, ads)
	weapon_rig.position = (
		hip.lerp(aimed.origin, ads) + bob * bob_scale
		+ Vector3(_look_lag.x, -_look_lag.y, 0.0) * 0.25 * lag_scale
		+ Vector3(0.03, -0.07, 0.04) * _sprint_blend
		+ Vector3(0.0, -0.32, 0.06) * lower
	)
	weapon_rig.rotation = (
		Vector3(_look_lag.y, _look_lag.x, _look_lag.x * 0.8) * 1.2 * lag_scale
		+ Vector3(-0.5, 0.35, 0.0) * _sprint_blend
		+ Vector3(aimed.basis.get_euler().x * ads - 0.9 * lower, 0.0, 0.0)
	)
	head.position.y = _height - EYE_DROP - absf(sin(_bob_time * 0.5)) * 0.03 * moving
