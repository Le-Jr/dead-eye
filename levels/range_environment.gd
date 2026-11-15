class_name RangeEnvironment
extends Node3D
## The range and the town around it, without targets or player: sky, sun,
## ground, the street of false fronts, church, windmill, water tower, fences,
## backstop and distance markers. All of it is built in code from primitive
## meshes, so there are no model files to import and everything is easy to
## retune. The firing line is at the origin; downrange is -Z.

const GROUND := Color(0.62, 0.52, 0.4)
const GREY := Color(0.55, 0.55, 0.56)
const DARK := Color(0.3, 0.3, 0.32)
const TIMBER := Color(0.42, 0.32, 0.22)

## Distance to the backstop berm.
@export var depth := 215.0
var _tumbleweeds: Array[Node3D] = []
var sun: DirectionalLight3D
var atmosphere: Environment
var lanterns: Array[OmniLight3D] = []
var _windmill: Node3D


func _ready() -> void:
	_build_sky()
	var ground := add_box(Vector3(800, 1, depth + 200), Vector3(0, -0.5, -depth * .5), GROUND)
	ground.set_meta(&"surface", &"dirt")
	(ground.get_child(0) as MeshInstance3D).material_override = _ground_material()
	add_box(Vector3(8.0, 0.02, 0.15), Vector3(0, 0.01, -1.0), DARK, false)
	for side: float in [-1,1]:
		for z: float in [-8,-20,-32,-44,-56]:
			var fence := Node3D.new()
			add_child(fence)
			# Low perimeter keeps targets readable and leaves a view of the town.
			add_box(Vector3(.12,.12,11),Vector3(side*12,.8,z),TIMBER)
			add_box(Vector3(.12,.12,11),Vector3(side*12,1.3,z),TIMBER)
			for dz: float in [-5,0,5]:
				add_box(Vector3(.24,1.6,.24),Vector3(side*12,.8,z+dz),TIMBER)
	add_box(Vector3(90.0, 12.0, 6.0), Vector3(0, 6.0, -depth), Color("aa6541")).set_meta(&"surface", &"dirt")
	_build_town()
	# Distance markers: every 10 m on the short range, every 50 m beyond.
	for i in range(1, 6):
		add_box(Vector3(0.3, 0.6 + i * 0.1, 0.3), Vector3(-10.5, 0.3 + i * 0.05, -10.0 * i), DARK)
	for i in range(2, int(depth / 50.0) + 1):
		add_box(Vector3(0.8, 2.5, 0.8), Vector3(-14.0, 1.25, -50.0 * i), DARK)
		_sign("%d m" % (i*50),Vector3(-14,3,-50*i),.025)
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"shadows":
			sun.shadow_enabled = Settings.shadows
		if key == &"time_of_day":
			set_time_of_day(Settings.time_of_day)
	)
	set_time_of_day(Settings.time_of_day)

