class_name RevolverModel
extends WeaponModel
## Single-action army revolver: nickel frame, fluted cylinder, ivory grips,
## brass guard and straps. The bore runs along -Z through the origin; the top
## of the front sight sits at y = 0.02.

const CHAMBERS := 6
const STEP := TAU / CHAMBERS
const BORE_OFFSET := 0.012  # chamber centers from the cylinder axis
const CYLINDER_RADIUS := 0.021
const CYLINDER_HALF := 0.0212  # half its length
const CHAMBER_RADIUS := 0.0058
const BORE_RADIUS := 0.0057
const AROUND := 144  # steps round the cylinder
const HAMMER_COCKED := 0.95
const HAMMER_HALF := 0.35

var _pose: Node3D  # whole gun; tilted for the reload
var _cylinder: Node3D
var _hammer: Node3D
var _cartridge: MeshInstance3D
var _rounds: Array[MeshInstance3D] = []  # one cartridge per chamber
var _thumb_hand: Node3D


func _init() -> void:
	_pose = _pivot(self, Vector3.ZERO, "Pose")
	var s := silver()
	var b := brass()

	# Barrel with a crowned muzzle, ejector housing beside it, base pin below.
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.046, 0.0094), Vector2(-0.053, 0.0094), Vector2(-0.055, 0.0088),
		Vector2(-0.184, 0.0082), Vector2(-0.1872, 0.0076), Vector2(-0.188, 0.0068),
		Vector2(-0.188, 0.0062), Vector2(-0.1868, BORE_RADIUS),
	]), s, Vector3.ZERO, 18, false, 0.0, 1)
	_bore(_pose, Vector3(0, 0, -0.1868), BORE_RADIUS)
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
	# The back sweeps round behind the hammer into the grip; the front is
	# rounded off under the barrel.
	_plate(_pose, PackedVector2Array([
		Vector2(-0.058, 0.0105), Vector2(-0.0555, 0.0142), Vector2(-0.051, 0.0155), Vector2(-0.0455, 0.0155),
		Vector2(-0.0455, -0.034), Vector2(0.0, -0.034), Vector2(0.0, 0.0155), Vector2(0.006, 0.0155),
		Vector2(0.0115, 0.0142), Vector2(0.0165, 0.011), Vector2(0.021, 0.0066), Vector2(0.025, 0.0012),
		Vector2(0.0285, -0.0055), Vector2(0.0315, -0.0135), Vector2(0.0335, -0.022), Vector2(0.0345, -0.03),
		Vector2(0.034, -0.0365), Vector2(0.0315, -0.0415), Vector2(0.027, -0.045), Vector2(0.02, -0.0468),
		Vector2(0.012, -0.047), Vector2(-0.03, -0.047), Vector2(-0.044, -0.0465), Vector2(-0.0515, -0.0445),
		Vector2(-0.056, -0.0405), Vector2(-0.058, -0.034),
	]), 0.0172, s, 0.0026)
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
	# The guard is a flat strap, wider than it is thick.
	var bow := _arc(Vector2(-0.008, -0.048), Vector2(0.022, 0.021), 180, 360, 16)
	var strap := PackedVector2Array()
	strap.resize(bow.size())
	strap.fill(Vector2(0.0046, 0.0013))
	_loft(_pose, bow, strap, b, 3.0, 10)
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

	# The cylinder sits a rim's thickness ahead of the recoil shield.
	_cylinder = _pivot(_pose, Vector3(0, -BORE_OFFSET, -0.0235))
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

	# Shooting hand: palm on the right of the grip, middle finger tucked under
	# the guard, index on the trigger, thumb along the left of the frame.
	_thumb_hand = _grip_hand(_pose, Vector3(0, -0.0686, 0.0373), Vector3(0, -0.906, 0.424), 0.0, Vector2(0.0146, 0.016),
		[[0.45, 0.75, 0.6], [0.58, 1.5, 0.82], [0.6, 1.5, 0.85], [0.66, 1.5, 0.9]],
		Vector3(-0.52, 0.66, 0.0), -0.3, Vector3(0.2, -0.36, 0.9))
	_add_load_hand()


