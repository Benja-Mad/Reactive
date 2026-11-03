## Fire, current and scrap act by themselves and on each other, with no water between them: a
## routine draws any of the four from where the yard keeps it, fire lights machines and passes
## from one to the next, current jumps to the nearest body and is spent, scrap is what wrecks
## leave, and matter touching matter reacts.
extends "res://tests/survivor/validate.gd"
const Catalog = preload("res://scripts/matter/materials.gd")
const Build = preload("res://scripts/survivor/build.gd")
const Recipe = preload("res://scripts/survivor/recipe.gd")
const Rules = preload("res://scripts/survivor/rules.gd")

func clear_world() -> void:
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id, {"remote": true})
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	await frames(2)

func play(seconds: float, step: float = 1.0 / 60.0) -> void:
	var left: float = seconds
	while left > 0.0:
		run.spellwork.tick(step)
		run.world._physics_process(step)
		left -= step

## One beat of the heat and conduction rules on the machines alive now.
func beat() -> void:
	var live: Array[Node3D] = []
	for enemy: Node3D in run.machines.get_children(): if not enemy.down and not enemy.is_queued_for_deletion(): live.append(enemy)
	run.spellwork.rules._clock = 0.0
	run.spellwork.rules.tick(0.01, live)

func machine(id: int, at: Vector3, kind: int = 0) -> Node3D:
	run.spawn_machine(id, at, kind, 20.0)
	var enemy: Node3D = run.machines.get_node("Machine%d" % id)
	enemy.set_physics_process(false)
	return enemy

