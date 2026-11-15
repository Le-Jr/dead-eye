class_name CanTarget
extends Target
## A tin can that pops into the air when shot and can be juggled with
## follow-up shots. Each hit while airborne scores as "juggle" and is worth
## more than the last. Origin is at the can's resting base.

signal juggled(count: int)

const HEIGHT := 0.11
const RADIUS := 0.034

## Seconds the can may lie still away from home before it is put back.
@export var return_delay := 3.0

## Consecutive mid-air hits in the current juggle.
var juggle_count := 0

var _body: RigidBody3D
var _airborne := false
var _rest_time := 0.0
var _still_time := 0.0


func _ready() -> void:
	respawn_time = 0.0  # cans are never destroyed, they just come home
	_build_body()


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var moving := _body.linear_velocity.length() > 0.25
	# The can is also momentarily "still" at the top of its arc, so only a
	# sustained stop ends the juggle.
	_still_time = 0.0 if moving else _still_time + delta
	if _airborne and _still_time > 0.3:
		_airborne = false
		juggle_count = 0
	var away := _body.global_position.distance_to(global_position) > 0.08
	_rest_time = _rest_time + delta if (away and not moving) else 0.0
	if _rest_time >= return_delay or _body.global_position.y < global_position.y - 30.0:
		reset()


func get_body() -> RigidBody3D:
	return _body


func _resolve_zone(_bullet: BulletHit) -> StringName:
	return &"juggle" if _airborne else &"body"


func _points_for(zone: StringName) -> int:
	if zone == &"juggle":
		return base_points * (juggle_count + 2)
	return base_points


func _on_hit(bullet: BulletHit, zone: StringName) -> void:
	if zone == &"juggle":
		juggle_count += 1
		juggled.emit(juggle_count)
	_airborne = true
	_rest_time = 0.0
	_still_time = 0.0
	# Mostly up, a little downrange: easy to see, hard to hit twice.
	var flat := Vector3(bullet.direction.x, 0.0, bullet.direction.z)
	var impulse := (Vector3.UP * randf_range(5.5, 7.0) + flat * 1.6) * _body.mass
	_body.linear_velocity = Vector3.ZERO
	_body.apply_impulse(impulse, bullet.position - _body.global_position)
	_body.angular_velocity += Vector3(randf_range(-12, 12), randf_range(-4, 4), randf_range(-12, 12))
	FX.burst(self, bullet.position, -bullet.direction, Color(1.0, 0.85, 0.5), 6, 5.0)


func _on_reset() -> void:
	_airborne = false
	juggle_count = 0
	_rest_time = 0.0
	if _body:
		_body.queue_free()
	_build_body()


func _build_body() -> void:
	_body = RigidBody3D.new()
	_body.collision_layer = TARGET_LAYER
	_body.collision_mask = WORLD_LAYER
	_body.mass = 0.1
	_body.continuous_cd = true
	_body.position.y = HEIGHT * 0.5

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.6, 0.56)
	material.metallic = 0.8
	material.roughness = 0.45
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = HEIGHT
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	_body.add_child(instance)

	# A painted label band so the spin reads in the air.
	var label_material := StandardMaterial3D.new()
	label_material.albedo_color = Color(0.7, 0.16, 0.1)
	label_material.roughness = 0.8
	var label_mesh := CylinderMesh.new()
	label_mesh.top_radius = RADIUS + 0.0008
	label_mesh.bottom_radius = RADIUS + 0.0008
	label_mesh.height = HEIGHT * 0.5
	label_mesh.radial_segments = 12
	label_mesh.rings = 1
	label_mesh.cap_top = false
	label_mesh.cap_bottom = false
	label_mesh.material = label_material
	var label := MeshInstance3D.new()
	label.mesh = label_mesh
	_body.add_child(label)

	var shape := CylinderShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_body.add_child(collision)
	add_child(_body)
