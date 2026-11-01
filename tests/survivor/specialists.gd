## The specialists and the walkers, each on its own: tells come first, the hit lands where it was
## marked, the window after it is real, and each one answers to the matter and the operator it is
## meant to answer to.
extends Node
const Enemy = preload("res://scripts/survivor/enemy.gd")
var checks: Dictionary = {}
var scene: Node
var run: Node
var player: Character
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("test")
func frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame
func check(key: String, ok: bool) -> void:
	checks[key] = ok
	if not ok: push_error("SPECIALISTS: " + key)
## Waits until `machine` reaches `state` (or dies, or time runs out). True if it got there.
func until(machine: Node, state: String, limit: int = 600) -> bool:
	for i: int in limit:
		if not is_instance_valid(machine) or machine.down: return false
		if machine.state == state: return true
		hold()
		await get_tree().physics_frame
	return false
## Keep the operator alive, unarmed and still while a machine is being observed.
func hold() -> void:
	run.clocks[1]["shot"] = 1000.0
	if player.health < 40: player.health = 100
func clear() -> void:
	for node: Node in run.machines.get_children(): node.queue_free()
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
func machine(id: int, offset: Vector3, kind: int) -> Node:
	run.spawn_machine(id, player.global_position + offset, kind, 1.0)
	return run.machines.get_node("Machine%d" % id)

func test() -> void:
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Prueba", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(40)
	player = scene.get_node("Players").get_child(0)
	player.global_position = Vector3(-3, 1.15, -2)
	await frames(10)
	run.builds[1] = preload("res://scripts/survivor/build.gd").fresh()
	run.builds[1]["routines"] = []
	run.clocks[1] = {"shot": 1000.0, "heal": 1000.0, "trail": player.global_position, "made": {}}
	await leaper()
	await diver()
	await drinker()
	await quiltro()
	await repartidor()
	await animita()
	await gravity()
	check("director_introduces_specialists", director())
	print("SPECIALIST CHECKS ", JSON.stringify(checks))
	get_tree().quit(1 if false in checks.values() else 0)

func leaper() -> void:
	clear()
	player.health = 100
	var hound: Node = machine(901, Vector3(0, -1.1, -5.5), Enemy.LEAPER)
	check("leaper_crouches_first", await until(hound, "crouch"))
	check("leaper_marks_landing", hound.marks.size() == 1 and Vector2(hound.state_to.x - player.global_position.x, hound.state_to.z - player.global_position.z).length() < 1.0)
	var health: float = player.health
	check("leaper_jumps", await until(hound, "air") and hound.airborne())
	await frames(int(hound.FLIGHT * 0.5 * Engine.physics_ticks_per_second))
	check("leaper_arcs_high", hound.global_position.y > player.global_position.y + 0.6)
	check("leaper_exposed_after_landing", await until(hound, "exposed") and hound.exposure > 1.0)
	check("leaper_slam_hurts_on_mark", player.health < health)
	hound.take_damage(1000)
	# A barrier between them: the leaper goes over it rather than chewing through it.
	clear()
	await frames(2)
	run.builds[1]["routines"] = [{"when": "cerca", "steps": ["wall", "cold"], "then": ""}]
	var wall: int = run.run_routine(1, 0, player.global_position + Vector3(0, 0, -2.6), Vector3.FORWARD)
	run.builds[1]["routines"] = []
	var integrity: float = run.world.records[wall]["integrity"] if run.world.records.has(wall) else 0.0
	hound = machine(902, Vector3(0, -1.1, -5.2), Enemy.LEAPER)
	hound.cooldown = 0.0
	var crossed: bool = false
	for i: int in 400:
		hold()
		await get_tree().physics_frame
		if not is_instance_valid(hound): break
		if hound.global_position.z > player.global_position.z - 2.0 and hound.state == "exposed":
			crossed = true
			break
	check("leaper_clears_barrier", wall > 0 and crossed)
	check("leaper_spares_barrier", run.world.records.has(wall) and run.world.records[wall]["integrity"] >= integrity)
	# Its slam cracks ice it lands beside.
	clear()
	await frames(2)
	var ground: Dictionary = run.arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.global_position, player.global_position - Vector3.UP * 4.0, 1))
	var sheet: Dictionary = run.world.execute(1, "create", 0, {"point": ground.get("position", player.global_position) + Vector3(0, 0.07, -2.5)})
	check("ice_sheet_setup", sheet.get("ok", false) and run.world.execute(1, "freeze", sheet["id"]).get("ok", false))
	var before: float = run.world.records[sheet["id"]]["integrity"] if sheet.get("ok", false) else 0.0
	hound = machine(903, Vector3(0, -1.1, -6.0), Enemy.LEAPER)
	hound.cooldown = 0.0
	await until(hound, "exposed")
	var id: int = sheet.get("id", -1)
	check("leaper_cracks_ice", sheet.get("ok", false) and (not run.world.records.has(id) or run.world.records[id]["integrity"] < before or run.world.records[id]["shape"] == "fragments"))
	if is_instance_valid(hound): hound.take_damage(5000)
	clear()
	await frames(2)

