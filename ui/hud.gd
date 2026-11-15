extends Control
## The in-game HUD and the two screens that sit on top of it (pause, results).
##
## Paper tags in the corners: bounty and chain (top left), the mode's clock
## and objective (top right), the gun and its rounds (bottom left). Points
## are stamped where the bullet landed. Everything reads state every frame;
## the only signals used are for one-off events (a score, a weapon swap).

const HINT_SECONDS := 7.0
const RESULTS_DELAY := 1.4

var player: Player
var mode: GameMode
## The pause or results screen, when one is up.
var overlay: Control
var result_shown := false

var _effect: ShaderMaterial
var _effect_amount := 0.0
var _score: Label
var _chain: Label
var _style: Label
var _chain_bar: ColorRect
var _mode_name: Label
var _headline: Label
var _objective: Label
var _banner: Label
var _banner_sub: Label
var _weapon_name: Label
var _weapon_status: Label
var _ammo: AmmoView
var _hint: Label
var _stamps: Control
var _hint_timer := 0.0
var _hit_flash := 0.0
var _finished_for := 0.0
var _shown_score := 0.0
var _last_second := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = FrontierUI.make_theme()

	var effect := ColorRect.new()
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect = ShaderMaterial.new()
	_effect.shader = preload("res://ui/dead_eye.gdshader")
	effect.material = _effect
	add_child(effect)

	_stamps = Control.new()
	_stamps.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamps)

	_build_score_tag()
	_build_mode_tag()
	_build_weapon_tag()

	_banner = _outlined(FrontierUI.title(self, "", 72, FrontierUI.PAPER), 12)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 190
	_banner_sub = _outlined(FrontierUI.label(self, "", 28, FrontierUI.PAPER), 8)
	_banner_sub.add_theme_font_override("font", FrontierUI.text_font(700))
	_banner_sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner_sub.offset_top = 290

	_hint = _outlined(FrontierUI.label(self, "", 22, FrontierUI.PAPER), 8)
	_hint.add_theme_font_override("font", FrontierUI.text_font(600))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -36
	_hint.offset_bottom = -32

	GameState.scored.connect(_on_scored)
	if player:
		player.weapon_changed.connect(func(_w: Weapon) -> void: _hint_timer = HINT_SECONDS)
	_hint_timer = HINT_SECONDS


# --- Building ---------------------------------------------------------------

func _build_score_tag() -> void:
	var column := _tag(Control.PRESET_TOP_LEFT, Vector2(36, 30))
	FrontierUI.caption(column, "Bounty").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score = FrontierUI.title(column, "$0", 52)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score.custom_minimum_size.x = 300
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	_chain = FrontierUI.label(row, "", 22)
	_chain.add_theme_font_override("font", FrontierUI.text_font(700))
	_style = FrontierUI.label(row, "", 22, FrontierUI.RED)
	_style.add_theme_font_override("font", FrontierUI.text_font(700))
	# How long the chain has left before it breaks.
	var track := ColorRect.new()
	track.color = Color(FrontierUI.INK, 0.25)
	track.custom_minimum_size.y = 6
	column.add_child(track)
	_chain_bar = ColorRect.new()
	_chain_bar.color = FrontierUI.RED
	_chain_bar.size = Vector2(0, 6)
	track.add_child(_chain_bar)


func _build_mode_tag() -> void:
	var column := _tag(Control.PRESET_TOP_RIGHT, Vector2(-36, 30))
	_mode_name = FrontierUI.caption(column, "")
	_mode_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_headline = FrontierUI.title(column, "", 52)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective = FrontierUI.label(column, "", 22)
	_objective.add_theme_font_override("font", FrontierUI.text_font(600))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective.custom_minimum_size.x = 260


func _build_weapon_tag() -> void:
	var column := _tag(Control.PRESET_BOTTOM_LEFT, Vector2(36, -30))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	_ammo = AmmoView.new()
	row.add_child(_ammo)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	_weapon_name = FrontierUI.title(text, "", 30)
	_weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_weapon_status = FrontierUI.label(text, "", 21, FrontierUI.INK_SOFT)
	_weapon_status.add_theme_font_override("font", FrontierUI.text_font(600))
	_weapon_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_weapon_status.custom_minimum_size.x = 300


