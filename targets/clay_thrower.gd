class_name ClayThrower
extends Node3D
## A trap that flings clay targets. It throws along its local -Z, tilted up
## by `elevation_deg`. Not a target itself.

signal thrown(clay: ClayTarget)

@export var speed := 15.0
@export var elevation_deg := 38.0
## Random sideways variation per throw, in degrees.
@export var scatter_deg := 6.0


func _ready() -> void:
	var timber := Target.make_material(Color(0.4, 0.3, 0.2))
	var iron := Target.make_material(Color(0.25, 0.25, 0.27), 0.8, 0.5)
	var base := MeshInstance3D.new()
	base.mesh = Target.box_mesh(Vector3(0.5, 0.35, 0.7))
	base.set_surface_override_material(0, timber)
	base.position.y = 0.175
	add_child(base)
	var arm := MeshInstance3D.new()
	arm.mesh = Target.box_mesh(Vector3(0.06, 0.04, 0.6))
	arm.set_surface_override_material(0, iron)
	arm.position = Vector3(0, 0.45, -0.15)
	arm.rotation.x = deg_to_rad(elevation_deg)
	add_child(arm)


func throw() -> ClayTarget:
	var clay := ClayTarget.new()
	var yaw := deg_to_rad(randf_range(-scatter_deg, scatter_deg))
	var pitch := deg_to_rad(elevation_deg + randf_range(-3.0, 3.0))
	var direction := global_basis * (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD)
	clay.velocity = direction * speed
	get_tree().current_scene.add_child(clay)
	clay.global_position = global_position + Vector3.UP * 0.5
	thrown.emit(clay)
	return clay
