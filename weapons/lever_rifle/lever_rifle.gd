class_name LeverRifle
extends Weapon
## Lever-action repeater. Every shot leaves a spent case in the chamber; the
## lever must be thrown (down ejects, up feeds and cocks) before the next.
## Rounds are thumbed into the tube one at a time and loading can stop at any
## point. The bullet travels and drops.
##
## Model actions: lever_open, lever_close, hammer_fall, reload_open, insert,
## reload_close.

enum Chamber { EMPTY, LIVE, SPENT }
enum State {
	IDLE,
	CYCLE_WAIT,  ## Auto-lever delay; working it by hand skips it.
	LEVER_OPEN,
	LEVER_CLOSE,
	FIRING,
	RELOAD_OPEN,
	RELOAD_INSERT,
	RELOAD_CLOSE,
}

var chamber := Chamber.LIVE
## Rounds waiting in the magazine tube.
var tube := 0
var hammer_cocked := true
var state := State.IDLE


func _create_default_model() -> WeaponModel:
	return LeverRifleModel.new()


func _on_equipped() -> void:
	tube = data.capacity - 1
	_sync()


# --- Actions --------------------------------------------------------------

func refill() -> void:
	chamber = Chamber.LIVE
	tube = data.capacity - 1
	hammer_cocked = true
	model.play_action(&"lever_open", 0.0)
	model.play_action(&"lever_close", 0.0)
	state = State.IDLE
	_timer = 0.0
	_sync()


func get_ammo() -> int:
	return tube + (1 if chamber == Chamber.LIVE else 0)


func is_reloading() -> bool:
	return state >= State.RELOAD_OPEN


func is_idle() -> bool:
	return state == State.IDLE or state == State.CYCLE_WAIT


func get_status_text() -> String:
	var round_text: String = ["empty", "LIVE", "spent"][chamber]
	return "chamber %s  tube %d/%d  hammer %s" % [
		round_text, tube, data.capacity, "COCKED" if hammer_cocked else "down",
	]


func pull_trigger() -> void:
	if is_reloading():
		_reload_interrupt = true
	elif state == State.CYCLE_WAIT:
		work_action()
	elif state != State.IDLE:
		return
	elif hammer_cocked:
		hammer_cocked = false
		model.play_action(&"hammer_fall", 0.03)
		state = State.FIRING
		if chamber == Chamber.LIVE:
			chamber = Chamber.SPENT
			_shoot(get_current_spread())
			_timer = data.fire_interval
		else:
			_timer = 0.08
			dry_fired.emit()
		_sync()
	elif Settings.auto_cock:
		work_action()


## Throw the lever. Whatever is in the chamber comes out, live or not.
func work_action() -> bool:
	if not is_idle() or (chamber == Chamber.LIVE and hammer_cocked):
		return false
	state = State.LEVER_OPEN
	_timer = data.cock_time * 0.5
	model.play_action(&"lever_open", _timer)
	return true


func start_reload() -> void:
	if not is_idle() or tube >= data.capacity:
		return
	_reload_interrupt = false
	state = State.RELOAD_OPEN
	_timer = data.reload_open_time
	model.play_action(&"reload_open", _timer)
	reload_started.emit()


# --- Internals ------------------------------------------------------------

func _on_timer_finished() -> void:
	match state:
		State.CYCLE_WAIT:
			state = State.IDLE
			work_action()
		State.LEVER_OPEN:
			if chamber != Chamber.EMPTY:
				_eject_casing(Vector3(0.3, 2.2, 0.6))
			chamber = Chamber.EMPTY
			state = State.LEVER_CLOSE
			_timer = data.cock_time * 0.5
			model.play_action(&"lever_close", _timer)
			_sync()
		State.LEVER_CLOSE:
			if tube > 0:
				tube -= 1
				chamber = Chamber.LIVE
			hammer_cocked = true
			state = State.IDLE
			_sync()
		State.FIRING:
			state = State.IDLE
			if Settings.auto_cock and tube > 0:
				state = State.CYCLE_WAIT
				_timer = Settings.auto_cock_delay
		State.RELOAD_OPEN:
			_insert_or_close()
		State.RELOAD_INSERT:
			tube += 1
			_sync()
			_insert_or_close()
		State.RELOAD_CLOSE:
			state = State.IDLE
			reload_finished.emit()
			if Settings.auto_cock and chamber != Chamber.LIVE and tube > 0:
				state = State.CYCLE_WAIT
				_timer = Settings.auto_cock_delay * 0.5


func _insert_or_close() -> void:
	if _reload_interrupt or tube >= data.capacity:
		state = State.RELOAD_CLOSE
		_timer = data.reload_close_time
		model.play_action(&"reload_close", _timer)
	else:
		state = State.RELOAD_INSERT
		_timer = data.reload_insert_time
		model.play_action(&"insert", _timer)


func _sync() -> void:
	ammo_changed.emit(get_ammo(), data.capacity)