func _build_town() -> void:
	_facade(Vector3(-19,0,-13),"GOLDEN SPUR",Color("7d4332"))
	_facade(Vector3(20,0,-24),"GUNSMITH",Color("59645b"))
	_facade(Vector3(-20,0,-42),"TRADING POST",Color("ad8855"))
	# Water tower: four legs, cross-braces, plank tank and iron hoops.
	var tower := Vector3(23,0,-53)
	for x: float in [-2,2]:
		for z: float in [-2,2]:
			add_box(Vector3(.35,8,.35),tower+Vector3(x,4,z),TIMBER)
	for y: float in [2,5]:
		add_box(Vector3(4.5,.25,.25),tower+Vector3(0,y,2),DARK)
	var tank := CylinderMesh.new()
	tank.top_radius = 3
	tank.bottom_radius = 3
	tank.height = 4
	tank.radial_segments = 16
	_prop(tank,tower+Vector3(0,9,0),Color("805239"))
	for y: float in [7.3,8.5,10.6]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = 2.95
		hoop.outer_radius = 3.08
		_prop(hoop,tower+Vector3(0,y,0),DARK)
	_sign("DEAD EYE\nWATER CO.",tower+Vector3(0,9,3.02),.012)
	_build_church(Vector3(31, 0, -92))
	_build_windmill(Vector3(-31, 0, -74))
	for spot: Vector3 in [
		Vector3(-14.2, 0, -8.6), Vector3(-13.6, 0, -9.3), Vector3(-14.4, 0, -17), Vector3(14.6, 0, -19.5),
		Vector3(15.2, 0, -20.3), Vector3(14.4, 0, -28.4), Vector3(-14.8, 0, -37.5), Vector3(-15.4, 0, -46.2),
	]:
		_barrel(spot)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1878
	for i in 26:
		var side := -1 if i%2 == 0 else 1
		var at := Vector3(side*rng.randf_range(15,65),0,rng.randf_range(-180,12))
		_cactus(at,rng.randf_range(1.1,3.3))
	for i in 12:
		var at := Vector3((-1 if i%2 == 0 else 1)*rng.randf_range(14,25),.5,rng.randf_range(-55,5))
		add_box(Vector3(1.5,1,1),at,Color("c49c50"))
		for dx: float in [-.5,.5]:
			add_box(Vector3(.05,1.02,1.02),at+Vector3(dx,0,0),Color("765936"),false)
	# Faceted sandstone mesas remain beyond the bullet lanes.
	for i in 16:
		var rock := CylinderMesh.new()
		rock.radial_segments = 5 + i%3
		rock.top_radius = rng.randf_range(8,16)
		rock.bottom_radius = rng.randf_range(22,38)
		rock.height = rng.randf_range(24,60)
		_prop(rock,Vector3((i-8)*65,rock.height*.5,-depth-80-rng.randf_range(0,60)),Color("b7734d"))
	for i in 6:
		var bush := Node3D.new()
		bush.position = Vector3(rng.randf_range(-10,10),.4,-3-i*8)
		add_child(bush)
		# A ball of dry twigs: many thin hoops at random angles.
		for j in 11:
			var ring := TorusMesh.new()
			var radius := rng.randf_range(.2, .36)
			ring.inner_radius = radius - .012
			ring.outer_radius = radius + .012
			ring.rings = 10
			ring.ring_segments = 3
			var mesh := MeshInstance3D.new()
			mesh.mesh = ring
			mesh.material_override = Target.make_material(Color("7a6540").lerp(Color("a08a5a"), rng.randf()))
			mesh.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
			mesh.position = Vector3(rng.randf_range(-.05, .05), rng.randf_range(-.05, .05), rng.randf_range(-.05, .05))
			bush.add_child(mesh)
		_tumbleweeds.append(bush)
	# Golden drifting dust is cheap enough for Compatibility as well.
	var dust := CPUParticles3D.new()
	dust.amount = 100
	dust.lifetime = 8
	dust.preprocess = 8
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(18,4,32)
	dust.position = Vector3(0,3,-25)
	dust.direction = Vector3.RIGHT
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = .2
	dust.initial_velocity_max = .7
	dust.scale_amount_min = .01
	dust.scale_amount_max = .035
	var mote := SphereMesh.new()
	mote.radius = 1
	mote.height = 2
	mote.radial_segments = 4
	mote.rings = 2
	mote.material = Target.make_material(Color("dfbd7f"))
	dust.mesh = mote
	add_child(dust)
	var haze := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(140,8)
	haze.mesh = plane
	haze.position = Vector3(0,4,-90)
	var shimmer := ShaderMaterial.new()
	shimmer.shader = preload("res://levels/heat_haze.gdshader")
	haze.material_override = shimmer
	add_child(haze)

