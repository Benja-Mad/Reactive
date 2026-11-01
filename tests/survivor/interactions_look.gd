## Casos repetibles con cámara real: mismo montaje antes y después, sin rótulos explicativos.
extends "res://tests/survivor/capture.gd"
var player: Character
var serial: int = 1500
func capture() -> void:
	out = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/interactions_20261021/after"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().size = Vector2i(1600, 900)
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Brasa", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(50)
	player = run.local_player()
	player.global_position = Vector3(-4, 1.15, -2)
	run.set_physics_process(false)
	run.world.set_physics_process(false)
	run.world.residue = true
	run.hud.hide()
	await clean()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or "gravity" in args: await gravity()
	if args.is_empty() or "circuit" in args: await circuit()
	if args.is_empty() or "thermal" in args: await thermal()
	if args.is_empty() or "weapon" in args: await weapon()
	if args.is_empty() or "drop" in args: await drop()
	get_tree().quit()
func clean() -> void:
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id, {"remote": true})
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	await frames(3)
func matter(kind: String, at: Vector3) -> int:
	return int(run.world.execute(1, "create", 0, {"point": at, "material": kind}).get("id", 0))
func machine(at: Vector3, kind: int = 0) -> Node3D:
	serial += 1
	run.spawn_machine(serial, at, kind, 50.0)
	var enemy: Node3D = run.machines.get_node("Machine%d" % serial)
	enemy.speed = 0.0
	return enemy
func simulate(count: int) -> void:
	for i: int in count:
		run.spellwork.tick(1.0 / 60.0)
		run.world._physics_process(1.0 / 60.0)
		await frames(1)
func gravity() -> void:
	for kind: String in ["water", "fire", "current", "scrap"]:
		await clean()
		var anchor: int = matter("scrap", Vector3(0, 0.07, -5))
		run.world.execute(1, "raise", anchor)
		var loose: int = matter(kind, Vector3(-3.5, 0.07, -3.8))
		machine(Vector3(-3.5, 0.05, -5.8), 1)
		run.world.execute(1, "well", anchor)
		await shot("well_" + kind + "_00")
		await simulate(45)
		await shot("well_" + kind + "_075")
		await simulate(75)
		await shot("well_" + kind + "_200")
		if run.world.records.has(loose): print("WELL POSITION ", kind, " ", run.world.records[loose]["position"])
func circuit() -> void:
	await clean()
	var origin: int = matter("current", Vector3(-7, 0.07, -4))
	for x: float in [-3.8, -0.6, 2.6]: matter("scrap", Vector3(x, 0.07, -4))
	machine(Vector3(5.7, 0.05, -4), 1)
	await shot("circuit_00")
	await simulate(1)
	await shot("circuit_01")
	await simulate(32)
	await shot("circuit_055")
	print("CIRCUIT SOURCE ", run.world.records.get(origin, {}).get("charge", 0))
func thermal() -> void:
	await clean()
	run.world.add_source(Vector3(2, 0.07, -4), "fire")
	var metal: int = matter("scrap", Vector3(1, 0.07, -4))
	run.world.execute(1, "wall", metal, {"vector": Vector3.FORWARD * 4})
	await shot("thermal_00")
	await simulate(40)
	await shot("thermal_hot")
	matter("water", Vector3(0, 0.07, -4))
	await simulate(30)
	await shot("thermal_quenched")
func weapon() -> void:
	await clean()
	var Build = preload("res://scripts/survivor/build.gd")
	run.builds[1] = Build.fresh()
	run.builds[1]["attack"]["steps"] = ["push", "wall", "arc"]
	run.reserves[1] = {"water": 0, "fire": 0, "current": 0, "scrap": 0}
	machine(player.global_position + Vector3(3.4, -1.1, -0.8), 1)
	machine(player.global_position + Vector3(4.4, -1.1, 0.4), 1)
	await frames(3)
	run._flame(player, 1, run.clocks[1], run.builds[1]["tools"])
	await shot("weapon_impact")
	await simulate(30)
	await shot("weapon_residue")
	run.hud.show()
	run.set_phase("paused")
	for i: int in 12: await get_tree().process_frame
	run.hud._process(0.0)
	run.hud._editor.focus = Build.ATTACK
	await shot("weapon_editor")
	run.set_phase("running")

## Drop after raise on each weapon: the ball going up, its shadow and reach on the way down, the
## landing, and the workshop's preview of it.
func drop() -> void:
	var Build = preload("res://scripts/survivor/build.gd")
	for base: String in ["fire", "water"]:
		await clean()
		run.builds[1] = Build.fresh()
		run.builds[1]["attack"]["steps"] = ["raise", "drop"]
		machine(player.global_position + Vector3(3.6, -1.1, -1.2), 1)
		machine(player.global_position + Vector3(4.4, -1.1, 0.2), 0)
		await frames(3)
		run.elapsed += 10.0
		run.clocks[1]["fall"] = -1.0
		if base == "fire": run._flame(player, 1, run.clocks[1], run.builds[1]["tools"])
		else: run._animas(player, 1, run.clocks[1], run.builds[1]["tools"])
		await frames(10)
		await shot("drop_%s_up" % base)
		await frames(18)
		await shot("drop_%s_down" % base)
		await frames(14)
		run._land_falls(1.0)
		await frames(3)
		await shot("drop_%s_landed" % base)
	run.hud.show()
	run.set_phase("paused")
	for i: int in 12: await get_tree().process_frame
	run.hud._process(0.0)
	run.hud._editor.focus = Build.ATTACK
	run.hud._editor._time = 1.5
	await shot("drop_editor")
	run.set_phase("running")
	run.hud.hide()
