extends Node
## Phase 6: the five cues each have three stems of identical length, the
## stems loop, layers follow gameplay, and the stingers exist.
## As in phase 5, this checks structure; it cannot judge how it sounds.

var failures := 0


func _ready() -> void:
	var music := AudioManager.bank.music
	for cue: String in ["menu", "gallery", "quick_draw", "results", "town"]:
		MusicDirector.play(cue)
		var stems := MusicDirector.stems
		check(stems.size() == 3, "%s has three stems" % cue)
		if stems.is_empty():
			continue
		var length := stems[0].stream.get_length()
		var same := stems.all(func(p: AudioStreamPlayer) -> bool: return absf(p.stream.get_length() - length) < 0.001)
		check(same and length > 10.0, "%s stems are the same length (%.2f s)" % [cue, length])
		check(stems.all(func(p: AudioStreamPlayer) -> bool: return p.stream is AudioStreamOggVorbis and p.stream.loop), "%s stems loop" % cue)
		check(FileAccess.file_exists("res://audio/music/midi/%s.mid" % cue), "%s has its MIDI source" % cue)
	for sting: String in ["sting_record", "sting_fail", "sting_ready"]:
		check(music.has(sting) and AudioManager.bank.stream(music[sting][0]) != null, "stinger %s loads" % sting)

	# Gallery: rhythm only at first; the tune and the band come in with the chain.
	MusicDirector.play("gallery")
	GameState.reset()
	await get_tree().create_timer(1.5).timeout
	var stems := MusicDirector.stems
	check(stems[0].volume_db > -8.0 and stems[2].volume_db < -40.0, "gallery opens on rhythm alone (%.0f / %.0f / %.0f dB)" % [stems[0].volume_db, stems[1].volume_db, stems[2].volume_db])
	GameState.combo_changed.emit(10, 2.0)
	await get_tree().create_timer(1.5).timeout
	check(stems[1].volume_db > -8.0 and stems[2].volume_db > -8.0, "a long chain brings in every layer (%.0f / %.0f dB)" % [stems[1].volume_db, stems[2].volume_db])
	GameState.combo_changed.emit(0, 1.0)
	await get_tree().create_timer(1.5).timeout
	check(stems[2].volume_db < -40.0, "a broken chain drops the band (%.0f dB)" % stems[2].volume_db)

	MusicDirector.play("town")
	await get_tree().create_timer(0.3).timeout
	check(MusicDirector.get_child_count() >= 3 and MusicDirector.current == "town", "cues crossfade")
	MusicDirector.stop()
	check(MusicDirector.stems.is_empty(), "stop silences the score")

	print("PHASE 6 SMOKE: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)


func check(value: bool, message: String) -> void:
	print("  ", "ok " if value else "FAIL ", message)
	if not value:
		failures += 1