func diver() -> void:
	player.health = 100
	var kite: Node = machine(911, Vector3(2.5, -1.1, -2.0), Enemy.DIVER)
	await frames(2)
	check("diver_flies", kite.airborne() and kite.global_position.y > player.global_position.y + 1.5)
	check("diver_casts_shadow", is_instance_valid(kite.shadow) and absf(kite.shadow.global_position.y - kite.ground_y) < 0.2)
	var health: float = kite.health
	run.clocks[1]["shot"] = 0
	run._flame(player, 1, run.clocks[1], run.builds[1]["tools"])
	check("flame_cannot_reach_flyer", kite.health == health)
	run._animas(player, 1, run.clocks[1], run.builds[1]["tools"])
	run._land_animas(1.0)
	check("animas_reach_flyer", kite.health < health)
	kite.health = 1000
	var touched: bool = false
	var before: float = player.health
	for i: int in 120:
		hold()
		await get_tree().physics_frame
		if player.health < before: touched = true
	check("diver_harmless_while_circling", not touched and kite.state in ["", "lock"])
	check("diver_locks_a_lane", await until(kite, "lock") and kite.marks.size() == 1)
	var lane: Vector3 = kite.state_to - kite.state_from
	var to_player: Vector3 = player.global_position - kite.state_from
	lane.y = 0
	to_player.y = 0
	check("lane_runs_through_operator", absf(lane.normalized().cross(to_player).y) < 0.6)
	before = player.health
	check("diver_dives", await until(kite, "dive"))
	check("diver_grounded_and_open", await until(kite, "grounded") and kite.exposure > 1.0 and not kite.airborne())
	check("dive_hits_on_lane", player.health < before)
	kite.take_damage(5000)
	# Steam beneath it throws it out of the air.
	clear()
	await frames(2)
	kite = machine(912, Vector3(-5, -1.1, 3), Enemy.DIVER)
	await frames(2)
	var made: Dictionary = run.world.execute(1, "create", 0, {"point": Vector3(kite.global_position.x, player.global_position.y - 1.08, kite.global_position.z)})
	run.world.execute(1, "heat", made.get("id", 0))
	check("steam_knocks_diver_down", await until(kite, "grounded", 60) and kite.state_value > 0.5)
	clear()
	await frames(2)

func drinker() -> void:
	player.health = 100
	var tank: Node = machine(921, Vector3(5.0, -1.1, -1.0), Enemy.DRINKER)
	var made: Dictionary = run.world.execute(1, "create", 0, {"point": player.global_position + Vector3(7.5, -1.08, -3.5)})
	var puddle: int = made.get("id", 0)
	check("drinker_seeks_water", await until(tank, "drink"))
	check("drinker_open_while_drinking", tank.exposure > 1.0 and tank.puddle_id == puddle)
	await until(tank, "")
	check("drinker_drains_puddle", not run.world.records.has(puddle) and tank.gulps == 1)
	await frames(30)
	check("drinker_swells", tank.swell > 1.05)
	check("drinker_aims_jet", await until(tank, "aim", 900) and tank.marks.size() == 1)
	var before: float = player.health
	check("drinker_fires", await until(tank, "spray"))
	check("jet_hits_on_lane", player.health < before)
	check("jet_leaves_water", run.world.records.values().any(func(r: Dictionary) -> bool: return r["material"] == "water"))
	tank.take_damage(5000)
	# Heat the puddle while it drinks: it inhales steam and stalls.
	clear()
	await frames(2)
	tank = machine(922, Vector3(5.0, -1.1, -1.0), Enemy.DRINKER)
	made = run.world.execute(1, "create", 0, {"point": player.global_position + Vector3(7.5, -1.08, -3.5)})
	await until(tank, "drink")
	var health: float = tank.health
	run.world.execute(1, "heat", made.get("id", 0))
	check("steam_scalds_drinker", await until(tank, "stunned", 30) and tank.health < health)
	clear()
	await frames(2)

