class_name LeverRifleModel
extends WeaponModel
## Lever-action repeater with a brass receiver, octagonal barrel, full
## magazine tube and a crescent butt. Bore along -Z through the origin, which
## sits in the middle of the receiver. Sight line at y = 0.031.

const LEVER_OPEN := 0.95
const HAMMER_COCKED := 0.8

var _pose: Node3D
var _lever: Node3D
var _hammer: Node3D
var _cartridge: MeshInstance3D
## The shooting hand hangs from this so it can follow the lever down.
var _grip: Node3D


func _init() -> void:
	_pose = _pivot(self, Vector3.ZERO, "Pose")
	var s := steel()
	var w := wood()
	var b := brass()

	# Receiver with raised side plates and the loading gate on the right.
	_plate(_pose, PackedVector2Array([
		Vector2(-0.082, 0.011), Vector2(0.052, 0.011), Vector2(0.064, 0.006), Vector2(0.078, -0.012),
		Vector2(0.074, -0.03), Vector2(0.066, -0.04), Vector2(-0.078, -0.04), Vector2(-0.082, -0.034),
	]), 0.0335, b, 0.0025)
	for side: float in [-1.0, 1.0]:
		_plate(_pose, PackedVector2Array([
			Vector2(-0.062, 0.004), Vector2(0.03, 0.004), Vector2(0.046, -0.006), Vector2(0.04, -0.031),
			Vector2(-0.062, -0.031),
		]), 0.0014, b, 0.0007, side * 0.0171)
		_screw(_pose, Vector3(side * 0.0182, -0.024, -0.052))
		_screw(_pose, Vector3(side * 0.0182, -0.004, 0.03))
	_plate(_pose, PackedVector2Array([
		Vector2(-0.03, -0.011), Vector2(-0.004, -0.011), Vector2(0.002, -0.016), Vector2(-0.004, -0.021),
		Vector2(-0.03, -0.021), Vector2(-0.034, -0.016),
	]), 0.0012, s, 0.0005, 0.0182)
	_engrave(_pose, 0.0181, -0.016, -0.012, 0.03, s)
	# Dust cover on top.
	_plate(_pose, PackedVector2Array([
		Vector2(-0.05, 0.011), Vector2(0.02, 0.011), Vector2(0.02, 0.0135), Vector2(-0.05, 0.0135),
	]), 0.014, s, 0.001)

	# Octagonal barrel over a full-length magazine tube.
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.078, 0.0098), Vector2(-0.672, 0.0092), Vector2(-0.676, 0.0085),
	]), s, Vector3.ZERO, 8, true, PI / 8.0)
	_muzzle_rim(_pose, Vector3(0, 0, -0.676), 0.009)
	_lathe(_pose, PackedVector2Array([Vector2(-0.078, 0.0068), Vector2(-0.655, 0.0068)]), s, Vector3(0, -0.0205, 0), 14)
	_lathe(_pose, PackedVector2Array([
		Vector2(-0.653, 0.0073), Vector2(-0.662, 0.0073), Vector2(-0.665, 0.0055),
	]), b, Vector3(0, -0.0205, 0), 14)
	_loft(_pose, PackedVector3Array([Vector3(0, -0.0103, -0.598), Vector3(0, -0.0103, -0.612)]),
		PackedVector2Array([Vector2(0.0112, 0.0212), Vector2(0.0112, 0.0212)]), s, 2.4)

	# Fore-end with its brass cap.
	_loft(_pose, PackedVector3Array([
		Vector3(0, -0.018, -0.082), Vector3(0, -0.0185, -0.18), Vector3(0, -0.019, -0.285),
	]), PackedVector2Array([Vector2(0.0172, 0.0205), Vector2(0.0166, 0.0198), Vector2(0.0156, 0.0186)]), w, 2.5)
	_loft(_pose, PackedVector3Array([
		Vector3(0, -0.019, -0.283), Vector3(0, -0.019, -0.296), Vector3(0, -0.019, -0.301),
	]), PackedVector2Array([Vector2(0.0163, 0.0194), Vector2(0.016, 0.019), Vector2(0.0125, 0.015)]), b, 2.5)

	# Butt stock: slim wrist swelling to the butt, crescent plate, tang on top.
	_loft(_pose, PackedVector3Array([
		Vector3(0, -0.016, 0.062), Vector3(0, -0.022, 0.1), Vector3(0, -0.034, 0.16),
		Vector3(0, -0.05, 0.26), Vector3(0, -0.064, 0.36), Vector3(0, -0.072, 0.44),
	]), PackedVector2Array([
		Vector2(0.0152, 0.0172), Vector2(0.015, 0.016), Vector2(0.016, 0.02),
		Vector2(0.0185, 0.034), Vector2(0.0195, 0.048), Vector2(0.019, 0.056),
	]), w, 2.5)
	_plate(_pose, PackedVector2Array([
		Vector2(0.434, -0.012), Vector2(0.447, -0.017), Vector2(0.452, -0.07), Vector2(0.447, -0.127),
		Vector2(0.434, -0.132), Vector2(0.443, -0.07),
	]), 0.038, b, 0.004)
	_plate(_pose, PackedVector2Array([
		Vector2(0.07, 0.003), Vector2(0.125, -0.0065), Vector2(0.125, -0.0085), Vector2(0.07, 0.0),
	]), 0.009, b, 0.0008)

	# Sights: notched rear leaf on the barrel, blade up front.
	_part(_pose, _box(0.014, 0.004, 0.03), s, Vector3(0, 0.011, -0.125))
	_plate(_pose, PackedVector2Array([
		Vector2(-0.112, 0.0125), Vector2(-0.132, 0.016), Vector2(-0.132, 0.018), Vector2(-0.112, 0.0145),
	]), 0.008, s, 0.0006)
	for side: float in [-1.0, 1.0]:
		_part(_pose, _box(0.004, 0.02, 0.004), s, Vector3(side * 0.0045, 0.02, -0.13))
	_part(_pose, _box(0.008, 0.004, 0.014), s, Vector3(0, 0.0105, -0.665))
	_part(_pose, _box(0.002, 0.024, 0.008), s, Vector3(0, 0.02, -0.665))
	# Trigger.
	_plate(_pose, PackedVector2Array([
		Vector2(0.041, -0.04), Vector2(0.046, -0.04), Vector2(0.047, -0.051), Vector2(0.043, -0.057),
		Vector2(0.041, -0.056), Vector2(0.043, -0.05),
	]), 0.004, s, 0.0007)

	# Lever: the guard bow, then the finger loop behind it.
	_lever = _pivot(_pose, Vector3(0, -0.037, 0.0))
	var c := case_hardened()
	_plate(_lever, PackedVector2Array([
		Vector2(-0.006, -0.002), Vector2(0.03, -0.002), Vector2(0.034, -0.02), Vector2(0.062, -0.024),
		Vector2(0.062, -0.03), Vector2(0.03, -0.026), Vector2(0.025, -0.008), Vector2(-0.006, -0.008),
	]), 0.008, c, 0.0012)
	var loop := PackedVector3Array()
	for corner: Array in [[Vector2(0.134, -0.014), 0], [Vector2(0.134, -0.032), -90], [Vector2(0.072, -0.032), -180], [Vector2(0.072, -0.014), -270]]:
		loop.append_array(_arc(corner[0], Vector2(0.012, 0.012), corner[1] + 90, corner[1], 4))
	loop.append(loop[0])
	_wire(_lever, loop, 0.0034, c)

	_hammer = _pivot(_pose, Vector3(0, 0.008, 0.07))
	_plate(_hammer, PackedVector2Array([
		Vector2(-0.004, -0.006), Vector2(0.004, -0.006), Vector2(0.005, 0.01), Vector2(0.012, 0.017),
		Vector2(0.013, 0.021), Vector2(0.004, 0.02), Vector2(-0.004, 0.014),
	]), 0.008, c, 0.001)
	_hammer.rotation.x = HAMMER_COCKED

	_cartridge = _cartridge_mesh(_pose, 0.0056, 0.04)
	_cartridge.visible = false

	_marker(_pose, "Muzzle", Vector3(0, 0, -0.68))
	_marker(_pose, "Eject", Vector3(0, 0.02, 0.02))

	# Right hand on the wrist with three fingers through the loop; left under the fore-end.
	# The hand hangs from a pivot down by the elbow, so that swinging it keeps
	# the fingers inside the loop as the lever drops.
	_grip = _pivot(_pose, Vector3(0.15, -0.23, 0.23))
	_grip_hand(_grip, Vector3(0, -0.023, 0.105) - _grip.position, Vector3(0, -0.57, 0.82), 1.6, Vector2(0.018, 0.019),
		[[0.35, 1.0, 0.9], [0.58, 1.45, 0.95], [0.6, 1.45, 0.97], [0.66, 1.45, 1.0]],
		Vector3(0.37, 1.05, 0.0), 0.15, Vector3(0.3, -0.55, 0.78), 0.012)
	_support_hand = _hand(_pose, -1.0, [[1.15, 1.3, 0.9], [1.2, 1.35, 0.9], [1.2, 1.35, 0.9], [1.15, 1.3, 0.9]],
		Vector3(-0.9, -0.5, 0.0), 0.4, Vector3(-0.74, 0.31, 0.56))
	_place_hand(_support_hand, Vector3(0, -0.04, -0.19), Vector3(0, 0, -1), Vector3(0.3, -0.9, 0), 0.066)
	_support_home = _support_hand.position
	_add_load_hand()


