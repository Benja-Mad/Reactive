## Frames of the yard's other stores and what their matter does by itself, for judging by eye:
## the drum, the transformer and the junk heap; fire drawn off a drum and thrown into a pack that
## then burns through; current jumping on its own to the nearest machine; a scrap barricade going
## red where a fire touches it. Run windowed:
## godot --path . tests/survivor/substances_look.tscn
extends Node
var scene: Node
var run: Node
var out: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/substances_20261021"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("capture")
func frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame
func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("SUBSTANCE SHOT ", file)
func hold(machine: Node) -> void:
	machine.speed = 0.0
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().size = Vector2i(1600, 900)
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Operador", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(60)
	var player: Character = scene.get_node("Players").get_child(0)
	run.open_sources()
	run.world.residue = true
	run.builds[1] = preload("res://scripts/survivor/build.gd").fresh()
	run.clocks[1] = {"shot": 1000.0, "heal": 3.0, "trail": player.global_position, "made": {}, "r0": 1000.0, "r1": 1000.0}
	# The drum.
	player.global_position = Vector3(9, 1.15, 6.5)
	await frames(40)
	await shot("01_drum")
	# Fire drawn off it and thrown at a pack, which then burns through.
	run.builds[1]["routines"] = [{"when": "cerca", "steps": ["raise", "push"], "then": "", "on": "contact", "from": "fire"}, {"when": "", "steps": [], "then": "", "on": "contact"}]
	for i: int in 5:
		run.spawn_machine(400 + i, Vector3(14.5 + (i % 3) * 1.1, 0.05, 6.5 + (i / 3) * 1.2), 0, 6.0)
	await frames(6)
	for enemy: Node in run.machines.get_children(): hold(enemy)
	run.spellwork.begin(1, 0, player.global_position + Vector3(2.5, -1.1, 0), Vector3.RIGHT)
	await frames(6)
	await shot("02_fire_drawn")
	await frames(30)
	await shot("03_fire_ball")
	await frames(40)
	await shot("04_pack_catches")
	await frames(70)
	await shot("05_fire_spreads")
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	# The transformer jumping on its own to a machine that strays close.
	player.global_position = Vector3(-2, 1.15, 8.5)
	run.spawn_machine(420, Vector3(1.0, 0.05, 11.0), 0, 6.0)
	await frames(4)
	hold(run.machines.get_node("Machine420"))
	await frames(40)
	await shot("06_transformer")
	await frames(12)
	await shot("06b_transformer")
	# A routine of current let loose: it seeks the nearest body by itself.
	run.builds[1]["routines"][0] = {"when": "cerca", "steps": ["raise"], "then": "", "on": "contact", "from": "current"}
	run.spawn_machine(421, Vector3(-6.0, 0.05, 8.0), 1, 6.0)
	await frames(4)
	hold(run.machines.get_node("Machine421"))
	run.spellwork.begin(1, 0, player.global_position + Vector3(-2.2, -1.1, -0.5), Vector3.LEFT)
	await frames(20)
	await shot("07_current_drawn")
	await frames(30)
	await shot("08_current_seeks")
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	# The heap, a scrap barricade, and fire put against it.
	player.global_position = Vector3(2, 1.15, -3.5)
	run.builds[1]["routines"][0] = {"when": "cerca", "steps": ["wall"], "then": "", "on": "contact", "from": "scrap"}
	print("SUBSTANCE BEGIN wall ", run.spellwork.begin(1, 0, Vector3(6, 0.07, -8.5), Vector3.RIGHT))
	await frames(60)
	await shot("09_heap_and_barricade")
	run.builds[1]["routines"][0] = {"when": "cerca", "steps": [], "then": "", "on": "contact", "from": "fire"}
	print("SUBSTANCE BEGIN fire ", run.spellwork.begin(1, 0, Vector3(6.6, 0.07, -7.2), Vector3.RIGHT))
	await frames(150)
	await shot("10_barricade_red_hot")
	for record: Dictionary in run.world.records.values():
		if record["owner"] == 1: print("SUBSTANCE RECORD ", record["material"], " ", record["shape"], " temp ", record.get("temp", 0), " at ", record["position"])
	get_tree().quit()
