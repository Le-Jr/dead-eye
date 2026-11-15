class_name SharpsRifleModel
extends WeaponModel
## Falling-block long rifle: heavy half-octagon barrel, case-hardened action
## and side lock, tang peep sight and globe front sight. Bore along -Z
## through the origin (middle of the receiver).
##
## The sights are geometrically honest: the peep disc rides up its staff by
## exactly the amount that points the bore `zero angle` above the sight line.

## Distance from the eye to the peep disc when aimed.
const EYE_RELIEF := 0.075
const PEEP_Z := 0.085
const FRONT_SIGHT := Vector3(0, 0.03, -0.8)
const LEVER_OPEN := 0.7
const BLOCK_DROP := 0.032
const HAMMER_COCKED := 0.8

var _pose: Node3D
var _lever: Node3D
var _block: Node3D
var _hammer: Node3D
var _peep: Node3D
var _cartridge: MeshInstance3D


func _init() -> void:
	_pose = _pivot(self, Vector3.ZERO, "Pose")
	var s := steel()
	var w := wood()
	var c := case_hardened()

	# Action body, open on top where the block drops, and the lock plate.
	for side: float in [-1.0, 1.0]:
		_plate(_pose, PackedVector2Array([
			Vector2(-0.05, 0.014), Vector2(-0.036, 0.018), Vector2(0.03, 0.018), Vector2(0.05, 0.006),
			Vector2(0.05, -0.04), Vector2(-0.05, -0.042),
		]), 0.007, c, 0.0018, side * 0.0145)
	_plate(_pose, PackedVector2Array([
		Vector2(-0.05, 0.012), Vector2(0.012, 0.012), Vector2(0.012, -0.022), Vector2(0.05, -0.022),
		Vector2(0.05, -0.04), Vector2(-0.05, -0.042),
	]), 0.024, c, 0.0005)
	_plate(_pose, PackedVector2Array([
		Vector2(-0.034, 0.006), Vector2(0.03, 0.009), Vector2(0.072, -0.003), Vector2(0.09, -0.017),
		Vector2(0.066, -0.029), Vector2(-0.02, -0.029), Vector2(-0.038, -0.012),
	]), 0.0032, c, 0.0012, 0.0192)
	_engrave(_pose, 0.0212, -0.012, 0.035, 0.05, silver())
	for z: float in [-0.022, 0.07]:
		_screw(_pose, Vector3(0.0212, -0.02, z))

	# Barrel: octagonal at the breech, turned round ahead of the fore-end.
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.048, 0.0132), Vector2(-0.33, 0.0128),
	]), s, Vector3.ZERO, 8, true, PI / 8.0)
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.328, 0.0128), Vector2(-0.335, 0.0118), Vector2(-0.805, 0.0108), Vector2(-0.811, 0.0098),
	]), s, Vector3.ZERO, 18)
	_muzzle_rim(_pose, Vector3(0, 0, -0.811), 0.0115)

	# Fore-end with a pewter tip and one barrel band.
	_loft(_pose, PackedVector3Array([
		Vector3(0, -0.021, -0.052), Vector3(0, -0.0215, -0.16), Vector3(0, -0.021, -0.27),
	]), PackedVector2Array([Vector2(0.0188, 0.0188), Vector2(0.018, 0.018), Vector2(0.0165, 0.016)]), w, 2.5)
	_loft(_pose, PackedVector3Array([
		Vector3(0, -0.021, -0.268), Vector3(0, -0.02, -0.292), Vector3(0, -0.017, -0.303),
	]), PackedVector2Array([Vector2(0.0172, 0.0167), Vector2(0.0168, 0.016), Vector2(0.011, 0.009)]), silver(), 2.5)
	_loft(_pose, PackedVector3Array([Vector3(0, -0.012, -0.196), Vector3(0, -0.012, -0.208)]),
		PackedVector2Array([Vector2(0.0192, 0.0262), Vector2(0.0192, 0.0262)]), s, 2.6)

	# Butt stock with a straight wrist and a flat steel butt plate.
	_loft(_pose, PackedVector3Array([
		Vector3(0, -0.016, 0.05), Vector3(0, -0.022, 0.1), Vector3(0, -0.034, 0.16),
		Vector3(0, -0.05, 0.26), Vector3(0, -0.064, 0.37), Vector3(0, -0.073, 0.455),
	]), PackedVector2Array([
		Vector2(0.0172, 0.0192), Vector2(0.0165, 0.0175), Vector2(0.0175, 0.021),
		Vector2(0.02, 0.036), Vector2(0.021, 0.05), Vector2(0.0205, 0.057),
	]), w, 2.5)
	_loft(_pose, PackedVector3Array([Vector3(0, -0.073, 0.454), Vector3(0, -0.0737, 0.461)]),
		PackedVector2Array([Vector2(0.021, 0.058), Vector2(0.0195, 0.0565)]), s, 2.5)

	# Folded barrel leaf (decorative) and the globe front sight.
	_part(_pose, _box(0.012, 0.004, 0.03), s, Vector3(0, 0.014, -0.13))
	_part(_pose, _box(0.008, 0.004, 0.014), s, FRONT_SIGHT - Vector3(0, 0.0185, 0))
	_part(_pose, _box(0.004, 0.012, 0.006), s, FRONT_SIGHT - Vector3(0, 0.012, 0))
	_part(_pose, _ring(0.006, 0.0075), s, FRONT_SIGHT, true)
	_part(_pose, _box(0.0012, 0.006, 0.0012), s, FRONT_SIGHT - Vector3(0, 0.003, 0))
	# Double set triggers.
	for z: float in [0.046, 0.062]:
		_plate(_pose, PackedVector2Array([
			Vector2(z, -0.041), Vector2(z + 0.004, -0.041), Vector2(z + 0.0045, -0.052),
			Vector2(z + 0.001, -0.058), Vector2(z - 0.001, -0.057), Vector2(z + 0.001, -0.051),
		]), 0.004, s, 0.0007)

	# Breech block: slides down inside the receiver when the lever opens.
	_block = _pivot(_pose, Vector3(0, 0.006, 0.03))
	_plate(_block, PackedVector2Array([
		Vector2(-0.015, 0.015), Vector2(0.015, 0.015), Vector2(0.015, -0.015), Vector2(-0.015, -0.015),
	]), 0.021, s, 0.0015)

	# Under-lever doubling as the trigger guard.
	_lever = _pivot(_pose, Vector3(0, -0.042, -0.03))
	var bow := PackedVector3Array([Vector3(0, -0.002, 0.0), Vector3(0, -0.004, 0.06)])
	bow.append_array(_arc(Vector2(0.092, -0.004), Vector2(0.032, 0.03), 180, 330, 10))
	bow.append_array(PackedVector3Array([Vector3(0, -0.024, 0.14), Vector3(0, -0.03, 0.17)]))
	_wire(_lever, bow, 0.0034, c)

	# Side hammer on the lock plate.
	_hammer = _pivot(_pose, Vector3(0.024, -0.004, 0.035))
	_plate(_hammer, PackedVector2Array([
		Vector2(-0.006, -0.008), Vector2(0.006, -0.008), Vector2(0.007, 0.014), Vector2(0.015, 0.026),
		Vector2(0.017, 0.032), Vector2(0.006, 0.033), Vector2(-0.003, 0.028), Vector2(-0.009, 0.022),
		Vector2(-0.013, 0.022), Vector2(-0.013, 0.015), Vector2(-0.006, 0.012),
	]), 0.008, c, 0.0012)

	# Tang sight: a staff on the wrist with a peep disc that rides up it.
	_part(_pose, _box(0.016, 0.003, 0.022), s, Vector3(0, 0.0005, PEEP_Z))
	_part(_pose, _box(0.001, 0.046, 0.001), s, Vector3(0.0066, 0.023, PEEP_Z))
	_part(_pose, _box(0.001, 0.046, 0.001), s, Vector3(-0.0066, 0.023, PEEP_Z))
	_peep = _pivot(_pose, Vector3(0, FRONT_SIGHT.y, PEEP_Z))
	_part(_peep, _ring(0.0042, 0.006), s, Vector3.ZERO, true)

	_cartridge = _cartridge_mesh(_pose, 0.0065, 0.06)
	_cartridge.visible = false

	_marker(_pose, "Muzzle", Vector3(0, 0, -0.82))
	_marker(_pose, "Eject", Vector3(0, 0.012, 0.04))

	# Right hand on the wrist, left hand under the fore-end.
	_grip_hand(_pose, Vector3(0, -0.024, 0.11), Vector3(0, -0.57, 0.82), 1.6, Vector2(0.019, 0.02),
		[[0.35, 1.0, 0.9], [0.58, 1.45, 0.95], [0.6, 1.45, 0.97], [0.66, 1.45, 1.0]],
		Vector3(0.28, 1.18, 0.0), 0.15, Vector3(0.3, -0.55, 0.78), 0.012)
	_support_hand = _hand(_pose, -1.0, [[1.15, 1.3, 0.9], [1.2, 1.35, 0.9], [1.2, 1.35, 0.9], [1.15, 1.3, 0.9]],
		Vector3(-0.9, -0.5, 0.0), 0.4, Vector3(-0.74, 0.31, 0.56))
	_place_hand(_support_hand, Vector3(0, -0.041, -0.2), Vector3(0, 0, -1), Vector3(0.3, -0.9, 0), 0.066)
	_support_home = _support_hand.position
	_add_load_hand()


