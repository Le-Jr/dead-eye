class_name Bullet
extends Node3D
## A rifle bullet with travel time. Each physics tick it advances under
## gravity and the global Wind, ray-testing the segment it covered. Invisible
## on purpose: black powder left smoke, not tracers.

var velocity := Vector3.ZERO
var data: WeaponData
var weapon: Node
var exclude: Array[RID] = []
var aimed := false

var _start := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


static func spawn(from: Weapon, origin: Vector3, initial_velocity: Vector3) -> Bullet:
	var bullet := Bullet.new()
	bullet.velocity = initial_velocity
	bullet.data = from.data
	bullet.weapon = from
	bullet.exclude = [from.player.get_rid()]
	bullet.aimed = from.player.ads_amount > 0.5
	var root := from.get_tree().current_scene
	root.add_child(bullet)
	bullet.global_position = origin
	bullet._start = origin
	return bullet


func _physics_process(delta: float) -> void:
	var accel := Vector3.DOWN * _gravity * data.gravity_scale
	accel += Wind.get_velocity() * data.wind_drift
	var new_velocity := velocity + accel * delta
	var from := global_position
	var to := from + (velocity + new_velocity) * 0.5 * delta
	velocity = new_velocity

	var query := PhysicsRayQueryParameters3D.create(from, to, Weapon.HIT_MASK, exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hit := BulletHit.new()
		hit.position = result.position
		hit.normal = result.normal
		hit.direction = velocity.normalized()
		hit.distance = _start.distance_to(hit.position)
		hit.damage = data.damage
		hit.collider = result.collider
		hit.weapon = weapon if is_instance_valid(weapon) else null
		hit.aimed = aimed
		if not Weapon.deliver_hit(self, hit):
			GameState.register_miss()
		queue_free()
		return

	global_position = to
	if _start.distance_to(to) > data.max_range or to.y < -50.0:
		GameState.register_miss()
		queue_free()
