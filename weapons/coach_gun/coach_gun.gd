class_name CoachGun
extends Weapon
## Double-barrel coach gun with exposed hammers. The trigger fires one barrel
## (left, then right); alt-fire lets both go at once. Breaking it open throws
## out the spent shells; fresh ones go in one at a time, then both hammers
## have to be cocked again.
##
## Model actions: cock, hammer_fall {index}, shells {states}, break_open,
## insert {index}, break_close.

enum Shell { EMPTY, LIVE, SPENT }
enum State { IDLE, COCK_WAIT, COCKING, FIRING, RELOAD_OPEN, RELOAD_INSERT, RELOAD_CLOSE }

var barrels: Array[int] = []
var hammers: Array[bool] = []
var state := State.IDLE

var _load_index := 0


func _create_default_model() -> WeaponModel:
	return CoachGunModel.new()


func _on_equipped() -> void:
	barrels.resize(data.capacity)
	barrels.fill(Shell.LIVE)
	hammers.resize(data.capacity)
	hammers.fill(true)
	model.play_action(&"cock", 0.0)
	_sync()


# --- Actions --------------------------------------------------------------

func refill() -> void:
	barrels.fill(Shell.LIVE)
	hammers.fill(true)
	model.play_action(&"cock", 0.0)
	state = State.IDLE
	_timer = 0.0
	_sync()


func get_ammo() -> int:
	return barrels.count(Shell.LIVE)


func is_reloading() -> bool:
	return state >= State.RELOAD_OPEN


func is_idle() -> bool:
	return state == State.IDLE or state == State.COCK_WAIT


func get_status_text() -> String:
	var text := ""
	for i in barrels.size():
		var shell: String = [" ", "#", "x"][barrels[i]]
		text += "(%s%s) " % [shell, "^" if hammers[i] else "_"]
	return text + " ^ = hammer cocked"


func pull_trigger() -> void:
	if is_reloading():
		_reload_interrupt = true
	elif state == State.COCK_WAIT or (state == State.IDLE and not true in hammers):
		if state == State.COCK_WAIT or Settings.auto_cock:
			_begin_cock()
	elif state == State.IDLE:
		_drop_hammers([hammers.find(true)])


## Both barrels at once.
func alt_fire(just_pressed: bool) -> void:
	if not just_pressed:
		return
	if state != State.IDLE or hammers.count(true) < 2:
		pull_trigger()
		return
	var cocked: Array[int] = []
	for i in hammers.size():
		if hammers[i]:
			cocked.append(i)
	_drop_hammers(cocked)


## Cock every hammer that is down.
func work_action() -> bool:
	if not is_idle() or not false in hammers:
		return false
	_begin_cock()
	return true


func start_reload() -> void:
	if not is_idle() or get_ammo() == data.capacity:
		return
	_reload_interrupt = false
	state = State.RELOAD_OPEN
	_timer = data.reload_open_time
	model.play_action(&"break_open", _timer)
	reload_started.emit()


# --- Internals ------------------------------------------------------------

func _begin_cock() -> void:
	state = State.COCKING
	_timer = data.cock_time
	model.play_action(&"cock", _timer)


func _drop_hammers(indices: Array) -> void:
	state = State.FIRING
	_timer = 0.08
	var shots := 0
	for i: int in indices:
		hammers[i] = false
		model.play_action(&"hammer_fall", 0.03, {"index": i})
		if barrels[i] == Shell.LIVE:
			barrels[i] = Shell.SPENT
			shots += 1
	if shots == 0:
		dry_fired.emit()
	for i in shots:
		# Two barrels together kick like a mule: more than twice one.
		_shoot(get_current_spread(), 1.0 if shots == 1 else 1.3)
		_timer = data.fire_interval
	_sync()


func _on_timer_finished() -> void:
	match state:
		State.COCK_WAIT:
			_begin_cock()
		State.COCKING:
			hammers.fill(true)
			state = State.IDLE
			_sync()
		State.FIRING:
			state = State.IDLE
		State.RELOAD_OPEN:
			# The extractor only kicks out fired shells.
			for i in barrels.size():
				if barrels[i] == Shell.SPENT:
					barrels[i] = Shell.EMPTY
					_eject_casing(Vector3(0.5 if i else -0.5, 1.2, 1.8))
			_sync()
			_insert_or_close()
		State.RELOAD_INSERT:
			barrels[_load_index] = Shell.LIVE
			_sync()
			_insert_or_close()
		State.RELOAD_CLOSE:
			state = State.IDLE
			reload_finished.emit()
			if Settings.auto_cock and false in hammers and get_ammo() > 0:
				state = State.COCK_WAIT
				_timer = Settings.auto_cock_delay * 0.5


func _insert_or_close() -> void:
	_load_index = barrels.find(Shell.EMPTY)
	if _reload_interrupt or _load_index < 0:
		state = State.RELOAD_CLOSE
		_timer = data.reload_close_time
		model.play_action(&"break_close", _timer)
	else:
		state = State.RELOAD_INSERT
		_timer = data.reload_insert_time
		model.play_action(&"insert", _timer, {"index": _load_index})


func _sync() -> void:
	model.play_action(&"shells", 0.0, {"states": barrels})
	ammo_changed.emit(get_ammo(), data.capacity)
