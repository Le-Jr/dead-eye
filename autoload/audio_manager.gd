extends Node
## Sound effects: buses, 3D one-shots, gunshot echoes, ambience and the
## slow-motion treatment. Music lives in MusicDirector.
##
## Bus layout (built here, so there is no bus layout file to keep in sync):
##   Master <- Music, SFX, UI, Ambience;  Canyon (reverb + echo) -> SFX

const MAX_VOICES := 32
const SPEED_OF_SOUND := 343.0

var bank: SoundBank = preload("res://audio/default_bank.tres")
var lowpass := AudioEffectLowPassFilter.new()
var voices: Array[AudioStreamPlayer3D] = []
var ambience: AudioStreamPlayer
## True while Dead Eye has the world slowed down.
var warped := false
var quitting := false

var _silent := DisplayServer.get_name() == "headless"
var _heartbeat := 0.0
var _last_impact_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	bank.load_manifests()
	for bus in ["Music", "SFX", "UI", "Ambience", "Canyon"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var canyon := AudioServer.get_bus_index("Canyon")
	AudioServer.set_bus_send(canyon, "SFX")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.9
	reverb.damping = 0.6
	reverb.wet = 0.45
	AudioServer.add_bus_effect(canyon, reverb)
	var delay := AudioEffectDelay.new()
	delay.tap1_delay_ms = 280
	delay.tap1_level_db = -12
	delay.tap2_delay_ms = 530
	delay.tap2_level_db = -18
	AudioServer.add_bus_effect(canyon, delay)
	lowpass.cutoff_hz = 20000
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), lowpass)
	Settings.changed.connect(_settings_changed)
	_settings_changed(&"")

	ambience = AudioStreamPlayer.new()
	ambience.bus = "Ambience"
	var wind := bank.pick(&"wind")
	if wind is AudioStreamWAV:
		wind = wind.duplicate()
		wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wind.loop_end = roundi(wind.get_length() * wind.mix_rate)
	ambience.stream = wind
	add_child(ambience)
	if wind and not _silent:
		ambience.play()


func _process(delta: float) -> void:
	# The wind you hear follows the wind that pushes the bullets.
	var strength := clampf(Wind.get_velocity().length() / 6.0, 0.0, 1.0)
	ambience.volume_db = lerpf(ambience.volume_db, lerpf(-16.0, 0.0, strength), minf(delta * 2.0, 1.0))
	if warped:
		_heartbeat -= delta / maxf(Engine.time_scale, 0.001)
		if _heartbeat <= 0.0:
			_heartbeat = 0.85
			play_ui(&"heartbeat", -2.0)


func _settings_changed(_key: StringName) -> void:
	for bus in ["Master", "Music", "SFX", "UI", "Ambience"]:
		var volume: float = Settings.get(bus.to_lower() + "_volume")
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(index, volume <= 0.001)


## Dead Eye: everything in the world goes slow, low and muffled.
func warp(enabled: bool) -> void:
	if enabled == warped:
		return
	warped = enabled
	lowpass.cutoff_hz = 1100 if enabled else 20000
	AudioServer.playback_speed_scale = 0.72 if enabled else 1.0
	_heartbeat = 0.5
	if not quitting:
		play_ui(&"dead_eye_in" if enabled else &"dead_eye_out")


## A non-positional sound on the UI bus.
func play_ui(key: StringName = &"ui", volume := 0.0) -> void:
	if quitting or _silent:
		return
	var stream := bank.pick(key)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "UI"
	p.volume_db = volume
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## A one-shot in the world. Returns null if the key has no sound.
func play_at(key: StringName, at: Vector3, volume := 0.0, bus := "SFX") -> AudioStreamPlayer3D:
	if quitting:
		return null
	var stream := bank.pick(key)
	if stream == null:
		return null
	for i in range(voices.size() - 1, -1, -1):
		if not is_instance_valid(voices[i]):
			voices.remove_at(i)
	if voices.size() >= MAX_VOICES:
		voices.pop_front().queue_free()
	var p := AudioStreamPlayer3D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	p.stream = stream
	p.bus = bus
	p.unit_size = 10
	p.max_distance = 650
	# Far sounds lose their top end, as they do across open ground.
	p.attenuation_filter_cutoff_hz = 3500
	p.attenuation_filter_db = -20
	p.volume_db = volume + randf_range(-1.5, 0)
	p.pitch_scale = randf_range(0.96, 1.04)
	add_child(p)
	p.global_position = at
	voices.append(p)
	p.finished.connect(p.queue_free)
	if not _silent:
		p.play()
	return p


## The report, then its echo off the nearest wall, delayed by the distance.
func gunshot(weapon: Weapon) -> void:
	var at := weapon.model.get_muzzle().global_position
	play_at(weapon.data.sound_fire, at)
	var distance := 180.0
	var space := weapon.get_world_3d().direct_space_state
	for direction: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + direction * 180, 1))
		if not hit.is_empty():
			distance = minf(distance, at.distance_to(hit.position))
	var key := weapon.data.sound_fire
	var scene := get_tree().current_scene
	get_tree().create_timer(clampf(distance * 2 / SPEED_OF_SOUND, 0.06, 1.1), false).timeout.connect(func() -> void:
		if is_instance_valid(scene) and scene == get_tree().current_scene:
			play_at(key, at, -15, "Canyon")
	)


## A weapon part moving. `action` is the name the weapon model animates.
func mechanical(weapon: Weapon, action: StringName) -> void:
	var key := &""
	match action:
		&"cock": key = weapon.data.sound_cock
		&"lever_open", &"lever_close": key = &"lever"
		&"reload_open", &"break_open", &"breech_open": key = weapon.data.sound_reload_open
		&"reload_close", &"break_close", &"breech_close": key = weapon.data.sound_reload_close
		&"insert": key = weapon.data.sound_reload_insert
		&"eject", &"extract": key = weapon.data.sound_reload_eject
	if key != &"":
		play_at(key, weapon.global_position, -7)


## A bullet hitting scenery. Bodies say what they are made of with the
## "surface" meta (&"dirt" or &"wood"); anything unmarked is wood.
func impact(at: Vector3, collider: Object) -> void:
	# A load of buckshot is one sound, not nine.
	var now := Time.get_ticks_msec()
	if now - _last_impact_msec < 40:
		return
	_last_impact_msec = now
	var surface: StringName = collider.get_meta(&"surface", &"wood") if collider else &"dirt"
	play_at(surface, at, -6)


func clear_voices() -> void:
	for p in voices:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	voices.clear()
	warped = false
	lowpass.cutoff_hz = 20000
	AudioServer.playback_speed_scale = 1.0


func shutdown() -> void:
	quitting = true
	clear_voices()
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
	MusicDirector.stop()
	# Let the mixer release its playback references before SceneTree tears down.
	await get_tree().create_timer(0.15, true, false, true).timeout


func quit_game() -> void:
	await shutdown()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not quitting:
		quit_game()
