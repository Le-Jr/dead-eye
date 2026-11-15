class_name BottleTarget
extends Target
## A glass bottle that shatters into physics shards. Origin is at its base.

const HEIGHT := 0.3
const RADIUS := 0.042
const GLASS_COLORS: Array[Color] = [
	Color(0.2, 0.5, 0.25, 0.6), Color(0.5, 0.3, 0.12, 0.65), Color(0.75, 0.85, 0.85, 0.45),
]

@export var shard_count := 9

var _body: StaticBody3D
var _collision: CollisionShape3D
var _glass: StandardMaterial3D


func _ready() -> void:
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = GLASS_COLORS[randi() % GLASS_COLORS.size()]
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.08
	_glass.metallic_specular = 0.9
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	_body = StaticBody3D.new()
	_body.collision_layer = TARGET_LAYER
	_body.collision_mask = 0
	add_child(_body)

	var shape := CylinderShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	_collision.position.y = HEIGHT * 0.5
	_body.add_child(_collision)

	_add_tube(RADIUS, RADIUS, HEIGHT * 0.6, HEIGHT * 0.3)
	_add_tube(0.016, RADIUS, HEIGHT * 0.15, HEIGHT * 0.675)
	_add_tube(0.014, 0.016, HEIGHT * 0.25, HEIGHT * 0.875)


func _on_hit(bullet: BulletHit, _zone: StringName) -> void:
	_body.visible = false
	_collision.set_deferred("disabled", true)
	FX.burst(self, bullet.position, bullet.direction, Color(0.9, 1.0, 0.95), 16, 6.0)
	FX.shards(
		self, global_position + Vector3.UP * HEIGHT * 0.5,
		Vector3(RADIUS, HEIGHT * 0.5, RADIUS), bullet.direction, _glass, shard_count
	)
	_destroy()


func _on_reset() -> void:
	_body.visible = true
	_collision.set_deferred("disabled", false)


func _add_tube(top: float, bottom: float, height: float, center_y: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.material = _glass
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = center_y
	_body.add_child(instance)
