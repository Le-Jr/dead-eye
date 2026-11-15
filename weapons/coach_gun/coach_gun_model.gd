class_name CoachGunModel
extends WeaponModel
## Side-by-side coach gun: short twin barrels, case-hardened action with
## outside hammers, bird's-head grip. The barrels hinge down from the front
## of the receiver. Origin on the centerline between the bores at the breech;
## sight line (rib and bead) at y = 0.018.

const HINGE := Vector3(0, -0.03, -0.07)
const BORE_X := 0.012
const BREAK_ANGLE := -0.55
const HAMMER_COCKED := 0.8

var _pose: Node3D
var _barrels: Node3D
var _hammers: Array[Node3D] = []
var _shells: Array[MeshInstance3D] = []
var _loose_shell: MeshInstance3D


func _init() -> void:
	_pose = _pivot(self, Vector3.ZERO, "Pose")
	var s := steel()
	var w := wood()
	var c := case_hardened()

	# Everything that swings down when the action breaks. `bore` is the model
	# origin in the barrel group's space, so parts below read in gun coordinates.
	_barrels = _pivot(_pose, HINGE)
	var bore := -HINGE
	for side: float in [-1.0, 1.0]:
		var at := bore + Vector3(side * BORE_X, 0, 0)
		_lathe(_barrels, PackedVector2Array([
			Vector2(0.0, 0.0122), Vector2(-0.06, 0.0118), Vector2(-0.496, 0.011), Vector2(-0.5, 0.0102),
		]), s, at, 18)
		_muzzle_rim(_barrels, at + Vector3(0, 0, -0.5), 0.0125)
		_shells.append(
			_part(_barrels, _tube(0.0105, 0.004, 14), brass(), at + Vector3(0, 0, 0.001), true)
		)
	# Top rib with a brass bead, and the rib underneath.
	_plate(_barrels, PackedVector2Array([
		Vector2(0.0, 0.0105), Vector2(-0.5, 0.0095), Vector2(-0.5, 0.0135), Vector2(0.0, 0.0145),
	]), 0.007, s, 0.0008).position = bore
	_part(_barrels, _ball(0.0022), brass(), bore + Vector3(0, 0.0158, -0.494))
	_plate(_barrels, PackedVector2Array([
		Vector2(-0.27, -0.0085), Vector2(-0.5, -0.0085), Vector2(-0.5, -0.0125), Vector2(-0.27, -0.0125),
	]), 0.006, s, 0.0008).position = bore
	# Splinter fore-end, its iron, and the hinge knuckle.
	var furniture := _pivot(_barrels, bore)
	_loft(furniture, PackedVector3Array([
		Vector3(0, -0.022, -0.066), Vector3(0, -0.024, -0.12), Vector3(0, -0.024, -0.22),
		Vector3(0, -0.021, -0.268), Vector3(0, -0.018, -0.278),
	]), PackedVector2Array([
		Vector2(0.0225, 0.014), Vector2(0.0235, 0.0155), Vector2(0.022, 0.0145),
		Vector2(0.0185, 0.011), Vector2(0.012, 0.006),
	]), w, 2.8)
	_plate(furniture, PackedVector2Array([
		Vector2(-0.002, -0.012), Vector2(-0.068, -0.012), Vector2(-0.068, -0.034), Vector2(-0.03, -0.042),
		Vector2(-0.002, -0.034),
	]), 0.03, c, 0.002)
	_part(_barrels, _tube(0.0125, 0.046, 16), c, Vector3.ZERO).rotation.z = PI / 2
	_marker(_barrels, "Muzzle", bore + Vector3(0, 0, -0.5))

	# Action body with rounded fences behind each breech and side lock plates.
	_plate(_pose, PackedVector2Array([
		Vector2(0.002, 0.013), Vector2(0.066, 0.013), Vector2(0.088, 0.004), Vector2(0.094, -0.014),
		Vector2(0.086, -0.032), Vector2(0.002, -0.036),
	]), 0.05, c, 0.003)
	for side: float in [-1.0, 1.0]:
		_part(_pose, _ball(0.0135), c, Vector3(side * BORE_X, 0.002, 0.014)).scale = Vector3(1, 1, 0.9)
		_plate(_pose, PackedVector2Array([
			Vector2(0.008, 0.004), Vector2(0.06, 0.006), Vector2(0.1, -0.006), Vector2(0.112, -0.018),
			Vector2(0.09, -0.028), Vector2(0.012, -0.026),
		]), 0.002, c, 0.0009, side * 0.0258)
		_screw(_pose, Vector3(side * 0.0272, -0.012, 0.03))
		_screw(_pose, Vector3(side * 0.0272, -0.014, 0.09))
	_engrave(_pose, 0.0271, -0.011, 0.058, 0.04, silver())
	# Top lever on the tang.
	_plate(_pose, PackedVector2Array([
		Vector2(0.05, 0.013), Vector2(0.092, 0.0105), Vector2(0.096, 0.013), Vector2(0.052, 0.017),
	]), 0.008, s, 0.001)

	# Two triggers inside a brass guard.
	for z: float in [0.058, 0.074]:
		_plate(_pose, PackedVector2Array([
			Vector2(z, -0.034), Vector2(z + 0.004, -0.034), Vector2(z + 0.0045, -0.045),
			Vector2(z + 0.001, -0.051), Vector2(z - 0.001, -0.05), Vector2(z + 0.001, -0.044),
		]), 0.004, s, 0.0007, -0.004 if z < 0.06 else 0.004)
	_wire(_pose, _arc(Vector2(0.07, -0.034), Vector2(0.047, 0.03), 180, 360, 14), 0.003, brass())

	# Bird's-head grip.
	_loft(_pose, PackedVector3Array([
		Vector3(0, -0.01, 0.088), Vector3(0, -0.016, 0.14), Vector3(0, -0.035, 0.19),
		Vector3(0, -0.065, 0.225), Vector3(0, -0.098, 0.245), Vector3(0, -0.114, 0.25),
	]), PackedVector2Array([
		Vector2(0.021, 0.021), Vector2(0.0185, 0.0195), Vector2(0.018, 0.019),
		Vector2(0.0188, 0.0205), Vector2(0.0195, 0.0215), Vector2(0.0135, 0.015),
	]), w, 2.4)
	_part(_pose, _ball(0.006), brass(), Vector3(0, -0.118, 0.251)).scale = Vector3(1.6, 0.5, 1.8)

	for side: float in [-1.0, 1.0]:
		var hammer := _pivot(_pose, Vector3(side * 0.02, 0.012, 0.075))
		_plate(hammer, PackedVector2Array([
			Vector2(-0.005, -0.008), Vector2(0.005, -0.008), Vector2(0.006, 0.01), Vector2(0.014, 0.019),
			Vector2(0.016, 0.024), Vector2(0.006, 0.024), Vector2(-0.003, 0.02), Vector2(-0.008, 0.012),
			Vector2(-0.012, 0.012), Vector2(-0.012, 0.007),
		]), 0.007, c, 0.001)
		_hammers.append(hammer)

	_loose_shell = _cartridge_mesh(_pose, 0.0105, 0.065, true)
	_loose_shell.visible = false
	_marker(_pose, "Eject", Vector3(0, 0.0, 0.03))

	# Right hand on the grip, left hand under the fore-end (it rides the barrels).
	_grip_hand(_pose, Vector3(0, -0.022, 0.155), Vector3(0, -0.5, 0.87), 1.6, Vector2(0.02, 0.0206),
		[[0.35, 1.0, 0.9], [0.58, 1.45, 0.95], [0.6, 1.45, 0.97], [0.66, 1.45, 1.0]],
		Vector3(-0.1, 1.2, 0.0), 0.15, Vector3(0.3, -0.55, 0.78), 0.012)
	_support_hand = _hand(furniture, -1.0, [[1.15, 1.3, 0.9], [1.2, 1.35, 0.9], [1.2, 1.35, 0.9], [1.15, 1.3, 0.9]],
		Vector3(-0.9, -0.5, 0.0), 0.4, Vector3(-0.74, 0.31, 0.56))
	_place_hand(_support_hand, Vector3(0, -0.04, -0.17), Vector3(0, 0, -1), Vector3(0.3, -0.9, 0), 0.066)
	_support_home = _support_hand.position
	_add_load_hand()