## A paper tag pinned to a corner. `offset` is the gap from that corner.
func _tag(corner: Control.LayoutPreset, offset: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", FrontierUI.tag_style())
	add_child(panel)
	panel.set_anchors_and_offsets_preset(corner)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if offset.x < 0 else Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if offset.y < 0 else Control.GROW_DIRECTION_END
	panel.position += offset
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	return column


func _outlined(label: Label, width: int) -> Label:
	label.add_theme_color_override("font_outline_color", FrontierUI.INK)
	label.add_theme_constant_override("outline_size", width)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Every frame -------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(player) or player.weapon == null or mode == null:
		return
	queue_redraw()
	if get_tree().paused:
		return
	var w := player.weapon

	_effect_amount = move_toward(_effect_amount, 1.0 if player.dead_eye.active else 0.0, delta / maxf(Engine.time_scale, 0.01) * 4.0)
	_effect.set_shader_parameter("amount", _effect_amount)
	_hit_flash = maxf(0.0, _hit_flash - delta)

	# Bounty counts up to the real score instead of jumping.
	_shown_score = move_toward(_shown_score, GameState.score, maxf(absf(GameState.score - _shown_score) * 8.0, 40.0) * delta)
	_score.text = "$%s" % _thousands(roundi(_shown_score))
	_chain.text = "CHAIN %d   ×%.1f" % [GameState.combo, GameState.get_combo_multiplier()] if GameState.combo > 0 else "NO CHAIN"
	_style.text = "STYLE ×%.2f" % GameState.style if GameState.style > 1.0 else ""
	var chain_left := clampf(GameState.get_combo_time_left() / GameState.COMBO_WINDOW, 0.0, 1.0)
	_chain_bar.size.x = (_chain_bar.get_parent() as Control).size.x * chain_left

	_mode_name.text = mode.display_name
	_headline.text = mode.get_headline()
	_headline.visible = _headline.text != ""
	_objective.text = mode.get_objective()
	var hurry := mode.time_limit > 0.0 and mode.time_left <= 10.0 and mode.state == GameMode.State.PLAYING
	_headline.add_theme_color_override("font_color", FrontierUI.RED if hurry else FrontierUI.INK)
	if hurry and ceili(mode.time_left) != _last_second:
		_last_second = ceili(mode.time_left)
		AudioManager.play_ui(&"hover", 4.0)

	_banner.text = mode.get_banner()
	_banner_sub.text = mode.get_banner_detail()

	_ammo.weapon = w
	_weapon_name.text = w.data.display_name
	_weapon_status.text = _weapon_line(w)

	_hint_timer -= delta
	_hint.text = _hint_for(w)
	_hint.modulate.a = clampf(_hint_timer, 0.0, 1.0)

	if mode.state == GameMode.State.FINISHED and not result_shown:
		_finished_for += delta
		if _finished_for >= RESULTS_DELAY and DisplayServer.get_name() != "headless":
			show_overlay(true)


func _weapon_line(w: Weapon) -> String:
	if player.is_holstered:
		return "Holstered"
	if w.is_reloading():
		return "Loading...  %s stops" % FrontierUI.key("reload")
	var line := _action_line(w)
	if w.get_zero_distance() > 0.0:
		var wind := Wind.get_velocity()
		var across := wind.dot(player.camera.global_basis.x)
		line += "\nSight %d m   Wind %.1f m/s %s" % [
			w.get_zero_distance(), wind.length(),
			"" if absf(across) < 0.2 else ("from the left" if across > 0.0 else "from the right"),
		]
	return line


## What the gun needs from the player next, in words.
func _action_line(w: Weapon) -> String:
	if w.get_ammo() == 0:
		return "Empty  ·  %s to load" % FrontierUI.key("reload")
	var ready := false
	var needs := "Cock the hammer"
	if w is Revolver:
		ready = w.hammer_cocked
	elif w is LeverRifle:
		ready = w.chamber == LeverRifle.Chamber.LIVE and w.hammer_cocked
		needs = "Work the lever"
	elif w is CoachGun:
		ready = true in w.hammers
		needs = "Cock the hammers"
	elif w is SharpsRifle:
		ready = w.chamber == SharpsRifle.Chamber.LIVE and w.hammer_cocked
		if w.chamber != SharpsRifle.Chamber.LIVE:
			return "Breech empty  ·  %s to load" % FrontierUI.key("reload")
	return "Ready" if ready else "%s  ·  %s" % [needs, FrontierUI.key("cock_hammer")]


func _hint_for(w: Weapon) -> String:
	var k := FrontierUI.key
	var lines := PackedStringArray()
	if player.dead_eye.active:
		_hint_timer = 1.0
		return "%s mark a target   ·   %s let fly" % [k.call("fire"), k.call("dead_eye")]
	if player.dead_eye.enabled and player.dead_eye.meter >= 100.0:
		_hint_timer = maxf(_hint_timer, 1.0)
		lines.append("%s Dead Eye" % k.call("dead_eye"))
	if w is Revolver:
		lines.append("%s cock   ·   %s + %s fan   ·   %s load" % [k.call("cock_hammer"), k.call("alt_fire"), k.call("fire"), k.call("reload")])
	elif w is CoachGun:
		lines.append("%s + %s both barrels   ·   %s load" % [k.call("alt_fire"), k.call("fire"), k.call("reload")])
	else:
		lines.append("%s work the action   ·   %s / %s sight   ·   %s load" % [k.call("cock_hammer"), k.call("sight_down"), k.call("sight_up"), k.call("reload")])
	lines.append("%s aim   ·   %s holster   ·   %s pause" % [k.call("aim"), k.call("holster"), k.call("pause")])
	return "\n".join(lines)


static func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


# --- Score stamps -----------------------------------------------------------

func _on_scored(event: Dictionary) -> void:
	_hit_flash = 0.22
	var points: int = event.points
	var tags: PackedStringArray = event.tags
	var at := size * 0.5 + Vector2(randf_range(50, 130), randf_range(-110, -50))
	var world: Vector3 = event.position
	if world != Vector3.ZERO and is_instance_valid(player) and not player.camera.is_position_behind(world):
		at = player.camera.unproject_position(world) + Vector2(randf_range(-20, 20), -40)
		at = at.clamp(Vector2(160, 120), size - Vector2(160, 160))
	var color := FrontierUI.RED if points < 0 else (FrontierUI.GOLD if tags.size() > 0 else FrontierUI.PAPER)
	var stamp := VBoxContainer.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_theme_constant_override("separation", -6)
	_outlined(FrontierUI.title(stamp, "%+d" % points, 44 if tags.is_empty() else 56, color), 10)
	if not tags.is_empty():
		var words := _outlined(FrontierUI.label(stamp, "  ".join(tags), 24, color), 8)
		words.add_theme_font_override("font", FrontierUI.text_font(800))
		AudioManager.play_ui(&"stamp", -7.0)
	_stamps.add_child(stamp)
	stamp.reset_size()
	stamp.pivot_offset = stamp.size * 0.5
	stamp.position = at - stamp.size * 0.5
	stamp.rotation = randf_range(-0.1, 0.1)
	stamp.scale = Vector2.ONE * 1.7
	var tween := stamp.create_tween()
	tween.tween_property(stamp, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.45)
	tween.tween_property(stamp, "position:y", stamp.position.y - 46, 0.5)
	tween.parallel().tween_property(stamp, "modulate:a", 0.0, 0.5)
	tween.tween_callback(stamp.queue_free)


# --- Drawn parts: crosshair, hit marker, Dead Eye, wind ---------------------

func _draw() -> void:
	if not is_instance_valid(player) or player.weapon == null or is_instance_valid(overlay):
		return
	var center := size * 0.5
	if player.ads_amount < 0.5 and not player.is_holstered:
		# A dot, and a ring the size of the real spread cone on screen.
		var spread := deg_to_rad(player.weapon.get_current_spread())
		var radius := tan(spread) / tan(deg_to_rad(player.camera.fov * 0.5)) * size.y * 0.5
		var alpha := 1.0 - player.ads_amount * 2.0
		draw_circle(center, 4.0, Color(FrontierUI.INK, 0.6 * alpha))
		draw_circle(center, 2.5, Color(FrontierUI.PAPER, alpha))
		draw_arc(center, radius + 5.0, 0.0, TAU, 48, Color(FrontierUI.INK, 0.35 * alpha), 3.5, true)
		draw_arc(center, radius + 5.0, 0.0, TAU, 48, Color(FrontierUI.PAPER, 0.75 * alpha), 1.5, true)
	if _hit_flash > 0.0:
		var color := Color(FrontierUI.GOLD, _hit_flash / 0.22)
		for dir: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			draw_line(center + dir * 9, center + dir * 20, color, 3.0, true)

	var dead_eye := player.dead_eye
	if dead_eye.enabled:
		_draw_dead_eye(dead_eye)
	if player.weapon.get_zero_distance() > 0.0 and mode.state != GameMode.State.FINISHED:
		_draw_wind_flag(Vector2(size.x - 60, 250))


func _draw_dead_eye(dead_eye: DeadEye) -> void:
	var font := FrontierUI.text_font(700)
	var bar := Rect2(Vector2(size.x * 0.5 - 170, size.y - 58), Vector2(340, 18))
	var amount := dead_eye.seconds_left / 4.0 if dead_eye.active else dead_eye.meter / 100.0
	var ready := dead_eye.meter >= 100.0 and not dead_eye.active
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	draw_rect(bar.grow(3), Color(FrontierUI.INK, 0.85))
	var fill := FrontierUI.RED if dead_eye.active else FrontierUI.GOLD.lerp(FrontierUI.PAPER, pulse * 0.6 if ready else 0.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(amount, 0, 1), bar.size.y)), fill)
	for i in range(1, 4):  # one notch per trick shot needed
		var x := bar.position.x + bar.size.x * i / 4.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(FrontierUI.INK, 0.7), 2.0)
	var caption := "DEAD EYE"
	if ready:
		caption = "DEAD EYE READY  ·  %s" % FrontierUI.key("dead_eye")
	elif dead_eye.active:
		caption = "MARK %d / %d" % [dead_eye.marks.size(), mini(6, player.weapon.get_ammo())]
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var at := Vector2(size.x * 0.5 - width * 0.5, bar.position.y - 12)
	draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 8, FrontierUI.INK)
	draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, FrontierUI.PAPER)
	for i in dead_eye.marks.size():
		var mark: Dictionary = dead_eye.marks[i]
		var body: Variant = mark.body.get_ref()
		if not is_instance_valid(body):
			continue
		var world: Vector3 = body.to_global(mark.point)
		if player.camera.is_position_behind(world):
			continue
		var screen := player.camera.unproject_position(world)
		draw_arc(screen, 16, 0, TAU, 24, FrontierUI.INK, 6, true)
		draw_arc(screen, 16, 0, TAU, 24, FrontierUI.RED, 3, true)
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(screen + dir * 10, screen + dir * 24, FrontierUI.RED, 3, true)
		draw_string_outline(font, screen + Vector2(22, -14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 8, FrontierUI.INK)
		draw_string(font, screen + Vector2(22, -14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, FrontierUI.PAPER)


## A pennant that streams the way the wind blows across your line of fire.
func _draw_wind_flag(top: Vector2) -> void:
	var wind := Wind.get_velocity()
	var across := wind.dot(player.camera.global_basis.x)
	var reach := clampf(absf(across) * 14.0, 6.0, 74.0) * (1.0 if across >= 0.0 else -1.0)
	var flutter := sin(Time.get_ticks_msec() / 110.0) * minf(absf(across) * 1.5, 6.0)
	draw_line(top + Vector2(1, 1), top + Vector2(1, 71), Color(0, 0, 0, 0.4), 6)
	draw_line(top, top + Vector2(0, 70), FrontierUI.PAPER, 4)
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(0, 2), top + Vector2(reach, 14 + flutter), top + Vector2(0, 28),
	]), FrontierUI.RED)


