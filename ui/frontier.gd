class_name FrontierUI
extends RefCounted
## Shared look of every screen: palette, fonts, theme and a few builders.
## Rye is the display face (titles, numbers), Bitter the text face.

const INK := Color("241b18")
const INK_SOFT := Color("5a463a")
const PAPER := Color("e8d3a3")
const PAPER_DARK := Color("cdb27c")
const GOLD := Color("c99b50")
const RED := Color("a8321f")
const SHADE := Color(0.08, 0.05, 0.04, 0.72)

const RYE := "res://ui/fonts/Rye-Regular.ttf"
const BITTER := "res://ui/fonts/Bitter-Variable.ttf"

static var _fonts := {}
static var _theme: Theme


## The display face. Falls back to a system serif if the file is missing.
static func display_font() -> Font:
	if not _fonts.has(&"display"):
		_fonts[&"display"] = load(RYE) if ResourceLoader.exists(RYE) else _system_font()
	return _fonts[&"display"]


## The text face at the given weight (Bitter is a variable font, 100-900).
static func text_font(weight := 500) -> Font:
	if not _fonts.has(weight):
		if ResourceLoader.exists(BITTER):
			var variation := FontVariation.new()
			variation.base_font = load(BITTER)
			variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			_fonts[weight] = variation
		else:
			_fonts[weight] = _system_font()
	return _fonts[weight]


static func make_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	_theme = t
	t.default_font = text_font(500)
	t.default_font_size = 24

	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := _box(PAPER, INK, 2)
		box.bg_color = {"normal": PAPER, "hover": GOLD, "pressed": PAPER_DARK, "disabled": PAPER_DARK}[state]
		box.content_margin_left = 28
		box.content_margin_right = 28
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		for control in ["Button", "OptionButton", "CheckButton"]:
			t.set_stylebox(state, control, box)
	var focus := _box(Color.TRANSPARENT, INK, 4)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	for control in ["Button", "OptionButton", "CheckButton", "HSlider"]:
		t.set_stylebox("focus", control, focus)
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(color, control, INK)
		t.set_color("font_disabled_color", control, INK_SOFT)
	t.set_font("font", "Button", text_font(700))
	t.set_color("font_color", "Label", INK)

	var track := _box(INK, INK, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(GOLD, INK, 0)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		t.set_icon(icon, "HSlider", load("res://ui/brass_knob.svg"))

	var rule := StyleBoxLine.new()
	rule.color = INK
	rule.thickness = 2
	t.set_stylebox("separator", "HSeparator", rule)
	t.set_constant("separation", "HSeparator", 18)

	var popup := _box(PAPER, INK, 2)
	popup.set_content_margin_all(8)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", _box(GOLD, GOLD, 0))
	for color in ["font_color", "font_hover_color"]:
		t.set_color(color, "PopupMenu", INK)

	var tip := _box(INK, GOLD, 1)
	tip.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", PAPER)
	return t


## A text label. `display` picks the display face.
static func label(parent: Node, text: String, font_size := 24, color := INK, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display_font() if display else text_font(500))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if parent:
		parent.add_child(l)
	return l


static func title(parent: Node, text: String, font_size := 48, color := INK) -> Label:
	return label(parent, text, font_size, color, true)


## Small spaced-out capitals, for captions above a value.
static func caption(parent: Node, text: String, color := INK_SOFT, font_size := 19) -> Label:
	var l := label(parent, text.to_upper(), font_size, color)
	if not _fonts.has(&"caption"):
		var font := (text_font(800) as Font).duplicate()
		if font is FontVariation:
			font.spacing_glyph = 3
		_fonts[&"caption"] = font
	l.add_theme_font_override("font", _fonts[&"caption"])
	return l


static func button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text

	b.pressed.connect(action)
	b.pressed.connect(func() -> void: AudioManager.play_ui(&"ui"))
	b.mouse_entered.connect(func() -> void: AudioManager.play_ui(&"hover"))
	b.focus_entered.connect(func() -> void: AudioManager.play_ui(&"hover"))
	if parent:
		parent.add_child(b)
	return b


## Gives a control keyboard focus once it is in the tree (and only if it
## still is by then).
static func focus(control: Control) -> void:
	var id := control.get_instance_id()
	(func() -> void:
		var target := instance_from_id(id) as Control
		if target and target.is_inside_tree():
			target.grab_focus()
	).call_deferred()


static func rule(parent: Node) -> HSeparator:
	var line := HSeparator.new()
	parent.add_child(line)
	return line


## Dark planked backdrop behind menus.
static func backdrop(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://ui/paper.gdshader")
	bg.material = mat
	parent.add_child(bg)
	return bg


## A sheet of aged paper. Returns the column that holds its contents.
static func poster(parent: Node, width := 640.0, margin := 40) -> VBoxContainer:
	var sheet := PanelContainer.new()
	var backing := _box(PAPER, INK, 0)
	backing.set_content_margin_all(margin)
	backing.shadow_color = Color(0, 0, 0, 0.55)
	backing.shadow_size = 18
	sheet.add_theme_stylebox_override("panel", backing)
	parent.add_child(sheet)
	var grain := ColorRect.new()
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := ShaderMaterial.new()
	paper.shader = preload("res://ui/poster.gdshader")
	grain.material = paper
	# Sits inside the panel's margin, which leaves a plain border around it.
	sheet.add_child(grain)
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 22)
	sheet.add_child(inset)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	column.add_theme_constant_override("separation", 12)
	inset.add_child(column)
	return column


## A small paper tag for the HUD.
static func tag_style(alpha := 0.94) -> StyleBoxFlat:
	var box := _box(Color(PAPER, alpha), INK, 2)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	return box


## Short name of a key, mouse button or gamepad button.
static func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return {1: "LMB", 2: "RMB", 3: "MMB", 4: "Wheel up", 5: "Wheel down", 8: "Mouse 4", 9: "Mouse 5"}.get(event.button_index, "Mouse %d" % event.button_index)
	if event is InputEventJoypadButton:
		var pad := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "Up", "Down", "Left", "Right"]
		var index: int = event.button_index
		return "Pad " + (pad[index] if index >= 0 and index < pad.size() else str(index))
	if event is InputEventJoypadMotion:
		return ["Left stick", "Left stick", "Right stick", "Right stick", "LT", "RT"][clampi(event.axis, 0, 5)]
	return event.as_text()


