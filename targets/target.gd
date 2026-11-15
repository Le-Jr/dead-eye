class_name Target
extends Node3D
## Base class for everything that can be shot for points. Subclasses build
## their own bodies (on the "targets" physics layer) and override the
## underscore hooks.

signal hit(zone: StringName, points: int)
signal destroyed

const TARGET_LAYER := 0b0100
const WORLD_LAYER := 0b0001

@export var base_points := 100
## Points multiplier per zone; zones not listed score 1x.
@export var zone_multipliers := {&"bullseye": 2.0, &"head": 2.0}
## Seconds until a destroyed target comes back. 0 = stays destroyed.
@export var respawn_time := 5.0

var is_active := true


## Walks up from a collider to the Target that owns it, if any. Colliders off
## the targets layer (a plate's wooden frame, say) are scenery, not target.
static func find_from(node: Node) -> Target:
	var body := node as CollisionObject3D
	if body and not (body.collision_layer & TARGET_LAYER):
		return null
	while node:
		if node is Target:
			return node
		node = node.get_parent()
	return null


func _enter_tree() -> void:
	add_to_group(&"targets")


func take_hit(bullet: BulletHit) -> void:
	if not is_active:
		return
	var zone := _resolve_zone(bullet)
	var points := _points_for(zone)
	var sound := &"tin"
	if self is BottleTarget:
		sound = &"glass"
	elif self is ClayTarget:
		sound = &"clay"
	elif self is CutoutTarget or self is RollingTarget:
		sound = &"wood"
	elif self is SteelPlateTarget or self is SpinnerTarget or self is RailTarget:
		sound = &"steel"
	AudioManager.play_at(sound, bullet.position, -5)
	_on_hit(bullet, zone)
	hit.emit(zone, points)
	GameState.register_hit(self, zone, points, bullet)


## Puts the target back in its initial state.
func reset() -> void:
	is_active = true
	_on_reset()


## Call from a subclass when the target is used up.
func _destroy() -> void:
	is_active = false
	destroyed.emit()
	if respawn_time > 0.0:
		get_tree().create_timer(respawn_time).timeout.connect(reset)


# --- Hooks ----------------------------------------------------------------

## Default: the zone the struck collider was tagged with in _add_collider().
func _resolve_zone(bullet: BulletHit) -> StringName:
	if bullet.collider:
		return bullet.collider.get_meta(&"zone", &"body")
	return &"body"


func _points_for(zone: StringName) -> int:
	return roundi(base_points * float(zone_multipliers.get(zone, 1.0)))


func _on_hit(_bullet: BulletHit, _zone: StringName) -> void:
	pass


func _on_reset() -> void:
	pass


# --- Construction helpers -------------------------------------------------

static func make_material(color: Color, metallic := 0.0, roughness := 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## A disc whose flat faces point along local Z once laid over (see _add_mesh).
static func disc_mesh(radius: float, thickness: float, segments := 20) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = thickness
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _add_mesh(
	parent: Node3D, mesh: Mesh, material: Material, at := Vector3.ZERO, facing_z := false
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.set_surface_override_material(0, material)
	instance.position = at
	if facing_z:
		instance.rotation.x = PI / 2.0
	parent.add_child(instance)
	return instance


## A shootable body that can be moved from code. `zone` is what a hit on it
## resolves to.
func _add_collider(
	parent: Node3D, shape: Shape3D, at := Vector3.ZERO, zone := &"body", facing_z := false
) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = TARGET_LAYER
	body.collision_mask = 0
	body.position = at
	body.set_meta(&"zone", zone)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	if facing_z:
		collision.rotation.x = PI / 2.0
	body.add_child(collision)
	parent.add_child(body)
	return body


## Solid scenery belonging to the target (posts, rails). Stops bullets but
## does not score.
func _add_scenery_box(size: Vector3, at: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = at
	_add_mesh(body, box_mesh(size), material)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body
