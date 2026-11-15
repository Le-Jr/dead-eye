class_name FX
extends RefCounted
## One-shot visual effects, spawned into the current scene. Every function
## takes a `ctx` node that is inside the tree; the effect cleans itself up.

const DEBRIS_LAYER := 0b1000
const WORLD_MASK := 0b0001

static var _soft_circle: Texture2D
static var _smoke_material: StandardMaterial3D
static var _smoke_ramp: GradientTexture1D
static var _smoke_scale: CurveTexture
static var _flash_material: StandardMaterial3D
static var _hole_material: StandardMaterial3D
static var _brass_material: StandardMaterial3D


## Thick white black-powder smoke that lingers and drifts with the wind.
static func smoke_puff(ctx: Node, position: Vector3, direction: Vector3, amount := 1.0) -> void:
	var p := GPUParticles3D.new()
	p.amount = int(18 + 8 * amount)
	p.lifetime = 4.5
	p.one_shot = true
	p.explosiveness = 0.94
	p.randomness = 0.5
	p.visibility_aabb = AABB(Vector3(-10, -4, -10), Vector3(20, 12, 20))

	var m := ParticleProcessMaterial.new()
	m.direction = direction
	m.spread = 16.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 9.0
	m.damping_min = 5.0
	m.damping_max = 9.0
	# Once the muzzle blast is spent, the cloud just rides the wind and rises.
	m.gravity = Wind.get_velocity() * 0.55 + Vector3.UP * 0.22
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.scale_min = 0.55
	m.scale_max = 1.15
	m.scale_curve = _get_smoke_scale()
	m.color_ramp = _get_smoke_ramp()
	p.process_material = m

	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42) * pow(amount, 0.4)
	quad.material = _get_smoke_material()
	p.draw_pass_1 = quad
	_spawn(ctx, p, position)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func muzzle_flash(muzzle: Node3D, size := 1.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 5.0
	light.omni_range = 7.0
	light.shadow_enabled = false
	muzzle.add_child(light)

	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * randf_range(0.16, 0.24) * size
	quad.material = _get_flash_material()
	flash.mesh = quad
	flash.position = Vector3(0, 0, -0.05)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle.add_child(flash)

	var timer := muzzle.get_tree().create_timer(0.05)
	timer.timeout.connect(light.queue_free)
	timer.timeout.connect(flash.queue_free)


## Dust kick and a bullet hole on world geometry.
static func impact(ctx: Node, position: Vector3, normal: Vector3, color := Color(0.72, 0.62, 0.48)) -> void:
	burst(ctx, position, normal, color, 10, 3.5)
	var hole := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	quad.material = _get_hole_material()
	hole.mesh = quad
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var up := Vector3.RIGHT if absf(normal.y) > 0.99 else Vector3.UP
	_spawn(ctx, hole, position)
	hole.global_transform = Transform3D(
		Basis.looking_at(-normal, up), position + normal * 0.004
	)
	ctx.get_tree().create_timer(20.0).timeout.connect(hole.queue_free)


## Short spray of small particles: dust, sparks, glass glitter.
static func burst(
	ctx: Node, position: Vector3, direction: Vector3, color: Color,
	count := 12, speed := 4.0, gravity := 9.0
) -> void:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	var m := ParticleProcessMaterial.new()
	m.direction = direction
	m.spread = 38.0
	m.initial_velocity_min = speed * 0.3
	m.initial_velocity_max = speed
	m.gravity = Vector3.DOWN * gravity
	m.scale_min = 0.4
	m.scale_max = 1.0
	m.color = color
	m.color_ramp = _get_smoke_ramp()
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = _get_smoke_material()
	p.draw_pass_1 = quad
	_spawn(ctx, p, position)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A spent brass case tumbling out of the gun.
## `size`: x = radius, y = length.
static func casing(
	ctx: Node, at: Transform3D, velocity: Vector3, size := Vector2(0.006, 0.032)
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = size.x * 0.92
	mesh.bottom_radius = size.x
	mesh.height = size.y
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = get_brass_material()
	var shape := CylinderShape3D.new()
	shape.radius = size.x
	shape.height = size.y
	var body := debris_body(mesh, shape, 0.012)
	_spawn(ctx, body, at.origin)
	body.global_transform = at
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-8, 8), randf_range(-20, 20))
	ctx.get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
		if is_instance_valid(body):
			AudioManager.play_at(&"casing", body.global_position, -14)
	)
	ctx.get_tree().create_timer(8.0).timeout.connect(body.queue_free)


