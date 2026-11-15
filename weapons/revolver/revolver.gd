class_name Revolver
extends Weapon
## Single-action revolver. The hammer must be cocked before every shot;
## cocking is what turns the cylinder. Reloads go one chamber at a time
## through the loading gate and can be abandoned at any point. Holding
## alt-fire with the trigger fans the hammer: fast and wild.
##
## Model actions: cock {index}, hammer_fall, chambers {states}, reload_open,
## eject {index}, insert {index}, reload_close {index}.

signal cylinder_changed(chambers: Array[int], index: int)
signal hammer_changed(cocked: bool)

enum Chamber { EMPTY, LIVE, SPENT }
enum State {
	IDLE,
	COCK_WAIT,  ## Auto-cock delay; a manual cock skips it.
	COCKING,
	FIRING,  ## Brief lockout after the hammer falls.
	RELOAD_OPEN,
	RELOAD_EJECT,
	RELOAD_INSERT,
	RELOAD_CLOSE,
}

var chambers: Array[int] = []
## The chamber under the hammer.
var chamber_index := 0
var hammer_cocked := false
var state := State.IDLE

var _fan_shot_pending := false
var _load_index := 0


func _create_default_model() -> WeaponModel:
	return RevolverModel.new()


func _on_equipped() -> void:
	chambers.resize(data.capacity)
	chambers.fill(Chamber.LIVE)
	_sync_cylinder()


# --- Actions --------------------------------------------------------------

func refill() -> void:
	chambers.fill(Chamber.LIVE)
	_set_hammer(false)
	model.play_action(&"hammer_fall", 0.0)
	state = State.IDLE
	_timer = 0.0
	_sync_cylinder()


func get_ammo() -> int:
	return chambers.count(Chamber.LIVE)


func is_reloading() -> bool:
	return state >= State.RELOAD_OPEN


func is_idle() -> bool:
	return state == State.IDLE or state == State.COCK_WAIT


func get_status_text() -> String:
	var text := ""
	for i in chambers.size():
		var mark: String = [" ", "#", "x"][chambers[i]]
		text += ("<%s>" if i == chamber_index else "[%s]") % mark
	return "%s  hammer %s" % [text, "COCKED" if hammer_cocked else "down"]


## Thumb the hammer back. Returns false if the gun is busy or already cocked.
func work_action() -> bool:
	if hammer_cocked or not is_idle():
		return false
	_begin_cock(data.cock_time)
	return true


func pull_trigger() -> void:
	if is_reloading():
		_reload_interrupt = true
	elif state == State.IDLE and hammer_cocked:
		_drop_hammer(false)
	elif state == State.COCK_WAIT:
		_begin_cock(data.cock_time)
	elif state == State.IDLE and Settings.auto_cock:
		# Pulling the trigger on a lowered hammer does nothing on a single
		# action; with auto-cock on we thumb it back for the player instead.
		_begin_cock(data.cock_time)


## Fanning: trigger held down, off hand slaps the hammer. Each slap cocks and
## immediately drops it.
func alt_fire(_just_pressed: bool) -> void:
	if is_reloading():
		_reload_interrupt = true
	elif state == State.IDLE and hammer_cocked:
		_drop_hammer(true)
	elif is_idle():
		_fan_shot_pending = true
		_begin_cock(data.fan_interval * 0.6)


func start_reload() -> void:
	if not is_idle() or get_ammo() == data.capacity:
		return
	# Lowered to half-cock so the cylinder spins freely.
	_set_hammer(false)
	_reload_interrupt = false
	_load_index = chamber_index
	state = State.RELOAD_OPEN
	_timer = data.reload_open_time
	model.play_action(&"reload_open", _timer)
	reload_started.emit()


# --- Internals ------------------------------------------------------------

func _begin_cock(duration: float) -> void:
	state = State.COCKING
	_timer = duration
	var next := (chamber_index + 1) % data.capacity
	model.play_action(&"cock", duration, {"index": next})


func _drop_hammer(fanned: bool) -> void:
	_set_hammer(false)
	model.play_action(&"hammer_fall", 0.03)
	state = State.FIRING
	if chambers[chamber_index] == Chamber.LIVE:
		chambers[chamber_index] = Chamber.SPENT
		if fanned:
			_shoot(data.fan_spread_deg, 1.25)
		else:
			_shoot(get_current_spread())
		_timer = data.fan_interval * 0.4 if fanned else data.fire_interval
		_sync_cylinder()
	else:
		_timer = 0.08
		dry_fired.emit()


func _on_timer_finished() -> void:
	match state:
		State.COCK_WAIT:
			_begin_cock(data.cock_time)
		State.COCKING:
			chamber_index = (chamber_index + 1) % data.capacity
			state = State.IDLE
			_set_hammer(true)
			_sync_cylinder()
			if _fan_shot_pending:
				_fan_shot_pending = false
				_drop_hammer(true)
		State.FIRING:
			state = State.IDLE
			if Settings.auto_cock and not alt_held and get_ammo() > 0:
				state = State.COCK_WAIT
				_timer = Settings.auto_cock_delay
		State.RELOAD_CLOSE:
			state = State.IDLE
			reload_finished.emit()
			if Settings.auto_cock and get_ammo() > 0:
				state = State.COCK_WAIT
				_timer = Settings.auto_cock_delay * 0.5
		_:
			_advance_reload()


func _advance_reload() -> void:
	var just_ejected := false
	match state:
		State.RELOAD_EJECT:
			chambers[_load_index] = Chamber.EMPTY
			just_ejected = true
			_eject_casing(Vector3(0.8, 0.0, 1.1))
			_sync_cylinder()
		State.RELOAD_INSERT:
			chambers[_load_index] = Chamber.LIVE
			_sync_cylinder()

	if _reload_interrupt:
		_close_gate()
		return
	if not just_ejected:
		_load_index = _next_unloaded_chamber()
		if _load_index < 0:
			_close_gate()
			return
	if chambers[_load_index] == Chamber.SPENT:
		state = State.RELOAD_EJECT
		_timer = data.reload_eject_time
		model.play_action(&"eject", _timer, {"index": _load_index})
	else:
		state = State.RELOAD_INSERT
		_timer = data.reload_insert_time
		model.play_action(&"insert", _timer, {"index": _load_index})


func _next_unloaded_chamber() -> int:
	for offset in data.capacity:
		var i := (chamber_index + 1 + offset) % data.capacity
		if chambers[i] != Chamber.LIVE:
			return i
	return -1


func _close_gate() -> void:
	# Park the cylinder so the next cock brings a live round under the
	# hammer (the start of a run of live chambers, if there is one).
	for offset in data.capacity:
		var i := (chamber_index + offset) % data.capacity
		var next := (i + 1) % data.capacity
		if chambers[next] == Chamber.LIVE and (chambers[i] != Chamber.LIVE or get_ammo() == data.capacity):
			chamber_index = i
			break
	state = State.RELOAD_CLOSE
	_timer = data.reload_close_time
	model.play_action(&"reload_close", _timer, {"index": chamber_index})
	_sync_cylinder()


func _set_hammer(cocked: bool) -> void:
	if hammer_cocked != cocked:
		hammer_cocked = cocked
		hammer_changed.emit(cocked)


func _sync_cylinder() -> void:
	model.play_action(&"chambers", 0.0, {"states": chambers})
	cylinder_changed.emit(chambers, chamber_index)
	ammo_changed.emit(get_ammo(), data.capacity)