func quiltro() -> void:
	await fresh_operator()
	var dog: Node = machine(931, Vector3(0, -1.1, -4.0), Enemy.PUMP)
	check("quiltro_bares_teeth_first", await until(dog, "bare"))
	var before: float = player.health
	check("quiltro_lunges", await until(dog, "lunge"))
	await until(dog, "")
	check("quiltro_bite_hurts", player.health < before)
	dog.take_damage(5000)
	# Fire sends it off; once it is brave again it comes back.
	clear()
	await frames(2)
	dog = machine(932, Vector3(1.5, -1.1, -1.5), Enemy.PUMP)
	dog.health = 1000
	await frames(2)
	var gap: float = dog.global_position.distance_to(player.global_position)
	run.clocks[1]["shot"] = 0
	run._flame(player, 1, run.clocks[1], run.builds[1]["tools"])
	run.clocks[1]["shot"] = 1000.0
	check("quiltro_flees_fire", dog.state == "flee")
	await frames(30)
	check("quiltro_runs_away", dog.global_position.distance_to(player.global_position) > gap + 1.0)
	check("quiltro_returns", await until(dog, "", 200) and dog.brave)
	run.clocks[1]["shot"] = 0
	run._flame(player, 1, run.clocks[1], run.builds[1]["tools"])
	run.clocks[1]["shot"] = 1000.0
	check("quiltro_flees_only_once", dog.state != "flee")
	# Soaked, it stops dead to shake.
	clear()
	await frames(2)
	dog = machine(933, Vector3(2.0, -1.1, -2.0), Enemy.PUMP)
	dog.health = 1000
	# A second dog beside the first, behind it from the operator: only the blast can reach it.
	var beside: Node = machine(934, Vector3(3.2, -1.1, -3.0), Enemy.PUMP)
	beside.health = 1000
	await frames(2)
	run.clocks[1]["shot"] = 0
	run.builds[1]["tools"]["split"] = 0
	run._animas(player, 1, run.clocks[1], run.builds[1]["tools"])
	check("animas_wait_for_flight", dog.health == 1000)
	run._land_animas(1.0)
	check("quiltro_shakes_when_soaked", dog.state == "shake")
	check("anima_blast_splashes_neighbour", beside.health < 1000 and beside.soaked > 0.0)
	for i: int in 36:
		hold()
		await get_tree().physics_frame
	check("quiltro_still_while_shaking", dog.state == "shake" and Vector2(dog.velocity.x, dog.velocity.z).length() < 0.5)
	clear()
	await frames(2)

