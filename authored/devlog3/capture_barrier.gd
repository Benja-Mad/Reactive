extends Node

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(1, "Player", 0, Statics.Role.DAMAGE)]
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(60)
	var player: Character = scene.get_node("Players").get_child(0)
	player.programming_block.code_block.release_focus()
	player.global_position = Vector3(-3, 0.1, -2)
	var sentries: Array = get_tree().get_nodes_in_group("yard_sentries")
	for sentry: Node in sentries:
		sentry.set_physics_process(false)
	sentries[0].global_position = Vector3(-3, 0.05, -12)
	# Use the actual in-game routine and keep its prepared reaction intact.
	var world: Node = scene.get_node("WorldMatter")
	var result: Dictionary = world.get_node("Programs").start(1,
		{"steps": ["raise", "freeze", "coat"], "trigger": "broken", "action": "push"},
		Vector3(-3, 0.07, -6), Vector3.FORWARD)
	assert(result.get("ok", false))
	await frames(90)
	assert(world.records.has(result["id"]) and world.records[result["id"]].has("reaction"))
	# Hide the preparation interface for this capture, keeping gameplay visuals.
	scene.get_node("MatterConsole").hide()
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://authored/devlog3/prepared_barrier.png"
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("DEVLOG_CAPTURE ", ProjectSettings.globalize_path(path), " error=", error)
	get_tree().quit(error)
