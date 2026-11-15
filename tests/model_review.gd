extends Node
## Renders every weapon model from four angles for looking over by eye:
## right side, front left, the shooter's own view, and mid-reload.
##   godot --path . --resolution 1920x1080 res://tests/model_review.tscn
## Writes output/review/models.png (and one models_<n>.png per weapon).

var MODELS := [RevolverModel, LeverRifleModel, CoachGunModel, SharpsRifleModel]
const DATA := ["revolver", "lever_rifle", "coach_gun", "sharps_rifle"]
## Framing per weapon: point the side cameras look at, and how wide they see.
const FOCUS := [Vector3(0, -0.04, -0.05), Vector3(0, -0.04, -0.1), Vector3(0, -0.04, -0.1), Vector3(0, -0.04, -0.15)]
const SPAN := [0.5, 1.2, 0.85, 1.35]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/review")
	var only := -1
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			only = int(arg)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("5d6468")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var canvas := get_viewport().get_visible_rect().size
	var rows := 1 if only >= 0 else MODELS.size()
	var cell := Vector2(canvas.x / 4.0, canvas.y / rows)
	var reloading: Array[WeaponModel] = []
	for row in rows:
		var index := only if only >= 0 else row
		var data: WeaponData = load("res://weapons/data/%s.tres" % DATA[index])
		for column in 4:
			var model: WeaponModel = MODELS[index].new()
			var camera := _cell(root, Rect2(Vector2(column, row) * cell, cell - Vector2(4, 4)), model)
			match column:
				0:
					camera.projection = Camera3D.PROJECTION_ORTHOGONAL
					camera.size = SPAN[index] * 0.62
					camera.position = FOCUS[index] + Vector3(2, 0, 0)
					camera.look_at(FOCUS[index])
				1:
					camera.projection = Camera3D.PROJECTION_ORTHOGONAL
					camera.size = SPAN[index] * 0.62
					camera.position = FOCUS[index] + Vector3(-1.2, 0.7, -1.3)
					camera.look_at(FOCUS[index])
				_:
					# Where the player's eye is when the gun is at the hip.
					camera.fov = 80
					camera.position = -data.hip_position
					if column == 3:
						reloading.append(model)
	await get_tree().create_timer(0.3).timeout
	for model in reloading:
		if model is RevolverModel:
			model.play_action(&"reload_open", 0.2)
		elif model is LeverRifleModel:
			model.play_action(&"reload_open", 0.2)
		elif model is CoachGunModel:
			model.play_action(&"break_open", 0.2)
		else:
			model.play_action(&"breech_open", 0.2)
	await get_tree().create_timer(0.5).timeout
	for model in reloading:
		model.play_action(&"insert", 1.2, {"index": 1})
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	var name_suffix := "_%d" % only if only >= 0 else ""
	get_viewport().get_texture().get_image().save_png("res://output/review/models%s.png" % name_suffix)
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
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	view.add_child(world)
	return camera
