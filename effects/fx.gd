class_name FX
extends RefCounted
## One-shot visual effects, spawned into the current scene. Every function
## takes a `ctx` node that is inside the tree; the effect cleans itself up.

const DEBRIS_LAYER := 0b1000
const WORLD_MASK := 0b0001

static var _soft_circle: Texture2D
static var _smoke_material: StandardMaterial3D
static var _smoke_ramp: GradientTexture1D
static var _puff_texture: Texture2D
static var _puff_material: StandardMaterial3D
static var _smoke_looks := {}  # fade ramps and size curves, by name

## Gun smoke is unshaded, so the level says how brightly (and in what colour)
## it is lit: white by day, dim blue-grey at night.
static var smoke_tint := Color.WHITE
static var _flash_material: StandardMaterial3D
static var _hole_material: StandardMaterial3D
static var _brass_material: StandardMaterial3D


## Black-powder smoke: a quick jet out of the muzzle that opens into a thin,
## ragged cloud, then hangs, curls and drifts off with the wind.
static func smoke_puff(ctx: Node, position: Vector3, direction: Vector3, amount := 1.0) -> void:
	var wind := Wind.get_velocity()

	# The blast: fast, narrow and brightest, spent within a second.
	var jet := _smoke_emitter(int(9 + 5 * amount), 1.1, 0.2 * pow(amount, 0.35))
	var m := jet.process_material as ParticleProcessMaterial
	m.direction = direction
	m.spread = 8.0
	m.initial_velocity_min = 4.0
	m.initial_velocity_max = 12.0
	m.damping_min = 16.0
	m.damping_max = 24.0
	m.gravity = wind * 0.3 + Vector3.UP * 0.15
	m.scale_curve = _smoke_curve(&"jet", [Vector2(0.0, 0.3), Vector2(0.25, 1.4), Vector2(1.0, 3.0)])
	m.color_ramp = _smoke_fade(&"jet", 0.26, 0.1)
	_spawn(ctx, jet, position)
	jet.emitting = true

	# The cloud it leaves: many faint, slowly rolling wisps that swell as they
	# thin out. Turbulence pulls them into strands instead of a round blob.
	var cloud := _smoke_emitter(int(16 + 10 * amount), 5.5, 0.42 * pow(amount, 0.4))
	m = cloud.process_material as ParticleProcessMaterial
	m.direction = direction
	m.spread = 20.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 6.5
	m.damping_min = 5.0
	m.damping_max = 9.0
	m.gravity = wind * 0.55 + Vector3.UP * 0.25
	m.lifetime_randomness = 0.45
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.9
	m.turbulence_noise_scale = 2.2
	m.turbulence_noise_speed = wind * 0.2 + Vector3(0.0, 0.25, 0.0)
	m.turbulence_influence_min = 0.03
	m.turbulence_influence_max = 0.12
	m.scale_curve = _smoke_curve(&"cloud", [Vector2(0.0, 0.3), Vector2(0.12, 1.0), Vector2(0.5, 2.0), Vector2(1.0, 2.9)])
	m.color_ramp = _smoke_fade(&"cloud", 0.2, 0.06)
	_spawn(ctx, cloud, position)
	cloud.emitting = true


## The thread of smoke that keeps curling out of a barrel after a shot.
## It is parented to `muzzle`, so it follows the gun as it moves.
static func barrel_wisp(muzzle: Node3D, amount := 1.0) -> void:
	var wisp := _smoke_emitter(int(7 + 3 * amount), 1.6, 0.07 * pow(amount, 0.3))
	wisp.explosiveness = 0.0
	var m := wisp.process_material as ParticleProcessMaterial
	m.direction = Vector3.UP
	m.spread = 35.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.3
	m.gravity = Wind.get_velocity() * 0.4 + Vector3.UP * 0.4
	m.scale_curve = _smoke_curve(&"wisp", [Vector2(0.0, 0.4), Vector2(1.0, 3.2)])
	m.color_ramp = _smoke_fade(&"wisp", 0.2, 0.06)
	muzzle.add_child(wisp)
	wisp.emitting = true


