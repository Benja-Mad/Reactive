## Exercises the actual menu/lobby/HUD callbacks, including exiting a paused run.
extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func frames(count: int) -> void:
	for frame: int in count: await process_frame

func check() -> void:
	var game = root.get_node("Game")
	game.multiplayer_test = false
	assert(change_scene_to_file("res://ui/main_menu.tscn") == OK)
	await scene_changed
	var menu_msaa: int = root.msaa_3d
	for cycle: int in 3:
		assert(current_scene.scene_file_path == "res://ui/main_menu.tscn")
		assert(not paused and not root.disable_3d)
		current_scene.solo.pressed.emit()
		await scene_changed
		assert(current_scene.scene_file_path == "res://lobby/waiting_screen.tscn")
		assert(game.players.size() == 1)
		var role: int = Statics.Role.SUPPORT if cycle == 1 else Statics.Role.DAMAGE
		current_scene._update_role(role)
		assert(not current_scene._ready_button.disabled)
		current_scene._ready_button.pressed.emit()
		await scene_changed
		await frames(120)
		var scene := current_scene
		var run = scene.get_node("SurvivorRun")
		assert(run.phase == "running" and run.elapsed > 0.0 and run.elapsed < 5.0)
		assert(run.local_player() != null)
		assert(game.players[0].role == role)
		assert(get_nodes_in_group("coop_players").size() == 1)
		assert(get_nodes_in_group("survivor_run").size() == 1)
		assert(get_nodes_in_group("pixel_view").size() == 1)
		assert(scene.get_node("Arena/DistrictEnvironment").enabled)
		assert(root.disable_3d)
		if cycle != 1:
			run.toggle_pause()
			assert(paused and run.phase == "paused")
		var old_scene: WeakRef = weakref(scene)
		# Same callback as the workshop/end-of-run Menu button.
		run.hud._to_menu()
		await scene_changed
		await frames(10)
		assert(old_scene.get_ref() == null)
		assert(current_scene.scene_file_path == "res://ui/main_menu.tscn")
		assert(not paused and not root.disable_3d)
		assert(root.msaa_3d == menu_msaa)
		assert(game.players.is_empty() and not game.solo)
		assert(root.get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer)
		assert(get_nodes_in_group("coop_players").is_empty())
		assert(get_nodes_in_group("survivor_run").is_empty())
		assert(get_nodes_in_group("pixel_view").is_empty())
		print("MENU ROUNDTRIP PASS ", cycle + 1, ": menu, operator selection, live game, exit, clean menu")
	quit()
