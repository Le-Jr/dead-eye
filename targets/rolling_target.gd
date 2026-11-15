class_name RollingTarget
extends Target
## A wagon wheel bowled across the range. It rolls along local X from the
## origin for `distance` metres, turning as it goes; a hit knocks it flat.
## Call roll() to send one. The wheel's face points along local +Z.

signal rolled_out

@export var radius := 0.38
@export var distance := 16.0
@export var speed := 4.5
## Send a wheel as soon as the target enters the scene.
@export var auto_roll := false
## Seconds between wheels when rolling on its own. 0 = only on roll().
@export var repeat_delay := 0.0

var is_rolling := false

var _wheel: Node3D
var _body: AnimatableBody3D
var _travelled := 0.0
var _repeat_timer := 0.0


func _ready() -> void:
	respawn_time = 0.0
	is_active = false
	var timber := make_material(Color(0.45, 0.32, 0.2))
	var iron := make_material(Color(0.2, 0.2, 0.22), 0.8, 0.5)
	_wheel = Node3D.new()
	_wheel.position.y = radius
	_wheel.visible = false
	add_child(_wheel)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.07
	_body = _add_collider(_wheel, shape, Vector3.ZERO, &"rim", true)
	_body.collision_layer = 0
	# Iron tyre, wooden felloe, hub, and spokes that make the spin readable.
	_add_mesh(_wheel, disc_mesh(radius, 0.05, 18), iron, Vector3.ZERO, true)
	_add_mesh(_wheel, disc_mesh(radius * 0.92, 0.06, 18), timber, Vector3.ZERO, true)
	_add_mesh(_wheel, disc_mesh(radius * 0.25, 0.09, 12), make_material(Color(0.75, 0.12, 0.08)), Vector3.ZERO, true)
	for i in 4:
		var spoke := _add_mesh(_wheel, box_mesh(Vector3(radius * 1.8, 0.035, 0.066)), iron)
		spoke.rotation.z = i * PI / 4.0

	if auto_roll:
		roll()


func _physics_process(delta: float) -> void:
	if is_rolling:
		var step := speed * delta
		_travelled += step
		_wheel.position.x = _travelled
		_wheel.rotation.z -= step / radius
		if _travelled >= distance:
			_stop()
			rolled_out.emit()
	elif repeat_delay > 0.0 and _repeat_timer > 0.0:
		_repeat_timer -= delta
		if _repeat_timer <= 0.0:
			roll()


func roll() -> void:
	if is_rolling:
		return
	_travelled = 0.0
	_wheel.position = Vector3(0, radius, 0)
	_wheel.rotation = Vector3.ZERO
	_wheel.visible = true
	_body.collision_layer = TARGET_LAYER
	is_rolling = true
	is_active = true


func _resolve_zone(bullet: BulletHit) -> StringName:
	var local := _wheel.to_local(bullet.position)
	return &"bullseye" if Vector2(local.x, local.y).length() <= radius * 0.25 else &"rim"


func _on_hit(bullet: BulletHit, _zone: StringName) -> void:
	FX.burst(self, bullet.position, -bullet.direction, Color(0.7, 0.55, 0.4), 10, 4.0)
	_stop()
	_wheel.visible = true
	# Topple onto its side where it was hit, then clear the lane.
	var tween := create_tween()
	tween.tween_property(_wheel, "rotation:x", -PI / 2.0, 0.35).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_wheel, "position:y", 0.04, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.2)
	tween.tween_callback(func() -> void:
		if not is_rolling:
			_wheel.visible = false
	)
	destroyed.emit()


func _stop() -> void:
	is_rolling = false
	is_active = false
	_body.collision_layer = 0
	_wheel.visible = false
	_repeat_timer = repeat_delay
