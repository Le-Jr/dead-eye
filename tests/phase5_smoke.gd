extends Node
## Phase 5: every sound the game asks for exists, the buses are wired, and
## the slow-motion treatment switches on and fully off again.
## Headless Godot has no audio device, so nothing is heard here: this checks
## resources and routing, not the mix.

## Every key the code plays, apart from the per-weapon ones read from WeaponData.
const USED_KEYS: Array[StringName] = [
	&"lever", &"ricochet", &"dirt", &"wood", &"glass", &"clay", &"tin", &"steel", &"casing",
	&"bell", &"wind", &"step_dirt", &"step_wood", &"spurs", &"ui", &"hover", &"stamp", &"star",
	&"dead_eye_in", &"dead_eye_out", &"heartbeat", &"hammer",
]

var failures := 0


func _ready() -> void:
	var bank := AudioManager.bank
	check(bank.sounds.size() >= 30, "%d sound keys in the bank" % bank.sounds.size())
	var broken := PackedStringArray()
	var count := 0
	for key: String in bank.sounds:
		for path: String in bank.sounds[key]:
			count += 1
			var stream := bank.stream(path)
			if stream == null or stream.get_length() <= 0.0:
				broken.append(path)
	check(broken.is_empty(), "all %d sound files load %s" % [count, broken])
	for key in USED_KEYS:
		check(bank.has_sound(key), "sound '%s' exists" % key)
	check(absf(bank.pick(&"wind").get_length() - 14.0) < 0.01, "wind bed is its full loop length")

	for bus in ["Music", "SFX", "UI", "Ambience", "Canyon"]:
		check(AudioServer.get_bus_index(bus) != -1, "bus %s exists" % bus)
	var canyon := AudioServer.get_bus_index("Canyon")
	check(AudioServer.get_bus_send(canyon) == &"SFX", "echo bus feeds the SFX bus")
	check(AudioServer.get_bus_effect_count(canyon) == 2, "echo bus has reverb and delay")
	Settings.set_value(&"sfx_volume", 0.5)
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.5)) < 0.01, "volume setting reaches its bus")
	Settings.set_value(&"sfx_volume", 0.8)

	var level := preload("res://modes/free_range.tscn").instantiate() as GameMode
	add_child(level)
	await get_tree().process_frame
	for w in level.player.weapons:
		for key: StringName in [w.data.sound_fire, w.data.sound_dry, w.data.sound_cock, w.data.sound_reload_open, w.data.sound_reload_insert, w.data.sound_reload_eject, w.data.sound_reload_close]:
			check(bank.has_sound(key), "%s: sound '%s' exists" % [w.data.display_name, key])
		AudioManager.gunshot(w)
	check(AudioManager.voices.size() == level.player.weapons.size(), "each gunshot takes a voice")
	var before := AudioManager.voices.size()
	for i in 9:
		AudioManager.impact(Vector3(0, 0, -5), null)
	check(AudioManager.voices.size() == before + 1, "a spread of pellets is one impact sound")
	for i in 60:
		AudioManager.play_at(&"tin", Vector3.ZERO)
	check(AudioManager.voices.size() <= AudioManager.MAX_VOICES, "voices are capped (%d)" % AudioManager.voices.size())

	AudioManager.warp(true)
	check(AudioManager.lowpass.cutoff_hz < 2000 and AudioServer.playback_speed_scale < 1.0, "slow motion muffles and slows the world")
	AudioManager.warp(false)
	check(AudioManager.lowpass.cutoff_hz > 15000 and AudioServer.playback_speed_scale == 1.0, "and lets go again")
	AudioManager.warp(true)
	level.queue_free()
	await get_tree().process_frame
	check(not AudioManager.warped and AudioServer.playback_speed_scale == 1.0 and AudioManager.voices.is_empty(), "leaving a mode clears voices and slow motion")

	print("PHASE 5 SMOKE: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)


func check(value: bool, message: String) -> void:
	print("  ", "ok " if value else "FAIL ", message)
	if not value:
		failures += 1