## A one-shot emitter of smoke sprites `size` metres across; the caller sets
## how they move. Frees itself when the last particle has faded.
static func _smoke_emitter(amount: int, lifetime: float, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.randomness = 0.6
	p.visibility_aabb = AABB(Vector3(-14, -4, -14), Vector3(28, 14, 28))
	var m := ParticleProcessMaterial.new()
	m.color = smoke_tint
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.angular_velocity_min = -22.0
	m.angular_velocity_max = 22.0
	m.scale_min = 0.6
	m.scale_max = 1.25
	# Each particle keeps one of the four puff shapes for its whole life.
	m.anim_offset_min = 0.0
	m.anim_offset_max = 1.0
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _get_puff_material()
	p.draw_pass_1 = quad
	p.finished.connect(p.queue_free)
	return p


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
	# The same fired case the guns show: rim, sooty brass, an open mouth.
	# Anything as fat as a shotgun bore is a paper shell.
	var mesh := WeaponModel.case_mesh(size.x, size.y, size.x > 0.009, true)
	var shape := CylinderShape3D.new()
	shape.radius = size.x
	shape.height = size.y
	var body := debris_body(mesh, shape, 0.012)
	# The case is modelled along Z from its base; the collider is along Y.
	var case := body.get_child(0) as Node3D
	case.rotation.x = PI / 2.0
	case.position.y = -size.y * 0.5
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


## Four ragged puffs in a 2 x 2 sheet: a soft disc eaten away by noise, so
## overlapping sprites read as billows and strands rather than round blobs.
static func _get_puff_texture() -> Texture2D:
	if _puff_texture == null:
		const CELL := 96
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 4
		noise.frequency = 0.03
		noise.seed = 1873
		var image := Image.create(CELL * 2, CELL * 2, true, Image.FORMAT_RGBA8)
		for y in CELL * 2:
			for x in CELL * 2:
				var local := Vector2(x % CELL, y % CELL) / float(CELL - 1) * 2.0 - Vector2.ONE
				var body := smoothstep(0.0, 1.0, 1.0 - local.length())
				# Offsetting the noise per cell gives four different puffs.
				var billow := noise.get_noise_2d(x + (x / CELL) * 311.0, y + (y / CELL) * 173.0) * 0.5 + 0.5
				var alpha := clampf(body * 1.6 - (1.0 - billow) * 1.05, 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha * (3.0 - 2.0 * alpha)))
		image.generate_mipmaps()
		_puff_texture = ImageTexture.create_from_image(image)
	return _puff_texture


static func _get_puff_material() -> StandardMaterial3D:
	if _puff_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _get_puff_texture()
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 2
		m.particles_anim_loop = false
		# Fade out against walls and the ground instead of slicing into them,
		# and right in front of the eye so a cloud never whites out the view.
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.35
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 0.15
		m.distance_fade_max_distance = 0.9
		_puff_material = m
	return _puff_material


## Opacity over a smoke particle's life: in at once, up to `peak`, down to
## `tail` by the middle and gone at the end, cooling from warm white to grey.
static func _smoke_fade(key: StringName, peak: float, tail: float) -> GradientTexture1D:
	if not _smoke_looks.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.05, 0.45, 1.0])
		g.colors = PackedColorArray([
			Color(1, 0.98, 0.94, 0.0), Color(1, 0.98, 0.94, peak),
			Color(0.9, 0.9, 0.89, tail), Color(0.82, 0.82, 0.83, 0.0),
		])
		var ramp := GradientTexture1D.new()
		ramp.gradient = g
		_smoke_looks[key] = ramp
	return _smoke_looks[key]


## Size over a smoke particle's life, as (time, scale) points.
static func _smoke_curve(key: StringName, points: Array) -> CurveTexture:
	key = StringName(key + "_scale")
	if not _smoke_looks.has(key):
		var c := Curve.new()
		c.max_value = 4.0
		for point: Vector2 in points:
			c.add_point(point)
		var texture := CurveTexture.new()
		texture.curve = c
		_smoke_looks[key] = texture
	return _smoke_looks[key]


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
