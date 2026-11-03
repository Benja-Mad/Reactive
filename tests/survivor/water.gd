## Nothing comes from nothing: routines draw water the yard already holds, the water is seen
## running to where it acts, each step happens on its own beat, and spent matter lands back on the
## floor as a puddle the next routine, the Novia or Brasa's fire can work.
extends "res://tests/survivor/validate.gd"
const Catalog = preload("res://scripts/matter/materials.gd")
const Build = preload("res://scripts/survivor/build.gd")
const Recipe = preload("res://scripts/survivor/recipe.gd")

func clear_world() -> void:
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id, {"remote": true})
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	await frames(2)

func yard_puddles() -> Array:
	return run.world.records.values().filter(func(record: Dictionary) -> bool: return record["owner"] == run.world.YARD)

## Ticks the routines and the world together, as play does.
func play(seconds: float, step: float = 1.0 / 60.0) -> void:
	var left: float = seconds
	while left > 0.0:
		run.spellwork.tick(step)
		run.world._physics_process(step)
		left -= step

func test() -> void:
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Prueba", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(50)
	player = run.local_player()
	run.set_physics_process(false)
	run.world.set_physics_process(false)
	run.spellwork.rules.enabled = false
	await clear_world()
	run.builds[1] = Build.fresh()
	run.clocks[1] = {"shot": 1000.0, "heal": 3.0, "trail": player.global_position, "made": {}}

	# The yard's sources open where the floor allows and each keeps a full puddle.
	run.open_sources()
	var sources: Array = run.world.records.values().filter(func(record: Dictionary) -> bool: return record.get("source", false) and record["material"] == "water")
	check("every_source_opens", sources.size() == run.SOURCES.size())
	check("sources_start_full", sources.all(func(record: Dictionary) -> bool: return is_equal_approx(float(record["volume"]), Catalog.MAX_VOLUME)))
	await clear_world()

	# A routine pours from its operator's hands: the yard keeps its water, and the draught lands
	# only after its run.
	player.global_position = Vector3(-4, 1.15, 2)
	run.builds[1]["routines"] = [{"when": "cerca", "steps": ["raise", "cold", "push"], "then": "fragmentos", "on": "broken"}]
	var source: int = run.world.add_source(Vector3(-3, 0.1, 2))
	check("pours_from_hands", run.spellwork.begin(1, 0, Vector3(1, 0.07, -2), Vector3.RIGHT) == "")
	check("yard_keeps_its_water", is_equal_approx(float(run.world.records[source]["volume"]), Catalog.MAX_VOLUME))
	check("water_runs_before_it_lands", run.world.records.size() == 1)
	play(0.4)
	var made: Array = run.world.records.values().filter(func(record: Dictionary) -> bool: return record["owner"] == 1)
	check("water_lands_where_routine_acts", made.size() == 1 and Vector2(made[0]["position"].x - 1, made[0]["position"].z + 2).length() < 0.5)
	var id: int = made[0]["id"] if not made.is_empty() else 0
	check("lands_as_water_still_forming", id != 0 and run.world.records[id]["material"] == "water" and run.world.records[id]["shape"] == "patch" and run.world.records[id].get("forming", false))
	check("forming_matter_cannot_be_drawn", id != 0 and not Catalog.drawable(run.world.records[id]))
	play(run.spellwork.STEP_BEAT * 0.6 + 0.02)
	check("first_step_alone", run.world.records.has(id) and run.world.records[id]["shape"] == "orb" and run.world.records[id]["material"] == "water")
	play(run.spellwork.STEP_BEAT)
	check("second_step_a_beat_later", run.world.records.has(id) and run.world.records[id]["material"] == "ice" and not run.world.records[id].has("reaction"))
	play(run.spellwork.STEP_BEAT * 2.0)
	check("armed_after_last_step", run.world.records.has(id) and run.world.records[id].has("reaction") and not run.world.records[id].get("forming", false))
	await clear_world()
	# «On wade» works the puddle a machine stands in, where it lies.
	var wade: int = run.world.add_source(Vector3(-3, 0.1, 2))
	check("on_wade_works_the_puddle", run.spellwork.begin(1, 0, Vector3(1, 0.07, -2), Vector3.RIGHT, 0, wade) == "" and is_equal_approx(float(run.world.records[wade]["volume"]), Catalog.MAX_VOLUME - 1.0))
	await clear_world()

	# Spent matter lands as a puddle: a water orb released in a splash, ice shards that melt.
	run.builds[1]["routines"] = [{"when": "cerca", "steps": ["raise"], "then": "fragmentos", "on": "timer"}]
	id = run.spellwork.cast(1, 0, Vector3(2, 0.07, 0), Vector3.RIGHT)
	run.spellwork.tick(Recipe.REACTION_DELAY + 0.05)
	check("splash_leaves_a_puddle", not run.world.records.has(id) and yard_puddles().size() == 1 and Vector2(yard_puddles()[0]["position"].x - 2, yard_puddles()[0]["position"].z).length() < 0.6)
	await clear_world()
	run.builds[1]["routines"] = [{"when": "cerca", "steps": ["raise", "cold"], "then": "", "on": "contact"}]
	id = run.spellwork.cast(1, 0, Vector3(2, 0.07, 0), Vector3.RIGHT)
	run.world.damage_construct(id, 999.0)
	check("ice_breaks_to_shards", run.world.records[id]["shape"] == "fragments")
	play(9.0)
	check("shards_melt_into_a_puddle", not run.world.records.has(id) and yard_puddles().size() == 1)
	var merged: int = yard_puddles()[0]["id"]
	run.world.spill(run.world.records[merged]["position"] + Vector3(1.0, 0, 0), 1.0)
	check("water_joins_a_puddle_nearby", yard_puddles().size() == 1 and is_equal_approx(float(run.world.records[merged]["volume"]), 2.0))
	await clear_world()

	# The yard's own ice warms back to water; a source refills what was drawn.
	var puddle: int = run.world.spill(Vector3(2, 0.07, 0), 1.0)
	run.world.execute(1, "freeze", puddle)
	check("yard_puddle_freezes", run.world.records[puddle]["material"] == "ice")
	play(run.world.MELT_TIME + 0.1)
	check("yard_ice_melts_back", run.world.records.has(puddle) and run.world.records[puddle]["material"] == "water" and run.world.records[puddle]["shape"] == "patch")
	source = run.world.add_source(Vector3(-3, 0.1, 2))
	run.world.draw_from(source)
	run.world.draw_from(source)
	run.world.draw_from(source)
	check("drawn_dry_source_stays", run.world.records.has(source) and float(run.world.records[source]["volume"]) < 0.01 and run.world.draw_from(source) == null)
	play(run.world.SOURCE_REFILL + 0.1)
	check("source_refills", is_equal_approx(float(run.world.records[source]["volume"]), 1.0))
	# Fire boils a yard puddle into a cloud that rains back as the same water.
	run.world.heat_along(Vector3(1, 0.15, 0), Vector3(3, 0.15, 0))
	check("fire_boils_yard_water", run.world.records[puddle]["material"] == "steam")
	play(Catalog.STEAM_LIFETIME + 0.1)
	check("steam_rains_back", run.world.records.has(puddle) and run.world.records[puddle]["material"] == "water" and is_equal_approx(float(run.world.records[puddle]["volume"]), 1.0))
	# A deep puddle loses one draught to the flame at a time; the cloud rains back into it.
	var deep: int = run.world.spill(Vector3(2, 0.07, 4), 3.0)
	run.world.heat_along(Vector3(1, 0.15, 4), Vector3(3, 0.15, 4))
	run.world.heat_along(Vector3(1, 0.15, 4), Vector3(3, 0.15, 4))
	var clouds: Array = run.world.records.values().filter(func(record: Dictionary) -> bool: return record["material"] == "steam" and record["id"] != puddle)
	check("fire_boils_a_draught_off_deep_water", run.world.records[deep]["material"] == "water" and is_equal_approx(float(run.world.records[deep]["volume"]), 2.0) and clouds.size() == 1)
	play(Catalog.STEAM_LIFETIME + 0.1)
	check("cloud_rains_back_into_its_puddle", run.world.records.has(deep) and is_equal_approx(float(run.world.records[deep]["volume"]), 3.0) and not run.world.records.has(clouds[0]["id"]))
	await clear_world()

	# «on wade»: a machine standing in water within reach fires the routine on that very puddle.
	puddle = run.world.spill(Vector3(1, 0.07, -2), 1.0)
	run.spawn_machine(950, Vector3(1.4, 0.05, -2.2), 0, 1.0)
	var wader: Node = run.machines.get_node("Machine950")
	wader.set_physics_process(false)
	await frames(2)
	var waders: Array[Node3D] = [wader]
	var spot: Variant = run._placement(player, run.clocks[1], "charco", waders)
	check("wade_finds_the_puddle", spot != null and spot.size() == 3 and spot[2] == puddle)
	run.builds[1]["routines"] = [{"when": "charco", "steps": ["cold"], "then": "", "on": "contact"}]
	check("wade_works_in_place", spot != null and run.spellwork.begin(1, 0, spot[0], spot[1], 0, spot[2]) == "" and not run.world.records.has(puddle))
	play(1.0)
	var frozen: Array = run.world.records.values().filter(func(record: Dictionary) -> bool: return record["owner"] == 1 and record["material"] == "ice")
	check("wade_freezes_under_the_machine", frozen.size() == 1 and Vector2(frozen[0]["position"].x - 1, frozen[0]["position"].z + 2).length() < 0.5)
	check("editor_names_the_water", Build.explain({"routines": [run.builds[1]["routines"][0]], "box": [], "tools": {"pressure": 0}}, 0)[1][1].begins_with("agua del charco"))
	await clear_world()

	# The Novia drinks a draught at a time and spills what she carried back on the yard.
	puddle = run.world.spill(Vector3(1, 0.07, -2), 2.0)
	run.spawn_machine(951, Vector3(1, 0.05, -2), 5, 1.0)
	var bride: Node = run.machines.get_node("Machine951")
	bride.set_physics_process(false)
	await frames(2)
	bride._drain(puddle)
	check("novia_drinks_a_draught", run.world.records.has(puddle) and is_equal_approx(float(run.world.records[puddle]["volume"]), 1.0))
	bride.gulps = 2
	bride._spill(Vector3(1.5, 0.07, -2), bride.gulps)
	check("novia_spill_joins_the_puddle", is_equal_approx(float(run.world.records[puddle]["volume"]), 3.0))
	print("WATER CHECKS ", JSON.stringify(checks))
	get_tree().quit(1 if false in checks.values() else 0)

