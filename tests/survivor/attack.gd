## The basic attack is programmed with the same DO pieces as a routine: bare, a weapon only hurts
## (and Brasa's fire heats); each piece plugged in adds one thing to every hit, at most once every
## half second on any one machine, and the editor reads it out from the same profile.
extends "res://tests/survivor/validate.gd"
const Build = preload("res://scripts/survivor/build.gd")
const Attack = preload("res://scripts/survivor/attack.gd")
const NodeEditor = preload("res://scripts/survivor/node_editor.gd")

func clear_world() -> void:
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id, {"remote": true})
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	await frames(2)

func machine(id: int, offset: Vector3, kind: int = 0) -> Node3D:
	run.spawn_machine(id, player.global_position + Vector3(0, -1.1, 0) + offset, kind, 20.0)
	var enemy: Node3D = run.machines.get_node("Machine%d" % id)
	enemy.set_physics_process(false)
	return enemy

## Brasa fires once with `steps` plugged in.
func flame(steps: Array) -> void:
	run.builds[1]["attack"]["steps"] = steps
	run.clocks[1]["shot"] = 0.0
	run._flame(player, 1, run.clocks[1], run.builds[1]["tools"])

## The next half-second beat, so a machine takes a hit's extras again.
func next_beat() -> void:
	run.elapsed += run.STRIKE_BEAT + 0.05

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
	run.clocks[1] = {"shot": 1000.0, "heal": 1000.0, "trail": player.global_position, "made": {}}
	run.reserves[1] = run.fresh_reserve("fire")

	# --- The profile, read the same by host and editor ------------------------------------------
	check("bare_fire_heats", Attack.profile([], "fire")["temp"] == 1 and Attack.profile([], "water")["temp"] == 0)
	check("heat_piece_ignites", Attack.profile(["fire"], "fire")["temp"] == 2)
	check("cold_turns_the_flame", Attack.profile(["cold", "cold"], "fire")["temp"] == -1)
	check("opposite_fields_idle", Attack.profile(["well", "repel"], "water")["trace"][1]["idle"])
	check("fresh_build_has_empty_attack", Build.attack_steps(Build.fresh()).is_empty())
	var boxed: Dictionary = Build.fresh()
	boxed["box"] = ["arc", "push", "coat", "wall"]
	var lifted: Array = Build.take(boxed, {"routine": -1, "index": 0})
	var armed: Dictionary = Build.put(lifted[0], lifted[1], {"routine": Build.ATTACK, "index": 0})
	check("box_piece_goes_into_attack", Build.attack_steps(armed) == ["arc"] and armed["box"].size() == 3)
	check("attack_pieces_are_owned", Build.same_pieces(armed, boxed))
	var full: Dictionary = armed
	for key: String in ["push", "coat"]: full = Build.put(Build.take(full, {"routine": -1, "index": 0})[0], key, {"routine": Build.ATTACK, "index": 9})
	check("attack_holds_three", Build.attack_steps(full).size() == 3 and Build.put(full, "wall", {"routine": Build.ATTACK, "index": 0}).is_empty())
	var wrong: Dictionary = Build.fresh()
	wrong["attack"]["steps"] = ["cerca"]
	check("attack_takes_only_do", not Build.well_formed(wrong, 2))
	check("level_up_can_plug_in", Build.attack_steps(Build.place(Build.fresh(), "arc", Build.ATTACK)) == ["arc"])
	check("editor_reads_attack", Build.explain_attack(armed, "fire")[1][1].contains("descarga"))

	# --- Brasa's flame, bare and programmed ------------------------------------------------------
	var target: Node3D = machine(900, Vector3(0, 0, -3))
	await frames(2)
	var health: float = target.health
	flame([])
	check("bare_flame_hurts_and_heats", target.health < health and target.temp == 1 and target.shove.length() < 0.01)
	flame([])
	check("extras_once_per_beat", target.temp == 1)
	next_beat()
	flame([])
	check("next_beat_heats_again", target.temp == 2)
	await clear_world()
	var pushed: Node3D = machine(901, Vector3(0, 0, -3))
	await frames(2)
	flame(["push"])
	check("push_piece_shoves", pushed.shove.length() > 3.0)
	await clear_world()
	var wet: Node3D = machine(902, Vector3(0, 0, -3))
	await frames(2)
	wet.soak(Vector3.ZERO)
	flame(["cold", "cold"])
	check("cold_flame_freezes_the_wet", wet.frozen > 0.0)
	await clear_world()
	var first: Node3D = machine(903, Vector3(0, 0, -3), 1)
	var second: Node3D = machine(904, Vector3(2.4, 0, -2.2), 1)
	await frames(2)
	var second_health: float = second.health
	flame(["arc"])
	check("charged_hit_jumps_through_metal", second.health < second_health)
	await clear_world()
	var coated: Node3D = machine(905, Vector3(0, 0, -3))
	var beside: Node3D = machine(906, Vector3(1.2, 0, -3))
	await frames(2)
	flame(["coat"])
	check("coat_plants_nanites", coated.nanites == 1)
	var beside_health: float = beside.health
	beside.nanites = 0
	coated.take_damage(10000)
	check("nanites_go_off_when_it_falls", beside.health < beside_health)
	await clear_world()
	var trod: Node3D = machine(907, Vector3(0, 0, -3))
	await frames(2)
	var carried: int = run.reserves[1]["fire"]
	flame(["wall"])
	check("wall_leaves_fire_from_the_reserve", run.reserves[1]["fire"] == carried - 1 and run.world.records.values().any(func(record: Dictionary) -> bool: return record["material"] == "fire"))
	await clear_world()
	run.reserves[1]["fire"] = 0
	var dry: Node3D = machine(908, Vector3(0, 0, -3))
	await frames(2)
	flame(["wall"])
	check("wall_needs_something_carried", run.world.records.is_empty())
	await clear_world()
	var kite: Node3D = machine(909, Vector3(0, 0, -3), 4)
	await frames(2)
	var kite_health: float = kite.health
	flame([])
	check("bare_flame_misses_flyers", kite.health == kite_health)
	flame(["raise"])
	check("raised_flame_reaches_flyers", kite.health < kite_health)
	await clear_world()
	# Drop: only what was raised falls, as in a routine; then a ball comes down where the lead is.
	check("drop_needs_raise_first", Attack.profile(["drop"], "fire")["trace"][0]["idle"] and Attack.profile(["drop", "raise"], "fire")["trace"][0]["idle"])
	check("drop_after_raise_falls", Attack.profile(["raise", "drop"], "fire")["slam"] and not Attack.profile(["raise", "drop"], "fire")["trace"][1]["idle"])
	check("drop_says_why_idle", Attack.profile(["drop"], "water")["trace"][0]["text"].contains("raise"))
	await clear_world()
	var under: Node3D = machine(910, Vector3(0, 0, -4))
	var flanker: Node3D = machine(911, Vector3(1.2, 0, -4))
	var clear_of: Node3D = machine(912, Vector3(-3.5, 0, -4))
	var overhead: Node3D = machine(915, Vector3(0.6, 0, -4), 4)
	await frames(2)
	run.elapsed += 10.0
	var healths: Array[float] = [under.health, flanker.health, clear_of.health, overhead.health]
	flame(["raise", "drop"])
	var after_flame: Array[float] = [under.health, flanker.health, clear_of.health, overhead.health]
	check("ball_goes_up_first", run._falling.size() == 1)
	check("ball_aimed_at_the_lead", Vector2(run._falling[0]["at"].x - under.global_position.x, run._falling[0]["at"].z - under.global_position.z).length() < 0.5)
	flame(["raise", "drop"])
	check("one_ball_at_a_time", run._falling.size() == 1)
	flanker.temp = 0
	run._land_falls(Attack.FALL_TIME + 0.05)
	check("ball_lands", run._falling.is_empty())
	check("ball_hits_what_is_under", after_flame[0] - under.health >= Attack.WEAPON["fire"]["fall"] * 0.9)
	check("ball_hits_round_it", after_flame[1] - flanker.health >= Attack.WEAPON["fire"]["fall"] * 0.6)
	check("ball_spares_the_clear", clear_of.health == after_flame[2])
	check("ball_brings_down_flyer", not overhead.airborne() and overhead.health < after_flame[3])
	check("fire_ball_heats", flanker.temp >= 1)
	await clear_world()
	await clear_world()
	var lead: Node3D = machine(913, Vector3(0, 0, -2.5))
	var flank: Node3D = machine(914, Vector3(1.8, 0, -5))
	await frames(2)
	flame(["well"])
	var toward: Vector3 = lead.global_position - flank.global_position
	check("attract_gathers_the_pack", flank.shove.length() > 1.0 and Vector2(flank.shove.x, flank.shove.z).dot(Vector2(toward.x, toward.z)) > 0.0)
	await clear_world()

	# --- The Sereno's ánimas -------------------------------------------------------------------------
	var hailed: Node3D = machine(920, Vector3(0, 0, -6))
	await frames(2)
	var burst := func(steps: Array) -> void:
		run._anima_blast({"at": hailed.global_position, "peer": 1, "from": player.global_position, "damage": 5.0, "lead": false, "hit": Attack.profile(steps, "water")}, hailed)
	burst.call([])
	check("bare_animas_soak", hailed.soaked > 0.0 and hailed.frozen <= 0.0)
	hailed.soaked = 0.0
	next_beat()
	burst.call(["cold"])
	check("hail_chills_then_wets", hailed.temp == -1 and hailed.soaked > 0.0 and hailed.frozen <= 0.0)
	next_beat()
	burst.call(["cold"])
	check("hail_freezes_what_it_wet", hailed.frozen > 0.0)
	await clear_world()
	var steamed: Node3D = machine(921, Vector3(0, 0, -6))
	await frames(2)
	run._anima_blast({"at": steamed.global_position, "peer": 1, "from": player.global_position, "damage": 5.0, "lead": false, "hit": Attack.profile(["fire", "fire"], "water")}, steamed)
	check("steam_animas_burn_and_stay_dry", steamed.soaked <= 0.0 and steamed.temp >= 1)
	await clear_world()

	# --- The editor shows the attack as its own row --------------------------------------------------
	var editor: Control = NodeEditor.new()
	editor.size = Vector2(900, 600)
	add_child(editor)
	editor.weapon = "water"
	editor.setup(armed)
	var weapon_node: Array = editor._nodes.filter(func(node: Dictionary) -> bool: return node["slot"] == "weapon")
	var attack_piece: Array = editor._nodes.filter(func(node: Dictionary) -> bool: return int(node["where"].get("routine", 0)) == Build.ATTACK and node["key"] == "arc")
	check("editor_has_attack_row", weapon_node.size() == 1 and attack_piece.size() == 1)
	check("editor_routines_sit_below", (editor._row_node(0, "when")["rect"] as Rect2).position.y > (weapon_node[0]["rect"] as Rect2).end.y)
	editor._pick(attack_piece[0])
	check("attack_piece_can_go_back_to_box", editor._targets.any(func(target: Dictionary) -> bool: return target.get("box", false)))
	editor.queue_free()

	print("ATTACK CHECKS ", JSON.stringify(checks))
	get_tree().quit(1 if false in checks.values() else 0)