# --- Pause and results -------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and mode and not result_shown:
		if is_instance_valid(overlay):
			close_overlay()
		else:
			show_overlay(false)
		get_viewport().set_input_as_handled()


func show_overlay(results: bool) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	result_shown = results
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = FrontierUI.SHADE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := FrontierUI.poster(center, 640)
	if results:
		_build_results(column)
	else:
		_build_pause(column)


func close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_pause(column: VBoxContainer) -> void:
	FrontierUI.caption(column, mode.display_name)
	FrontierUI.title(column, "HOLD YOUR HORSES", 50)
	FrontierUI.rule(column)
	FrontierUI.focus(FrontierUI.button(column, "RESUME", close_overlay))
	FrontierUI.button(column, "START OVER", _restart)
	FrontierUI.button(column, "SETTINGS", func() -> void:
		for child in column.get_children():
			child.queue_free()
		var page := SettingsPage.new()
		page.closed.connect(func() -> void: show_overlay(false))
		column.add_child(page)
	)
	FrontierUI.button(column, "MAIN MENU", _to_menu)


func _build_results(column: VBoxContainer) -> void:
	var result := mode.result
	var stars := int(result.get("stars", 0))
	FrontierUI.caption(column, "The Frontier Gazette  ·  Special Edition")
	FrontierUI.title(column, mode.display_name.to_upper(), 54)
	FrontierUI.rule(column)
	var row := FrontierUI.Stars.new(0, 3, 64)
	column.add_child(row)
	var score_text := "%s ms" % result.get("score", 0) if mode.lower_is_better else "$%s" % _thousands(int(result.get("score", 0)))
	FrontierUI.title(column, score_text, 76)
	var verdict := FrontierUI.label(column, "NEW RECORD" if mode.is_new_best else mode.get_verdict(), 26, FrontierUI.RED if mode.is_new_best else FrontierUI.INK_SOFT)
	verdict.add_theme_font_override("font", FrontierUI.text_font(800))
	FrontierUI.rule(column)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for line: Array in mode.get_result_lines():
		FrontierUI.label(grid, line[0], 24, FrontierUI.INK_SOFT).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var value := FrontierUI.label(grid, line[1], 24)
		value.add_theme_font_override("font", FrontierUI.text_font(700))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var next := mode.get_next_star_text()
	if next != "":
		FrontierUI.label(column, next, 20, FrontierUI.INK_SOFT)
	FrontierUI.rule(column)
	FrontierUI.focus(FrontierUI.button(column, "RIDE AGAIN", _restart))
	FrontierUI.button(column, "MAIN MENU", _to_menu)
	# Stars land one at a time.
	for i in stars:
		var timer := get_tree().create_timer(0.5 + i * 0.45, true, false, true)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(row):
				row.filled = i + 1
				AudioManager.play_ui(&"star", -4.0 + i * 2.0)
		)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/menu.tscn")


