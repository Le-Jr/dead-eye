class_name RevolverModel
extends WeaponModel
## Single-action army revolver: nickel frame, fluted cylinder, ivory grips,
## brass guard and straps. The bore runs along -Z through the origin; the top
## of the front sight sits at y = 0.02.

const CHAMBERS := 6
const STEP := TAU / CHAMBERS
const BORE_OFFSET := 0.012  # chamber centers from the cylinder axis
const CYLINDER_RADIUS := 0.021
const HAMMER_COCKED := 0.95
const HAMMER_HALF := 0.35

var _pose: Node3D  # whole gun; tilted for the reload
var _cylinder: Node3D
var _hammer: Node3D
var _cartridge: MeshInstance3D
var _rims: Array[MeshInstance3D] = []
var _thumb_hand: Node3D


func _init() -> void:
	_pose = _pivot(self, Vector3.ZERO, "Pose")
	var s := silver()
	var b := brass()

	# Barrel with a crowned muzzle, ejector housing beside it, base pin below.
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.046, 0.0094), Vector2(-0.053, 0.0094), Vector2(-0.055, 0.0088),
		Vector2(-0.184, 0.0082), Vector2(-0.188, 0.0074),
	]), s)
	_muzzle_rim(_pose, Vector3(0, 0, -0.188), 0.0085)
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.05, 0.0046), Vector2(-0.143, 0.0046), Vector2(-0.148, 0.003),
	]), s, Vector3(0.0105, -0.0125, 0), 12)
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.149, 0.0056), Vector2(-0.152, 0.0056),
	]), s, Vector3(0.0105, -0.0125, 0), 12)
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.046, 0.0032), Vector2(-0.07, 0.0032), Vector2(-0.072, 0.0044), Vector2(-0.077, 0.0044),
	]), s, Vector3(0, -BORE_OFFSET, 0), 10)
	_plate(_pose, PackedVector2Array([
		Vector2(-0.187, 0.0075), Vector2(-0.169, 0.0075), Vector2(-0.174, 0.02), Vector2(-0.183, 0.02),
	]), 0.0022, s, 0.0004)

	# Frame: one piece around the cylinder window, with the top strap over it.
	_plate(_pose, PackedVector2Array([
		Vector2(-0.058, 0.0115), Vector2(-0.05, 0.0155), Vector2(-0.0455, 0.0155), Vector2(-0.0455, -0.034),
		Vector2(0.0, -0.034), Vector2(0.0, 0.0155), Vector2(0.006, 0.0155), Vector2(0.016, 0.011),
		Vector2(0.024, 0.003), Vector2(0.031, -0.012), Vector2(0.035, -0.03), Vector2(0.031, -0.041),
		Vector2(0.012, -0.047), Vector2(-0.03, -0.047), Vector2(-0.058, -0.043),
	]), 0.0172, s, 0.002)
	_plate(_pose, PackedVector2Array([
		Vector2(-0.0455, 0.0105), Vector2(0.0, 0.0105), Vector2(0.0, 0.0155), Vector2(-0.0455, 0.0155),
	]), 0.013, s, 0.0015)
	# Recoil shield and loading gate.
	_lathe(_pose, PackedVector2Array([
		Vector2(0.0005, 0.019), Vector2(0.0025, 0.0228), Vector2(0.011, 0.0228), Vector2(0.013, 0.02),
	]), s, Vector3(0, -BORE_OFFSET, 0), 24)
	_plate(_pose, PackedVector2Array([
		Vector2(0.002, -0.004), Vector2(0.012, -0.004), Vector2(0.012, -0.02), Vector2(0.002, -0.02),
	]), 0.0016, s, 0.0006, 0.0232)
	for side: float in [-1.0, 1.0]:
		_screw(_pose, Vector3(side * 0.0088, -0.04, -0.012))
		_screw(_pose, Vector3(side * 0.0088, -0.04, 0.012))
	_engrave(_pose, 0.0089, -0.04, -0.03, 0.022, b)

	# Trigger and guard.
	_wire(_pose, _arc(Vector2(-0.008, -0.048), Vector2(0.022, 0.021), 180, 360, 12), 0.0024, b)
	_plate(_pose, PackedVector2Array([
		Vector2(-0.0105, -0.046), Vector2(-0.006, -0.046), Vector2(-0.0065, -0.057),
		Vector2(-0.0095, -0.063), Vector2(-0.0115, -0.062), Vector2(-0.0095, -0.056),
	]), 0.005, s, 0.0008)

	# Grip: brass straps showing front and back, ivory panels over them.
	var grip_path := PackedVector3Array([
		Vector3(0, -0.036, 0.022), Vector3(0, -0.055, 0.029), Vector3(0, -0.075, 0.038),
		Vector3(0, -0.096, 0.049), Vector3(0, -0.113, 0.058),
	])
	_loft(_pose, grip_path, PackedVector2Array([
		Vector2(0.0125, 0.0125), Vector2(0.0135, 0.013), Vector2(0.0146, 0.0145),
		Vector2(0.0153, 0.017), Vector2(0.015, 0.0185),
	]), ivory(), 2.6)
	_loft(_pose, grip_path, PackedVector2Array([
		Vector2(0.0058, 0.0148), Vector2(0.0058, 0.0153), Vector2(0.0058, 0.0168),
		Vector2(0.0058, 0.0193), Vector2(0.0058, 0.0208),
	]), b, 4.0)
	_loft(_pose, PackedVector3Array([Vector3(0, -0.113, 0.058), Vector3(0, -0.1165, 0.0598)]),
		PackedVector2Array([Vector2(0.0128, 0.0195), Vector2(0.0118, 0.0185)]), b, 2.6)
	for side: float in [-1.0, 1.0]:
		_screw(_pose, Vector3(side * 0.0148, -0.077, 0.039), b)

	_cylinder = _pivot(_pose, Vector3(0, -BORE_OFFSET, -0.022))
	_build_cylinder(s)

	_hammer = _pivot(_pose, Vector3(0, -0.004, 0.017))
	_plate(_hammer, PackedVector2Array([
		Vector2(-0.0035, -0.004), Vector2(0.0045, -0.004), Vector2(0.0055, 0.012), Vector2(0.0125, 0.0185),
		Vector2(0.0165, 0.0195), Vector2(0.0165, 0.0225), Vector2(0.006, 0.0235), Vector2(-0.002, 0.02),
		Vector2(-0.0045, 0.012),
	]), 0.0072, s, 0.001)

	# Loose cartridge carried in during an insert.
	_cartridge = _cartridge_mesh(_pose, 0.0056, 0.04)
	_cartridge.visible = false

	_marker(_pose, "Muzzle", Vector3(0, 0, -0.19))
	_marker(_pose, "Eject", Vector3(0.016, -0.006, 0.01))

	# Shooting hand, index finger along the guard.
	_thumb_hand = _hand(_pose, 1.0, [[0.6, 0.95, 0.5], [1.35, 1.4, 0.8], [1.4, 1.4, 0.8], [1.45, 1.45, 0.8]],
		Vector3(-1.15, 0.25, 0.0), 0.55, Vector3(0.5, 0.25, 0.83))
	_place_hand(_thumb_hand, Vector3(0.009, -0.076, 0.049), Vector3(0, -0.89, 0.457), Vector3(0.6, 0, 0.8), 0.082)
	_add_load_hand()


