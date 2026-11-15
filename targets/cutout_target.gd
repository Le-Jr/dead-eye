class_name CutoutTarget
extends Target
## A cardboard figure that rises from behind cover. Bandits score (double
## for the head); innocents, hands in the air, cost points. Origin is on the
## ground at the figure's feet; it faces local +Z.

signal popped_up
## `was_hit` is false when it simply timed out and went back down.
signal dropped(was_hit: bool)

const RISE := 1.95  # how far it sinks out of sight
const RISE_TIME := 0.16

@export var is_innocent := false
## Points lost for shooting an innocent.
@export var innocent_penalty := 250
## Seconds it stays up before ducking again. 0 = until shot.
@export var up_time := 0.0
@export var starts_up := false

var is_up := false

var _figure: Node3D
var _colliders: Array[AnimatableBody3D] = []
var _tween: Tween
var _up_timer := 0.0


func _ready() -> void:
	respawn_time = 0.0
	_figure = Node3D.new()
	add_child(_figure)

	var card := make_material(Color(0.72, 0.6, 0.42))
	var cloth := make_material(Color(0.55, 0.68, 0.8) if is_innocent else Color(0.2, 0.16, 0.14))
	var skin := make_material(Color(0.82, 0.66, 0.5))
	# Backing board and stake.
	_add_mesh(_figure, box_mesh(Vector3(0.08, 0.7, 0.03)), card, Vector3(0, 0.35, -0.01))
	# Body.
	_add_mesh(_figure, box_mesh(Vector3(0.52, 0.75, 0.025)), cloth, Vector3(0, 1.0, 0))
	_colliders.append(_add_collider(_figure, _box_shape(0.52, 0.75), Vector3(0, 1.0, 0), &"body"))
	# Head.
	_add_mesh(_figure, box_mesh(Vector3(0.22, 0.26, 0.025)), skin, Vector3(0, 1.52, 0))
	_colliders.append(_add_collider(_figure, _box_shape(0.22, 0.26), Vector3(0, 1.52, 0), &"head"))

	if is_innocent:
		# Hands up, pale clothes, no hat: readable in a split second.
		for side: float in [-1.0, 1.0]:
			var arm := _add_mesh(
				_figure, box_mesh(Vector3(0.12, 0.5, 0.025)), cloth, Vector3(side * 0.34, 1.45, 0)
			)
			arm.rotation.z = -side * 0.35
			_add_mesh(_figure, box_mesh(Vector3(0.12, 0.12, 0.025)), skin, Vector3(side * 0.44, 1.74, 0))
	else:
		var hat := make_material(Color(0.12, 0.1, 0.09))
		var bandana := make_material(Color(0.7, 0.12, 0.1))
		_add_mesh(_figure, box_mesh(Vector3(0.46, 0.035, 0.03)), hat, Vector3(0, 1.66, 0.003))
		_add_mesh(_figure, box_mesh(Vector3(0.24, 0.15, 0.03)), hat, Vector3(0, 1.74, 0.003))
		_add_mesh(_figure, box_mesh(Vector3(0.24, 0.1, 0.03)), bandana, Vector3(0, 1.45, 0.003))
		# Gun arm out to the side.
		var arm := _add_mesh(
			_figure, box_mesh(Vector3(0.12, 0.45, 0.025)), cloth, Vector3(0.36, 1.1, 0)
		)
		arm.rotation.z = 0.9

	_set_up(starts_up, true)


func _process(delta: float) -> void:
	if is_up and _up_timer > 0.0:
		_up_timer -= delta
		if _up_timer <= 0.0:
			drop(false)


func pop_up() -> void:
	if is_up:
		return
	_set_up(true, false)
	_up_timer = up_time
	popped_up.emit()


func drop(was_hit := false) -> void:
	if not is_up:
		return
	_set_up(false, false)
	dropped.emit(was_hit)


func _points_for(zone: StringName) -> int:
	if is_innocent:
		return -innocent_penalty
	return super(zone)


func _on_hit(bullet: BulletHit, _zone: StringName) -> void:
	FX.burst(self, bullet.position, bullet.direction, Color(0.75, 0.62, 0.45), 8, 3.0)
	drop(true)
	destroyed.emit()


func _on_reset() -> void:
	_set_up(starts_up, true)


func _set_up(up: bool, instant: bool) -> void:
	is_up = up
	is_active = up
	# A ducked figure must not stop bullets meant for something behind it.
	for body in _colliders:
		body.collision_layer = TARGET_LAYER if up else 0
	if _tween and _tween.is_valid():
		_tween.kill()
	var height := 0.0 if up else -RISE
	if instant:
		_figure.position.y = height
	else:
		_tween = create_tween()
		_tween.tween_property(_figure, "position:y", height, RISE_TIME) \
			.set_trans(Tween.TRANS_BACK if up else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _box_shape(width: float, height: float) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.03)
	return shape
