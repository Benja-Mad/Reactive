## Run two instances with --script res://tests/coop_impact.gd -- host (or client).
## ENet uses loopback only. Both views run the normal match scene and cameras.
extends SceneTree

func _initialize() -> void:
	var session := MatchCheck.new()
	session.name = "MatchCheck"
	root.add_child.call_deferred(session)


class MatchCheck extends Node:
	const PORT := 45429
	var started_ms := Time.get_ticks_msec()
	var guest_id := 0
	var diver: CharacterBody3D
	var crab: CharacterBody3D
	var crashes := 0
	var hit_bursts := 0
	var in_view := false
	var remote_report: Dictionary
	var failures: Array[String] = []

	func _ready() -> void:
		get_window().size = Vector2i(1152, 648)
		get_node("/root/Game").multiplayer_test = false
		get_node("/root/Lobby").return_to_lobby_on_player_disconnect = false
		get_tree().node_added.connect(_watch)
		var peer := ENetMultiplayerPeer.new()
		var err: Error
		if OS.get_cmdline_user_args().has("host"):
			peer.set_bind_ip("127.0.0.1")
			err = peer.create_server(PORT, 1)
		else:
			multiplayer.connected_to_server.connect(func(): begin_session.rpc_id(1))
			err = peer.create_client("127.0.0.1", PORT)
		if err != OK:
			push_error(error_string(err))
			get_tree().quit(1)
			return
		multiplayer.multiplayer_peer = peer
		print("ENET ", "HOST" if multiplayer.is_server() else "CLIENT")

	func _process(_delta: float) -> void:
		if Time.get_ticks_msec() - started_ms > 45000:
			push_error("Two-peer combat check timed out")
			get_tree().quit(1)

	func _watch(node: Node) -> void:
		var script := node.get_script() as Script
		if script and script.resource_path == "res://scenes/enemies/enemy.gd":
			# A lethal fixture would hide duplicate damage behind the zero-HP clamp.
			node.maxHealth = 130
			diver = node
		elif script and script.resource_path == "res://scenes/enemies/lunger.gd":
			crab = node
		if node is Sprite3D and node.texture:
			var filename: String = node.texture.resource_path.get_file()
			if filename == "shell_clang.png":
				crashes += 1
				check_view.call_deferred(node)
			elif filename == "bursts.png" and node.frame_coords.y == 2:
				hit_bursts += 1

	func check_view(sparks: Sprite3D) -> void:
		var cam := get_viewport().get_camera_3d()
		in_view = cam.get_parent().get_multiplayer_authority() == multiplayer.get_unique_id() and sparks.is_visible_in_tree() and cam.is_position_in_frustum(sparks.global_position) and is_equal_approx(cam.size, 17.5)
		print("IMPACT frame=", Engine.get_process_frames(), " peer=", multiplayer.get_unique_id(), " in_view=", in_view, " camera=", cam.size)

	@rpc("any_peer", "reliable")
	func begin_session() -> void:
		if not multiplayer.is_server():
			return
		guest_id = multiplayer.get_remote_sender_id()
		load_match.rpc_id(guest_id, guest_id)

	@rpc("authority", "reliable")
	func load_match(guest: int) -> void:
		guest_id = guest
		await open_match()
		client_ready.rpc_id(1)

	func open_match() -> void:
		var game = get_node("/root/Game")
		game.add_player(Statics.PlayerData.new(1, "Rivet", 0, Statics.Role.DAMAGE))
		game.add_player(Statics.PlayerData.new(guest_id, "Brine", 1, Statics.Role.SUPPORT))
		get_tree().change_scene_to_packed(game.main_scene)
		await get_tree().scene_changed
		# Only the two enemies arranged for this encounter should enter the test.
		get_tree().current_scene.enemy_spawn_interval = 120.0

	func character(peer_id: int) -> CharacterBody3D:
		return get_tree().current_scene.get_node("Players/" + str(peer_id))

	func ticks(count: int) -> void:
		for i in count:
			await get_tree().physics_frame

	@rpc("any_peer", "reliable")
	func client_ready() -> void:
		if multiplayer.is_server() and multiplayer.get_remote_sender_id() == guest_id:
			await open_match()
			await ticks(65)
			await play_encounter()

	@rpc("authority", "call_local", "reliable")
	func place_players(host: Vector3, guest: Vector3) -> void:
		character(1).position = host
		character(guest_id).position = guest

	@rpc("authority", "reliable")
	func cast_ice() -> void:
		Input.action_press("move_right")
		await ticks(4)
		Input.action_release("move_right")
		character(guest_id).use_ability(Statics.Ability.ICE_SHARD)

	func snapshot() -> Dictionary:
		var rescued = character(guest_id)
		var actor = character(1)
		var context = load("res://scripts/blocks/program_context.gd").new(actor)
		var palette = actor.programming_block.code_list.get_node("Scroll/VBoxContainer")
		return {"diver": diver.currentHealth, "crab": crab.currentHealth, "crashes": crashes,
			"stalled_sensor": palette.get_node("Stalled").evaluate(context),
			"rescue_sensor": palette.get_node("Rescue").evaluate(context),
			"hits": hit_bursts, "visible": in_view, "chilled": diver.slow_time > 0.0, "ally": rescued.currentHealth,
			"restarting": "RESTART" in rescued.label_3d.text, "down": rescued.is_dead}

	@rpc("authority", "reliable")
	func request_snapshot() -> void:
		submit.rpc_id(1, snapshot())

	@rpc("any_peer", "reliable")
	func submit(report: Dictionary) -> void:
		if multiplayer.is_server() and multiplayer.get_remote_sender_id() == guest_id:
			remote_report = report

	func expect_both(stage: String, expected: Dictionary) -> void:
		remote_report.clear()
		request_snapshot.rpc_id(guest_id)
		for i in 180:
			if not remote_report.is_empty():
				break
			await get_tree().physics_frame
		var host := snapshot()
		print(stage, " frame=", Engine.get_process_frames(), " host=", host, " client=", remote_report)
		for key in expected:
			if host.get(key) != expected[key] or remote_report.get(key) != expected[key]:
				failures.append(stage + "/" + key)

	func play_encounter() -> void:
		place_players.rpc(Vector3(-1.7, 1, -3), Vector3(-3.6, 1, 1.1))
		await ticks(75)
		var spawner: MultiplayerSpawner = get_tree().current_scene.get_node("EnemySpawner")
		var bait := character(1)
		spawner.spawn({"kind": "lunger"})
		crab.position = bait.position - Vector3(2.85, .18, 0)
		spawner.spawn({"kind": "enemy"})
		diver.position = bait.position - Vector3(.84, 0, .06)
		if diver.currentHealth != 130:
			failures.append("Initial diver HP")
		await ticks(8)
		Input.action_press("move_down")
		await ticks(34)
		Input.action_release("move_down")
		await ticks(43)
		await expect_both("RAM", {"diver":90, "hits":1, "crashes":1, "stalled_sensor":true, "visible":true})
		# Isolate the following ability and rescue checks from a second attack.
		diver.set_physics_process(false)
		crab.set_physics_process(false)
		diver.position = Vector3(-.2, 1, -2)
		crab.position = Vector3(1.8, .8, -2)
		place_players.rpc(Vector3(-2.6, 1, -2), Vector3(-4.4, 1, -2))
		await ticks(35)
		var editor = bait.programming_block
		var palette = editor.code_list.get_node("Scroll/VBoxContainer")
		editor.code_list_btn.pressed.emit()
		var sequence = editor.program_container
		sequence._drop_data(Vector2.ZERO, palette.get_node("IfBlock"))
		var branch = sequence.get_child(0)
		branch.condition_container._drop_data(Vector2.ZERO, palette.get_node("HpAboveBlock"))
		branch.condition_container._drop_data(Vector2(0, 999), palette.get_node("Chilled"))
		branch.then_container._drop_data(Vector2.ZERO, palette.get_node("FlameWaveBlock"))
		branch.else_container._drop_data(Vector2.ZERO, palette.get_node("EndCycle"))
		# Verify that returning from a branch skips later top-level instructions.
		sequence._drop_data(Vector2(0, 999), palette.get_node("FireBlock"))
		editor.cast_timer.timeout.emit()
		if not editor.last_trace.ends_with("else · fin de ciclo"):
			failures.append("Cold guard / early return")
		sequence.get_child(-1).queue_free()
		editor.cast_timer.start()
		cast_ice.rpc_id(guest_id)
		for i in 90:
			if diver.slow_time > 0: break
			await get_tree().physics_frame
		for i in 150:
			if diver.currentHealth == 40: break
			await get_tree().physics_frame
		if not "flame_wave()" in editor.last_trace:
			failures.append("Wave did not fire at a slowed enemy")
		editor.cast_timer.stop()
		print("PROGRAM frame=", Engine.get_process_frames(), " ", editor.last_trace)
		await ticks(12)
		editor.code_list_btn.pressed.emit()
		# Ice deals 10 and the wave deals 40. The crab is outside the wave.
		await expect_both("WAVE ON SLOWED ENEMY", {"diver":40, "crab":30, "chilled":true})
		character(guest_id).take_damage(200)
		await ticks(38)
		await expect_both("RESCUE START", {"rescue_sensor":true, "down":true, "restarting":true})
		Input.action_press("move_right")
		await ticks(32)
		Input.action_release("move_right")
		await ticks(16)
		await expect_both("RESCUE CANCEL", {"rescue_sensor":false, "down":true, "restarting":false, "ally":0})
		Input.action_press("move_left")
		await ticks(32)
		Input.action_release("move_left")
		await ticks(152)
		await expect_both("RESCUE COMPLETE", {"rescue_sensor":false, "down":false, "restarting":false, "ally":35})
		print("RESULT ", "PASS" if failures.is_empty() else str(failures))
		finish.rpc_id(guest_id, failures.is_empty())
		await ticks(10)
		get_tree().quit(0 if failures.is_empty() else 1)

	@rpc("authority", "reliable")
	func finish(success: bool) -> void:
		print("CLIENT RESULT ", success)
		get_tree().quit(0 if success else 1)