## The cylinder: six flutes milled between the chambers, chamber mouths at
## the front, cartridge rims at the back.
func _build_cylinder(material: Material) -> void:
	var rings := 12
	var around := 72
	var half := 0.022
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings + 1:
		var z := lerpf(-half, half, float(i) / rings)
		var chamfer := 1.0 - 0.09 * smoothstep(half - 0.003, half, absf(z))
		var flute_depth := 0.0042 * (1.0 - smoothstep(-0.001, 0.009, z))
		for j in around:
			var a := j * TAU / around
			var between := cos((a - PI / 2.0 - STEP * 0.5) * CHAMBERS)
			var cut := pow(clampf((between - 0.35) / 0.65, 0.0, 1.0), 0.8)
			var radius := (CYLINDER_RADIUS - flute_depth * cut) * chamfer
			st.add_vertex(Vector3(cos(a) * radius, sin(a) * radius, z))
	for i in rings:
		for j in around:
			var k := (j + 1) % around
			var a := i * around + j
			var b := i * around + k
			var c := (i + 1) * around + k
			var d := (i + 1) * around + j
			for index: int in [a, c, b, a, d, c]:
				st.add_index(index)
	st.generate_normals()
	_part(_cylinder, st.commit(), material, Vector3.ZERO)
	for z: float in [-half, half]:
		_lathe(_cylinder, PackedVector2Array([Vector2(z, 0.0), Vector2(z, CYLINDER_RADIUS * 0.915)]) if z > 0.0
			else PackedVector2Array([Vector2(z, CYLINDER_RADIUS * 0.915), Vector2(z, 0.0)]), material, Vector3.ZERO, 24)
	for i in CHAMBERS:
		var angle := PI / 2.0 + i * STEP
		var at := Vector3(cos(angle), sin(angle), 0.0) * BORE_OFFSET
		_part(_cylinder, _tube(0.0054, 0.001, 12), bore(), at + Vector3(0, 0, -half - 0.0003), true)
		_rims.append(_part(_cylinder, _tube(0.0062, 0.002, 12), brass(), at + Vector3(0, 0, half + 0.0005), true))