func repartidor() -> void:
	await fresh_operator()
	var rider: Node = machine(941, Vector3(0, -1.1, -4.5), Enemy.RUNNER)
	check("repartidor_pings_lane", await until(rider, "ping") and rider.marks.size() == 1)
	var lane: Vector3 = rider.state_to - rider.state_from
	var to_player: Vector3 = player.global_position - rider.state_from
	lane.y = 0
	to_player.y = 0
	check("repartidor_lane_through_operator", absf(lane.normalized().cross(to_player).y) < 0.6 and lane.length() > to_player.length())
	var before: float = player.health
	check("repartidor_dashes", await until(rider, "dash"))
	check("repartidor_stumbles_open", await until(rider, "stumble") and rider.exposure > 1.0)
	check("repartidor_dash_hurts", player.health < before)
	rider.take_damage(5000)
	# A wall at the end of the lane stops him hard and takes the blow.
	clear()
	await frames(2)
	run.builds[1]["routines"] = [{"when": "cerca", "steps": ["wall", "cold"], "then": ""}]
	var wall: int = run.run_routine(1, 0, player.global_position + Vector3(0, 0, -2.4), Vector3.FORWARD)
	run.builds[1]["routines"] = []
	await frames(6)
	var integrity: float = run.world.records[wall]["integrity"] if run.world.records.has(wall) else 0.0
	rider = machine(942, Vector3(0, -1.1, -5.3), Enemy.RUNNER)
	rider.cooldown = 0.0
	check("repartidor_crashes_into_wall", await until(rider, "dazed", 120) and rider.state_value == rider.CRASH)
	check("crash_damages_wall", wall > 0 and (not run.world.records.has(wall) or run.world.records[wall]["integrity"] < integrity))
	if is_instance_valid(rider): rider.take_damage(5000)
	# Water across the lane takes his feet.
	clear()
	await frames(2)
	run.world.execute(1, "create", 0, {"point": player.global_position + Vector3(0, -1.08, -2.0)})
	rider = machine(943, Vector3(0, -1.1, -4.5), Enemy.RUNNER)
	rider.cooldown = 0.0
	check("repartidor_slips_on_water", await until(rider, "ping", 60) and rider.state_value == rider.SLIP)
	check("slip_puts_him_down", await until(rider, "dazed", 120))
	clear()
	await frames(2)

func animita() -> void:
	await fresh_operator()
	var shrine: Node = machine(951, Vector3(3.0, -1.1, 0.0), Enemy.HAULER)
	await frames(2)
	check("animita_tough_while_lit", shrine.exposure < 1.0)
	var before: float = player.health
	for i: int in 400:
		hold()
		await get_tree().physics_frame
		if player.health < before: break
	check("animita_contact_hurts", player.health < before)
	# Water puts the candles out and opens it up; fire brings the relight sooner.
	shrine.health = 1000
	shrine.state_time = 5.0
	shrine.soak(Vector3.RIGHT)
	check("animita_doused_by_water", shrine.state == "doused" and shrine.exposure > 1.0)
	for i: int in 20: shrine.burn(player.global_position)
	check("flame_hurries_relight", await until(shrine, "sputter", 90))
	check("animita_relights", await until(shrine, "", 90) and shrine.exposure < 1.0)
	shrine.soak(Vector3.RIGHT)
	check("animita_caught_resists_douse", shrine.state == "")
	shrine.take_damage(50000)
	# Its heat runs the crew's ice.
	await fresh_operator()
	var sheet: Dictionary = run.world.execute(1, "create", 0, {"point": player.global_position + Vector3(4.0, -1.08, 0)})
	await frames(2)
	run.world.execute(1, "freeze", sheet.get("id", 0))
	var id: int = sheet.get("id", -1)
	var integrity: float = run.world.records[id]["integrity"] if run.world.records.has(id) and run.world.records[id]["material"] == "ice" else -1.0
	shrine = machine(952, Vector3(6.4, -1.1, 0.0), Enemy.HAULER)
	await frames(90)
	check("animita_melts_ice", sheet.get("ok", false) and (not run.world.records.has(id) or run.world.records[id]["material"] != "ice" or run.world.records[id]["integrity"] < integrity))
	clear()
	await frames(2)