## Model-space position of the peep aperture for a given bore elevation.
func get_peep_position(zero_angle: float) -> Vector3:
	var sight_radius := PEEP_Z - FRONT_SIGHT.z
	return Vector3(0, FRONT_SIGHT.y + tan(zero_angle) * sight_radius, PEEP_Z)


func _play_procedural(action: StringName, duration: float, args: Dictionary) -> void:
	match action:
		&"cock":
			_tween_to(_hammer, "rotation:x", HAMMER_COCKED, duration)
		&"hammer_fall":
			_tween_to(_hammer, "rotation:x", 0.0, duration)
		&"zero":
			_tween_to(_peep, "position", get_peep_position(args.get("angle", 0.0)), duration)
		&"breech_open":
			_tween_to(_lever, "rotation:x", LEVER_OPEN, duration * 0.7)
			_tween_to(_block, "position:y", 0.006 - BLOCK_DROP, duration * 0.7)
			_tween_to(_pose, "rotation", Vector3(0.22, 0.25, 0.55), duration)
			_tween_to(_pose, "position", Vector3(-0.05, 0.04, 0.05), duration)
			_begin_loading(duration)
		&"breech_close":
			_tween_to(_lever, "rotation:x", 0.0, duration * 0.6)
			_tween_to(_block, "position:y", 0.006, duration * 0.6)
			_tween_to(_pose, "rotation", Vector3.ZERO, duration)
			_tween_to(_pose, "position", Vector3.ZERO, duration)
			_cartridge.visible = false
			_end_loading(duration)
		&"insert":
			_animate_insert(_cartridge, Vector3(0.04, 0.045, 0.1), Vector3(0, 0, 0.02), duration)