func _play_procedural(action: StringName, duration: float, args: Dictionary) -> void:
	match action:
		&"cock":
			_tween_to(_hammer, "rotation:x", HAMMER_COCKED, duration)
			_spin_cylinder(args.get("index", 0), 0.0, duration)
		&"hammer_fall":
			_tween_to(_hammer, "rotation:x", 0.0, duration)
		&"chambers":
			var states: Array = args.get("states", [])
			for i in mini(states.size(), _rims.size()):
				_rims[i].visible = states[i] != Revolver.Chamber.EMPTY
				_rims[i].material_override = (
					spent_brass() if states[i] == Revolver.Chamber.SPENT else null
				)
		&"reload_open":
			_tween_to(_hammer, "rotation:x", HAMMER_HALF, duration)
			_tween_to(_pose, "rotation", Vector3(0.55, 0.5, -0.6), duration)
			_tween_to(_pose, "position", Vector3(-0.05, 0.02, 0.04), duration)
			_begin_loading(duration)
		&"reload_close":
			_tween_to(_hammer, "rotation:x", 0.0, duration)
			_tween_to(_pose, "rotation", Vector3.ZERO, duration)
			_tween_to(_pose, "position", Vector3.ZERO, duration)
			_spin_cylinder(args.get("index", 0), 0.0, duration * 0.6)
			_cartridge.visible = false
			_end_loading(duration)
		&"eject":
			_spin_cylinder(args.get("index", 0), -STEP, duration * 0.5)
		&"insert":
			_spin_cylinder(args.get("index", 0), -STEP, duration * 0.4)
			_animate_insert(
				_cartridge, Vector3(0.05, -0.03, 0.1), Vector3(0.0104, -0.006, 0.03), duration
			)


## Rotates the cylinder so chamber `index` sits at `offset` radians from the
## top (0 = under the hammer, -STEP = at the loading gate). Always turns the
## same way, like the real ratchet.
func _spin_cylinder(index: int, offset: float, duration: float) -> void:
	var target := -index * STEP + offset
	var current := _cylinder.rotation.z
	target += ceilf((current - target) / TAU) * TAU
	if target > current + 0.001:
		target -= TAU
	_tween_to(_cylinder, "rotation:z", target, duration)
