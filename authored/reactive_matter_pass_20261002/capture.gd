## Captures the matter vocabulary, the sentry warning and the console in the real match scene.
## Usage: Godot --path . authored/reactive_matter_pass_20261002/capture.tscn -- <out dir> [shot...]
extends Node

var scene: Node
var world: Node
var player: Character
var out: String

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func shot(file: String) -> void:
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("SHOT ", file)

func _ready() -> void: call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "user://matter_pass"
	var wanted: Array = Array(args.slice(1))
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(1, "Operador", 0, Statics.Role.DAMAGE)]
	if "operators" in Array(args.slice(1)):
		Game.instance.players.append(Statics.PlayerData.new(2, "Sereno", 1, Statics.Role.SUPPORT))
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	world = scene.get_node("WorldMatter")
	await frames(60)
	player = scene.get_node("Players").get_child(0)
	player.programming_block.code_block.release_focus()
	var sentries: Array = get_tree().get_nodes_in_group("yard_sentries")
	for sentry: Node in sentries: sentry.set_physics_process(false)
	var console: Node = scene.get_node("MatterConsole")
	player.global_position = Vector3(-3, 0.1, -1)
	await frames(90)
	if wanted.is_empty() or "matter" in wanted:
		var patch: int = world.execute(1, "create", 0, {"point": Vector3(-7.5, 0.07, -4.5)})["id"]
		var wall: int = world.execute(1, "create", 0, {"point": Vector3(-2.5, 0.07, -5.5)})["id"]
		world.execute(1, "raise", wall, {"vector": Vector3.RIGHT})
		var ice: int = world.execute(1, "create", 0, {"point": Vector3(2.5, 0.07, -5.5)})["id"]
		world.execute(1, "raise", ice, {"vector": Vector3.RIGHT})
		world.execute(1, "freeze", ice)
		world.execute(1, "coat", ice)
		world.execute(1, "react", ice, {"trigger": "broken", "action": "push", "vector": Vector3.FORWARD * 14})
		world.execute(1, "link", wall, {"to": ice})
		var steam: int = world.execute(1, "create", 0, {"point": Vector3(6.0, 0.07, -7.0)})["id"]
		world.execute(1, "heat", steam)
		var cracked: int = world.execute(1, "create", 0, {"point": Vector3(-6.0, 0.07, -13.0)})["id"]
		world.execute(1, "raise", cracked, {"vector": Vector3(1, 0, -0.3)})
		world.execute(1, "freeze", cracked)
		world._damage(cracked, 13.0)
		await frames(120)
		await shot("matter_overview")
		console.selected = ice
		await frames(20)
		await shot("matter_selected")
		world.execute(1, "impact", ice)
		await frames(4)
		await shot("matter_shatter")
		await frames(80)
		for id: int in world.records.keys(): world.execute(1, "remove", id)
		await frames(10)
	if wanted.is_empty() or "sentry" in wanted:
		var gun: Node3D = sentries[0]
		gun.global_position = Vector3(-3, 0.05, -11)
		gun.set_physics_process(true)
		gun.cycle = 2.45
		await frames(4)
		await frames(14)
		await shot("sentry_hunting")
		await frames(26)
		await shot("sentry_locked")
		for i in 40:
			await get_tree().physics_frame
			if gun.cycle < 0.1: break
		await shot("sentry_discharge")
		await frames(5)
		await shot("sentry_impact")
		await frames(20)
		gun.set_physics_process(false)
		var cover: Dictionary = world.get_node("Programs").start(1, {"steps": ["raise", "freeze"], "trigger": "broken", "action": "push"}, Vector3(-3, 0.07, -5), Vector3.FORWARD)
		await frames(50)
		gun.cycle = 2.45
		gun.set_physics_process(true)
		await frames(30)
		await shot("sentry_on_cover")
		for i in 60:
			await get_tree().physics_frame
			if gun.cycle < 0.1: break
		await shot("sentry_cover_hit")
		await frames(6)
		await shot("sentry_cover_after")
		player.global_position = Vector3(1.5, 0.1, -1)
		gun.cycle = 2.45
		await frames(40)
		player.global_position = Vector3(-1.5, 0.1, 2.5)
		for i in 60:
			await get_tree().physics_frame
			if gun.cycle < 0.1: break
		await frames(2)
		await shot("sentry_miss")
		gun.set_physics_process(false)
		gun.telegraph.cancel()
		for id: int in world.records.keys(): world.execute(1, "remove", id)
		await frames(10)
	if "operators" in wanted:
		var others: Array = scene.get_node("Players").get_children()
		player.global_position = Vector3(-2.5, 0.1, -3.0)
		if others.size() > 1: others[1].global_position = Vector3(0.5, 0.1, -2.0)
		console.hide()
		await frames(30)
		await shot("operators_idle")
		player.input_synchronizer.move_input = Vector2(1, 0)
		await frames(20)
		await shot("operators_walk")
		player.input_synchronizer.move_input = Vector2.ZERO
		console.show()
	if wanted.is_empty() or "console" in wanted:
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.pressed = true
		console._unhandled_input(key)
		await frames(10)
		await shot("console_open")
		console._unhandled_input(key)
		console.pointer_override = Vector2(1060, 600)
		await frames(2)
		key.keycode = KEY_Q
		console._unhandled_input(key)
		await frames(10)
		await shot("console_aiming")
	get_tree().quit()