func _play_procedural(action: StringName, duration: float, _args: Dictionary) -> void:
	match action:
		&"lever_open":
			# The bolt runs back over the hammer and cocks it; the muzzle dips
			# as the off hand takes the weight.
			_tween_to(_lever, "rotation:x", LEVER_OPEN, duration)
			_tween_to(_grip, "rotation:x", -0.46, duration)
			_tween_to(_hammer, "rotation:x", HAMMER_COCKED, duration)
			_tween_to(_pose, "rotation", Vector3(-0.07, 0.0, 0.12), duration)
		&"lever_close":
			_tween_to(_lever, "rotation:x", 0.0, duration)
			_tween_to(_grip, "rotation:x", 0.0, duration)
			_tween_to(_pose, "rotation", Vector3.ZERO, duration)
		&"hammer_fall":
			_tween_to(_hammer, "rotation:x", 0.0, duration)
		&"reload_open":
			# Roll the right side up so the loading gate faces the shooter.
			_tween_to(_pose, "rotation", Vector3(0.12, 0.2, 0.85), duration)
			_tween_to(_pose, "position", Vector3(-0.05, 0.03, 0.02), duration)
			_begin_loading(duration)
		&"reload_close":
			_tween_to(_pose, "rotation", Vector3.ZERO, duration)
			_tween_to(_pose, "position", Vector3.ZERO, duration)
			_cartridge.visible = false
			_end_loading(duration)
		&"insert":
			_animate_insert(
				_cartridge, Vector3(0.07, -0.02, 0.1), Vector3(0.016, -0.016, 0.0), duration
			)