func _facade(at: Vector3, title: String, color: Color) -> void:
	add_box(Vector3(9,6,5),at+Vector3(0,3,0),color)
	for y in 12:
		add_box(Vector3(9,.025,.025),at+Vector3(0,.3+y*.47,2.52),color.darkened(.3),false)
	add_box(Vector3(10,.35,6),at+Vector3(0,6,0),TIMBER)
	add_box(Vector3(10,1.7,.4),at+Vector3(0,6.5,2.8),color)
	_sign(title,at+Vector3(0,6.5,3.05),.012)
	var porch := add_box(Vector3(11,.3,3),at+Vector3(0,.15,4),TIMBER)
	porch.set_meta("wood_floor",true)
	add_box(Vector3(11,.2,3.4),at+Vector3(0,3.6,4),TIMBER)
	for x: float in [-4.5,-1.4,1.4,4.5]:
		add_box(Vector3(.18,3.5,.18),at+Vector3(x,1.8,5),TIMBER)
	for x: float in [-3,3]:
		add_box(Vector3(1.5,1.6,.08),at+Vector3(x,2.1,2.55),Color("26383b"))
		add_box(Vector3(.08,1.7,.12),at+Vector3(x,2.1,2.6),Color("d9b777"))
		add_box(Vector3(1.6,.08,.12),at+Vector3(x,2.1,2.6),Color("d9b777"))
	add_box(Vector3(1.8,2.8,.1),at+Vector3(0,1.4,2.55),Color("35241d"))
	for x: float in [-2,2]:
		var light := OmniLight3D.new()
		light.position = at+Vector3(x,2.8,3)
		light.light_color = Color("ffc67c")
		light.light_energy = 1.8
		light.omni_range = 7
		add_child(light)
		lanterns.append(light)
		add_box(Vector3(.22,.4,.22),light.position,Color("d8aa61"),false)

## White clapboard church with a bell tower, far down the street.
func _build_church(at: Vector3) -> void:
	var white := Color("d9cfb8")
	var roof_color := Color("5b4034")
	add_box(Vector3(9, 6, 14), at + Vector3(0, 3, 0), white)
	var roof := PrismMesh.new()
	roof.size = Vector3(10, 3.2, 15)
	_prop(roof, at + Vector3(0, 7.6, 0), roof_color)
	add_box(Vector3(3.6, 13, 3.6), at + Vector3(0, 6.5, 8), white)
	# Open belfry: four posts, the bell between them, a pointed cap.
	for x: float in [-1.5, 1.5]:
		for z: float in [-1.5, 1.5]:
			add_box(Vector3(.3, 2.6, .3), at + Vector3(x, 14.3, 8 + z), white, false)
	var bell := CylinderMesh.new()
	bell.top_radius = .25
	bell.bottom_radius = .75
	bell.height = 1.1
	bell.radial_segments = 10
	_prop(bell, at + Vector3(0, 14.4, 8), Color("b8892f")).material_override = Target.make_material(Color("b8892f"), 0.9, 0.35)
	var cap := CylinderMesh.new()
	cap.top_radius = 0
	cap.bottom_radius = 2.9
	cap.height = 4
	cap.radial_segments = 4
	_prop(cap, at + Vector3(0, 17.6, 8), roof_color).rotation.y = PI / 4
	add_box(Vector3(.16, 1.6, .16), at + Vector3(0, 20.2, 8), white, false)
	add_box(Vector3(.9, .16, .16), at + Vector3(0, 20.5, 8), white, false)
	add_box(Vector3(1.6, 3, .12), at + Vector3(0, 1.5, 9.83), Color("35241d"), false)
	for z: float in [-4, 0, 4]:
		for x: float in [-4.52, 4.52]:
			add_box(Vector3(.08, 2.4, 1), at + Vector3(x, 3.4, z), Color("26383b"), false)


