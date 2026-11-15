extends Node
## Visual check of the modes: saves captures of the Gallery (all pop-ups
## raised, wheel rolling, clays in the air) and of a Quick Draw round to
## user://shots/.
## Run:  godot --path . res://tests/screenshots_modes.tscn

const GALLERY := preload("res://modes/gallery.tscn")
const QUICK_DRAW := preload("res://modes/quick_draw.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	SaveSystem.path = "user://test_save.json"

	var gallery := GALLERY.instantiate() as Gallery
	gallery.countdown = 0.2
	gallery.roller_interval = 1.0
	gallery.clay_schedule = {1.2: 3}
	add_child(gallery)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(0.5)
	for node in get_tree().get_nodes_in_group(&"targets"):
		if node is CutoutTarget:
			node.pop_up()
	gallery.player.aim_at(Vector3(0, 1.6, -16))
	await _wait(2.6)
	await _capture("mode_gallery")
	gallery.player.aim_at(Vector3(-5, 1.3, -14.7))
	Input.action_press("aim")
	await _wait(0.5)
	await _capture("mode_gallery_ads")
	Input.action_release("aim")
	gallery.finish()
	await _wait(0.3)
	await _capture("mode_gallery_result")
	gallery.queue_free()
	await _wait(0.3)

	var duel := QUICK_DRAW.instantiate() as QuickDraw
	duel.countdown = 0.2
	duel.min_wait = 0.8
	duel.max_wait = 0.8
	add_child(duel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	duel.player.aim_at(Vector3(0, 1.3, -12))
	await _wait(0.8)
	await _capture("mode_duel_steady")
	while duel.phase != QuickDraw.Phase.DRAW:
		await get_tree().process_frame
	duel.player.draw()
	await _wait(0.55)
	await _capture("mode_duel_draw")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	get_tree().quit()


func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
