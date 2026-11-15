class_name ClayTarget
extends Target
## A clay pigeon in flight. Created and launched by a ClayThrower; flies a
## ballistic arc and breaks on a hit (always a mid-air trick shot) or on the
## ground (a miss).

signal missed

const RADIUS := 0.055
## Hit radius. Bigger than the disc: at speed it would otherwise slip
## between the pellets of a well-centered pattern.
const HIT_RADIUS := 0.11

var velocity := Vector3.ZERO
## Clays plane a little; they fall slower than a rock.
var gravity_scale := 0.55

var _disc: Node3D
var _material: StandardMaterial3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	respawn_time = 0.0
	base_points = 150
	_material = make_material(Color(0.95, 0.45, 0.1), 0.0, 0.6)
	_disc = Node3D.new()
	add_child(_disc)
	_add_mesh(_disc, disc_mesh(RADIUS, 0.022, 14), _material)
	_add_mesh(_disc, disc_mesh(RADIUS * 0.6, 0.03, 14), make_material(Color(0.15, 0.12, 0.1)))
	var shape := SphereShape3D.new()
	shape.radius = HIT_RADIUS
	_add_collider(self, shape, Vector3.ZERO, &"midair")


func _physics_process(delta: float) -> void:
	velocity += Vector3.DOWN * _gravity * gravity_scale * delta
	velocity += Wind.get_velocity() * 0.15 * delta
	global_position += velocity * delta
	_disc.rotate_y(25.0 * delta)
	if is_active and global_position.y <= RADIUS:
		is_active = false
		missed.emit()
		_shatter(Vector3.UP, 4)


func _on_hit(bullet: BulletHit, _zone: StringName) -> void:
	is_active = false
	destroyed.emit()
	_shatter(bullet.direction + velocity.normalized(), 8)


func _shatter(direction: Vector3, pieces: int) -> void:
	FX.burst(self, global_position, direction, Color(1.0, 0.55, 0.2), 12, 5.0)
	FX.shards(self, global_position, Vector3.ONE * RADIUS, direction, _material, pieces, 6.0)
	queue_free()