## Everything bound to an action, e.g. "F / RMB / Pad X".
static func action_text(action: String) -> String:
	var names := PackedStringArray()
	for event in InputMap.action_get_events(action):
		var text := event_text(event)
		if text not in names:
			names.append(text)
	return " / ".join(names) if not names.is_empty() else "unbound"


## The first keyboard or mouse binding of an action, for on-screen hints.
static func key(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event_text(event)
	return action_text(action)


static func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	return box


static func _system_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "DejaVu Serif", "serif"])
	return font


## A row of rating stars, drawn rather than typed so it needs no glyphs.
class Stars:
	extends Control

	var total := 3
	var star_size := 44.0
	var filled := 0:
		set(value):
			filled = value
			queue_redraw()

	func _init(count := 0, of := 3, size_px := 44.0) -> void:
		total = of
		star_size = size_px
		filled = count
		custom_minimum_size = Vector2(total * star_size * 1.15, star_size)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in total:
			var center := Vector2((i + 0.5) * star_size * 1.15, star_size * 0.5)
			var points := PackedVector2Array()
			for k in 10:
				var radius := star_size * (0.5 if k % 2 == 0 else 0.21)
				points.append(center + Vector2.UP.rotated(k * TAU / 10.0) * radius)
			if i < filled:
				draw_colored_polygon(points, FrontierUI.GOLD)
			points.append(points[0])
			draw_polyline(points, FrontierUI.INK, 2.5, true)
