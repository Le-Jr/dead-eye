class_name WeaponModel
extends Node3D
## The visual half of a weapon. Weapons never touch meshes directly; they call
## play_action() and ask for the muzzle / eject markers.
##
## To drop in a .glb: make a scene with this script on the root, add the model
## as a child, add Marker3D children named "Muzzle" and "Eject", and (optional)
## an AnimationPlayer whose animation names match the action names the weapon
## sends (listed at the top of each weapon script). Then assign the scene to
## WeaponData.model_scene. Actions without a matching animation are ignored.
##
## The procedural models in weapons/*/ subclass this and build themselves
## with the helpers below: turned parts (_lathe), rounded solids (_loft),
## chamfered plate (_plate) and the player's hands (_hand).

@export var animation_player: AnimationPlayer
signal action_played(action: StringName)

static var _materials := {}
static var _case_meshes := {}

var _muzzle: Node3D
var _eject: Node3D
var _hands: Array[Node3D] = []
var _tweens := {}


func get_muzzle() -> Node3D:
	if _muzzle == null:
		_muzzle = find_child("Muzzle", true, false) as Node3D
	return _muzzle if _muzzle else self


func get_eject_point() -> Node3D:
	if _eject == null:
		_eject = find_child("Eject", true, false) as Node3D
	return _eject if _eject else self


## Plays `action` so that it finishes in `duration` seconds. Authored
## animations win; otherwise the procedural implementation runs.
func play_action(action: StringName, duration := 0.0, args := {}) -> void:
	if duration > 0:
		action_played.emit(action)
	if animation_player and animation_player.has_animation(action):
		var length := animation_player.get_animation(action).length
		var speed := length / duration if duration > 0.0 else 1.0
		animation_player.play(action, -1.0, speed)
		return
	_play_procedural(action, duration, args)


func _play_procedural(_action: StringName, _duration: float, _args: Dictionary) -> void:
	pass


## Hides or shows the player's hands and arms, to look at the gun alone.
func set_hands_visible(shown: bool) -> void:
	for hand in _hands:
		hand.visible = shown


# --- Shared materials -----------------------------------------------------

## Blued gun steel.
static func steel() -> StandardMaterial3D:
	return _material(&"steel", Color(0.1, 0.115, 0.15), 0.9, 0.3)


## Oiled walnut with a grain running along the gun.
static func wood() -> StandardMaterial3D:
	var m := _material(&"wood", Color(0.62, 0.3, 0.15), 0.0, 0.42)
	if m.albedo_texture == null:
		m.albedo_texture = _noise_texture(1873, 0.05, [Color(0.36, 0.2, 0.12), Color(0.8, 0.56, 0.36), Color(1, 0.86, 0.64)])
		m.uv1_scale = Vector3(22, 22, 1.6)
		m.uv1_triplanar = true
		m.clearcoat_enabled = true
		m.clearcoat = 0.35
		m.clearcoat_roughness = 0.35
	return m


static func ivory() -> StandardMaterial3D:
	var m := _material(&"ivory", Color("efe3c2"), 0.0, 0.3)
	if m.albedo_texture == null:
		m.albedo_texture = _noise_texture(7, 0.03, [Color(0.86, 0.8, 0.68), Color(1, 1, 1)])
		m.uv1_scale = Vector3(30, 6, 30)
		m.uv1_triplanar = true
	return m


## Nickel plate.
static func silver() -> StandardMaterial3D:
	return _material(&"silver", Color("c3ccce"), 0.95, 0.22)


static func bore() -> StandardMaterial3D:
	return _material(&"bore", Color("090b0e"), 0.1, 0.9)


static func brass() -> StandardMaterial3D:
	return _material(&"brass", Color(0.83, 0.62, 0.27), 0.95, 0.3)


## Fired cases and shells: dull, sooty brass.
static func spent_brass() -> StandardMaterial3D:
	return _material(&"spent", Color(0.3, 0.24, 0.14), 0.6, 0.6)


static func lead() -> StandardMaterial3D:
	return _material(&"lead", Color(0.42, 0.41, 0.4), 0.6, 0.55)


## Colour case-hardened steel: mottled grey, blue and straw.
static func case_hardened() -> StandardMaterial3D:
	var m := _material(&"case", Color(1, 1, 1), 0.85, 0.34)
	if m.albedo_texture == null:
		m.albedo_texture = _noise_texture(44, 0.035, [Color(0.2, 0.25, 0.36), Color(0.42, 0.42, 0.44), Color(0.56, 0.47, 0.33), Color(0.3, 0.33, 0.42)])
		m.uv1_scale = Vector3(26, 26, 26)
		m.uv1_triplanar = true
	return m


