extends Node
const World = preload("res://scripts/matter/world_matter.gd")
const Recipe = preload("res://scripts/survivor/recipe.gd")
const Catalog = preload("res://scripts/matter/materials.gd")
const Build = preload("res://scripts/survivor/build.gd")
var world: Node3D
var checks: Dictionary = {}
func _ready() -> void: call_deferred("run")
func check(key: String, ok: bool) -> void:
	checks[key] = ok
	if not ok: push_error("BENDING: " + key)
func frames(count: int = 2) -> void:
	for i: int in count: await get_tree().physics_frame
func make() -> int:
	return world.execute(1, "create", 0, {"point": Vector3(0, 0.05, 0)}).get("id", 0)
func clean() -> void:
	for id: int in world.records.keys(): world.execute(1, "remove", id)
	await frames()
func run() -> void:
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50, 1, 50)
	collider.shape = box
	collider.position.y = -0.5
	floor_body.add_child(collider)
	add_child(floor_body)
	var player := Node3D.new()
	player.add_to_group("coop_players")
	player.position = Vector3(-4, 0, 0)
	add_child(player)
	world = World.new()
	add_child(world)
	world.set_physics_process(false)
	world.get_node("Programs").set_physics_process(false)
	await frames()
	# Every pair of instructions, plus meaningful longer chains: the preview is a contract.
	var keys: Array = ["raise", "wall", "cold", "fire", "push", "drop", "well", "repel", "arc", "coat"]
	var sequences: Array = []
	for first: String in keys:
		for second: String in keys: sequences.append([first, second])
	sequences.append_array([["raise", "cold", "push"], ["cold", "raise", "fire", "push"], ["raise", "fire", "cold", "drop"], ["fire", "raise", "cold", "cold"], ["raise", "coat", "arc", "drop"], ["cold", "raise", "drop", "fire"], ["raise", "wall", "cold", "drop"], ["wall", "cold", "push"], ["raise", "push", "fire", "cold"]])
	for steps: Array in sequences:
		var id: int = make()
		var state: Dictionary = Recipe.source()
		var agrees: bool = id > 0
		for key: String in steps:
			var plan: Dictionary = Recipe.step(state, key)
			if plan["op"] != "":
				var result: Dictionary = world.execute(1, plan["op"], id, {"vector": Vector3.RIGHT * 9})
				agrees = agrees and result["ok"]
			state = plan["next"]
			if not world.records.has(id):
				agrees = agrees and state["shape"] == "gone"
				continue
			var actual: Dictionary = Recipe.state_of(world.records[id])
			for property: String in ["material", "shape", "suspended", "temp", "charge", "grav", "coat", "moving"]:
				if actual[property] != state[property]:
					print("MISMATCH ", steps, " at ", key, " ", property, ": ", actual[property], " expected ", state[property])
					agrees = false
		check("preview_" + "_".join(steps), agrees)
		await clean()
	var id: int = make()
	check("drop_needs_height", not world.execute(1, "drop", id)["ok"])
	world.execute(1, "raise", id)
	check("water_is_a_non_solid_sphere", world.records[id]["shape"] == "orb" and world.views[id].water_body.mesh is SphereMesh and world.views[id].collision_layer == 0)
	check("height_is_real", world.records[id]["position"].y > world.records[id]["ground_y"] + 0.5)
	world.execute(1, "freeze", id)
	check("frozen_sphere_has_spherical_collision", world.views[id].collider.shape is SphereShape3D and world.views[id].collision_layer == 1)
	world.execute(1, "heat", id)
	world.execute(1, "heat", id)
	world.records[id]["condense"] = 0.01
	world._physics_process(0.02)
	check("natural_condensation_keeps_hold", world.records[id]["shape"] == "orb" and world.records[id]["suspended"])
	world.execute(1, "drop", id)
	check("drop_returns_to_ground", world.records[id]["shape"] == "patch" and not world.records[id]["suspended"] and is_equal_approx(world.records[id]["position"].y, world.records[id]["ground_y"]))
	await clean()
	# Real projectile collision: the same water can be thrown, lands as water, retains its identity.
	var actor = preload("res://tests/matter/test_actor.gd").new()
	actor.position = Vector3(3, 0, 0.95) # A grazing sphere hit: its center ray misses the capsule.
	add_child(actor)
	await frames()
	id = make()
	world.execute(1, "raise", id)
	world.execute(1, "push", id, {"vector": Vector3.RIGHT * 9})
	for i: int in 50: world._physics_process(1.0 / 60.0)
	check("launched_water_hits_and_splashes", actor.health < 100 and world.records.has(id) and world.records[id]["shape"] == "patch" and not world.records[id]["suspended"])
	await clean()
	actor.health = 100
	id = make()
	world.execute(1, "raise", id)
	world.execute(1, "freeze", id)
	world.execute(1, "push", id, {"vector": Vector3.RIGHT * 9})
	for i: int in 50: world._physics_process(1.0 / 60.0)
	check("launched_ice_hits_and_shatters", actor.health < 100 and world.records.has(id) and world.records[id]["shape"] == "fragments")
	await clean()
	actor.queue_free()
	await frames()
	# An anchored wall resists fields, a puddle and a suspended orb both move.
	var field: int = make()
	world.execute(1, "well", field, {"vector": Vector3.LEFT})
	for phase: String in ["water", "ice", "steam"]:
		var item: int = world.execute(1, "create", 0, {"point": Vector3(4, 0.05, 0)})["id"]
		if phase != "water": world.execute(1, "freeze" if phase == "ice" else "heat", item)
		world._pull_toward(world.records[field], 0.1)
		check("attract_moves_" + phase, world.records[item]["velocity"].x < 0)
		world.execute(1, "repel", field, {"vector": Vector3.LEFT})
		world.records[item]["velocity"] = Vector3.ZERO
		# The wave reaches it once its front has run the 4 m out.
		for i: int in 6: world._pull_toward(world.records[field], 0.1)
		check("repel_moves_" + phase, world.records[item]["velocity"].x > 0)
		world.execute(1, "remove", item)
		world.execute(1, "well", field, {"vector": Vector3.LEFT})
		await frames()
	var wall: int = world.execute(1, "create", 0, {"point": Vector3(4, 0.05, 0)})["id"]
	world.execute(1, "wall", wall, {"vector": Vector3.RIGHT})
	world._pull_toward(world.records[field], 0.1)
	check("wall_is_explicit_and_anchored", world.records[wall]["shape"] == "wall" and world.records[wall]["velocity"] == Vector3.ZERO)
	var build: Dictionary = Build.fresh()
	build["routines"][0]["on"] = "timer"
	check("trigger_is_editable_without_new_pieces", Build.well_formed(build, 2) and Build.same_pieces(build, Build.fresh()))
	build["routines"][0]["on"] = "arbitrary"
	check("host_rejects_unknown_trigger", not Build.well_formed(build, 2))
	check("detonation_explains_missing_energy", Build.problem({"when": "cerca", "steps": [], "then": "detonar"}).contains("coat"))
	check("liquid_cannot_break", Build.problem({"when": "cerca", "steps": ["raise"], "then": "estallar", "on": "broken"}).contains("hielo"))
	print("BENDING CHECKS ", JSON.stringify(checks))
	get_tree().quit(1 if false in checks.values() else 0)
