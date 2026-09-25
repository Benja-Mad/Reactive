extends Node

var checks: Dictionary = {}
var out: String
var arena: Node

func _ready() -> void:
	call_deferred("run")

func capture(id: String) -> void:
	for i in 45: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(id + ".png"))

func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.DAMAGE)]
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	arena = scene.get_node("Arena")
	if "original" in OS.get_cmdline_user_args():
		arena.lateral_extension = 0.0
		arena.south_extension = 0.0
		arena.restrained_presentation = false
	if "wet" in OS.get_cmdline_user_args():
		arena.restrained_presentation = false
	add_child(scene)
	for i in 90: await get_tree().physics_frame
	var player: Character = scene.get_node("Players").get_child(0)
	player.programming_block.code_block.release_focus()
	arena.controller.auto_demo = false
	arena.controller.set_process(false)
	await capture("centre")
	if "centre_only" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	query.shape = capsule
	query.exclude = [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	for side: int in [-1, 1]:
		var cells: int = 0
		var destination := Vector3.ZERO
		# Connected straight paths from the old yard into each new strip.
		for z in range(-18, 11, 2):
			var clear := true
			for x in range(20, 33):
				query.transform.origin = Vector3(x * side, 1.1, z)
				if not space.intersect_shape(query, 1).is_empty():
					clear = false
					break
			if clear:
				cells += 1
				destination = Vector3(30 * side, 0.4, z)
		checks[str(side) + "_open_corridors"] = cells
		if cells > 0:
			player.global_position = destination
			player.velocity = Vector3.ZERO
			for i in 90: await get_tree().physics_frame
			var screen: Vector2 = arena.gameplay_camera.unproject_position(player.global_position + Vector3.UP)
			checks[str(side) + "_in_frame"] = get_viewport().get_visible_rect().grow(-80).has_point(screen)
			checks[str(side) + "_floor_contact"] = player.is_on_floor()
			checks[str(side) + "_paved"] = arena.sector_runtime.perimeter.is_paved(player.global_position)
			await capture("west" if side < 0 else "east")
	var south_corridors: int = 0
	var south_destination := Vector3.ZERO
	for x in range(-24, 25, 2):
		var clear := true
		for z in range(8, 27):
			query.transform.origin = Vector3(x, 1.1, z)
			if not space.intersect_shape(query, 1).is_empty():
				clear = false
				break
		if clear:
			south_corridors += 1
			if south_corridors == 1 or absf(x) < absf(south_destination.x):
				south_destination = Vector3(x, 0.4, 24)
	checks["south_open_corridors"] = south_corridors
	if south_corridors > 0:
		player.global_position = south_destination
		player.velocity = Vector3.ZERO
		for i in 90: await get_tree().physics_frame
		checks["south_floor_contact"] = player.is_on_floor()
		checks["south_paved"] = arena.sector_runtime.perimeter.is_paved(player.global_position)
		checks["south_in_frame"] = get_viewport().get_visible_rect().grow(-80).has_point(arena.gameplay_camera.unproject_position(player.global_position + Vector3.UP))
		await capture("south")
	arena.camera_rig.offset = Vector2.ZERO
	arena.camera_rig._apply()
	player.global_position = Vector3(-3, 0.4, -2)
	player.velocity = Vector3.ZERO
	for i in 90: await get_tree().physics_frame
	var ground: Node = arena.get_node("GroundSurfaceState")
	ground.set_process(false)
	checks["surface_patch_accepted"] = ground.set_patch("test", Vector2(player.position.x, player.position.z), 5.0, 0.0, 0.8)
	await capture("dry_cracked")
	ground.set_patch("test", Vector2(player.position.x, player.position.z), 5.0, 1.0, 0.8)
	await capture("wet_cracked")
	ground.remove_patch("test")
	checks["surface_patch_removed"] = ground.patches.is_empty()
	checks["camera_height_preserved"] = is_equal_approx(arena.gameplay_camera.global_position.y, arena.approved_transform.origin.y)
	checks["bounds_min"] = str(arena.sector_runtime.collision.YARD_MIN)
	checks["bounds_max"] = str(arena.sector_runtime.collision.YARD_MAX)
	checks["perimeter"] = arena.sector_runtime.perimeter.stats
	FileAccess.open(out.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(checks, "  "))
	print("EXPANSION ", checks)
	var failures: Array[String] = []
	if not "original" in OS.get_cmdline_user_args():
		for side: String in ["-1", "1", "south"]:
			if int(checks.get(side + "_open_corridors", 0)) == 0:
				failures.append(side + " unreachable")
			for suffix: String in ["_floor_contact", "_in_frame", "_paved"]:
				if not bool(checks.get(side + suffix, false)):
					failures.append(side + suffix)
		if not checks["camera_height_preserved"]:
			failures.append("camera height changed")
	print("EXPANSION CHECKS ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
