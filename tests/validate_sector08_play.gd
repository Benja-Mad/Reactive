## Walkable Sector 08: collision, player movement, camera follow, and P30 integrity throughout.
extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	var scene: Node = load("res://scenes/environment/sector_08/Sector08LookDev.tscn").instantiate()
	root.add_child(scene)
	scene.debug_layer.visible = false
	scene.controller.auto_demo = false
	scene.controller.set_process(false)
	scene.controller.preset_normal()
	for i in 180: scene.controller._process(1.0 / 60.0)
	scene.pixel_presentation.set_mode(0)
	scene.pixel_presentation.set_diorama(true)
	for i in 20: await process_frame

	var approved: Transform3D = scene.parallax.center
	var report: Dictionary = {"collision": scene.sector_runtime.collision.stats}

	scene.set_play_mode(true)
	assert(scene.player != null)
	assert(not scene.test_character.visible)
	for i in 30: await process_frame

	# The player must come to rest on the yard floor, not sink or hover.
	assert(scene.player.is_on_floor())
	report["rest_height_m"] = snappedf(scene.player.global_position.y, 0.001)
	assert(absf(scene.player.global_position.y) < 0.20)

	# Walk in each direction and confirm the body actually translates and stays in bounds.
	var walks: Dictionary = {}
	for direction: Array in [["move_right", Vector2(1, 0)], ["move_left", Vector2(-1, 0)], ["move_up", Vector2(0, -1)], ["move_down", Vector2(0, 1)]]:
		var action: String = direction[0]
		var start: Vector3 = scene.player.global_position
		Input.action_press(action)
		for i in 70: await process_frame
		Input.action_release(action)
		for i in 10: await process_frame
		var moved: float = start.distance_to(scene.player.global_position)
		walks[action] = snappedf(moved, 0.01)
		assert(moved > 0.5)
		assert(absf(scene.player.global_position.x) < 27.0 and scene.player.global_position.z > -27.0 and scene.player.global_position.z < 15.0)
		assert(scene.gameplay_camera.fov == 30.0)
		assert(scene.gameplay_camera.global_basis.is_equal_approx(approved.basis))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("walk_" + action + ".png"))
	report["walk_distance_m"] = walks
	report["camera"] = scene.camera_rig.get_report()
	assert(bool(report["camera"]["basis_preserved"]))

	# Drive the player hard into the perimeter: it must be stopped, not escape.
	Input.action_press("move_left")
	for i in 240: await process_frame
	Input.action_release("move_left")
	for i in 20: await process_frame
	report["west_stop_x"] = snappedf(scene.player.global_position.x, 0.01)
	assert(scene.player.global_position.x > -27.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("perimeter_west.png"))

	# Leaving play mode must restore the approved transform exactly.
	scene.set_play_mode(false)
	for i in 10: await process_frame
	assert(scene.test_character.visible)
	assert(scene.gameplay_camera.global_transform.is_equal_approx(approved))
	report["restored_to_approved_transform"] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("restored.png"))

	FileAccess.open(out.path_join("play.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("SECTOR08 PLAY PASS ", JSON.stringify(report))
	quit()
