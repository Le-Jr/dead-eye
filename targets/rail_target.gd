class_name RailTarget
extends Target
## A ringed bullseye riding back and forth on a rail. Never destroyed; score
## depends on the ring. The rail runs along local X, centered on the origin;
## the target faces local +Z.

@export var travel := 6.0
@export var speed := 2.2
@export var radius := 0.32
@export var height := 1.3

var _carriage: Node3D
var _disc: Node3D
var _time := 0.0
var _wobble := 0.0


func _ready() -> void:
	respawn_time = 0.0
	zone_multipliers = {&"bullseye": 2.0, &"inner": 1.5}
	var iron := make_material(Color(0.25, 0.25, 0.27), 0.8, 0.5)
	var timber := make_material(Color(0.4, 0.3, 0.2))
	_add_scenery_box(Vector3(travel + radius * 2.0 + 0.4, 0.06, 0.08), Vector3(0, 0.35, 0), iron)
	for side: float in [-1.0, 1.0]:
		_add_scenery_box(
			Vector3(0.12, 0.4, 0.12), Vector3(side * (travel * 0.5 + radius + 0.2), 0.2, 0), timber
		)

	_carriage = Node3D.new()
	add_child(_carriage)
	_add_mesh(_carriage, box_mesh(Vector3(0.05, height - 0.35, 0.05)), timber, Vector3(0, (height + 0.35) * 0.5, -0.03))
	_disc = Node3D.new()
	_disc.position.y = height
	_carriage.add_child(_disc)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.03
	_add_collider(_disc, shape, Vector3.ZERO, &"outer", true)
	_add_mesh(_disc, disc_mesh(radius, 0.03), make_material(Color(0.92, 0.9, 0.85)), Vector3.ZERO, true)
	_add_mesh(_disc, disc_mesh(radius * 0.6, 0.034), make_material(Color(0.15, 0.15, 0.15)), Vector3.ZERO, true)
	_add_mesh(_disc, disc_mesh(radius * 0.25, 0.038), make_material(Color(0.75, 0.12, 0.08)), Vector3.ZERO, true)


func _physics_process(delta: float) -> void:
	_time += delta
	if travel > 0.0:
		_carriage.position.x = pingpong(_time * speed, travel) - travel * 0.5
	_wobble = lerpf(_wobble, 0.0, 1.0 - exp(-5.0 * delta))
	_disc.rotation.x = _wobble * sin(_time * 30.0)


func _resolve_zone(bullet: BulletHit) -> StringName:
	var local := _disc.to_local(bullet.position)
	var distance := Vector2(local.x, local.y).length()
	if distance <= radius * 0.25:
		return &"bullseye"
	if distance <= radius * 0.6:
		return &"inner"
	return &"outer"


func _on_hit(bullet: BulletHit, _zone: StringName) -> void:
	_wobble = 0.25
	FX.burst(self, bullet.position, -bullet.direction, Color(0.9, 0.85, 0.7), 6, 4.0)