## Wind pump on a tapering tower; the wheel turns with the range's wind.
func _build_windmill(at: Vector3) -> void:
	for x: float in [-1, 1]:
		for z: float in [-1, 1]:
			var leg := add_box(Vector3(.22, 11.2, .22), at + Vector3(x * 1.05, 5.5, z * 1.05), TIMBER, false)
			leg.rotation = Vector3(-z * .11, 0, x * .11)
	for y: float in [2.5, 5.5, 8.5]:
		var reach := 3.2 - y * .21
		add_box(Vector3(reach, .14, .14), at + Vector3(0, y, reach * .5), DARK, false)
		add_box(Vector3(reach, .14, .14), at + Vector3(0, y, -reach * .5), DARK, false)
		add_box(Vector3(.14, .14, reach), at + Vector3(reach * .5, y, 0), DARK, false)
		add_box(Vector3(.14, .14, reach), at + Vector3(-reach * .5, y, 0), DARK, false)
	add_box(Vector3(1.6, .2, 1.6), at + Vector3(0, 11, 0), TIMBER, false)
	var head := Node3D.new()
	head.position = at + Vector3(0, 11.6, 0)
	head.rotation.y = .5
	add_child(head)
	_windmill = Node3D.new()
	_windmill.position = Vector3(0, 0, 1.1)
	head.add_child(_windmill)
	for i in 14:
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.5, 2.2, .04)
		mesh.material = Target.make_material(Color("9aa0a0"), 0.6, 0.5)
		blade.mesh = mesh
		var spoke := Node3D.new()
		spoke.rotation.z = i * TAU / 14
		blade.position.y = 1.7
		blade.rotation.y = .35
		spoke.add_child(blade)
		_windmill.add_child(spoke)
	var hub := MeshInstance3D.new()
	hub.mesh = BoxMesh.new()
	(hub.mesh as BoxMesh).size = Vector3(.3, .3, 1.4)
	hub.mesh.surface_set_material(0, Target.make_material(DARK))
	hub.position.z = .45
	head.add_child(hub)
	var vane := MeshInstance3D.new()
	vane.mesh = BoxMesh.new()
	(vane.mesh as BoxMesh).size = Vector3(.05, 1.5, 2.6)
	vane.mesh.surface_set_material(0, Target.make_material(Color("8b3a2c")))
	vane.position.z = -2.2
	head.add_child(vane)


func _barrel(at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, .45, 0)
	var staves := CylinderMesh.new()
	staves.top_radius = .3
	staves.bottom_radius = .3
	staves.height = .9
	staves.radial_segments = 12
	var mesh := MeshInstance3D.new()
	mesh.mesh = staves
	mesh.material_override = Target.make_material(Color("6b4a2f"))
	body.add_child(mesh)
	for y: float in [-.28, .28]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = .295
		hoop.outer_radius = .325
		hoop.ring_segments = 4
		var band := MeshInstance3D.new()
		band.mesh = hoop
		band.material_override = Target.make_material(DARK, 0.7, 0.5)
		band.position.y = y
		body.add_child(band)
	var shape := CylinderShape3D.new()
	shape.radius = .32
	shape.height = .9
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


## Packed earth with broad lighter and darker patches, so the ground reads
## as ground and gives the eye something to judge distance against.
func _ground_material() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.01
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	var ramp := Gradient.new()
	ramp.set_color(0, GROUND.darkened(0.2))
	ramp.set_color(1, GROUND.lightened(0.14))
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.035
	material.roughness = 1.0
	return material


## A sparse field of points for the night sky.
func _star_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.frequency = 0.45
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.972, 1.0])
	ramp.colors = PackedColorArray([Color.BLACK, Color.BLACK, Color.WHITE])
	var texture := NoiseTexture2D.new()
	texture.width = 2048
	texture.height = 1024
	texture.noise = noise
	texture.color_ramp = ramp
	return texture


func _cactus(at: Vector3, height: float) -> void:
	var stem := CylinderMesh.new()
	stem.top_radius = .17
	stem.bottom_radius = .22
	stem.height = height
	stem.radial_segments = 7
	_prop(stem,at+Vector3(0,height*.5,0),Color("52664b"))
	for side: float in [-1,1]:
		add_box(Vector3(.7,.22,.22),at+Vector3(side*.3,height*.55,0),Color("52664b"),false)
		add_box(Vector3(.22,height*.35,.22),at+Vector3(side*.6,height*.7,0),Color("52664b"),false)