func _play_procedural(action: StringName, duration: float, args: Dictionary) -> void:
	match action:
		&"cock":
			for i in _hammers.size():
				# Thumb rolls across one hammer, then the other.
				_tween_to(_hammers[i], "rotation:x", HAMMER_COCKED, duration * 0.6, duration * 0.4 * i)
		&"hammer_fall":
			_tween_to(_hammers[args.get("index", 0)], "rotation:x", 0.0, duration)
		&"shells":
			var states: Array = args.get("states", [])
			for i in mini(states.size(), _shells.size()):
				_shells[i].visible = states[i] != CoachGun.Shell.EMPTY
				_shells[i].material_override = (
					spent_brass() if states[i] == CoachGun.Shell.SPENT else null
				)
		&"break_open":
			_tween_to(_barrels, "rotation:x", BREAK_ANGLE, duration * 0.7)
			_tween_to(_pose, "rotation", Vector3(0.3, 0.35, 0.3), duration)
			_tween_to(_pose, "position", Vector3(-0.06, 0.05, 0.08), duration)
			_begin_loading(duration)
		&"break_close":
			_tween_to(_barrels, "rotation:x", 0.0, duration * 0.6)
			_tween_to(_pose, "rotation", Vector3.ZERO, duration)
			_tween_to(_pose, "position", Vector3.ZERO, duration)
			_loose_shell.visible = false
			_end_loading(duration)
		&"insert":
			# Breech position of that barrel with the action broken open.
			var side := -1.0 if args.get("index", 0) == 0 else 1.0
			var breech := HINGE + Basis(Vector3.RIGHT, BREAK_ANGLE) * (-HINGE + Vector3(side * BORE_X, 0, 0))
			_loose_shell.rotation.x = BREAK_ANGLE
			_animate_insert(_loose_shell, breech + Vector3(side * 0.03, 0.06, 0.1), breech, duration)
