class_name Weapon
extends Node3D
## Base class: owns the WeaponData, the model slot, input polling, shooting
## (spread, hitscan or travelling bullets, recoil, muzzle effects), sight
## zeroing and the viewmodel kick.
##
## Subclasses implement one period action each (hammer, lever, break, falling
## block) as a small state machine: they override the "Actions" virtuals and
## _on_timer_finished(), and drive time with _timer.

signal fired
signal dry_fired
signal ammo_changed(current: int, capacity: int)
signal reload_started
signal reload_finished
signal zero_changed(distance: float)

const HIT_MASK := 0b0101  # world + targets

@export var data: WeaponData

var player: Player
var model: WeaponModel
## Set false to ignore player input (menus, holstered, scripted sequences).
var input_enabled := true
## True while the alt-fire modifier is held (fanning, both barrels).
var alt_held := false
## Index into data.zero_distances.
var zero_index := 0

## Counts down to _on_timer_finished(). The state machines run on this.
var _timer := 0.0
var _reload_interrupt := false
var _kick_pos := Vector3.ZERO
var _kick_rot := Vector3.ZERO

@onready var model_slot: Node3D = $ModelSlot


func _ready() -> void:
	if data.model_scene:
		model = data.model_scene.instantiate() as WeaponModel
	if model == null:
		model = _create_default_model()
	model_slot.add_child(model)
	model.action_played.connect(func(action: StringName) -> void: AudioManager.mechanical(self, action))
	dry_fired.connect(func() -> void: AudioManager.play_at(data.sound_dry, global_position, -8))
	_on_equipped()


func _process(delta: float) -> void:
	var decay := 1.0 - exp(-11.0 * delta)
	_kick_pos = _kick_pos.lerp(Vector3.ZERO, decay)
	_kick_rot = _kick_rot.lerp(Vector3.ZERO, decay)
	model_slot.position = _kick_pos
	model_slot.rotation = _kick_rot

	_poll_input()
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_on_timer_finished()


# --- Actions: the whole public control surface -----------------------------
# Player input, tests and Dead Eye all drive weapons through these.

func pull_trigger() -> void:
	pass


## Called every frame while the alt-fire modifier and the trigger are both
## held. `just_pressed` is true on the frame the trigger went down.
func alt_fire(just_pressed: bool) -> void:
	if just_pressed:
		pull_trigger()


## Cock the hammer / throw the lever. Returns false if there was nothing to do.
func work_action() -> bool:
	return false


func start_reload() -> void:
	pass


## Stops a reload after the step in progress.
func interrupt_reload() -> void:
	if is_reloading():
		_reload_interrupt = true


func get_ammo() -> int:
	return 0


## Instantly loads the gun and leaves it ready to cock. For modes that hand
## the player a fresh weapon (Quick Draw rounds, challenge starts).
func refill() -> void:
	pass


func is_reloading() -> bool:
	return false


## True when nothing is mid-motion, so the gun may be holstered or swapped.
func is_idle() -> bool:
	return _timer <= 0.0


func can_ads() -> bool:
	return not is_reloading()


## One line describing the action's state, for the HUD.
func get_status_text() -> String:
	return ""


# --- Sights ---------------------------------------------------------------

func get_zero_distance() -> float:
	if data.zero_distances.is_empty():
		return 0.0
	return data.zero_distances[clampi(zero_index, 0, data.zero_distances.size() - 1)]


## Radians the bore points above the line of sight so that the bullet drops
## back onto it at the zero distance.
func get_zero_angle() -> float:
	var distance := get_zero_distance()
	if distance <= 0.0 or data.muzzle_velocity <= 0.0:
		return 0.0
	var time := distance / data.muzzle_velocity
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	return atan2(0.5 * gravity * data.gravity_scale * time * time, distance)


## Steps the sight up (+1) or down (-1). Returns false at the end of travel.
func adjust_zero(step: int) -> bool:
	var index := clampi(zero_index + step, 0, maxi(data.zero_distances.size() - 1, 0))
	if index == zero_index:
		return false
	zero_index = index
	_on_zero_changed()
	zero_changed.emit(get_zero_distance())
	return true


## Viewmodel transform, relative to the camera, when fully aimed.
func get_ads_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, get_zero_angle()), data.ads_position)


## Current cone half-angle in degrees, used for shots and the crosshair.
func get_current_spread() -> float:
	if player == null:
		return data.spread_deg
	var spread := lerpf(data.spread_deg, data.ads_spread_deg, player.ads_amount)
	return spread + data.move_spread_deg * player.get_speed_fraction()


# --- For subclasses -------------------------------------------------------

func _create_default_model() -> WeaponModel:
	return WeaponModel.new()


func _on_equipped() -> void:
	pass


func _on_timer_finished() -> void:
	pass


func _on_zero_changed() -> void:
	pass


func _poll_input() -> void:
	alt_held = false
	if not input_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	alt_held = Input.is_action_pressed("alt_fire")
	if Input.is_action_just_pressed("reload"):
		if is_reloading():
			interrupt_reload()
		else:
			start_reload()
	var trigger_down := Input.is_action_just_pressed("fire")
	if alt_held and Input.is_action_pressed("fire"):
		alt_fire(trigger_down)
	elif trigger_down:
		pull_trigger()
	elif Input.is_action_just_pressed("cock_hammer"):
		work_action()