func _prop(mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Target.make_material(color)
	instance.position = at
	add_child(instance)
	return instance

func _sign(text: String, at: Vector3, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = pixel_size
	label.modulate = Color("efdbad")
	label.outline_modulate = Color("35251e")
	label.position = at
	add_child(label)

func _process(delta: float) -> void:
	for bush in _tumbleweeds:
		var drift := Wind.get_velocity() * delta * .7
		bush.position += drift
		bush.rotate_z(-drift.x * 2)
		if absf(bush.position.x) > 11:
			bush.position.x = -signf(bush.position.x)*10.9
	if _windmill:
		_windmill.rotate_z(-(0.4 + Wind.get_velocity().length() * 0.5) * delta)

func set_time_of_day(preset: String) -> void:
	sun.rotation_degrees.x = -65 if preset == "noon" else -12 if preset == "night" else -24
	sun.light_energy = .15 if preset == "night" else 1.4
	sun.light_color = Color(.5,.62,1) if preset == "night" else Color(1,.86,.68)
	atmosphere.ambient_light_energy = .25 if preset == "night" else .8
	var sky_material := atmosphere.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = Color("0a1128") if preset == "night" else Color("3f74b5") if preset == "noon" else Color("46618f")
	sky_material.sky_horizon_color = Color("2a3350") if preset == "night" else Color("c4d5dc") if preset == "noon" else Color("f2a65f")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.sky_cover_modulate = Color(0.8, 0.85, 1.0) if preset == "night" else Color.BLACK
	sky_material.sky_energy_multiplier = 0.6 if preset == "night" else 1.0
	atmosphere.fog_light_color = Color("242e43") if preset == "night" else Color("cfa87b")
	FX.smoke_tint = Color(0.3, 0.34, 0.46) if preset == "night" else Color.WHITE if preset == "noon" else Color(1.0, 0.93, 0.84)
	for light in lanterns:
		light.visible = preset == "night"


## Adds a box to the range. `solid` boxes stop bullets and the player.
func add_box(size: Vector3, at: Vector3, color: Color, solid := true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Target.make_material(color, 0.0, 0.9)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	if not solid:
		instance.position = at
		add_child(instance)
		return instance
	var body := StaticBody3D.new()
	body.position = at
	body.add_child(instance)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


## A table: top surface at `height`, centered on `at` (ground position).
func add_table(at: Vector3, width := 2.4, height := 0.9) -> void:
	add_box(Vector3(width, 0.08, 0.7), at + Vector3(0, height - 0.04, 0), TIMBER)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			add_box(
				Vector3(0.08, height - 0.08, 0.08),
				at + Vector3(x * (width * 0.5 - 0.1), (height - 0.08) * 0.5, z * 0.28), TIMBER
			)


## A rail fence: top rail surface at `height`, centered on `at`.
func add_fence(at: Vector3, width := 6.4, height := 1.05) -> void:
	add_box(Vector3(width, 0.1, 0.14), at + Vector3(0, height - 0.05, 0), TIMBER)
	add_box(Vector3(width, 0.1, 0.06), at + Vector3(0, height * 0.5, 0), TIMBER)
	var posts := maxi(int(width / 1.5), 1)
	for i in posts + 1:
		add_box(
			Vector3(0.12, height, 0.12),
			at + Vector3(-width * 0.5 + 0.2 + i * (width - 0.4) / posts, height * 0.5, 0), TIMBER
		)


func _build_sky() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, 140.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.4
	sun.shadow_enabled = Settings.shadows
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.3, 0.45, 0.7)
	sky_material.sky_horizon_color = Color(0.95, 0.75, 0.55)
	sky_material.ground_bottom_color = Color(0.35, 0.28, 0.2)
	sky_material.ground_horizon_color = Color(0.95, 0.75, 0.55)
	sky_material.sky_cover = _star_texture()
	sky_material.sky_curve = 0.12
	sky_material.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	atmosphere = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("cfa87b")
	env.fog_density = .0007
	# Let the sky keep its own colour; the fog is for the ground.
	env.fog_sky_affect = 0.2
	env.volumetric_fog_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	env.volumetric_fog_density = .0015
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