static func skin() -> StandardMaterial3D:
	var m := _material(&"skin", Color("c98f6b"), 0.0, 0.62)
	m.rim_enabled = true
	m.rim = 0.25
	return m


## The player's coat sleeve.
static func sleeve() -> StandardMaterial3D:
	var m := _material(&"sleeve", Color("6a4a33"), 0.0, 0.92)
	if m.albedo_texture == null:
		m.albedo_texture = _noise_texture(3, 0.4, [Color(0.82, 0.8, 0.78), Color(1, 1, 1)])
		m.uv1_scale = Vector3(60, 60, 60)
		m.uv1_triplanar = true
	return m


static func cuff() -> StandardMaterial3D:
	return _material(&"cuff", Color("3d2a1e"), 0.0, 0.8)


static func _material(key: StringName, color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		_materials[key] = m
	return _materials[key]


static func _noise_texture(noise_seed: int, frequency: float, colors: Array) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / maxi(colors.size() - 1, 1))
	ramp.offsets = offsets
	ramp.colors = PackedColorArray(colors)
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	return texture


# --- Shapes ----------------------------------------------------------------
# Three ways to make a part that is not a box. All take real dimensions in
# metres and write their own normals, so round things shade round and flat
# things stay crisp.

## A turned part: `profile` is (z, radius) pairs along the bore axis, in
## order. Good for barrels, cylinders, bands and cartridges. `flat` leaves
## the facets visible (8 segments + flat = an octagonal barrel).
func _lathe(
	parent: Node3D, profile: PackedVector2Array, material: Material, at := Vector3.ZERO,
	segments := 18, flat := false, phase := 0.0, caps := 3, inside := false
) -> MeshInstance3D:
	return _part(parent, lathe_mesh(profile, segments, flat, phase, caps, inside), material, at)


