extends Node
## Close-ups of the hands on one weapon, for checking a grip by eye:
## right, left, top, rear, then the shooter's view at the hip and aimed.
##   godot --path . --resolution 1920x1080 res://tests/hand_review.tscn -- 0
## The number picks the weapon (0-3); add `reload` to pose it mid-reload, or
## any other action name (lever_open, cock, ...) to pose it part-way through.
## `bare` hides the hands and swaps the rear view for a front quarter, to
## look at the gun itself. Writes output/review/hands_<n>[_<pose>].png.

var MODELS := [RevolverModel, LeverRifleModel, CoachGunModel, SharpsRifleModel]
const DATA := ["revolver", "lever_rifle", "coach_gun", "sharps_rifle"]
## Middle of the shooting hand, and how much of the gun the side views show.
const FOCUS := [Vector3(0, -0.05, 0.03), Vector3(0, -0.04, 0.1), Vector3(0, -0.05, 0.17), Vector3(0, -0.04, 0.1)]
const SPAN := [0.24, 0.42, 0.42, 0.42]
const BARE_FOCUS := [Vector3(0, -0.03, -0.06), Vector3(0, -0.03, -0.12), Vector3(0, -0.04, -0.12), Vector3(0, -0.03, -0.17)]
const BARE_SPAN := [0.27, 1.2, 0.85, 1.4]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/review")
	var index := 0
	var reload := false
	var action := &""
	var bare := false
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			index = int(arg)
		elif arg == "reload":
			reload = true
		elif arg == "bare":
			bare = true
		else:
			action = StringName(arg)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("5d6468")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var canvas := get_viewport().get_visible_rect().size
	var cell := Vector2(canvas.x / 3.0, canvas.y / 2.0)
	var data: WeaponData = load("res://weapons/data/%s.tres" % DATA[index])
	var focus: Vector3 = BARE_FOCUS[index] if bare else FOCUS[index]
	var models: Array[WeaponModel] = []
	for view in 6:
		var model: WeaponModel = MODELS[index].new()
		models.append(model)
		if bare:
			model.set_hands_visible(false)
		var camera := _cell(root, Rect2(Vector2(view % 3, view / 3) * cell, cell - Vector2(4, 4)), model)
		if view < 4:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = BARE_SPAN[index] if bare else SPAN[index]
			var from: Vector3 = [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 2, 0.001), Vector3(-1.1, 0.5, -1.6) if bare else Vector3(0, 0.5, 2)][view]
			camera.position = focus + from
			camera.look_at(focus, Vector3.FORWARD if view == 2 else Vector3.UP)
		elif view == 4:
			camera.fov = 30
			camera.position = -data.hip_position
			camera.look_at(focus + Vector3(0, 0, -0.05))
		else:
			camera.fov = 60
			camera.position = -data.ads_position
	if reload:
		await get_tree().create_timer(0.3).timeout
		for model in models:
			model.play_action([&"reload_open", &"reload_open", &"break_open", &"breech_open"][index], 0.2)
		await get_tree().create_timer(0.5).timeout
		for model in models:
			model.play_action(&"insert", 1.2, {"index": 1})
		await get_tree().create_timer(0.75).timeout
	elif action:
		await get_tree().create_timer(0.3).timeout
		for model in models:
			model.play_action(action, 0.2)
		await get_tree().create_timer(0.4).timeout
	else:
		await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://output/review/hands_%d%s.png" % [index, "_reload" if reload else "_%s" % action if action else "_bare" if bare else ""]
	)
	await AudioManager.shutdown()
	get_tree().quit()


func _cell(root: Control, rect: Rect2, model: WeaponModel) -> Camera3D:
	var panel := SubViewportContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.stretch = true
	root.add_child(panel)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	panel.add_child(view)
	view.add_child(model)
	var camera := Camera3D.new()
	camera.near = 0.01
	view.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 1.6
	sun.light_color = Color(1, 0.93, 0.82)
	view.add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("5d6468")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.84, 0.9)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	view.add_child(world)
	return camera