## The cylinder: six flutes milled between the chambers, which are bored
## right through, a locking notch behind each flute, and a cartridge in every
## chamber (rim and primer at the back, bullet nose down the hole in front).
func _build_cylinder(material: Material) -> void:
	var rings := 12
	var half := CYLINDER_HALF
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings + 1:
		var z := lerpf(-half, half, float(i) / rings)
		for j in AROUND:
			var a := j * TAU / AROUND
			st.add_vertex(Vector3(cos(a), sin(a), 0) * _cylinder_radius(a, z) + Vector3(0, 0, z))
	for i in rings:
		for j in AROUND:
			var k := (j + 1) % AROUND
			var a := i * AROUND + j
			var b := i * AROUND + k
			var c := (i + 1) * AROUND + k
			var d := (i + 1) * AROUND + j
			for index: int in [a, c, b, a, d, c]:
				st.add_index(index)
	st.generate_normals()
	_part(_cylinder, st.commit(), material, Vector3.ZERO)

	# Both ends, with the chamber mouths left open.
	var ends := SurfaceTool.new()
	ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: float in [-half, half]:
		var normal := Vector3(0, 0, signf(z))
		for j in AROUND:
			var spokes: Array = []
			for a: float in [j * TAU / AROUND, (j + 1) * TAU / AROUND]:
				# Where this spoke enters and leaves the nearest chamber.
				var off := wrapf(a - PI / 2.0 + STEP * 0.5, 0.0, STEP) - STEP * 0.5
				var across := BORE_OFFSET * sin(off)
				var chord := sqrt(maxf(CHAMBER_RADIUS * CHAMBER_RADIUS - across * across, 0.0))
				var along := BORE_OFFSET * cos(off)
				spokes.append([Vector3(cos(a), sin(a), 0), 0.0, along - chord, along + chord, _cylinder_radius(a, z)])
			for band: int in [1, 3]:
				var d0: Vector3 = spokes[0][0]
				var d1: Vector3 = spokes[1][0]
				_quad(ends,
					d0 * spokes[0][band] + Vector3(0, 0, z), d1 * spokes[1][band] + Vector3(0, 0, z),
					d1 * spokes[1][band + 1] + Vector3(0, 0, z), d0 * spokes[0][band + 1] + Vector3(0, 0, z),
					normal, normal, normal, normal)
	_part(_cylinder, ends.commit(), material, Vector3.ZERO)

	var chamber_wall := _material(&"chamber", Color(0.07, 0.075, 0.085), 0.7, 0.55)
	for i in CHAMBERS:
		var angle := PI / 2.0 + i * STEP
		var out := Vector3(cos(angle), sin(angle), 0.0)
		_lathe(_cylinder, PackedVector2Array([Vector2(-half, CHAMBER_RADIUS), Vector2(half, CHAMBER_RADIUS)]),
			chamber_wall, out * BORE_OFFSET, 14, false, 0.0, 0, true)
		var round := _cartridge_mesh(_cylinder, 0.0056, 0.04)
		round.position = out * BORE_OFFSET + Vector3(0, 0, half + 0.0015)
		_rounds.append(round)
		var notch := _part(_cylinder, _box(0.0034, 0.0012, 0.0056), bore(), out * (CYLINDER_RADIUS - 0.0004) + Vector3(0, 0, half - 0.0085))
		notch.rotation.z = angle - PI / 2.0


## The cylinder's outline: its radius at angle `a`, `z` along its length.
## Flutes run from the front to past the middle; both ends are chamfered.
func _cylinder_radius(a: float, z: float) -> float:
	var chamfer := 1.0 - 0.09 * smoothstep(CYLINDER_HALF - 0.003, CYLINDER_HALF, absf(z))
	var flute_depth := 0.0042 * (1.0 - smoothstep(-0.001, 0.009, z))
	var between := cos((a - PI / 2.0 - STEP * 0.5) * CHAMBERS)
	var cut := pow(clampf((between - 0.35) / 0.65, 0.0, 1.0), 0.8)
	return (CYLINDER_RADIUS - flute_depth * cut) * chamfer


func _play_procedural(action: StringName, duration: float, args: Dictionary) -> void:
	match action:
		&"cock":
			_tween_to(_hammer, "rotation:x", HAMMER_COCKED, duration)
			_spin_cylinder(args.get("index", 0), 0.0, duration)
		&"hammer_fall":
			_tween_to(_hammer, "rotation:x", 0.0, duration)
		&"chambers":
			var states: Array = args.get("states", [])
			for i in mini(states.size(), _rounds.size()):
				_rounds[i].visible = states[i] != Revolver.Chamber.EMPTY
				set_cartridge_spent(_rounds[i], states[i] == Revolver.Chamber.SPENT)
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
