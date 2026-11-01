## Frames of the third pass, for judging by eye: the workshop with the attack row on top and its
## preview; Brasa's flame programmed with push and coat on a pack; a scrap well dragging a pack in
## and pressing it; the reserve over the program, and a draught siphoned off a drum as she walks
## past. Run windowed:
## godot --path . tests/survivor/attack_look.tscn
extends "res://tests/survivor/capture.gd"
const Build = preload("res://scripts/survivor/build.gd")
func hold(machine: Node) -> void:
	machine.speed = 0.0
func capture() -> void:
	out = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/attack_20261021"
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
	# The workshop: the attack on top, the routines under it.
	run.builds[1]["attack"]["steps"] = ["arc", "push", "coat"]
	run.builds[1]["routines"][1] = {"when": "grupo", "steps": ["raise", "well"], "then": "", "on": "contact", "from": "scrap"}
	run.builds[1]["box"] = ["cold", "wall", "drop"]
	run.set_phase("paused")
	await frames(10)
	run.hud._editor.focus = Build.ATTACK
	for moment: float in [1.6, 2.9]:
		run.hud._editor._time = moment
		await shot("01_workshop_attack_%d" % int(moment * 10))
	run.hud._editor.focus = 1
	run.hud._editor._time = 2.4
	await shot("02_workshop_scrap_well")
	run.set_phase("running")
	await frames(10)
	# Brasa's flame with push and coat on a pack walking in.
	run.builds[1]["routines"] = [Build.empty_routine(), Build.empty_routine()]
	run.builds[1]["attack"]["steps"] = ["push", "coat"]
	player.global_position = Vector3(-3, 1.15, -2)
	for i: int in 5:
		run.spawn_machine(500 + i, Vector3(1.5 + (i % 3) * 1.2, 0.05, -2.5 + (i / 3) * 1.6), i % 2, 8.0)
	await frames(30)
	await shot("03_flame_push_coat")
	await frames(40)
	await shot("04_flame_nanites")
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	await frames(4)
	# A scrap well dragging a pack in and pressing it.
	run.builds[1]["attack"]["steps"] = []
	run.clocks[1]["shot"] = 1000.0
	var center := Vector3(4.0, 0.07, -9.0)
	for i: int in 6:
		var angle: float = i * TAU / 6.0
		run.spawn_machine(520 + i, center + Vector3(cos(angle), 0, sin(angle)) * 4.5, [0, 1, 2][i % 3], 12.0)
	await frames(4)
	for enemy: Node in run.machines.get_children(): hold(enemy)
	var well: int = run.world.execute(1, "create", 0, {"point": center, "material": "scrap"})["id"]
	run.world.execute(1, "raise", well)
	run.world.execute(1, "well", well)
	run.world.records[well]["ttl"] = 30.0
	player.global_position = Vector3(-2, 1.15, -6)
	await frames(30)
	await shot("05_scrap_well_drags")
	await frames(60)
	await shot("06_scrap_well_presses")
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	run.world.execute(1, "remove", well)
	# The reserve: walking past a drum siphons a draught of fire into the pocket.
	run.reserves[1] = {"water": 1, "fire": 0, "current": 0, "scrap": 2}
	run.clocks[1]["own"] = 1000.0
	run.clocks[1]["siphon"] = 0.05
	player.global_position = Vector3(10.5, 1.15, 5.0)
	await frames(4)
	await shot("07_siphon_drum")
	await frames(40)
	await shot("08_reserve_filled")
	print("ATTACK LOOK reserve ", run.reserves[1], " crushed ", run.spellwork.rules.stats.get("crushed", 0))
	get_tree().quit()
