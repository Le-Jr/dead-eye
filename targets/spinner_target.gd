class_name SpinnerTarget
extends Target
## Two steel paddles on an axle: a big one below, a small one above. A hit
## kicks it round; land enough hits fast enough and it goes over the top,
## which pays a trick-shot bonus. Axle along local X, faces local +Z.

signal spun_over

@export var axle_height := 1.2
@export var arm_length := 0.32
@export var spin_bonus := 300

## Radians from rest (big paddle hanging down), and radians per second.
var angle := 0.0
var angular_velocity := 0.0

var _arm: Node3D
## Rotation accumulated since the arm last hung at rest.
var _turned := 0.0
var _paid := false


func _ready() -> void:
	respawn_time = 0.0
	zone_multipliers = {&"small": 2.0}
	var steel := make_material(Color(0.5, 0.5, 0.52), 0.9, 0.4)
	var timber := make_material(Color(0.4, 0.3, 0.2))
	for side: float in [-1.0, 1.0]:
		_add_scenery_box(Vector3(0.08, axle_height + 0.1, 0.08), Vector3(side * 0.3, (axle_height + 0.1) * 0.5, 0), timber)
	_add_mesh(self, box_mesh(Vector3(0.6, 0.03, 0.03)), steel, Vector3(0, axle_height, 0))

	_arm = Node3D.new()
	_arm.position.y = axle_height
	add_child(_arm)
	_add_mesh(_arm, box_mesh(Vector3(0.03, arm_length * 2.0, 0.015)), steel)
	_add_paddle(Vector3(0, -arm_length, 0), 0.14, &"big", make_material(Color(0.85, 0.85, 0.8), 0.6, 0.5))
	_add_paddle(Vector3(0, arm_length, 0), 0.075, &"small", make_material(Color(0.75, 0.12, 0.08), 0.6, 0.5))


func _physics_process(delta: float) -> void:
	if is_zero_approx(angular_velocity) and absf(angle) < 0.001:
		return
	# The heavy paddle wants to hang down: a pendulum with bearing drag.
	var accel := -14.0 * sin(angle) - 0.5 * angular_velocity
	angular_velocity += accel * delta
	var step := angular_velocity * delta
	angle += step
	_turned += step
	_arm.rotation.x = angle

	if not _paid and absf(_turned) >= TAU:
		_paid = true
		spun_over.emit()
		GameState.register_bonus(spin_bonus, "SPINNER", self)
	var near_rest := absf(wrapf(angle, -PI, PI)) < 0.05 and absf(angular_velocity) < 0.15
	if near_rest:
		angle = 0.0
		angular_velocity = 0.0
		_turned = 0.0
		_paid = false
		_arm.rotation.x = 0.0


func _on_hit(bullet: BulletHit, _zone: StringName) -> void:
	# Torque about the axle from where and which way the bullet pushed.
	var axle := global_basis.x
	var lever := bullet.position - _arm.global_position
	var torque := lever.cross(bullet.direction).dot(axle)
	angular_velocity += torque * 14.0 * bullet.damage / 40.0
	FX.burst(self, bullet.position, -bullet.direction, Color(1.0, 0.8, 0.4), 8, 7.0)
	if not bullet.ricochet:
		Weapon.ricochet(self, bullet)


func _on_reset() -> void:
	angle = 0.0
	angular_velocity = 0.0
	_turned = 0.0
	_paid = false
	_arm.rotation.x = 0.0


func _add_paddle(at: Vector3, radius: float, zone: StringName, material: Material) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.02
	_add_collider(_arm, shape, at, zone, true)
	_add_mesh(_arm, disc_mesh(radius, 0.02, 14), material, at, true)
