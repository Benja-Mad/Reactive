## Real-engine frames of arc, for art review: a puddle is charged and a metal pack set around it,
## then discharges through the pack on the next conduction beat. Saves a strip of frames from the
## charge to the end of the bolt (LOOK_DIR, default user://arc_look).
extends Node
const Enemy = preload("res://scripts/survivor/enemy.gd")
var scene: Node
var run: Node
var player: Character
var output: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "user://arc_look"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("start")
func frames(count: int) -> void:
	for i: int in count: await get_tree().process_frame
func start() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size = Vector2i(1600, 900)
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Prueba", 0, Statics.Role.SUPPORT)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(100)
	player = run.local_player()
	player.global_position = Vector3(-3, 1.15, 2)
	run.builds[1]["routines"] = []
	run.hud.hide()
	await frames(30)
	var me: Vector3 = player.global_position - Vector3(0, 1.1, 0)
	var puddle: Dictionary = run.world.execute(1, "create", 0, {"point": Vector3(me.x + 3.5, me.y + 0.02, me.z - 3.5)})
	for id: int in run.world.records: run.world.records[id]["ttl"] = 1000.0
	# Charged first, so the live water reads on its own before anything closes the circuit.
	await frames(10)
	run.world.execute(1, "arc", puddle.get("id", 0))
	for i: int in int(OS.get_environment("LOOK_STRIP")) if OS.has_environment("LOOK_STRIP") else 40:
		# Then a metal pack walks in: one on the water, the rest a jump apart so the charge runs on.
		if i == 14:
			var id: int = 700
			for offset: Vector3 in [Vector3(3.8, 0, -3.1), Vector3(6.2, 0, -2.4), Vector3(5.6, 0, -5.4), Vector3(8.2, 0, -4.2)]:
				id += 1
				run.spawn_machine(id, me + offset, Enemy.RUNNER, 1.0)
				run.machines.get_node("Machine%d" % id).health = 100000.0
				run.machines.get_node("Machine%d" % id).speed = 0.0
		await frames(2)
		await shot("arc_%02d" % i)
	get_tree().quit()
func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(title + ".png"))
	print("ARC LOOK ", title)
