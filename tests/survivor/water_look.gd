## Frames of one routine from source to residue, for judging by eye: the yard's burst mains, the
## draught running from a puddle to where the routine acts, each step on its beat with the
## operator's beam, the throw, and the puddle it leaves. Run windowed:
## godot --path . tests/survivor/water_look.tscn
extends Node
var scene: Node
var run: Node
var out: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/water_20261021"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("capture")
func frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame
## The frame as it is now, without letting the simulation settle first.
func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("WATER SHOT ", file)
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
	player.global_position = Vector3(-4, 1.15, -2)
	run.open_sources()
	run.builds[1] = preload("res://scripts/survivor/build.gd").fresh()
	run.builds[1]["routines"] = [{"when": "cerca", "steps": ["raise", "cold", "push"], "then": "fragmentos", "on": "broken"}, {"when": "", "steps": [], "then": "", "on": "contact"}]
	run.clocks[1] = {"shot": 1000.0, "heal": 3.0, "trail": player.global_position, "made": {}, "r0": 1000.0, "r1": 1000.0}
	for i: int in 3:
		run.spawn_machine(300 + i, Vector3(3.5 + i * 0.9, 0.05, -3.5 + i * 1.4), 0, 3.0)
	await frames(90)
	for enemy: Node in run.machines.get_children(): enemy.speed = 0.0
	await shot("01_yard_sources")
	var toward := Vector3.RIGHT
	run.spellwork.begin(1, 0, player.global_position + Vector3(3.1, -1.1, 0), toward)
	await frames(8)
	await shot("02_draught_runs")
	await frames(22)
	await shot("03_raised")
	await frames(14)
	await shot("04_cold_beam")
	await frames(16)
	await shot("05_thrown")
	await frames(60)
	await shot("06_after_impact")
	await frames(560)
	await shot("07_residue_puddle")
	# «on wade»: a machine walks into the burst main's puddle and the routine freezes it there.
	run.builds[1]["routines"][0] = {"when": "charco", "steps": ["cold"], "then": "", "on": "contact"}
	var main: Dictionary = run.world.records.values().filter(func(record: Dictionary) -> bool: return record.get("source", false))[0]
	run.spawn_machine(320, main["position"] + Vector3(1.0, 0, 0.6), 0, 3.0)
	await frames(4)
	var wader: Node = run.machines.get_node("Machine320")
	wader.speed = 0.0
	wader.soak(Vector3.ZERO)
	run.clocks[1]["r0"] = 0.0
	run._automate(player, 1, 0.01)
	run.clocks[1]["r0"] = 1000.0
	await frames(34)
	await shot("08_wade_freeze")
	# Away from all water: the routine waits and its row carries the rose drop.
	player.global_position = Vector3(8, 1.15, 4)
	for record: Dictionary in run.world.records.values():
		if record["owner"] == run.world.YARD and not record.get("source", false): run.world.execute(1, "remove", record["id"], {"remote": true})
	run.builds[1]["routines"][0] = {"when": "cada", "steps": ["raise", "cold", "push"], "then": "fragmentos", "on": "broken"}
	run.clocks[1]["r0"] = 0.0
	await frames(20)
	await shot("09_dry_hud")
	get_tree().quit()
