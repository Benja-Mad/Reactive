extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = root.get_node("Game")
	game.multiplayer_test = false
	var roster: Array[Statics.PlayerData] = [Statics.PlayerData.new(1, "Environment check", 0, Statics.Role.DAMAGE)]
	game.players = roster
	for cycle: int in 2:
		var scene = load("res://scenes/main_scene.tscn").instantiate()
		root.add_child(scene)
		for frame: int in 120: await process_frame
		var arena = scene.get_node("Arena")
		var environment = arena.get_node("DistrictEnvironment")
		var run = scene.get_node("SurvivorRun")
		assert(environment.enabled)
		assert(arena.find_children("DistrictEnvironment", "", true, false).size() == 1)
		assert(environment.has_node("DistrictServiceArchitecture"))
		assert(environment.has_node("CoolingLandmark"))
		assert(environment.has_node("CyberpunkDepth"))
		assert(environment.collision_changes.size() >= 59)
		assert(environment.replacement_collisions.size() >= 28)
		for item: Dictionary in environment.collision_changes: assert(item["node"].disabled)
		for shape: CollisionShape3D in environment.replacement_collisions: assert(not shape.disabled)
		assert(run.local_player() != null)
		assert(run.elapsed > 0.0)
		assert(is_equal_approx(arena.framing_distance, 50.0))
		assert(is_equal_approx(arena.gameplay_camera.fov, 38.0))
		var sightline = run.get_node("Sightline")
		assert(sightline._initial_collection_complete)
		var registered: Dictionary = {}
		for entry: Dictionary in sightline._candidates:
			assert(not registered.has(entry["node"]))
			registered[entry["node"]] = true
		if cycle == 0 and "capture" in OS.get_cmdline_user_args():
			root.size = Vector2i(1600, 900)
			run.local_player().global_position = Vector3(-7, 1.15, -9)
			for frame: int in 90: await process_frame
			paused = true
			RenderingServer.force_draw(false)
			var picture := root.get_texture().get_image()
			assert(picture.save_png("res://authored/stylized_yard_20261016/main_scene.png") == OK)
			paused = false
		print("MAIN ENVIRONMENT PASS cycle ", cycle + 1, ": art, repaired collisions, normal camera, player spawn, live gameplay, unique sightline meshes")
		scene.queue_free()
		for frame: int in 4: await process_frame
	quit()