## The crew's gravity reaches the specialists' own motion: a well brings a flyer down and bends a
## leap or a charge into its lip; a repulsor breaks the bride's aim.
func gravity() -> void:
	# A well under a circling ray drags it down to the lip, dazed and open, but unburnt.
	await fresh_operator()
	var kite: Node = machine(961, Vector3(2.5, -1.1, -2.0), Enemy.DIVER)
	kite.health = 1000
	await frames(2)
	var health: float = kite.health
	var well: int = routine(["well"], kite.global_position + Vector3(2.0, 0, 0))
	check("well_grounds_diver", well > 0 and await until(kite, "grounded", 30) and kite.exposure > 1.0 and not kite.airborne() and kite.state_value > 0.5)
	await frames(30)
	check("diver_lands_at_well_lip", flat(kite.global_position - spot(well)) < 1.6 and absf(kite.global_position.y - kite.ground_y) < 0.3 and kite.health == health)
	kite.take_damage(5000)
	# A well beside a leap pulls the gargoyle off its mark; the slam is marked again where it falls.
	await fresh_operator()
	var hound: Node = machine(962, Vector3(0, -1.1, -5.5), Enemy.LEAPER)
	hound.health = 1000
	await until(hound, "crouch")
	var mark: Vector3 = hound.state_to
	well = routine(["well"], mark + Vector3(3.0, 0, -1.5))
	var bent: bool = false
	if await until(hound, "air", 120):
		for i: int in 10:
			hold()
			if hound.state_value == hound.PULLED and hound.marks.size() == 1: bent = true
			await get_tree().physics_frame
	check("well_bends_leap", well > 0 and bent)
	check("bent_leap_lands_at_lip", await until(hound, "exposed", 60) and flat(hound.global_position - spot(well)) < 2.0 and flat(hound.global_position - mark) > 1.5)
	if is_instance_valid(hound): hound.take_damage(5000)
	# A well beside the lane drags the rider's charge into it, and he goes down there.
	await fresh_operator()
	var rider: Node = machine(963, Vector3(0, -1.1, -4.5), Enemy.RUNNER)
	rider.health = 1000
	await until(rider, "ping")
	var end: Vector3 = rider.state_to
	well = routine(["well"], rider.state_from.lerp(end, 0.5) + Vector3(2.5, 0, 0))
	bent = false
	if await until(rider, "dash", 60):
		for i: int in 6:
			hold()
			if rider.state == "dash" and rider.state_value == rider.PULLED: bent = true
			await get_tree().physics_frame
	check("well_bends_dash", well > 0 and bent)
	check("bent_dash_puts_him_down", await until(rider, "dazed", 60) and rider.exposure > 1.0 and flat(rider.global_position - spot(well)) < 1.6 and flat(rider.global_position - end) > 1.5)
	if is_instance_valid(rider): rider.take_damage(5000)
	# A repulsor's wave while the bride takes aim chokes the wail: no jet, the water kept.
	await fresh_operator()
	var tank: Node = machine(964, Vector3(5.0, -1.1, -1.0), Enemy.DRINKER)
	tank.health = 1000
	tank.gulps = 1
	tank.cooldown = 0.0
	check("drinker_takes_aim", await until(tank, "aim", 120))
	var before: float = player.health
	var stood: Vector3 = tank.global_position
	var toward: Vector3 = player.global_position - stood
	toward.y = 0
	routine(["repel"], stood + toward.normalized() * 1.5)
	await frames(2) # The field acts on the next simulation tick.
	check("repel_breaks_drinker_aim", tank.state == "choke" and tank.marks.is_empty())
	await until(tank, "", 60)
	check("choked_drinker_staggers_back", flat(tank.global_position - stood) > 1.0 and tank.gulps == 1)
	check("choked_jet_never_fires", player.health >= before)
	tank.take_damage(5000)
	clear()
	await frames(2)

## One routine of `steps` cast at `point`, as the crew would. Returns its matter's id.
func routine(steps: Array, point: Vector3) -> int:
	run.builds[1]["routines"] = [{"when": "cerca", "steps": steps, "then": ""}]
	var id: int = run.run_routine(1, 0, point, Vector3.FORWARD)
	run.builds[1]["routines"] = []
	return id
func spot(id: int) -> Vector3:
	return run.world.records[id]["position"] if run.world.records.has(id) else Vector3.INF
static func flat(value: Vector3) -> float:
	return Vector2(value.x, value.z).length()

## Walker checks start from the same spot with a whole, unhurried operator.
func fresh_operator() -> void:
	clear()
	# Earlier kills drop salvage; a level-up would pause the yard mid-check.
	for pickup: Node in run.pickups.get_children(): pickup.queue_free()
	run.offers.clear()
	run.xp = 0
	run.set_phase("running")
	player.eliminated = false
	player.health = 100
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-3, 1.15, -2)
	await frames(6)

func director() -> bool:
	var seen: Dictionary = {}
	run.elapsed = 200.0
	for serial: int in range(1, 120):
		run._serial = serial
		seen[run.next_kind()] = true
	run.elapsed = 10.0
	var early: int = run.next_kind()
	return seen.has(Enemy.LEAPER) and seen.has(Enemy.DIVER) and seen.has(Enemy.DRINKER) and seen.has(Enemy.HAULER) and early == Enemy.PUMP
