## Renders the front-end backdrop from the real yard: no players, no HUD, a few constructs so
## the menu shows what the game is about rather than an empty set.
extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = []
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	for i in 40: await get_tree().physics_frame
	scene.get_node("MatterConsole").hide()
	for sentry: Node in get_tree().get_nodes_in_group("yard_sentries"): sentry.set_physics_process(false)
	var world: Node = scene.get_node("WorldMatter")
	var stand_in := Node3D.new()
	stand_in.add_to_group("coop_players")
	scene.add_child(stand_in)
	stand_in.global_position = Vector3(0, 0, -4)
	var wall: int = world.execute(1, "create", 0, {"point": Vector3(-1.5, 0.07, -6.0)})["id"]
	world.execute(1, "raise", wall, {"vector": Vector3(1, 0, 0.25)})
	world.execute(1, "freeze", wall)
	world.execute(1, "coat", wall)
	world.execute(1, "react", wall, {"trigger": "broken", "action": "push", "vector": Vector3.FORWARD * 14})
	var mine: int = world.execute(1, "create", 0, {"point": Vector3(5.0, 0.07, -3.0)})["id"]
	world.execute(1, "coat", mine)
	world.execute(1, "react", mine, {"trigger": "pulsed", "action": "command", "vector": Vector3.ZERO})
	world.execute(1, "link", wall, {"to": mine})
	var veil: int = world.execute(1, "create", 0, {"point": Vector3(-7.0, 0.07, -2.0)})["id"]
	world.execute(1, "heat", veil)
	for i in 150: await get_tree().physics_frame
	# Labels are instruments, not scenery: the backdrop shows the yard without them.
	for label: Node in scene.find_children("*", "Label3D", true, false): label.visible = false
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://ui/art/sector08_backdrop.png")
	print("BACKDROP SAVED")
	get_tree().quit()
