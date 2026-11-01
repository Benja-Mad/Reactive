## Gravity in the yard, for judging by eye with the real camera: a well of each matter with a pack
## going round its ring, the moment one lets go, and a repulsor's wave and bubble. Run windowed:
## godot --path . tests/survivor/gravity_look.tscn
extends "res://tests/survivor/capture.gd"
const Build = preload("res://scripts/survivor/build.gd")
var player: Character
var serial: int = 1700

func clean() -> void:
	for id: int in run.world.records.keys():
		if not run.world.records[id].get("source", false): run.world.execute(1, "remove", id, {"remote": true})
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	await frames(3)

func pack(center: Vector3, count: int, reach: float) -> void:
	for i: int in count:
		serial += 1
		var angle: float = i * TAU / count + 0.4
		run.spawn_machine(serial, center + Vector3(cos(angle), 0, sin(angle)) * (reach + (i % 2) * 0.8), [0, 1, 0, 2, 3][i % 5], 30.0)

func capture() -> void:
	out = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/gravity_20261022"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().size = Vector2i(1600, 900)
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Brasa", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(60)
	player = run.local_player()
	run.open_sources()
	run.world.residue = true
	run.hud.hide()
	# Nobody fires: the pictures are of gravity alone.
	run.builds[1] = Build.fresh()
	run.clocks[1]["shot"] = 100000.0
	player.global_position = Vector3(-5, 1.15, -1)
	var center := Vector3(1.5, 0.07, -3.0)
	for material: String in ["water", "fire", "scrap"]:
		await clean()
		run.clocks[1]["shot"] = 100000.0
		pack(center, 6, 4.8)
		await frames(4)
		var heart: int = int(run.world.execute(1, "create", 0, {"point": center, "material": material}).get("id", 0))
		run.world.execute(1, "well", heart, {"time": 30.0})
		await frames(70)
		await shot("well_%s" % material)
	# The same scrap well letting go: the pack flies off along the ring.
	for id: int in run.world.records.keys():
		if Catalog_field(run.world.records[id]) == "well": run.world.records[id]["grav_left"] = 0.02
	await frames(5)
	await shot("well_release_0")
	await frames(14)
	await shot("well_release_1")
	# A repulsor: the front halfway out, then the bubble holding a pack off.
	await clean()
	run.clocks[1]["shot"] = 100000.0
	pack(center, 8, 2.2)
	await frames(10)
	var blast: int = int(run.world.execute(1, "create", 0, {"point": center, "material": "water"}).get("id", 0))
	run.world.execute(1, "repel", blast)
	await frames(10)
	await shot("repel_front")
	await frames(34)
	await shot("repel_bubble")
	# The workshop's preview of a fire whirl and of a wave, mid-turn and letting go.
	run.hud.show()
	run.builds[1]["routines"][0] = {"when": "grupo", "steps": ["raise", "well"], "then": "", "on": "contact", "from": "fire"}
	run.builds[1]["routines"][1] = {"when": "cerca", "steps": ["repel"], "then": "", "on": "contact", "from": "water"}
	run.set_phase("paused")
	for i: int in 12: await get_tree().process_frame
	run.hud._process(0.0)
	for moment: float in [2.6, 4.7]:
		run.hud._editor.focus = 0
		run.hud._editor._time = moment
		await shot("workshop_well_%d" % int(moment * 10))
	run.hud._editor.focus = 1
	run.hud._editor._time = 2.2
	await shot("workshop_repel")
	run.set_phase("running")
	print("GRAVITY LOOK ", run.spellwork.rules.stats)
	get_tree().quit()

func Catalog_field(record: Dictionary) -> String:
	return preload("res://scripts/matter/materials.gd").field(record)
