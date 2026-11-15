extends Node
## Phase 4: fonts, menu, settings and rebinding, HUD, pause and results.

const HUD := preload("res://ui/hud.gd")

var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	check(FrontierUI.display_font() is FontFile, "Rye loads as the display face")
	check(FrontierUI.text_font(700) is FontVariation, "Bitter loads as the text face")

	var menu := preload("res://ui/menu.tscn").instantiate()
	add_child(menu)
	check(menu.mode_buttons.size() == GameMode.SCENES.size(), "main menu lists every mode")
	for entry: Dictionary in menu.MODES:
		check(GameMode.SCENES.has(entry.id), "menu entry '%s' has a scene" % entry.id)
	menu.show_settings()
	var page := menu.pages.get_child(0) as SettingsPage
	check(page != null, "settings page opens")
	check(page._sections.size() == 4, "settings has four sections")
	for action: String in SettingsPage.ACTION_NAMES:
		check(InputMap.has_action(action), "action '%s' exists" % action)

	# Rebinding replaces the keyboard binding, keeps the gamepad one, and can be undone.
	var pads_before := _pad_events("reload")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	Settings.bind_action("reload", key)
	check(FrontierUI.key("reload") == "T", "rebinding takes effect (%s)" % FrontierUI.action_text("reload"))
	check(_pad_events("reload") == pads_before, "rebinding a key keeps the gamepad binding")
	Settings.reset_bindings()
	check(FrontierUI.key("reload") == "R", "defaults restore (%s)" % FrontierUI.action_text("reload"))
	check(InputMap.has_action("dead_eye"), "Dead Eye action survives a reset")
	page.closed.emit()
	check(menu.mode_buttons.size() == GameMode.SCENES.size(), "back returns to the mode list")
	menu.queue_free()
	await get_tree().process_frame

	var level := preload("res://modes/gallery.tscn").instantiate() as GameMode
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: Control = level.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n.get_script() == HUD)[0]
	check(hud._score.text.begins_with("$"), "HUD shows the bounty (%s)" % hud._score.text)
	check(hud._headline.text == "1:30", "HUD shows the clock (%s)" % hud._headline.text)
	check(hud._banner.text == "3", "countdown on the banner (%s)" % hud._banner.text)
	check(hud._weapon_name.text == level.player.weapon.data.display_name, "HUD names the weapon")
	GameState.register_hit(level, &"bullseye", 100)
	await get_tree().process_frame
	check(hud._stamps.get_child_count() == 1, "a hit stamps its points on screen")

	hud.show_overlay(false)
	var elapsed: float = level.elapsed
	await get_tree().create_timer(0.15, true).timeout
	check(get_tree().paused and level.elapsed == elapsed, "pause freezes the run")
	hud.close_overlay()
	await get_tree().create_timer(0.15, true).timeout
	check(not get_tree().paused and not is_instance_valid(hud.overlay), "resume carries on")

	level.finish()
	check(level.get_result_lines().size() >= 5, "results list the run's figures")
	check(level.get_next_star_text() != "", "results say what the next star takes")
	hud.show_overlay(true)
	check(is_instance_valid(hud.overlay) and hud.result_shown, "results sheet builds")
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame

	var duel := preload("res://modes/quick_draw.tscn").instantiate() as QuickDraw
	duel.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(duel)
	duel.phase = QuickDraw.Phase.DRAW
	duel.state = GameMode.State.PLAYING
	check(duel.get_banner() == "DRAW!", "Quick Draw calls the draw")
	duel._bell_usec = Time.get_ticks_usec()
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	get_tree().paused = false
	check(duel._since_bell_ms() < 80, "Quick Draw does not count paused time")
	duel.queue_free()
	await get_tree().process_frame

	print("PHASE 4 SMOKE: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)


func _pad_events(action: String) -> int:
	return InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion).size()


func check(value: bool, message: String) -> void:
	print("  ", "ok " if value else "FAIL ", message)
	if not value:
		failures += 1
