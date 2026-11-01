## Gravity's contract: a well is a whirl -- what is loose within reach goes round a ring of the
## well's matter, keeps what it is, touches that matter there and nowhere else, and flies off along
## the ring when the well lets go -- and a repulsor is a wave that throws each thing it reaches once,
## then a bubble that keeps machines out.
extends "res://tests/survivor/substances.gd"

## Flat distance from `center`, and the angle round it, of a world record.
func spot(id: int, center: Vector3) -> Vector2:
	var at: Vector3 = run.world.records[id]["position"]
	return Vector2(at.x - center.x, at.z - center.z)

func test() -> void:
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Prueba", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(50)
	player = run.local_player()
	player.global_position = Vector3(-6, 1.15, 2)
	run.set_physics_process(false)
	run.world.set_physics_process(false)
	await clear_world()
	run.reserves.erase(1)

	# --- A well draws loose matter round onto its ring, whatever it is --------------------------
	for kind: String in Catalog.SUBSTANCES:
		var heart: int = matter("water", Vector3(0, 0.07, -4))
		run.world.execute(1, "well", heart)
		var center: Vector3 = Catalog.field_center(run.world.records[heart])
		var loose: int = matter(kind, center + Vector3(4.6, 0, 0))
		var before: Dictionary = run.world.records[loose].duplicate(true)
		var start: Vector2 = spot(loose, center)
		for i: int in 60: run.world._physics_process(1.0 / 60.0)
		var after: Dictionary = run.world.records.get(loose, {})
		check("well_takes_" + kind + "_toward_ring", not after.is_empty() and absf(spot(loose, center).length() - Catalog.VORTEX_RING) < absf(start.length() - Catalog.VORTEX_RING))
		check("well_turns_" + kind + "_counterclockwise", not after.is_empty() and start.angle_to(spot(loose, center)) > 0.15)
		check("well_keeps_" + kind + "_whole", not after.is_empty() and after["material"] == before["material"] and after.get("volume", 1.0) == before.get("volume", 1.0) and after.get("charge", 0) == before.get("charge", 0) and after["owner"] == before["owner"])
		await clear_world()

	# --- What stays put, and what is out of reach -------------------------------------------------
	var heart: int = matter("scrap", Vector3(0, 0.07, -4))
	run.world.execute(1, "well", heart)
	var record: Dictionary = run.world.records[heart]
	var center: Vector3 = Catalog.field_center(record)
	var wall: int = matter("scrap", center + Vector3(-3, 0, 0))
	run.world.execute(1, "wall", wall, {"vector": Vector3.FORWARD})
	var store: int = run.world.add_source(center + Vector3(3, 0.03, 0), "fire")
	var far: int = matter("water", center + Vector3(0, 0, Catalog.VORTEX_REACH + 1.5))
	run.world._pull_toward(record, 0.1)
	check("well_leaves_walls_stores_and_the_far", run.world.records[wall]["velocity"] == Vector3.ZERO and run.world.records[store]["velocity"] == Vector3.ZERO and run.world.records[far]["velocity"] == Vector3.ZERO and record["velocity"] == Vector3.ZERO)
	check("gravity_same_for_every_carrier", is_equal_approx(Catalog.gravity(record), Catalog.gravity({"material": "fire"})))
	check("editor_calls_it_a_whirl", Recipe.simulate(["raise", "well"], "scrap")["trace"][1]["text"].contains("remolino"))
	check("touch_names_the_ring", " ".join(Rules.touch(Recipe.simulate(["well"], "scrap")["state"])).contains("muele"))
	await clear_world()

	# --- Machines ride the ring, and the ring is where they touch the matter ---------------------
	var wet_heart: int = matter("water", Vector3(0, 0.07, -4))
	run.world.execute(1, "well", wet_heart)
	center = Catalog.field_center(run.world.records[wet_heart])
	var outside: Node3D = machine(900, center + Vector3(4.5, 0.05, 0))
	var riding: Node3D = machine(901, center + Vector3(0, 0.05, -Catalog.VORTEX_RING))
	var middle: Node3D = machine(902, center + Vector3(0.2, 0.05, 0.1))
	await frames(2)
	for i: int in 6: run.spellwork._forces(run.world.records[wet_heart], 1.0 / 60.0)
	check("machines_drawn_in_from_beyond", outside.shove.x < 0.0)
	check("machines_carried_round", Vector2(riding.shove.x, riding.shove.z).dot(Vector2(1, 0)) > 0.5)
	check("middle_pushed_out_to_ring", middle.shove.x > 0.0)
	beat()
	# The one in the middle stands in the puddle itself, so it is wet by plain contact.
	check("water_ring_soaks_its_riders", riding.wet() and not outside.wet())
	await clear_world()
	var grinder: int = matter("scrap", Vector3(0, 0.07, -4))
	run.world.execute(1, "well", grinder)
	center = Catalog.field_center(run.world.records[grinder])
	var ground: Node3D = machine(910, center + Vector3(Catalog.VORTEX_RING, 0.05, 0))
	var spared: Node3D = machine(911, center + Vector3(0.3, 0.05, 0))
	await frames(2)
	var ground_health: float = ground.health
	var spared_health: float = spared.health
	beat()
	check("scrap_ring_grinds_by_weight", is_equal_approx(ground_health - ground.health, Rules.GRIND * Catalog.mass_of(run.world.records[grinder])))
	check("no_damage_off_the_ring", spared.health == spared_health)
	await clear_world()
	var torch: int = matter("fire", Vector3(0, 0.07, -4))
	run.world.execute(1, "well", torch)
	center = Catalog.field_center(run.world.records[torch])
	var lit: Node3D = machine(920, center + Vector3(-Catalog.VORTEX_RING, 0.05, 0))
	await frames(2)
	beat()
	check("fire_ring_lights_its_riders", lit.temp >= 2)
	await clear_world()

	# --- Letting go: everything on the ring flies off along it, and the heart is flung -----------
	var sling_heart: int = matter("water", Vector3(0, 0.07, -4))
	run.world.execute(1, "well", sling_heart)
	center = Catalog.field_center(run.world.records[sling_heart])
	var slung: Node3D = machine(930, center + Vector3(Catalog.VORTEX_RING, 0.05, 0))
	var passenger: int = matter("scrap", center + Vector3(-Catalog.VORTEX_RING, 0, 0))
	await frames(2)
	slung.shove = Vector3.ZERO
	run.world.records[sling_heart]["grav_left"] = 0.01
	run.world._physics_process(0.02)
	run.world._publish()
	await frames(1)
	check("release_flings_riders_along_ring", slung.shove.length() > 7.0 and slung.shove.z > 0.0)
	check("release_flings_loose_matter", run.world.records.has(passenger) and run.world.records[passenger]["velocity"].length() > 7.0 and run.world.records[passenger]["velocity"].z < 0.0)
	check("release_splashes_the_heart", not run.world.records.has(sling_heart) or Catalog.field(run.world.records[sling_heart]) == "")
	check("release_soaks_round_it", slung.wet())
	await clear_world()
	var standing: int = matter("scrap", Vector3(0, 0.07, -4))
	run.world.execute(1, "wall", standing, {"vector": Vector3.FORWARD})
	run.world.execute(1, "well", standing)
	run.world.records[standing]["grav_left"] = 0.01
	run.world._physics_process(0.02)
	run.world._publish()
	await frames(1)
	check("a_wall_heart_stays_standing", run.world.records.has(standing) and run.world.records[standing]["shape"] == "wall")
	await clear_world()

	# --- A repulsor: the front throws each thing it reaches once, then the bubble holds ----------
	var blast: int = matter("water", Vector3(0, 0.07, -4))
	center = Catalog.field_center(run.world.records[blast])
	var near_one: Node3D = machine(940, center + Vector3(1.5, 0.05, 0))
	var far_one: Node3D = machine(941, center + Vector3(-5.5, 0.05, 0))
	var blown: int = matter("scrap", center + Vector3(0, 0, 2.0))
	await frames(2)
	run.world.execute(1, "repel", blast)
	for i: int in 12:
		run.world._physics_process(1.0 / 60.0)
		run.spellwork._forces(run.world.records[blast], 1.0 / 60.0)
	check("front_throws_the_near_first", near_one.shove.x > 7.0 and far_one.shove.length() < 0.1)
	for i: int in 30:
		run.world._physics_process(1.0 / 60.0)
		run.spellwork._forces(run.world.records[blast], 1.0 / 60.0)
	check("front_reaches_the_far_later", far_one.shove.x < -6.0)
	check("front_throws_loose_matter_out", spot(blown, center).y > 3.0)
	near_one.shove = Vector3.ZERO
	near_one.global_position = center + Vector3(1.2, 0.05, 0)
	for i: int in 4: run.spellwork._forces(run.world.records[blast], 1.0 / 60.0)
	check("thrown_once_then_bubble_pushes", near_one.shove.x > 0.0 and near_one.shove.x < 4.6)
	var copied: Dictionary = bytes_to_var(var_to_bytes(run.world.records[blast]))
	check("wave_replicates", copied.has("wave_age") and copied["grav"] == -1)
	await clear_world()
	print("GRAVITY CHECKS ", JSON.stringify(checks))
	get_tree().quit(1 if false in checks.values() else 0)
