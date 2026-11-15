class_name QuickDraw
extends GameMode
## A duel against the clock. Each round: holster, wait for the church bell,
## draw and hit the man opposite. Reaction time runs from the bell to the
## hit. Going for the gun before the bell is a foul that adds time; taking
## too long loses the round. The run is rated on the average reaction.

## The bell. Phase 5 hangs the sound on this; the HUD shows "DRAW!".
signal bell_rang
## `reaction_ms` is INF for a lost round.
signal round_finished(round_number: int, reaction_ms: float)
signal fouled

enum Phase { HOLSTERING, STEADY, DRAW, ROUND_OVER }

@export var rounds := 5
@export var opponent_distance := 12.0
## The bell rings a random time in this range after the gun is holstered.
@export var min_wait := 2.0
@export var max_wait := 5.0
## Seconds after the bell before the other man gets his shot off.
@export var shot_limit := 3.0
@export var foul_penalty_ms := 500.0
@export var pause_between_rounds := 2.2

var phase := Phase.HOLSTERING
var round_number := 0
## One entry per finished round, in milliseconds (INF = lost).
var reaction_times: Array[float] = []
var fouls := 0
var opponent: CutoutTarget

var _wait := 0.0
var _bell_usec := 0
var _penalty_ms := 0.0
var _message := ""
var _pause_usec := 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_pause_usec = Time.get_ticks_usec()
	elif what == NOTIFICATION_UNPAUSED and _pause_usec > 0:
		if phase == Phase.DRAW:
			_bell_usec += Time.get_ticks_usec() - _pause_usec
		_pause_usec = 0


func _setup() -> void:
	environment.add_box(Vector3(0.6, 0.02, 0.6), Vector3(0, 0.01, 0), RangeEnvironment.DARK, false)
	opponent = spawn_target(CutoutTarget, Vector3(0, 0, -opponent_distance)) as CutoutTarget
	opponent.hit.connect(_on_opponent_hit)
	player.weapon_switch_enabled = false
	player.dead_eye.enabled = false
	player.draw_started.connect(_on_player_drew)


func _on_play_started() -> void:
	_begin_round()


func _tick(delta: float) -> void:
	# The heartbeat and the clock rise while you wait for the bell.
	MusicDirector.set_layer(2, 1.0 if phase in [Phase.HOLSTERING, Phase.STEADY] else 0.25)
	match phase:
		Phase.HOLSTERING:
			if player.is_fully_holstered():
				phase = Phase.STEADY
				_wait = randf_range(min_wait, max_wait)
				_message = "Steady... wait for the bell."
		Phase.STEADY:
			_wait -= delta
			if _wait <= 0.0:
				phase = Phase.DRAW
				_bell_usec = Time.get_ticks_usec()
				_message = "DRAW!"
				bell_rang.emit()
				AudioManager.play_at(&"bell", Vector3(0, 4, -12), 2)
		Phase.DRAW:
			if _since_bell_ms() > shot_limit * 1000.0:
				_end_round(INF, "Too slow. Round missed.")
		Phase.ROUND_OVER:
			_wait -= delta
			if _wait <= 0.0:
				if round_number >= rounds:
					finish()
				else:
					_begin_round()


## Milliseconds since the bell, measured on the wall clock so slow motion
## cannot flatter the player.
func _since_bell_ms() -> float:
	return (Time.get_ticks_usec() - _bell_usec) / 1000.0


func _begin_round() -> void:
	round_number += 1
	_penalty_ms = 0.0
	phase = Phase.HOLSTERING
	_message = "Holster your gun (H)."
	player.weapons[0].refill()
	player.holster()
	opponent.pop_up()


func _on_player_drew() -> void:
	if state != State.PLAYING or phase != Phase.STEADY:
		return
	# Jumped the bell: time is added to this round and the wait starts over.
	fouls += 1
	_penalty_ms += foul_penalty_ms
	phase = Phase.HOLSTERING
	_message = "TOO EARLY! +%d ms. Holster and wait for the bell." % int(foul_penalty_ms)
	player.holster()
	fouled.emit()
	MusicDirector.sting("sting_fail")