## The mesh behind _lathe. `caps` closes the ends (1 = the first point, 2 = the
## last, 3 = both, 0 = an open tube). `inside` turns the surface to face the
## axis, for bores and chambers. `onto` adds the result to an existing mesh as
## one more surface.
static func lathe_mesh(
	profile: PackedVector2Array, segments := 18, flat := false, phase := 0.0, caps := 3,
	inside := false, onto: ArrayMesh = null
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facing := -1.0 if inside else 1.0
	var forward := signf(profile[profile.size() - 1].x - profile[0].x)
	if forward == 0.0:
		forward = 1.0
	for i in profile.size() - 1:
		var p := profile[i]
		var q := profile[i + 1]
		var slope := Vector2(-(q.y - p.y), q.x - p.x) * forward * facing  # (along z, outward)
		if slope.length() < 0.000001:
			continue
		slope = slope.normalized()
		for s in segments:
			var a0 := phase + s * TAU / segments
			var a1 := phase + (s + 1) * TAU / segments
			var d0 := Vector3(cos(a0), sin(a0), 0)
			var d1 := Vector3(cos(a1), sin(a1), 0)
			var n0 := d0 * slope.y + Vector3(0, 0, slope.x)
			var n1 := d1 * slope.y + Vector3(0, 0, slope.x)
			if flat:
				n0 = ((d0 + d1).normalized() * slope.y + Vector3(0, 0, slope.x)).normalized()
				n1 = n0
			_quad(st,
				d0 * p.y + Vector3(0, 0, p.x), d1 * p.y + Vector3(0, 0, p.x),
				d1 * q.y + Vector3(0, 0, q.x), d0 * q.y + Vector3(0, 0, q.x),
				n0, n1, n1, n0)
	for end: int in [0, profile.size() - 1]:
		var p := profile[end]
		if p.y <= 0.0 or caps & (1 if end == 0 else 2) == 0:
			continue
		var normal := Vector3(0, 0, -forward if end == 0 else forward) * facing
		for s in segments:
			var a0 := phase + s * TAU / segments
			var a1 := phase + (s + 1) * TAU / segments
			_tri(st, Vector3(0, 0, p.x), Vector3(cos(a0), sin(a0), 0) * p.y + Vector3(0, 0, p.x),
				Vector3(cos(a1), sin(a1), 0) * p.y + Vector3(0, 0, p.x), normal, normal, normal)
	return st.commit(onto)


## A rounded solid swept along `path`: at each point the cross-section is a
## superellipse `sizes[i]` (half-width across the gun, half-height).
## `power` 2 is an ellipse; higher is boxier. Good for stocks, grips, arms.
func _loft(
	parent: Node3D, path: PackedVector3Array, sizes: PackedVector2Array, material: Material,
	power := 2.0, segments := 16
) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var normals: Array = []
	var tangents: Array = []
	for i in path.size():
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var up := Vector3.RIGHT.cross(tangent)
		up = up.normalized() if up.length() > 0.01 else Vector3.UP
		var right := tangent.cross(up).normalized()
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for s in segments:
			var a := s * TAU / segments
			var c := cos(a)
			var d := sin(a)
			var x := signf(c) * pow(absf(c), 2.0 / power)
			var y := signf(d) * pow(absf(d), 2.0 / power)
			ring.append(path[i] + right * x * sizes[i].x + up * y * sizes[i].y)
			var nx := signf(c) * pow(absf(c), 2.0 - 2.0 / power) / maxf(sizes[i].x, 0.0001)
			var ny := signf(d) * pow(absf(d), 2.0 - 2.0 / power) / maxf(sizes[i].y, 0.0001)
			ring_normals.append((right * nx + up * ny).normalized())
		rings.append(ring)
		normals.append(ring_normals)
		tangents.append(tangent)
	for i in path.size() - 1:
		for s in segments:
			var t := (s + 1) % segments
			_quad(st, rings[i][s], rings[i][t], rings[i + 1][t], rings[i + 1][s],
				normals[i][s], normals[i][t], normals[i + 1][t], normals[i + 1][s])
	for end: int in [0, path.size() - 1]:
		var normal: Vector3 = tangents[end] * (-1.0 if end == 0 else 1.0)
		for s in segments:
			_tri(st, path[end], rings[end][s], rings[end][(s + 1) % segments], normal, normal, normal)
	return _part(parent, st.commit(), material, Vector3.ZERO)


## A flat part cut from plate: `outline` is the side view as (z, y) points,
## `width` its thickness across the gun, centred on `x`. The edges are
## chamfered by `bevel`. Good for receivers, hammers, triggers, sights.
func _plate(
	parent: Node3D, outline: PackedVector2Array, width: float, material: Material,
	bevel := 0.0012, x := 0.0
) -> MeshInstance3D:
	var count := outline.size()
	var area := 0.0
	for i in count:
		var p := outline[i]
		var q := outline[(i + 1) % count]
		area += p.x * q.y - q.x * p.y
	var turn := 1.0 if area > 0.0 else -1.0
	var edge_normals: Array[Vector2] = []
	for i in count:
		var d := outline[(i + 1) % count] - outline[i]
		edge_normals.append(Vector2(d.y, -d.x).normalized() * turn)
	bevel = minf(bevel, width * 0.45)
	var inset := PackedVector2Array()
	for i in count:
		var n := edge_normals[i] + edge_normals[(i - 1 + count) % count]
		n = n.normalized() / maxf(n.normalized().dot(edge_normals[i]), 0.35)
		inset.append(outline[i] - n * bevel)
	var half := width * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var j := (i + 1) % count
		# Shade round a gentle bend in the outline; keep a real corner crisp.
		var before := edge_normals[(i - 1 + count) % count]
		var after := edge_normals[j]
		var start := (edge_normals[i] + before).normalized() if edge_normals[i].dot(before) > 0.75 else edge_normals[i]
		var finish := (edge_normals[i] + after).normalized() if edge_normals[i].dot(after) > 0.75 else edge_normals[i]
		var na := Vector3(0, start.y, start.x)
		var nb := Vector3(0, finish.y, finish.x)
		var a := Vector3(0, outline[i].y, outline[i].x)
		var b := Vector3(0, outline[j].y, outline[j].x)
		var wall := Vector3(half - bevel, 0, 0)
		_quad(st, a - wall + Vector3(x, 0, 0), b - wall + Vector3(x, 0, 0), b + wall + Vector3(x, 0, 0), a + wall + Vector3(x, 0, 0), na, nb, nb, na)
		for side: float in [-1.0, 1.0]:
			var sa := (na + Vector3(side, 0, 0)).normalized()
			var sb := (nb + Vector3(side, 0, 0)).normalized()
			_quad(st,
				a + Vector3(x + side * (half - bevel), 0, 0), b + Vector3(x + side * (half - bevel), 0, 0),
				Vector3(x + side * half, inset[j].y, inset[j].x), Vector3(x + side * half, inset[i].y, inset[i].x),
				sa, sb, sb, sa)
	var triangles := Geometry2D.triangulate_polygon(inset)
	for side: float in [-1.0, 1.0]:
		var n := Vector3(side, 0, 0)
		for i in range(0, triangles.size(), 3):
			var a := inset[triangles[i]]
			var b := inset[triangles[i + 1]]
			var c := inset[triangles[i + 2]]
			_tri(st, Vector3(x + side * half, a.y, a.x), Vector3(x + side * half, b.y, b.x), Vector3(x + side * half, c.y, c.x), n, n, n)
	return _part(parent, st.commit(), material, Vector3.ZERO)


## Adds a triangle with its corners ordered to face along its normals
## (Godot's front faces wind clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (c - a).cross(b - a).dot(na + nb + nc) < 0.0:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.add_vertex(b)
	else:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nb)
		st.add_vertex(b)
		st.set_normal(nc)
		st.add_vertex(c)


