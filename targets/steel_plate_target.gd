class_name SteelPlateTarget
extends Target
## A steel gong hanging from a frame. Hits make it swing (a damped pendulum
## driven in code, so it can never tangle or explode like a joint chain).
## Faces along its local Z axis; origin is on the ground under the frame.

@export var plate_radius := 0.3
@export var hang_length := 0.35
@export var frame_height := 2.0
## Fraction of the radius that counts as the bullseye.
@export var bullseye_fraction := 0.3

## Radians from vertical, and radians per second.
var swing_angle := 0.0
var swing_velocity := 0.0

var _pivot: Node3D
var _plate: AnimatableBody3D


func _ready() -> void:
	respawn_time = 0.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.5, 0.5, 0.52)
	steel.metallic = 0.9
	steel.roughness = 0.4
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.75, 0.12, 0.08)
	paint.roughness = 0.7
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.4, 0.3, 0.2)
	timber.roughness = 0.9

	# Frame: two posts and a crossbar. Solid, so a wide shot thuds into wood.
	var half_width := plate_radius + 0.3
	for side: float in [-1.0, 1.0]:
		_add_frame_box(
			Vector3(0.1, frame_height, 0.1),
			Vector3(side * half_width, frame_height * 0.5, 0.0), timber
		)
	_add_frame_box(
		Vector3(half_width * 2.0 + 0.1, 0.1, 0.1), Vector3(0.0, frame_height, 0.0), timber
	)

	_pivot = Node3D.new()
	_pivot.position.y = frame_height - 0.05
	add_child(_pivot)

	var arm := hang_length + plate_radius
	for side: float in [-1.0, 1.0]:
		var chain := MeshInstance3D.new()
		var chain_mesh := BoxMesh.new()
		chain_mesh.size = Vector3(0.012, hang_length, 0.012)
		chain_mesh.material = steel
		chain.mesh = chain_mesh
		chain.position = Vector3(side * plate_radius * 0.6, -hang_length * 0.5, 0.0)
		_pivot.add_child(chain)

	_plate = AnimatableBody3D.new()
	_plate.sync_to_physics = false
	_plate.collision_layer = TARGET_LAYER
	_plate.collision_mask = 0
	_plate.position.y = -arm
	_pivot.add_child(_plate)

	var shape := CylinderShape3D.new()
	shape.radius = plate_radius
	shape.height = 0.02
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.rotation.x = PI / 2.0
	_plate.add_child(collision)

	_add_disc(plate_radius, 0.02, steel)
	_add_disc(plate_radius * bullseye_fraction, 0.024, paint)


func _physics_process(delta: float) -> void:
	if is_zero_approx(swing_velocity) and is_zero_approx(swing_angle):
		return
	var arm := hang_length + plate_radius
	var accel := -(9.8 / arm) * sin(swing_angle) - 0.8 * swing_velocity
	swing_velocity += accel * delta
	swing_angle += swing_velocity * delta
	if absf(swing_angle) < 0.002 and absf(swing_velocity) < 0.01:
		swing_angle = 0.0
		swing_velocity = 0.0
	_pivot.rotation.x = swing_angle


func _resolve_zone(bullet: BulletHit) -> StringName:
	var local := _plate.to_local(bullet.position)
	if Vector2(local.x, local.y).length() <= plate_radius * bullseye_fraction:
		return &"bullseye"
	return &"plate"


func _on_hit(bullet: BulletHit, _zone: StringName) -> void:
	# Positive pivot rotation carries the plate toward local -Z, so a bullet
	# travelling along -Z pushes the swing positive.
	var local_direction := _pivot.global_basis.inverse() * bullet.direction
	swing_velocity += -local_direction.z * 2.2 * bullet.damage / 40.0
	FX.burst(self, bullet.position, -bullet.direction, Color(1.0, 0.8, 0.4), 8, 7.0)
	# Lead splashes off hardened steel. One bounce only, or two plates
	# facing each other would trade the same bullet forever.
	if not bullet.ricochet:
		Weapon.ricochet(self, bullet)


func _on_reset() -> void:
	swing_angle = 0.0
	swing_velocity = 0.0
	_pivot.rotation.x = 0.0


func _add_disc(radius: float, thickness: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = thickness
	mesh.radial_segments = 20
	mesh.rings = 1
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.rotation.x = PI / 2.0
	_plate.add_child(instance)


func _add_frame_box(size: Vector3, at: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	body.add_child(instance)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
