class_name GameMode
extends Node3D
## Base for every playable mode. Builds the scene (environment, player, HUD),
## runs the countdown / play / finished flow, and on finish turns the run
## into a result Dictionary, rates it in stars and hands it to SaveSystem.
##
## Subclasses override the hooks at the bottom. Each mode has its own scene
## in modes/ whose root uses the subclass script.

signal state_changed(state: State)
signal finished(result: Dictionary)

enum State { COUNTDOWN, PLAYING, FINISHED }

const PLAYER_SCENE := preload("res://player/player.tscn")
const ENVIRONMENT_SCENE := preload("res://levels/range_environment.tscn")
const HUD := preload("res://ui/hud.gd")
## Scene per mode id. The menus (phase 4) launch from this table.
const SCENES := {
	&"free_range": "res://modes/free_range.tscn",
	&"gallery": "res://modes/gallery.tscn",
	&"quick_draw": "res://modes/quick_draw.tscn",
	&"long_shot": "res://modes/long_shot.tscn",
}

## Key for high scores in SaveSystem.
@export var challenge_id := &"free_range"
@export var display_name := "Free Range"
## Seconds of play. 0 = untimed (the mode ends itself, or never ends).
@export var time_limit := 0.0
@export var countdown := 3.0
## Scores needed for 1, 2 and 3 stars (ascending). With lower_is_better the
## list is still ordered 1 star first, so it descends.
@export var star_thresholds: Array[float] = []
@export var lower_is_better := false

var state := State.COUNTDOWN
var player: Player
var environment: RangeEnvironment
## Seconds played so far.
var elapsed := 0.0
var time_left := 0.0
## The result of the finished run (empty until then).
var result := {}
var is_new_best := false

var _countdown_left := 0.0


func _ready() -> void:
	environment = ENVIRONMENT_SCENE.instantiate()
	if challenge_id == &"long_shot":
		environment.depth = 550
	add_child(environment)
	player = PLAYER_SCENE.instantiate()
	add_child(player)

	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := HUD.new()
	hud.player = player
	hud.mode = self
	layer.add_child(hud)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	GameState.reset()
	_setup()
	MusicDirector.play(String(challenge_id) if challenge_id in [&"gallery", &"quick_draw"] else "town")
	time_left = time_limit
	_countdown_left = countdown
	if countdown > 0.0:
		player.weapons_locked = true
		MusicDirector.sting("sting_ready")
	else:
		_start_play()


func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown_left -= delta
			if _countdown_left <= 0.0:
				_start_play()
		State.PLAYING:
			elapsed += delta
			if time_limit > 0.0:
				time_left = maxf(time_limit - elapsed, 0.0)
				if time_left <= 0.0:
					finish()
					return
			_tick(delta)

func _exit_tree() -> void:
	AudioManager.clear_voices()


func _unhandled_input(event: InputEvent) -> void:
	# Shortcuts beside the menus: a click grabs the mouse back, F1-F4 jump
	# between modes, Enter restarts a finished run.
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var ids := SCENES.keys()
		var index: int = event.physical_keycode - KEY_F1
		if index >= 0 and index < ids.size():
			get_tree().change_scene_to_file(SCENES[ids[index]])
		elif event.physical_keycode == KEY_ENTER and state == State.FINISHED:
			get_tree().reload_current_scene()


## Seconds left on the starting countdown.
func get_countdown() -> float:
	return maxf(_countdown_left, 0.0)


## Ends the run, scores it and saves it. Safe to call more than once.
func finish() -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	player.dead_eye.cancel()
	player.weapons_locked = true
	result = _build_result()
	result["stars"] = _stars_for(float(result.get("score", 0)))
	if _should_save():
		is_new_best = SaveSystem.submit(challenge_id, result, lower_is_better)
	if is_new_best:
		MusicDirector.sting("sting_record")
	_on_finished()
	MusicDirector.play("results")
	state_changed.emit(state)
	finished.emit(result)


## Places a target built from its script class.
func spawn_target(script: GDScript, at: Vector3, yaw_deg := 0.0, properties := {}) -> Target:
	var target: Target = script.new()
	for key: String in properties:
		target.set(key, properties[key])
	target.position = at
	target.rotation_degrees.y = yaw_deg
	add_child(target)
	return target


func _start_play() -> void:
	state = State.PLAYING
	player.weapons_locked = false
	_on_play_started()
	state_changed.emit(state)


func _stars_for(score: float) -> int:
	var stars := 0
	for threshold in star_thresholds:
		if (score <= threshold) if lower_is_better else (score >= threshold):
			stars += 1
	return stars


# --- Hooks ----------------------------------------------------------------

## Build the mode's targets and props. Runs before the countdown.
func _setup() -> void:
	pass


func _on_play_started() -> void:
	pass


## Called every frame while playing.
func _tick(_delta: float) -> void:
	pass


func _on_finished() -> void:
	pass


## The stats of the run. Must include "score".
func _build_result() -> Dictionary:
	return {
		"score": GameState.score,
		"accuracy": GameState.get_accuracy(),
		"shots": GameState.shots_fired,
		"hits": GameState.shots_hit,
		"max_combo": GameState.max_combo,
		"trick_shots": GameState.trick_shots,
		"bullseyes": GameState.bullseyes,
		"innocents_hit": GameState.innocents_hit,
		"time": elapsed,
	}


func _should_save() -> bool:
	return true


## One line describing the run, for logs and tests.
func get_status_text() -> String:
	return display_name


# --- What the HUD shows -----------------------------------------------------

## The big figure on the mode tag: the clock, a round number...
func get_headline() -> String:
	if time_limit <= 0.0:
		return ""
	var left := ceili(time_left)
	@warning_ignore("integer_division")
	return "%d:%02d" % [left / 60, left % 60]


## The line under the headline: what to do, or how it is going.
func get_objective() -> String:
	return ""


## Large text across the middle of the screen. Empty most of the time.
func get_banner() -> String:
	if state == State.COUNTDOWN and countdown > 0.0:
		return str(ceili(get_countdown()))
	return ""


func get_banner_detail() -> String:
	return "Get ready" if state == State.COUNTDOWN and countdown > 0.0 else ""


## The line under the score on the results sheet.
func get_verdict() -> String:
	return ["Keep practising, stranger", "A steady hand", "Sharp shooting", "Dead eye"][clampi(int(result.get("stars", 0)), 0, 3)]


## Label / value pairs for the results sheet.
func get_result_lines() -> Array:
	var lines := [
		["Accuracy", "%d%%" % roundi(float(result.get("accuracy", 0.0)) * 100.0)],
		["Hits", "%d of %d shots" % [result.get("hits", 0), result.get("shots", 0)]],
		["Longest chain", str(result.get("max_combo", 0))],
		["Bullseyes", str(result.get("bullseyes", 0))],
		["Trick shots", str(result.get("trick_shots", 0))],
	]
	if int(result.get("innocents_hit", 0)) > 0:
		lines.append(["Innocents hit", str(result.innocents_hit)])
	var best := SaveSystem.get_record(challenge_id)
	if not best.is_empty():
		lines.append(["Your record", _format_score(best.get("score", 0))])
	return lines


## "Three stars at ..." for the results sheet; empty once all are earned.
func get_next_star_text() -> String:
	var stars := int(result.get("stars", 0))
	if stars >= star_thresholds.size():
		return ""
	return "%s star at %s" % [["First", "Second", "Third"][mini(stars, 2)], _format_score(star_thresholds[stars])]


func _format_score(value: Variant) -> String:
	return "%d ms" % int(value) if lower_is_better else "$" + HUD._thousands(int(value))
