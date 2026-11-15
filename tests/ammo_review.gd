extends Node
## Close-ups of the ammunition: the revolver's cylinder from behind and from
## the front (chambers live, spent and empty), then every cartridge the guns
## use, live beside spent, from the side and from the base.
##   godot --path . --resolution 1920x1080 res://tests/ammo_review.tscn
## Writes output/review/ammo.png.

## Radius, length, shotgun shell?
const ROUNDS := [[0.0056, 0.04, false], [0.0065, 0.06, false], [0.0105, 0.065, true]]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/review")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var canvas := get_viewport().get_visible_rect().size
	var cell := canvas / 2.0
	for view in 4:
		var subject: Node3D
		var camera := Camera3D.new()
		camera.near = 0.005
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		if view < 2:
			var revolver := RevolverModel.new()
			revolver.set_hands_visible(false)
			revolver.play_action(&"chambers", 0.0, {"states": [
				Revolver.Chamber.LIVE, Revolver.Chamber.SPENT, Revolver.Chamber.EMPTY,
				Revolver.Chamber.LIVE, Revolver.Chamber.SPENT, Revolver.Chamber.EMPTY,
			]})
			subject = revolver
			camera.size = 0.1
			var focus := Vector3(0, -0.012, -0.022)
			camera.position = focus + (Vector3(-0.9, 0.5, 1.0) if view == 0 else Vector3(-0.6, 0.35, -1.0))
			camera.look_at_from_position(camera.position, focus)
		else:
			var maker := WeaponModel.new()
			var x := -0.05
			for spec: Array in ROUNDS:
				for spent: bool in [false, true]:
					var cartridge := maker._cartridge_mesh(maker, spec[0], spec[1], spec[2])
					WeaponModel.set_cartridge_spent(cartridge, spent)
					cartridge.position = Vector3(x, 0, 0)
					cartridge.rotation.x = PI / 2.0  # stand it on its base
					x += 0.02 if spec[0] < 0.009 else 0.028
			subject = maker
			camera.size = 0.15
			var focus := Vector3(0.012, 0.03, 0)
			camera.position = focus + (Vector3(0.2, 0.25, 1.0) if view == 2 else Vector3(0.25, -0.7, 0.7))
			camera.look_at_from_position(camera.position, focus)
		_cell(root, Rect2(Vector2(view % 2, view / 2) * cell, cell - Vector2(4, 4)), subject, camera)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/review/ammo.png")
	await AudioManager.shutdown()
	get_tree().quit()


func _cell(root: Control, rect: Rect2, subject: Node3D, camera: Camera3D) -> void:
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
	view.add_child(subject)
	view.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 1.6
	sun.light_color = Color(1, 0.93, 0.82)
	view.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -40, 0)
	fill.light_energy = 0.7
	view.add_child(fill)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("5d6468")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	view.add_child(world)