func _on_opponent_hit(zone: StringName, _points: int) -> void:
	if phase != Phase.DRAW:
		return
	var reaction := _since_bell_ms() + _penalty_ms
	_end_round(reaction, "%d ms%s" % [roundi(reaction), "  (headshot)" if zone == &"head" else ""])


func _end_round(reaction_ms: float, message: String) -> void:
	reaction_times.append(reaction_ms)
	phase = Phase.ROUND_OVER
	_wait = pause_between_rounds
	_message = message
	opponent.drop(false)
	round_finished.emit(round_number, reaction_ms)
	if not is_finite(reaction_ms):
		MusicDirector.sting("sting_fail")


## Fastest and mean reaction over the rounds won, in ms (INF if none).
func get_best_ms() -> float:
	var best := INF
	for time in reaction_times:
		best = minf(best, time)
	return best


func get_average_ms() -> float:
	var total := 0.0
	var wins := 0
	for time in reaction_times:
		if is_finite(time):
			total += time
			wins += 1
	return total / wins if wins > 0 else INF


func _build_result() -> Dictionary:
	var wins := reaction_times.filter(func(time: float) -> bool: return is_finite(time)).size()
	var average := get_average_ms()
	# Lost rounds count at the full time limit, so ducking a slow round by
	# missing on purpose never helps the average.
	var rated := 0.0
	for time in reaction_times:
		rated += time if is_finite(time) else shot_limit * 1000.0
	rated /= maxf(reaction_times.size(), 1.0)
	return {
		"score": roundi(rated),
		"average_ms": roundi(average) if is_finite(average) else -1,
		"best_ms": roundi(get_best_ms()) if wins > 0 else -1,
		"rounds": reaction_times.size(),
		"wins": wins,
		"fouls": fouls,
		"accuracy": GameState.get_accuracy(),
		"time": elapsed,
	}


func get_headline() -> String:
	return "%d / %d" % [mini(maxi(round_number, 1), rounds), rounds]


func get_objective() -> String:
	var best := get_best_ms()
	return "Best draw %d ms" % roundi(best) if is_finite(best) else "Wait for the bell"


func get_banner() -> String:
	if state != State.PLAYING:
		return super()
	match phase:
		Phase.DRAW: return "DRAW!"
		Phase.ROUND_OVER: return _message
		Phase.HOLSTERING: return "TOO EARLY" if _penalty_ms > 0.0 else ""
	return ""


func get_banner_detail() -> String:
	if state != State.PLAYING:
		return super()
	match phase:
		Phase.HOLSTERING:
			return "Holster your gun  ·  %s" % FrontierUI.key("holster")
		Phase.STEADY:
			return "Steady...  wait for the bell"
	return ""


func get_verdict() -> String:
	return ["Slow on the draw", "Quick enough to live", "Fast hands", "Fastest gun in the territory"][clampi(int(result.get("stars", 0)), 0, 3)]


func get_result_lines() -> Array:
	var lines := [
		["Rounds won", "%d of %d" % [result.get("wins", 0), result.get("rounds", 0)]],
		["Fastest draw", "%d ms" % result.best_ms if int(result.get("best_ms", -1)) >= 0 else "none"],
		["Average of rounds won", "%d ms" % result.average_ms if int(result.get("average_ms", -1)) >= 0 else "none"],
		["Fouls", str(result.get("fouls", 0))],
	]
	var best := SaveSystem.get_record(challenge_id)
	if not best.is_empty():
		lines.append(["Your record", _format_score(best.get("score", 0))])
	return lines


func get_status_text() -> String:
	match state:
		State.COUNTDOWN:
			return "%s starts in %d..." % [display_name, ceili(get_countdown())]
		State.PLAYING:
			return "%s   round %d / %d\n%s" % [display_name, round_number, rounds, _message]
	return display_name
