class_name SharpsRifle
extends Weapon
## Single-shot falling-block long rifle. One cartridge per reload: drop the
## lever (the block falls), pull the fired case, seat a new round, close, then
## cock the side hammer. Heavy bullet, strong drop; the tang sight is stepped
## through data.zero_distances to dial in the range.
##
## Model actions: cock, hammer_fall, breech_open, extract, insert,
## breech_close, zero {angle}.

enum Chamber { EMPTY, LIVE, SPENT }
enum State {
	IDLE, COCK_WAIT, COCKING, FIRING,
	RELOAD_OPEN, RELOAD_EXTRACT, RELOAD_INSERT, RELOAD_CLOSE,
}

var chamber := Chamber.LIVE
var hammer_cocked := true
var state := State.IDLE


func _create_default_model() -> WeaponModel:
	return SharpsRifleModel.new()


func _on_equipped() -> void:
	model.play_action(&"cock", 0.0)
	_on_zero_changed()
	_sync()


# --- Actions --------------------------------------------------------------

func refill() -> void:
	chamber = Chamber.LIVE
	hammer_cocked = true
	model.play_action(&"cock", 0.0)
	state = State.IDLE
	_timer = 0.0
	_sync()


func get_ammo() -> int:
	return 1 if chamber == Chamber.LIVE else 0


func is_reloading() -> bool:
	return state >= State.RELOAD_OPEN


func is_idle() -> bool:
	return state == State.IDLE or state == State.COCK_WAIT


func get_status_text() -> String:
	var round_text: String = ["empty", "LIVE", "spent"][chamber]
	return "chamber %s  hammer %s  sight %d m" % [
		round_text, "COCKED" if hammer_cocked else "down", int(get_zero_distance()),
	]


func pull_trigger() -> void:
	if is_reloading():
		_reload_interrupt = true
	elif state == State.COCK_WAIT:
		_begin_cock()
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
		# Hammer down: do whatever comes next for the player.
		if chamber == Chamber.LIVE:
			_begin_cock()
		else:
			start_reload()


func work_action() -> bool:
	if hammer_cocked or not is_idle():
		return false
	_begin_cock()
	return true


func start_reload() -> void:
	if not is_idle() or chamber == Chamber.LIVE:
		return
	_reload_interrupt = false
	state = State.RELOAD_OPEN
	_timer = data.reload_open_time
	model.play_action(&"breech_open", _timer)
	reload_started.emit()


## The tang sight sits in front of the eye, not at the model origin, so the
## rifle pivots about the peep as the sight is raised.
func get_ads_transform() -> Transform3D:
	var sharps_model := model as SharpsRifleModel
	if sharps_model == null:
		return super()
	var tilt := Basis(Vector3.RIGHT, get_zero_angle())
	var peep := sharps_model.get_peep_position(get_zero_angle())
	return Transform3D(tilt, Vector3(0.0, 0.0, -SharpsRifleModel.EYE_RELIEF) - tilt * peep)


# --- Internals ------------------------------------------------------------

func _on_zero_changed() -> void:
	model.play_action(&"zero", 0.12, {"angle": get_zero_angle()})


func _begin_cock() -> void:
	state = State.COCKING
	_timer = data.cock_time
	model.play_action(&"cock", _timer)


func _on_timer_finished() -> void:
	match state:
		State.COCK_WAIT:
			_begin_cock()
		State.COCKING:
			hammer_cocked = true
			state = State.IDLE
			_sync()
		State.FIRING:
			state = State.IDLE
		State.RELOAD_OPEN:
			if _reload_interrupt:
				_close_breech()
			elif chamber == Chamber.SPENT:
				state = State.RELOAD_EXTRACT
				_timer = data.reload_eject_time
				model.play_action(&"extract", _timer)
			else:
				_begin_insert()
		State.RELOAD_EXTRACT:
			chamber = Chamber.EMPTY
			_eject_casing(Vector3(0.4, 0.6, 1.4))
			_sync()
			if _reload_interrupt:
				_close_breech()
			else:
				_begin_insert()
		State.RELOAD_INSERT:
			chamber = Chamber.LIVE
			_sync()
			_close_breech()
		State.RELOAD_CLOSE:
			state = State.IDLE
			reload_finished.emit()
			if Settings.auto_cock and not hammer_cocked and chamber == Chamber.LIVE:
				state = State.COCK_WAIT
				_timer = Settings.auto_cock_delay * 0.5


func _begin_insert() -> void:
	state = State.RELOAD_INSERT
	_timer = data.reload_insert_time
	model.play_action(&"insert", _timer)


func _close_breech() -> void:
	state = State.RELOAD_CLOSE
	_timer = data.reload_close_time
	model.play_action(&"breech_close", _timer)


func _sync() -> void:
	ammo_changed.emit(get_ammo(), data.capacity)
