extends Node
## Scoring for the current run. Targets report raw hits here; this turns them
## into points using three layers:
##   combo   - consecutive hits without a miss (and without dawdling)
##   style   - a multiplier earned by trick shots that fades if you play safe
##   tricks  - flat bonuses for the shot itself (juggle, ricochet, mid-air...)
## Modes read the totals when they finish; the HUD listens to the signals.

## Emitted for every scoring hit and every penalty. Keys: points (final),
## base, zone, tags (PackedStringArray, e.g. "BULLSEYE", "TRICK SHOT"),
## combo, multiplier, target, position.
signal scored(event: Dictionary)
signal score_changed(score: int)
signal combo_changed(combo: int, multiplier: float)
signal style_changed(style: float)
signal shot_fired

## Seconds a combo survives without another hit.
const COMBO_WINDOW := 4.0
const COMBO_STEP := 5  # hits per multiplier step
const COMBO_STEP_BONUS := 0.5
const MAX_COMBO_MULTIPLIER := 3.0
const TRICK_BONUS := 150
const STYLE_PER_TRICK := 0.25
const MAX_STYLE := 3.0
## Style holds this long after a trick, then drains.
const STYLE_HOLD := 6.0
const STYLE_DECAY := 0.15  # per second
const LONG_SHOT_DISTANCE := 100.0
const HIP_SHOT_DISTANCE := 20.0

var score := 0
var shots_fired := 0
var shots_hit := 0
var combo := 0
var max_combo := 0
var style := 1.0
var trick_shots := 0
var bullseyes := 0
var innocents_hit := 0

var _combo_timer := 0.0
var _style_timer := 0.0


func _process(delta: float) -> void:
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_break_combo()
	if style > 1.0:
		_style_timer -= delta
		if _style_timer <= 0.0:
			_set_style(maxf(style - STYLE_DECAY * delta, 1.0))


func reset() -> void:
	score = 0
	shots_fired = 0
	shots_hit = 0
	combo = 0
	max_combo = 0
	style = 1.0
	trick_shots = 0
	bullseyes = 0
	innocents_hit = 0
	score_changed.emit(score)
	combo_changed.emit(combo, 1.0)
	style_changed.emit(style)


func register_shot() -> void:
	shots_fired += 1
	shot_fired.emit()


## A shot that touched no target. Ends the combo.
func register_miss() -> void:
	_break_combo()


## Called by Target.take_hit(). Negative `base_points` is a penalty (an
## innocent): it costs points and wipes combo and style.
func register_hit(target: Node, zone: StringName, base_points: int, bullet: BulletHit = null) -> void:
	var event := {
		"base": base_points, "zone": zone, "target": target,
		"position": bullet.position if bullet else Vector3.ZERO,
	}
	if base_points < 0:
		innocents_hit += 1
		score += base_points
		_break_combo()
		_set_style(1.0)
		event.merge({"points": base_points, "tags": PackedStringArray(["INNOCENT!"]), "combo": 0, "multiplier": 1.0})
		scored.emit(event)
		score_changed.emit(score)
		return

	shots_hit += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	_combo_timer = COMBO_WINDOW

	var tags := PackedStringArray()
	var tricks := _find_tricks(zone, bullet)
	if zone == &"bullseye":
		bullseyes += 1
		tags.append("BULLSEYE!")
	elif zone == &"head":
		bullseyes += 1
		tags.append("HEADSHOT!")
	if not tricks.is_empty():
		trick_shots += tricks.size()
		tags.append("TRICK SHOT!")
		tags.append_array(tricks)
		_style_timer = STYLE_HOLD
		_set_style(minf(style + STYLE_PER_TRICK * tricks.size(), MAX_STYLE))

	var multiplier := get_combo_multiplier() * style
	var points := roundi(base_points * multiplier) + TRICK_BONUS * tricks.size()
	score += points
	event.merge({"points": points, "tags": tags, "combo": combo, "multiplier": multiplier})
	scored.emit(event)
	combo_changed.emit(combo, get_combo_multiplier())
	score_changed.emit(score)


## Flat points that are not a hit (a spinner going all the way round).
func register_bonus(points: int, tag: String, target: Node = null) -> void:
	trick_shots += 1
	_style_timer = STYLE_HOLD
	_set_style(minf(style + STYLE_PER_TRICK, MAX_STYLE))
	score += points
	scored.emit({
		"points": points, "base": points, "zone": &"bonus", "target": target,
		"position": (target as Node3D).global_position if target is Node3D else Vector3.ZERO,
		"tags": PackedStringArray(["TRICK SHOT!", tag]), "combo": combo,
		"multiplier": 1.0,
	})
	score_changed.emit(score)


## Seconds before the current combo lapses (0 with no combo).
func get_combo_time_left() -> float:
	return maxf(_combo_timer, 0.0) if combo > 0 else 0.0


func get_combo_multiplier() -> float:
	@warning_ignore("integer_division")
	return minf(1.0 + (combo / COMBO_STEP) * COMBO_STEP_BONUS, MAX_COMBO_MULTIPLIER)


## Hits per shot, 0..1. (Pellets and ricochets can land more hits than shots.)
func get_accuracy() -> float:
	if shots_fired == 0:
		return 0.0
	return minf(float(shots_hit) / float(shots_fired), 1.0)


func _find_tricks(zone: StringName, bullet: BulletHit) -> PackedStringArray:
	var tricks := PackedStringArray()
	if zone == &"juggle":
		tricks.append("JUGGLE")
	elif zone == &"midair":
		tricks.append("MID-AIR")
	if bullet:
		if bullet.ricochet:
			tricks.append("RICOCHET")
		if bullet.distance >= LONG_SHOT_DISTANCE:
			tricks.append("LONG SHOT")
		elif not bullet.aimed and not bullet.ricochet and bullet.distance >= HIP_SHOT_DISTANCE:
			tricks.append("FROM THE HIP")
	return tricks


func _break_combo() -> void:
	if combo == 0:
		return
	combo = 0
	combo_changed.emit(combo, 1.0)


func _set_style(value: float) -> void:
	if not is_equal_approx(value, style):
		style = value
		style_changed.emit(style)