## Flat triangular fragments (glass, clay, cardboard) thrown from a box of
## half-size `extent` around `origin`, mostly along `direction`.
static func shards(
	ctx: Node, origin: Vector3, extent: Vector3, direction: Vector3,
	material: Material, count := 9, speed := 5.0
) -> void:
	var tree := ctx.get_tree()
	for i in count:
		var size := Vector3(randf_range(0.015, 0.05), randf_range(0.02, 0.07), 0.004)
		var mesh := PrismMesh.new()
		mesh.size = size
		mesh.material = material
		var shape := BoxShape3D.new()
		shape.size = size
		var shard := debris_body(mesh, shape, 0.02)
		var offset := Vector3(
			randf_range(-extent.x, extent.x), randf_range(-extent.y, extent.y),
			randf_range(-extent.z, extent.z)
		)
		_spawn(ctx, shard, origin + offset)
		shard.global_basis = Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU)
		var scatter := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.4), randf_range(-1, 1))
		shard.linear_velocity = direction * randf_range(0.2, 1.0) * speed + scatter * 2.0
		shard.angular_velocity = scatter * 14.0
		tree.create_timer(randf_range(4.0, 6.0)).timeout.connect(shard.queue_free)


## A small physics prop that collides with the world but is ignored by
## bullets and the player.
static func debris_body(mesh: Mesh, shape: Shape3D, mass: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = DEBRIS_LAYER
	body.collision_mask = WORLD_MASK
	body.mass = mass
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body


static func get_brass_material() -> StandardMaterial3D:
	if _brass_material == null:
		_brass_material = StandardMaterial3D.new()
		_brass_material.albedo_color = Color(0.78, 0.6, 0.25)
		_brass_material.metallic = 0.9
		_brass_material.roughness = 0.35
	return _brass_material


static func get_soft_circle() -> Texture2D:
	if _soft_circle == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		_soft_circle = tex
	return _soft_circle


static func _spawn(ctx: Node, node: Node3D, position: Vector3) -> void:
	var root := ctx.get_tree().current_scene
	if root == null:
		root = ctx.get_tree().root
	root.add_child(node)
	node.global_position = position


static func _get_smoke_material() -> StandardMaterial3D:
	if _smoke_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = get_soft_circle()
		_smoke_material = m
	return _smoke_material


static func _get_smoke_ramp() -> GradientTexture1D:
	if _smoke_ramp == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.06, 0.45, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 0.0), Color(1, 0.98, 0.95, 0.5),
			Color(0.96, 0.94, 0.9, 0.22), Color(0.9, 0.88, 0.85, 0.0),
		])
		_smoke_ramp = GradientTexture1D.new()
		_smoke_ramp.gradient = g
	return _smoke_ramp


static func _get_smoke_scale() -> CurveTexture:
	if _smoke_scale == null:
		var c := Curve.new()
		c.max_value = 3.0
		c.add_point(Vector2(0.0, 0.3))
		c.add_point(Vector2(0.15, 1.0))
		c.add_point(Vector2(1.0, 2.0))
		_smoke_scale = CurveTexture.new()
		_smoke_scale.curve = c
	return _smoke_scale


static func _get_flash_material() -> StandardMaterial3D:
	if _flash_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(1.0, 0.8, 0.45)
		m.albedo_texture = get_soft_circle()
		_flash_material = m
	return _flash_material


static func _get_hole_material() -> StandardMaterial3D:
	if _hole_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.05, 0.04, 0.03, 0.85)
		m.albedo_texture = get_soft_circle()
		_hole_material = m
	return _hole_material