func _eject_casing(velocity_local: Vector3) -> void:
	var eject := model.get_eject_point()
	var jitter := Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3))
	FX.casing(
		self, eject.global_transform, eject.global_basis * (velocity_local + jitter),
		data.casing_size
	)


# --- Shooting -------------------------------------------------------------

## Fires one shot (data.pellets projectiles) in a `spread_deg` cone around
## the player's aim, with all the trimmings.
func _shoot(spread_deg: float, recoil_scale := 1.0) -> void:
	GameState.register_shot()
	var origin := player.camera.global_position
	var aim := player.get_aim_basis() * Basis(Vector3.RIGHT, get_zero_angle())
	var roll := randf() * TAU
	var hits := {}  # Target -> BulletHit, so one shot scores a target once
	for i in data.pellets:
		var direction := (
			_pellet_direction(aim, spread_deg, i, roll) if data.pellets > 1
			else _direction_in_cone(aim, spread_deg)
		)
		if data.muzzle_velocity > 0.0:
			Bullet.spawn(self, origin, direction * data.muzzle_velocity)
			continue
		var hit := _raycast(origin, direction)
		if hit == null:
			continue
		var target := Target.find_from(hit.collider as Node)
		if target == null or not target.is_active:
			FX.impact(self, hit.position, hit.normal)
			AudioManager.impact(hit.position, hit.collider)
		elif hits.has(target):
			hits[target].damage += hit.damage
			hits[target].pellets += 1
		else:
			hits[target] = hit
	for target: Target in hits:
		target.take_hit(hits[target])
	if hits.is_empty() and data.muzzle_velocity <= 0.0:
		GameState.register_miss()

	var muzzle := model.get_muzzle()
	FX.muzzle_flash(muzzle, sqrt(data.smoke_amount))
	FX.smoke_puff(self, muzzle.global_position, -muzzle.global_basis.z, data.smoke_amount)

	var kick := Vector2(data.recoil_kick.x, randf_range(-1.0, 1.0) * data.recoil_kick.y)
	player.apply_recoil(kick * recoil_scale, data.recoil_duration, data.recoil_curve)
	var k := data.viewmodel_kick * recoil_scale
	_kick_pos += Vector3(0.0, 0.006, 0.035) * k
	_kick_rot += Vector3(deg_to_rad(11.0), deg_to_rad(randf_range(-2.0, 2.0)), 0.0) * k
	fired.emit()
	AudioManager.gunshot(self)


## Sends a finished hit to the target it struck, or scuffs the scenery.
## Returns true if a target took it.
static func deliver_hit(ctx: Node, hit: BulletHit) -> bool:
	var target := Target.find_from(hit.collider as Node)
	if target and target.is_active:
		target.take_hit(hit)
		return true
	FX.impact(ctx, hit.position, hit.normal)
	AudioManager.impact(hit.position, hit.collider)
	return false


## Sends a bullet glancing off hard steel. If the deflected path finds
## another target within `reach` metres, that target takes a ricochet hit.
static func ricochet(ctx: Node3D, hit: BulletHit, reach := 40.0) -> void:
	AudioManager.play_at(&"ricochet", hit.position, -8)
	var bounce := hit.direction.bounce(hit.normal)
	bounce = (bounce + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.04).normalized()
	var from := hit.position + hit.normal * 0.02
	var exclude: Array[RID] = []
	if hit.collider is CollisionObject3D:
		exclude.append((hit.collider as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, from + bounce * reach, HIT_MASK, exclude)
	var result := ctx.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var glance := BulletHit.new()
	glance.position = result.position
	glance.normal = result.normal
	glance.direction = bounce
	glance.distance = hit.distance + from.distance_to(glance.position)
	glance.damage = hit.damage * 0.6
	glance.collider = result.collider
	glance.weapon = hit.weapon
	glance.aimed = hit.aimed
	glance.ricochet = true
	deliver_hit(ctx, glance)


func _raycast(origin: Vector3, direction: Vector3) -> BulletHit:
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * data.max_range, HIT_MASK, [player.get_rid()]
	)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var hit := BulletHit.new()
	hit.position = result.position
	hit.normal = result.normal
	hit.direction = direction
	hit.distance = origin.distance_to(hit.position)
	hit.damage = data.damage
	hit.collider = result.collider
	hit.weapon = self
	hit.aimed = player.ads_amount > 0.5
	return hit


func _direction_in_cone(aim: Basis, spread_deg: float) -> Vector3:
	# sqrt() keeps the distribution uniform over the disc instead of
	# clustering at the center.
	return _cone_point(aim, deg_to_rad(spread_deg) * sqrt(randf()), randf() * TAU)


## Shot pattern: one pellet near the middle, the rest on a jittered ring.
## Random enough to feel like shot, even enough that a centered pattern
## never leaves a hole a clay can slip through.
func _pellet_direction(aim: Basis, spread_deg: float, index: int, roll: float) -> Vector3:
	var spread := deg_to_rad(spread_deg)
	if index == 0:
		return _cone_point(aim, spread * 0.15 * randf(), randf() * TAU)
	var around := roll + TAU * float(index - 1) / float(data.pellets - 1)
	return _cone_point(aim, spread * randf_range(0.45, 1.0), around + randf_range(-0.2, 0.2))


func _cone_point(aim: Basis, angle: float, around: float) -> Vector3:
	var local := Vector3(sin(angle) * cos(around), sin(angle) * sin(around), -cos(angle))
	return (aim * local).normalized()