## A record of `material` made by player 1 at `at`, as a routine would leave it.
func matter(material: String, at: Vector3) -> int:
	var made: Dictionary = run.world.execute(1, "create", 0, {"point": at, "material": material})
	return made.get("id", 0)

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
	await clear_world()
	run.builds[1] = Build.fresh()
	run.clocks[1] = {"shot": 1000.0, "heal": 3.0, "trail": player.global_position, "made": {}}

	# --- The recipe table speaks each substance ---------------------------------------------------
	check("recipe_fire_ball", Recipe.matter_text(Recipe.simulate(["raise"], "fire")["state"]) == "bola de fuego suspendida")
	check("recipe_cold_puts_fire_out", Recipe.step(Recipe.source("fire"), "cold")["op"] == "quench" and Recipe.simulate(["cold"], "fire")["state"]["shape"] == "gone")
	check("recipe_heat_stokes_fire", Recipe.step(Recipe.source("fire"), "fire")["op"] == "stoke")
	check("recipe_current_comes_charged", Recipe.source("current")["charge"] == Catalog.CURRENT_CHARGE and Recipe.step(Recipe.source("current"), "arc")["op"] == "arc")
	check("recipe_scrap_goes_red", Recipe.step(Recipe.source("scrap"), "fire")["op"] == "warm" and Recipe.simulate(["fire", "fire"], "scrap")["state"]["temp"] == 2)
	check("recipe_water_unchanged", Recipe.simulate(["cold"])["state"]["material"] == "ice")
	var every_then: bool = true
	for from: String in Catalog.SUBSTANCES:
		for steps: Array in [[], ["raise"], ["wall"], ["raise", "push"]]:
			var state: Dictionary = Recipe.simulate(steps, from)["state"]
			for then: String in ["fragmentos", "estallar", "colapso"]:
				if Recipe.effect(state, then) == "": every_then = false
	check("every_then_on_every_substance", every_then)
	var fire_build: Dictionary = {"routines": [{"when": "cerca", "steps": ["raise", "push"], "then": "estallar", "on": "contact", "from": "fire"}], "box": [], "tools": {"pressure": 0}}
	check("editor_says_where_fire_comes_from", Build.explain(fire_build, 0)[1][1].begins_with("fuego desde tus manos"))
	check("build_accepts_a_source", Build.well_formed(fire_build, 1))
	fire_build["routines"][0]["from"] = "lava"
	check("build_rejects_unknown_source", not Build.well_formed(fire_build, 1))
	check("source_node_cycles", Build.next_source("water") == "fire" and Build.next_source("scrap") == "water")
	check("touch_says_fire_spreads", Rules.touch(Recipe.source("fire")).any(func(line: String) -> bool: return line.contains("pasa a las de al lado")))

	# --- The yard keeps every substance ---------------------------------------------------------
	run.open_sources()
	var stores: Dictionary = {}
	for record: Dictionary in run.world.records.values():
		if record.get("source", false): stores[record["material"]] = int(stores.get(record["material"], 0)) + 1
	check("yard_keeps_every_substance", stores.get("water", 0) == run.SOURCES.size() and stores.get("fire", 0) == 2 and stores.get("current", 0) == 2 and stores.get("scrap", 0) == 2)
	await clear_world()

	# --- A fire routine pours fire from the hands and leaves the yard alone ---------------------------
	run.world.residue = true
	player.global_position = Vector3(-3, 1.15, -2)
	run.builds[1]["routines"] = [{"when": "cerca", "steps": ["raise"], "then": "", "on": "contact", "from": "fire"}]
	var puddle: int = run.world.add_source(Vector3(-3, 0.1, 2))
	var drum: int = run.world.add_source(Vector3(-6, 0.1, -4), "fire")
	check("fire_routine_pours_from_hands", run.spellwork.begin(1, 0, Vector3(1, 0.07, -2), Vector3.RIGHT) == "")
	check("fire_routine_ignores_the_yard", is_equal_approx(float(run.world.records[puddle]["volume"]), Catalog.MAX_VOLUME) and is_equal_approx(float(run.world.records[drum]["volume"]), Catalog.MAX_VOLUME))
	play(1.2)
	var ball: Array = run.world.records.values().filter(func(record: Dictionary) -> bool: return record["owner"] == 1)
	check("drawn_fire_lands_and_rises", ball.size() == 1 and ball[0]["material"] == "fire" and ball[0]["shape"] == "orb")
	var fuel: float = float(ball[0].get("burn", 0.0)) if not ball.is_empty() else 0.0
	play(fuel + 0.2)
	check("fire_burns_out_and_leaves_nothing", run.world.records.values().filter(func(record: Dictionary) -> bool: return record["owner"] == 1).is_empty() and run.world.records.size() == 2)
	check("drum_is_not_consumed", run.world.records.has(drum))
	await clear_world()

	# --- Fire lights machines by itself, and they light each other ---------------------------------
	var flame: int = matter("fire", Vector3(0, 0.07, 0))
	var lit: Node3D = machine(800, Vector3(0.5, 0.05, 0.3))
	var neighbour: Node3D = machine(801, Vector3(0.5, 0.05, 4.0))
	var wet: Node3D = machine(802, Vector3(-1.0, 0.05, -0.8))
	await frames(2)
	wet.soak(Vector3.ZERO)
	neighbour.global_position = Vector3(0.5, 0.05, 4.0)
	beat()
	check("fire_lights_a_dry_machine", lit.temp >= 2)
	check("wet_machine_resists_fire", wet.temp < 2 and not wet.wet())
	neighbour.global_position = lit.global_position + Vector3(1.2, 0, 0)
	run.world.execute(1, "remove", flame, {"remote": true})
	beat()
	beat()
	check("fire_spreads_machine_to_machine", neighbour.temp >= 2)
	await clear_world()

	# --- Current jumps to the nearest body, a discharge at a time ------------------------------------
	var current: int = matter("current", Vector3(0, 0.07, 0))
	var near: Node3D = machine(810, Vector3(3.6, 0.05, 0))
	var further: Node3D = machine(811, Vector3(-4.2, 0.05, 0.5))
	await frames(2)
	var health: float = near.health
	var other_health: float = further.health
	beat()
	check("current_seeks_the_nearest", near.health < health and is_equal_approx(further.health, other_health))
	check("current_spends_one_discharge", run.world.records.has(current) and int(run.world.records[current]["charge"]) == Catalog.CURRENT_CHARGE - 1)
	beat()
	check("spent_current_is_gone", not run.world.records.has(current))
	var far_current: int = matter("current", Vector3(0, 0.07, 0))
	near.global_position = Vector3(12, 0.05, 0)
	further.global_position = Vector3(-12, 0.05, 0)
	beat()
	check("current_waits_without_a_body", run.world.records.has(far_current) and int(run.world.records[far_current]["charge"]) == Catalog.CURRENT_CHARGE)
	await clear_world()

	# --- Matter on matter, no machine between them ---------------------------------------------------
	var fire_on_water: int = matter("fire", Vector3(0, 0.07, 0))
	var water: int = run.world.spill(Vector3(1, 0.07, 0), 1.0)
	beat()
	check("water_puts_fire_out", not run.world.records.has(fire_on_water))
	check("fire_boils_the_water", run.world.records.has(water) and run.world.records[water]["material"] == "steam")
	await clear_world()
	var hot: int = matter("fire", Vector3(0, 0.07, 0))
	var metal: int = run.world.spill(Vector3(1, 0.07, 0), 1.0, "scrap")
	beat()
	check("fire_heats_scrap", run.world.records.has(metal) and Catalog.temp_of(run.world.records[metal]) == 1 and run.world.records.has(hot))
	beat()
	check("scrap_goes_red_hot", Catalog.temp_of(run.world.records[metal]) == 2)
	run.world.execute(1, "remove", hot, {"remote": true})
	var cool: int = run.world.spill(Vector3(1.5, 0.07, 0.5), 1.0)
	beat()
	check("hot_scrap_boils_water_and_cools", run.world.records.has(cool) and run.world.records[cool]["material"] == "steam" and Catalog.temp_of(run.world.records[metal]) == 1)
	await clear_world()
	var spark: int = matter("fire", Vector3(0, 0.07, 0))
	var bomb: int = matter("scrap", Vector3(4.5, 0.07, 0))
	run.world.execute(1, "coat", bomb, {})
	var victim: Node3D = machine(820, Vector3(5.5, 0.05, 0))
	await frames(2)
	health = victim.health
	beat()
	check("nanites_far_from_fire_wait", run.world.records.has(bomb) and run.world.records[bomb]["attachments"].has("nanites"))
	run.world.records[spark]["position"] = Vector3(3.0, 0.07, 0)
	beat()
	check("fire_sets_off_nanites", not run.world.records.has(bomb) or not run.world.records[bomb]["attachments"].has("nanites"))
	check("the_blast_reaches_the_machine", victim.health < health)
	await clear_world()
	var live_wire: int = matter("current", Vector3(0, 0.07, 0))
	var charged_bomb: int = matter("water", Vector3(2.0, 0.07, 0))
	run.world.execute(1, "coat", charged_bomb, {})
	var through: Node3D = machine(830, Vector3(2.4, 0.05, 0))
	await frames(2)
	beat()
	await frames(2)
	check("discharge_sets_off_nanites", not run.world.records.has(charged_bomb) or not run.world.records[charged_bomb]["attachments"].has("nanites"))
	run.world.execute(1, "remove", live_wire, {"remote": true})
	await clear_world()

	# --- Scrap is what wrecks leave, and it conducts ---------------------------------------------------
	run.machine_killed(Vector3(2, 0.05, 2), 0)
	run.machine_killed(Vector3(2.5, 0.05, 2.2), 0)
	var piles: Array = run.world.records.values().filter(func(record: Dictionary) -> bool: return record["material"] == "scrap")
	check("wrecks_leave_scrap", piles.size() == 1 and is_equal_approx(float(piles[0]["volume"]), 1.0))
	check("scrap_drags_machines", run.slow_factor(Vector3(2, 0.05, 2)) < 0.7)
	await clear_world()
	var plate: int = run.world.spill(Vector3(0, 0.07, 0), 1.0, "scrap")
	run.world.records[plate]["charge"] = 1
	var a: Node3D = machine(840, Vector3(0.4, 0.05, 0.2))
	var b: Node3D = machine(841, Vector3(0.4, 0.05, 2.6), 1)
	await frames(2)
	var b_health: float = b.health
	beat()
	check("charge_runs_through_scrap", b.health < b_health)
	await clear_world()

	# --- Gravity works with the substances ----------------------------------------------------------
	var wells: Dictionary = {}
	for kind: String in ["water", "scrap", "fire"]:
		var id: int = matter(kind, Vector3(-8 + wells.size() * 8, 0.07, 6))
		run.world.execute(1, "raise", id)
		run.world.execute(1, "well", id)
		wells[kind] = id
	var pull: Callable = func(kind: String) -> float: return Catalog.gravity(run.world.records[wells[kind]])
	check("gravity_equal_for_all_carriers", is_equal_approx(pull.call("scrap"), pull.call("water")) and is_equal_approx(pull.call("water"), pull.call("fire")))
	check("editor_says_it_whirls", Recipe.simulate(["raise", "well"], "scrap")["trace"][1]["text"].contains("remolino"))
	var store: int = run.world.add_source(run.world.records[wells["water"]]["position"] * Vector3(1, 0, 1) + Vector3(-4, 0.1, 0))
	var store_at: Vector3 = run.world.records[store]["position"]
	var loose: int = run.world.spill(run.world.records[wells["water"]]["position"] * Vector3(1, 0, 1) + Vector3(0.5, 0.07, 0), 1.0)
	var heap: int = run.world.spill(run.world.records[wells["scrap"]]["position"] * Vector3(1, 0, 1) + Vector3(0.4, 0.07, 0.3), 1.0, "scrap")
	var volume_before: float = float(run.world.records[wells["water"]].get("volume", 1.0))
	run.world._physics_process(0.05)
	check("well_keeps_caught_water_apart", run.world.records.has(loose) and float(run.world.records[wells["water"]].get("volume", 1.0)) == volume_before)
	check("well_keeps_caught_scrap_apart", run.world.records.has(heap) and Catalog.mass_of(run.world.records[wells["scrap"]]) == 3.0)
	check("stores_stay_put", run.world.records[store]["position"] == store_at)
	var core: Vector3 = run.world.records[wells["water"]]["position"] * Vector3(1, 0, 1) + Vector3(0, 0.05, 0)
	var pressed: Node3D = machine(850, core + Vector3(0.5, 0, 0))
	var pressed_too: Node3D = machine(851, core + Vector3(-0.5, 0, 0.3), 2)
	var alone: Node3D = machine(852, run.world.records[wells["fire"]]["position"] * Vector3(1, 0, 1) + Vector3(0.3, 0.05, 0))
	await frames(2)
	var pressed_health: float = pressed.health
	var alone_health: float = alone.health
	beat()
	check("well_does_not_hurt_by_proximity", pressed.health == pressed_health and run.spellwork.rules.stats["crushed"] == 0)
	check("lone_machine_only_held", alone.health >= alone_health - 3.5)
	await clear_world()
	# A machine thrown into another: both are hit and the second is sent on.
	run.spawn_machine(860, Vector3(0, 0.05, -12), 0, 20.0)
	run.spawn_machine(861, Vector3(1.3, 0.05, -12), 3, 20.0)
	var thrown: Node3D = run.machines.get_node("Machine860")
	var pin: Node3D = run.machines.get_node("Machine861")
	await frames(2)
	var pin_health: float = pin.health
	thrown.shove = Vector3(14, 0, 0)
	await frames(12)
	check("thrown_machine_bowls", pin.health < pin_health and run.spellwork.rules.stats["bowled"] >= 1)
	await clear_world()

	print("SUBSTANCE CHECKS ", JSON.stringify(checks))
	get_tree().quit(1 if false in checks.values() else 0)
