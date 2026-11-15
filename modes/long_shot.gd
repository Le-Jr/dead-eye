class_name LongShot
extends GameMode

const DISTANCES := [100.0, 200.0, 300.0, 400.0, 500.0]
var stage := 0
var stage_hits := 0
var plates: Array[SteelPlateTarget] = []
var previous_wind: Vector3
var previous_gusts := 0.0

func _setup() -> void:
	previous_wind = Wind.direction * Wind.base_speed
	previous_gusts = Wind.gustiness
	player.switch_weapon(3)
	for i in DISTANCES.size():
		var plate := spawn_target(SteelPlateTarget, Vector3(0,0,-DISTANCES[i]),0,{"plate_radius": .65 + i*.15,"frame_height": 3.0 + i*.2,"base_points": 200+i*100}) as SteelPlateTarget
		plate.hit.connect(_on_plate_hit.bind(i))
		plates.append(plate)
		_set_plate_enabled(plate, i == 0)
	Wind.set_wind(Vector3.RIGHT, 1.0, .15)

func _on_play_started() -> void:
	player.weapon_switch_enabled = false
	player.dead_eye.enabled = false

func _set_plate_enabled(plate: SteelPlateTarget, value: bool) -> void:
	plate.is_active = value
	plate.visible = value
	for body in plate.find_children("*", "CollisionObject3D", true, false):
		if not body.has_meta("original_layer"):
			body.set_meta("original_layer",body.collision_layer)
		body.set_deferred("collision_layer",body.get_meta("original_layer") if value else 0)

func _on_plate_hit(_zone: StringName, _points: int, index: int) -> void:
	if state != State.PLAYING or index != stage:
		return
	stage_hits += 1
	if stage_hits < 2:
		return
	_set_plate_enabled(plates[stage],false)
	stage += 1
	stage_hits = 0
	if stage == DISTANCES.size():
		# Target registers score after emitting hit; finish after it has done so.
		finish.call_deferred()
	else:
		_set_plate_enabled(plates[stage],true)
		Wind.set_wind(Vector3.RIGHT if stage % 2 == 0 else Vector3.LEFT,1.0+stage*.6,.15)

func get_objective() -> String:
	if stage >= DISTANCES.size():
		return "Every distance cleared"
	return "%d m   ·   hit %d of 2" % [DISTANCES[stage], stage_hits]


func get_banner_detail() -> String:
	if state == State.COUNTDOWN:
		return "Set your sight with %s / %s and read the wind" % [FrontierUI.key("sight_down"), FrontierUI.key("sight_up")]
	return ""


func get_result_lines() -> Array:
	var lines := super()
	lines.insert(0, ["Distances cleared", "%d of %d" % [stage, DISTANCES.size()]])
	return lines


func get_status_text() -> String:
	if state == State.COUNTDOWN:
		return "LONG SHOT  ·  %d" % ceili(get_countdown())
	if stage >= DISTANCES.size():
		return "ALL DISTANCES CLEARED"
	return "%d m  ·  %d / 2 HITS\nQ / E: adjust sight · Read the wind · Hold the firing line" % [DISTANCES[stage],stage_hits]

func _tick(_delta: float) -> void:
	# Fixed firing line: the challenge cannot be shortened by walking downrange.
	player.position.x = clampf(player.position.x,-1,1)
	player.position.z = clampf(player.position.z,-.3,.3)

func _exit_tree() -> void:
	Wind.set_wind(previous_wind,previous_wind.length(),previous_gusts)
	super._exit_tree()