# --- Rounds in the gun -------------------------------------------------------

## Draws what is loaded: the revolver's cylinder as seen from behind, or a
## row of cartridges for the long guns.
class AmmoView:
	extends Control

	const BRASS := Color("c99b50")
	const SPENT := Color("7a6240")
	const LEAD := Color("6d6a66")
	const SHELL := Color("a8321f")

	var weapon: Weapon:
		set(value):
			if value != weapon:
				weapon = value
				_angle = _target_angle()
				custom_minimum_size = _wanted_size()
			queue_redraw()
	var _angle := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(104, 104)

	func _process(delta: float) -> void:
		_angle = lerp_angle(_angle, _target_angle(), 1.0 - exp(-18.0 * delta))

	func _target_angle() -> float:
		return -(weapon as Revolver).chamber_index * TAU / 6.0 if weapon is Revolver else 0.0

	func _wanted_size() -> Vector2:
		if weapon is Revolver or weapon == null:
			return Vector2(104, 104)
		return Vector2(maxf(weapon.data.capacity * (30.0 if weapon is CoachGun else 17.0), 40.0), 104)

	func _draw() -> void:
		if weapon == null:
			return
		if weapon is Revolver:
			_draw_cylinder(weapon)
		else:
			_draw_row()

	func _draw_cylinder(revolver: Revolver) -> void:
		var center := size * 0.5
		draw_circle(center, 51, FrontierUI.INK)
		draw_circle(center, 47, Color("8f8a84"))
		draw_circle(center, 9, FrontierUI.INK)
		for i in 6:
			var at := center + Vector2.UP.rotated(_angle + i * TAU / 6.0) * 29
			var state: int = revolver.chambers[i]
			draw_circle(at, 13.5, FrontierUI.INK)
			if state == Revolver.Chamber.LIVE:
				draw_circle(at, 11.5, BRASS)
				draw_circle(at, 4, BRASS.darkened(0.25))
			elif state == Revolver.Chamber.SPENT:
				draw_circle(at, 11.5, SPENT)
				draw_circle(at, 4, FrontierUI.INK)
		# The chamber under the hammer.
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-8, -56), center + Vector2(8, -56), center + Vector2(0, -45),
		]), FrontierUI.RED)

	func _draw_row() -> void:
		var capacity := weapon.data.capacity
		var loaded := weapon.get_ammo()
		var shells := weapon is CoachGun
		var step := 30.0 if shells else 17.0
		var width := 22.0 if shells else 11.0
		for i in capacity:
			var x := i * step + (step - width) * 0.5
			var body := Rect2(x, 38, width, 50)
			if i < loaded:
				if shells:
					draw_rect(Rect2(x, 26, width, 46), SHELL)
					draw_rect(Rect2(x, 72, width, 16), BRASS)
				else:
					draw_rect(body, BRASS)
					draw_colored_polygon(PackedVector2Array([
						Vector2(x, 38), Vector2(x + width * 0.2, 22), Vector2(x + width * 0.5, 16),
						Vector2(x + width * 0.8, 22), Vector2(x + width, 38),
					]), LEAD)
				draw_rect(Rect2(x - 1, 86, width + 2, 4), BRASS.darkened(0.3))
			else:
				draw_rect(Rect2(x, 26 if shells else 38, width, 62 if shells else 50), Color(FrontierUI.INK, 0.28), false, 2.0)