static func _quad(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3
) -> void:
	_tri(st, a, b, c, na, nb, nc)
	_tri(st, a, c, d, na, nc, nd)


## A round rod through `points`.
func _wire(parent: Node3D, points: PackedVector3Array, radius: float, mat: Material) -> void:
	for i in points.size() - 1:
		var delta := points[i + 1] - points[i]
		if delta.length() < 0.00001:
			continue
		var piece := _part(parent, _capsule(radius, delta.length() + radius * 2.0, 6), mat, (points[i + 1] + points[i]) * 0.5)
		piece.quaternion = Quaternion(Vector3.UP, delta.normalized())


## Points on an arc in the gun's side plane (x = 0), for guards and loops.
static func _arc(center: Vector2, radius: Vector2, from_deg: float, to_deg: float, steps := 10) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		points.append(Vector3(0, center.y + sin(a) * radius.y, center.x + cos(a) * radius.x))
	return points


## Leaf-scroll inlay on each side of a receiver, kept below the sight line.
func _engrave(parent: Node3D, x: float, y: float, z: float, length: float, mat: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var points := PackedVector3Array()
		for i in 25:
			var t := float(i) / 24
			points.append(Vector3(side * x, y + sin(t * TAU * 2) * 0.004, z + (t - 0.5) * length))
		_wire(parent, points, 0.0006, mat)
		for i in 5:
			var at := Vector3(side * x, y, z + (float(i) / 4 - 0.5) * length * 0.8)
			_wire(parent, PackedVector3Array([at + Vector3(0, -0.006, -0.006), at, at + Vector3(0, 0.006, -0.006)]), 0.0005, mat)


func _screw(parent: Node3D, at: Vector3, material: Material = null) -> void:
	var disc := _part(parent, _tube(0.003, 0.0016, 10), material if material else steel(), at)
	disc.rotation.z = PI / 2
	_part(parent, _box(0.0019, 0.0006, 0.0046), bore(), at + Vector3(signf(at.x) * 0.0005, 0, 0)).rotation.x = at.z * 40.0


## The black hole and bright crown at the end of a barrel.
func _muzzle_rim(parent: Node3D, at: Vector3, radius: float) -> void:
	_part(parent, _tube(radius * 0.62, 0.001, 14), bore(), at + Vector3(0, 0, -0.0006), true)


## A real hole down a barrel: dark walls and a floor `depth` behind the
## muzzle face at `at`. The barrel's own profile has to stop at the same
## radius with its last end left open (caps = 1).
func _bore(parent: Node3D, at: Vector3, radius: float, depth := 0.03) -> void:
	_lathe(parent, PackedVector2Array([Vector2(0, radius), Vector2(depth, radius)]), bore(), at, 14, false, 0.0, 2, true)


# --- Ammunition ------------------------------------------------------------------

## A cartridge lying along the bore, bullet toward -Z, base at the origin:
## rimmed brass case, primer in its pocket, round-nosed lead bullet. With
## `shell` it is a shotgun shell instead (brass head, paper hull, card wad).
## Use set_cartridge_spent() to turn it into a fired case.
func _cartridge_mesh(parent: Node3D, radius: float, length: float, shell := false) -> MeshInstance3D:
	var case_length := length if shell else length * 0.66
	var holder := _part(parent, case_mesh(radius, case_length, shell), brass(), Vector3.ZERO)
	# Primer: a dark ring where the pocket is, the cup itself, and the dent
	# the firing pin leaves (hidden until the round is spent).
	var cup := 0.3 if shell else 0.36
	_lathe(holder, PackedVector2Array([Vector2(0.00005, radius * (cup + 0.07)), Vector2(-0.0004, radius * (cup + 0.07))]), bore(), Vector3.ZERO, 12, false, 0.0, 1)
	_lathe(holder, PackedVector2Array([Vector2(0.00012, radius * cup), Vector2(-0.0004, radius * cup)]),
		_material(&"primer", Color(0.8, 0.72, 0.52), 0.9, 0.28), Vector3.ZERO, 12, false, 0.0, 1)
	var dent := _lathe(holder, PackedVector2Array([Vector2(0.0002, radius * 0.12), Vector2(-0.0004, radius * 0.12)]), bore(), Vector3.ZERO, 8, false, 0.0, 1)
	dent.name = "Dent"
	dent.visible = false
	if not shell:
		var nose := length - case_length - 0.0015
		var bullet := _lathe(holder, PackedVector2Array([
			Vector2(-case_length + 0.001, radius * 0.93), Vector2(-case_length - 0.0015, radius * 0.93),
			Vector2(-length + nose * 0.6, radius * 0.86), Vector2(-length + nose * 0.3, radius * 0.68),
			Vector2(-length + nose * 0.09, radius * 0.47), Vector2(-length, radius * 0.36),
		]), lead(), Vector3.ZERO, 14, false, 0.0, 2)
		bullet.name = "Bullet"
	return holder


## Shows a cartridge made by _cartridge_mesh as live, or as a fired case:
## sooty brass, the bullet gone, the primer struck.
static func set_cartridge_spent(cartridge: MeshInstance3D, spent: bool) -> void:
	cartridge.set_surface_override_material(0, spent_brass() if spent else brass())
	var bullet := cartridge.get_node_or_null("Bullet") as Node3D
	if bullet:
		bullet.visible = not spent
	var dent := cartridge.get_node_or_null("Dent") as Node3D
	if dent:
		dent.visible = spent


## An empty case (or shotgun shell) `length` long, base at the origin, mouth
## toward -Z. Surface 0 is the brass; the rest carry their own materials.
## Shared and cached: the guns use it and so do the cases they throw out.
static func case_mesh(radius: float, length: float, shell := false, spent := false) -> ArrayMesh:
	var key := "%.4f:%.4f:%s:%s" % [radius, length, shell, spent]
	if _case_meshes.has(key):
		return _case_meshes[key]
	var mesh: ArrayMesh
	var metal := spent_brass() if spent else brass()
	if shell:
		mesh = lathe_mesh(PackedVector2Array([
			Vector2(0, radius * 0.95), Vector2(-0.0004, radius * 1.1), Vector2(-0.0016, radius * 1.1),
			Vector2(-0.002, radius), Vector2(-0.016, radius), Vector2(-0.0165, radius * 0.985),
		]), 16, false, 0.0, 1)
		mesh.surface_set_material(0, metal)
		lathe_mesh(PackedVector2Array([
			Vector2(-0.0165, radius * 0.985), Vector2(-length + 0.003, radius * 0.985),
			Vector2(-length + 0.0008, radius * 0.95), Vector2(-length, radius * 0.88),
		]), 16, false, 0.0, 0, false, mesh)
		mesh.surface_set_material(1, _material(&"shell", Color(0.5, 0.1, 0.07), 0.0, 0.6))
		# The mouth: a card wad on a live shell, a burnt hole on a fired one.
		lathe_mesh(PackedVector2Array([
			Vector2(-length, radius * 0.88), Vector2(-length + (0.02 if spent else 0.0025), radius * 0.88),
		]), 16, false, 0.0, 2, true, mesh)
		mesh.surface_set_material(2, bore() if spent else _material(&"wad", Color(0.72, 0.62, 0.45), 0.0, 0.85))
	else:
		mesh = lathe_mesh(PackedVector2Array([
			Vector2(0, radius * 0.95), Vector2(-0.0003, radius * 1.13), Vector2(-0.0013, radius * 1.13),
			Vector2(-0.0017, radius), Vector2(-length + 0.0006, radius), Vector2(-length, radius * 0.965),
		]), 14, false, 0.0, 1)
		mesh.surface_set_material(0, metal)
		lathe_mesh(PackedVector2Array([
			Vector2(-length, radius * 0.9), Vector2(-length + minf(0.012, length * 0.5), radius * 0.9),
		]), 14, false, 0.0, 2, true, mesh)
		mesh.surface_set_material(1, bore())
	_case_meshes[key] = mesh
	return mesh


# --- Hands -------------------------------------------------------------------

const FINGER_X := [-0.031, -0.0105, 0.0105, 0.0295]
const FINGER_LENGTHS := [[0.042, 0.026, 0.022], [0.046, 0.029, 0.023], [0.043, 0.027, 0.022], [0.034, 0.021, 0.019]]
const FINGER_RADII := [0.0096, 0.01, 0.0095, 0.0084]
const PALM_HALF_THICKNESS := 0.0125
const KNUCKLE_Z := -0.094
const HAND_SCALE := 0.93
## How far a gripping hand is turned in behind the grip, so the forearm ends
## up behind the gun rather than beside it.
const GRIP_TILT := 0.35

## A hand closed around something, on a forearm in a coat sleeve.
##
## In its own space the wrist is at the origin, the fingers point down -Z and
## close toward -Y (the palm side), and the knuckles run along X from the
## index to the little finger. `side` is 1 for a right hand, -1 for a left.
## `curls` is one [knuckle, middle, tip] triple of radians per finger, index
## first. `arm` is the direction the forearm leaves the wrist, in hand space.
## `wrap` is how far (metres) the base of the thumb closes across the palm:
## 0 for a hand lying on something, about 0.028 for a fist round a pistol
## grip, where the heel of the hand fills in behind whatever is held.
func _hand(
	parent: Node3D, side: float, curls: Array, thumb: Vector3, thumb_curl: float, arm: Vector3,
	wrap := 0.0
) -> Node3D:
	var hand := _pivot(parent, Vector3.ZERO)
	_hands.append(hand)
	var flesh := skin()
	_loft(hand, PackedVector3Array([
		Vector3(0, 0, 0.006), Vector3(0, 0, -0.03), Vector3(0, 0, -0.072), Vector3(0, 0, -0.098),
	]), PackedVector2Array([
		Vector2(0.029, 0.0155), Vector2(0.04, 0.0145), Vector2(0.0425, PALM_HALF_THICKNESS), Vector2(0.041, 0.0105),
	]), flesh, 3.2, 14)
	for f in 4:
		var joint := _pivot(hand, Vector3(side * FINGER_X[f], -0.0005, KNUCKLE_Z))
		for s in 3:
			joint.rotation.x = -curls[f][s]
			var length: float = FINGER_LENGTHS[f][s]
			var radius: float = FINGER_RADII[f] * (1.0 - 0.07 * s)
			_part(joint, _capsule(radius, length + radius * 1.5, 8), flesh, Vector3(0, 0, -length * 0.5), true)
			joint = _pivot(joint, Vector3(0, 0, -length))
	# Thumb: two joints on the muscle at its base, and the web of skin that
	# joins it to the index knuckle (what sits against the back of a grip).
	var base := _pivot(hand, Vector3(-side * 0.036, -0.004 - wrap, -0.04 - wrap))
	base.rotation = Vector3(thumb.x, thumb.y * side, thumb.z * side)
	_part(base, _capsule(0.0118, 0.04 + 0.016, 8), flesh, Vector3(0, 0, -0.02), true)
	var tip := _pivot(base, Vector3(0, 0, -0.04))
	tip.rotation.x = -thumb_curl
	_part(tip, _capsule(0.0105, 0.03 + 0.014, 8), flesh, Vector3(0, 0, -0.015), true)
	var thumb_joint: Vector3 = base.transform * Vector3(0, 0, -0.024)
	_loft(hand, PackedVector3Array([
		Vector3(-side * 0.014, -0.005 - wrap * 0.3, 0.0),
		Vector3(-side * 0.03, -0.006 - wrap * 0.75, -0.03 - wrap * 0.5), thumb_joint,
	]), PackedVector2Array([Vector2(0.017, 0.0135), Vector2(0.0165, 0.014), Vector2(0.0125, 0.012)]), flesh, 2.2, 12)
	var index_knuckle := Vector3(side * FINGER_X[0], -0.002, KNUCKLE_Z + 0.008)
	_loft(hand, PackedVector3Array([
		thumb_joint, thumb_joint.lerp(index_knuckle, 0.5) + Vector3(0, 0, 0.012), index_knuckle,
	]), PackedVector2Array([Vector2(0.0115, 0.0105), Vector2(0.012, 0.0095), Vector2(0.0105, 0.0095)]), flesh, 2.0, 10)
	if wrap > 0.0:
		# Heel of the hand, thick under the thumb and thinning to the edge.
		_loft(hand, PackedVector3Array([
			Vector3(-side * 0.044, -0.006 - wrap * 0.55, -0.05), Vector3(-side * 0.036, -0.006 - wrap * 0.55, -0.05),
			Vector3(0, -0.006 - wrap * 0.35, -0.047),
			Vector3(side * 0.035, -0.008 - wrap * 0.12, -0.042), Vector3(side * 0.042, -0.008 - wrap * 0.12, -0.042),
		]), PackedVector2Array([
			Vector2(0.016, 0.004 + wrap * 0.3), Vector2(0.03, 0.006 + wrap * 0.6), Vector2(0.03, 0.006 + wrap * 0.45),
			Vector2(0.024, 0.005 + wrap * 0.25), Vector2(0.013, 0.004 + wrap * 0.1),
		]), flesh, 2.0, 12)

	var d := arm.normalized()
	_part(hand, _ball(0.024), flesh, d * 0.004).scale = Vector3(1.15, 0.75, 1.0)
	_loft(hand, PackedVector3Array([d * 0.0, d * 0.035, d * 0.075]), PackedVector2Array([
		Vector2(0.0275, 0.018), Vector2(0.0285, 0.021), Vector2(0.03, 0.024),
	]), flesh, 2.4, 14)
	_loft(hand, PackedVector3Array([d * 0.05, d * 0.058, d * 0.085, d * 0.09]), PackedVector2Array([
		Vector2(0.037, 0.031), Vector2(0.0395, 0.0335), Vector2(0.0395, 0.0335), Vector2(0.036, 0.03),
	]), cuff(), 2.4, 14)
	_loft(hand, PackedVector3Array([d * 0.085, d * 0.2, d * 0.34, d * 0.5]), PackedVector2Array([
		Vector2(0.0365, 0.031), Vector2(0.044, 0.04), Vector2(0.052, 0.049), Vector2(0.056, 0.054),
	]), sleeve(), 2.2, 14)
	return hand


## Puts a hand where its palm presses on `palm_point`. `across` is the way
## the hand's +X runs (toward the little finger on a right hand, toward the
## thumb on a left) and `back` the way the back of the hand faces; both in
## the parent's space.
## `along` is how far from the wrist the contact is: 0.055 is mid-palm, more
## moves it toward the knuckles for a tight wrap around a thin grip.
func _place_hand(hand: Node3D, palm_point: Vector3, across: Vector3, back: Vector3, along := 0.055) -> void:
	var basis := _hand_basis(across, back)
	hand.transform = Transform3D(basis, palm_point + basis * Vector3(0, PALM_HALF_THICKNESS, along))


## Puts a hand by its knuckles, for a grip the fingers wrap right around:
## `knuckles` is where the middle of the knuckle line goes, beside the grip.
## From there the fingers leave at right angles to `across` and `back`, and
## the palm runs the other way to the wrist.
func _place_knuckles(hand: Node3D, knuckles: Vector3, across: Vector3, back: Vector3) -> void:
	var basis := _hand_basis(across, back)
	hand.transform = Transform3D(basis, knuckles - basis * Vector3(0, 0, KNUCKLE_Z))


## A right hand closed round a grip, thumb wrapped over to the far side.
## `center` is the point on the grip's axis that the middle of the palm
## covers and `down` runs along the grip toward the little finger. `roll`
## turns the hand about the grip: at 0 the palm lies flat on the right side
## with the wrist behind it (a pistol); more brings the palm underneath and
## the wrist out to the right (the wrist of a rifle stock). `size` is the
## grip's half-width and half-depth where the fingers meet it. `fingers` and
## the thumb angles and `wrap` are as for _hand; `arm` is in the parent's
## space.
func _grip_hand(
	parent: Node3D, center: Vector3, down: Vector3, roll: float, size: Vector2,
	fingers: Array, thumb: Vector3, thumb_curl: float, arm: Vector3, wrap := 0.0275
) -> Node3D:
	var x := down.normalized()
	var front := Vector3.RIGHT.cross(x).normalized()  # the side the fingers cross
	var palm := Vector3.RIGHT * cos(roll) + front * sin(roll)  # the side the palm lies on
	front = front * cos(roll) - Vector3.RIGHT * sin(roll)
	var back := palm * cos(GRIP_TILT) - front * sin(GRIP_TILT)
	var hand := _hand(parent, 1.0, fingers, thumb, thumb_curl, _hand_basis(x, back).inverse() * arm, wrap)
	# The knuckles sit behind the middle of the grip so that the first finger
	# joint lands on its front corner.
	var finger_radius: float = FINGER_RADII[1] * HAND_SCALE
	var knuckles := center + palm * (size.x + finger_radius) - front * (0.039 - size.y - finger_radius)
	_place_knuckles(hand, knuckles, x, back)
	return hand


## The hand's axes in its parent's space; see _place_hand for the arguments.
## Use its inverse to turn a parent-space direction into an `arm` for _hand.
static func _hand_basis(across: Vector3, back: Vector3) -> Basis:
	var x := across.normalized()
	var y := (back - x * back.dot(x)).normalized()
	return Basis(x, y, x.cross(y)).scaled(Vector3.ONE * HAND_SCALE)

# --- Construction helpers -------------------------------------------------

func _pivot(parent: Node3D, at: Vector3, node_name := "") -> Node3D:
	var node := Node3D.new()
	if node_name:
		node.name = node_name
	node.position = at
	parent.add_child(node)
	return node


func _marker(parent: Node3D, marker_name: String, at: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = at
	parent.add_child(marker)
	return marker


## Adds a mesh. `along_z` lays a cylinder/torus (built along Y) down the bore.
func _part(
	parent: Node3D, mesh: Mesh, material: Material, at: Vector3, along_z := false
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.set_surface_override_material(0, material)
	instance.position = at
	if along_z:
		instance.rotation.x = PI / 2.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _box(x: float, y: float, z: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(x, y, z)
	return mesh


func _tube(radius: float, length: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _capsule(radius: float, length: float, segments := 8) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)
	mesh.radial_segments = segments
	mesh.rings = 3
	return mesh


func _ball(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	return mesh


func _ring(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 6
	return mesh


## Tweens one property, replacing any tween already running on it.
func _tween_to(
	node: Node3D, property: String, value: Variant, duration: float, delay := 0.0
) -> Tween:
	var key := "%d:%s" % [node.get_instance_id(), property]
	if _tweens.has(key) and _tweens[key].is_valid():
		_tweens[key].kill()
	var tween := create_tween()
	tween.tween_property(node, property, value, maxf(duration, 0.001)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(delay)
	_tweens[key] = tween
	return tween


## Shows `cartridge` travelling from the hand into the gun. The loading
## hand, if the model has one, carries it there.
func _animate_insert(cartridge: Node3D, from: Vector3, to: Vector3, duration: float) -> void:
	cartridge.visible = true
	cartridge.position = from
	_carried = cartridge
	var tween := _tween_to(cartridge, "position", to, duration * 0.85)
	tween.tween_callback(func() -> void: cartridge.visible = false)


# --- The loading hand ---------------------------------------------------------
# The left hand leaves the gun to feed it. It lives in the model's own space
# (not the tilting Pose), so the arm keeps coming from the shooter's side
# while the hand follows whatever cartridge is being carried.

## Where the fingertips pinch a cartridge, in the loading hand's space.
const PINCH := Vector3(0.03, -0.052, -0.128)

var _support_hand: Node3D
var _support_home := Vector3.ZERO
var _load_hand: Node3D
var _carried: Node3D
var _loading := false
## Out of sight, and waiting beside the gun between cartridges.
var _load_rest := Vector3(-0.2, -0.34, 0.16)
var _load_hover := Vector3(-0.06, -0.13, 0.1)


func _add_load_hand() -> void:
	_load_hand = _hand(self, -1.0, [[0.55, 0.8, 0.45], [0.9, 1.1, 0.6], [1.0, 1.15, 0.65], [1.1, 1.2, 0.7]],
		Vector3(-0.75, -0.55, 0.0), 0.45, Vector3(-0.25, -0.35, 1.0))
	var fingers := Vector3(0.42, 0.3, -0.86).normalized()
	var back := Vector3(-0.5, -0.8, -0.3)
	back = (back - fingers * back.dot(fingers)).normalized()
	_load_hand.basis = Basis(back.cross(-fingers), back, -fingers).scaled(Vector3.ONE * HAND_SCALE)
	_load_hand.position = _load_rest
	_load_hand.visible = false


## The support hand lets go and the loading hand comes up.
func _begin_loading(duration: float) -> void:
	_loading = true
	_carried = null
	if _load_hand:
		_load_hand.visible = true
	if _support_hand:
		var tween := _tween_to(_support_hand, "position", _support_home + Vector3(-0.07, -0.16, 0.1), duration * 0.6)
		tween.tween_callback(func() -> void: _support_hand.visible = false)


func _end_loading(duration: float) -> void:
	_loading = false
	_carried = null
	if _support_hand:
		_support_hand.visible = true
		_tween_to(_support_hand, "position", _support_home, duration * 0.8, duration * 0.2)


func _process(delta: float) -> void:
	if _load_hand == null or not _load_hand.visible:
		return
	var target := _load_hover if _loading else _load_rest
	if _loading and is_instance_valid(_carried) and _carried.visible:
		target = to_local(_carried.global_position) - _load_hand.basis * PINCH
	_load_hand.position = _load_hand.position.lerp(target, 1.0 - exp(-14.0 * delta))
	if not _loading and _load_hand.position.distance_to(_load_rest) < 0.03:
		_load_hand.visible = false
