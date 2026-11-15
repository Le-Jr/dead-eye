extends Node
## Captures of the real renderer for looking over by eye. Run windowed:
##   godot --path . --resolution 1280x720 res://tests/visual_review.tscn
## Images go to output/review/ (add `-- --wide` for a second, suffixed set).

const HUD := preload("res://ui/hud.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("res://output/review")
	var menu := preload("res://ui/menu.tscn").instantiate()
	add_child(menu)
	await capture("menu")
	menu.show_settings()
	await capture("settings")
	(menu.pages.get_child(0) as SettingsPage)._show("Controls")
	await capture("settings_controls")
	menu.queue_free()
	await get_tree().process_frame

	var range_scene := preload("res://modes/free_range.tscn").instantiate()
	add_child(range_scene)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	range_scene.player.controls_enabled = false
	range_scene.player.sway_enabled = false
	for i in 4:
		range_scene.player.switch_weapon(i)
		await get_tree().create_timer(.8).timeout
		await capture("game_%d" % i)
	range_scene.player.dead_eye.meter = 100
	range_scene.player.dead_eye.activate()
	await capture("dead_eye")
	range_scene.player.dead_eye.cancel()
	range_scene.environment.set_time_of_day("night")
	await capture("night")
	range_scene.environment.set_time_of_day("noon")
	await capture("noon")
	range_scene.queue_free()
	await get_tree().process_frame

	var gallery := preload("res://modes/gallery.tscn").instantiate() as GameMode
	gallery.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gallery)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gallery.player.controls_enabled = false
	await capture("countdown")
	gallery._countdown_left = 0.0
	await get_tree().create_timer(.6).timeout
	for i in 6:
		GameState.register_hit(gallery, &"body", 100)
	var bullet := BulletHit.new()
	bullet.position = Vector3(1.5, 1.6, -9.0)
	bullet.distance = 9.0
	GameState.register_hit(gallery, &"bullseye", 250, bullet)
	await get_tree().create_timer(.15).timeout
	await capture("gallery")
	var hud: Control = gallery.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n.get_script() == HUD)[0]
	hud.show_overlay(false)
	await capture("pause")
	hud.close_overlay()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gallery.finish()
	hud.show_overlay(true)
	await get_tree().create_timer(2.2).timeout
	await capture("results")
	get_tree().paused = false
	gallery.queue_free()
	await get_tree().process_frame

	var duel := preload("res://modes/quick_draw.tscn").instantiate() as QuickDraw
	add_child(duel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	duel.player.controls_enabled = false
	duel._countdown_left = 0.0
	await get_tree().create_timer(1.6).timeout
	await capture("duel")
	duel.queue_free()
	await get_tree().process_frame
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = FrontierUI.make_theme()
	add_child(root)
	FrontierUI.backdrop(root)
	var title := FrontierUI.title(root,"THE GUNSMITH COLLECTION",32,FrontierUI.PAPER)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 20
	var types := [RevolverModel,LeverRifleModel,CoachGunModel,SharpsRifleModel]
	var names := ["01  ·  IVORY SIX","02  ·  GOLDEN REPEATER","03  ·  DEVIL'S COACH","04  ·  LONG HORIZON"]
	var canvas := get_viewport().get_visible_rect().size
	var cell := Vector2((canvas.x-60)/2,(canvas.y-160)/2)
	for i in 4:
		var panel := SubViewportContainer.new()
		panel.position = Vector2(20+(i%2)*(cell.x+20),80+(i/2)*cell.y)
		panel.size = cell-Vector2(0,50)
		panel.stretch = true
		root.add_child(panel)
		var view := SubViewport.new()
		view.size = Vector2i(panel.size)
		view.own_world_3d = true
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		panel.add_child(view)
		var model: WeaponModel = types[i].new()
		view.add_child(model)
		var camera := Camera3D.new()
		view.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = [.19,.52,.4,.58][i]
		var center := Vector3(0,-.045,[-.055,-.12,-.12,-.15][i])
		camera.position = center+Vector3(.9,.4,.3)
		camera.look_at(center)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35,-30,0)
		light.light_energy = 2
		view.add_child(light)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(15,120,0)
		fill.light_energy = 1
		fill.light_color = Color(.5,.7,1)
		view.add_child(fill)
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(.75,.8,.9)
		world.environment.ambient_light_energy = .7
		view.add_child(world)
		var caption := FrontierUI.label(root,names[i],20,FrontierUI.PAPER)
		caption.position = panel.position+Vector2(0,panel.size.y+5)
		caption.size.x = panel.size.x
	await capture("weapons")
	await AudioManager.shutdown()
	get_tree().quit()

func capture(caption: String) -> void:
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	var suffix := "_wide" if "--wide" in OS.get_cmdline_user_args() else ""
	get_viewport().get_texture().get_image().save_png("res://output/review/%s%s.png" % [caption,suffix])
