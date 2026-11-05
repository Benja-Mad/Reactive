extends Node
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
	if not ok: push_error("SURVIVOR: " + key)
## The programmable matter, combined freely: the table the editor reads, then the host doing
## what it said.
func systemic_checks(Build: GDScript) -> void:
	var Recipe = preload("res://scripts/survivor/recipe.gd")
	var trace: Dictionary = Recipe.simulate(["fire", "raise", "cold", "coat"])
	check("recipe_no_step_stops_the_rest", trace["idle"].is_empty() and trace["state"]["suspended"] and trace["state"]["shape"] == "orb" and trace["state"]["material"] == "water" and trace["state"]["coat"] == 1)
	var ice: Dictionary = Recipe.simulate(["cold"])["state"]
	var steam: Dictionary = Recipe.simulate(["fire"])["state"]
	check("recipe_old_refusals_now_act", Recipe.step(ice, "cold")["op"] == "harden" and Recipe.step(steam, "fire")["op"] == "scald" and Recipe.step(Recipe.source(), "push")["op"] == "slide" and Recipe.step(ice, "raise")["op"] == "raise" and Recipe.step(Recipe.simulate(["coat"])["state"], "coat")["op"] == "charge")
	var every_then_works: bool = true
	for then: String in ["fragmentos", "detonar", "estallar", "cadena", "colapso"]:
		for steps: Array in [[], ["cold"], ["fire"], ["raise", "cold"], ["well"], ["repel", "coat"]]:
			var state: Dictionary = Recipe.simulate(steps)["state"]
			if Recipe.effect(state, then) == "" or Recipe.moment(state, then) == "": every_then_works = false
	check("every_then_works_on_every_matter", every_then_works)
	check("programming_words_in_english", Build.PIECES["cerca"]["name"] == "near" and Build.PIECES["fragmentos"]["name"] == "release" and Build.SLOT_NAMES["step"] == "DO")
	var readout: Array = Build.explain({"routines": [{"when": "cerca", "steps": ["raise", "cold"], "then": "cadena", "on": "broken"}, {"when": "eco", "steps": ["well"], "then": "colapso"}], "box": [], "tools": {"pressure": 0}}, 0)
	var keys: Array = readout.map(func(line: Array) -> String: return line[0])
	check("editor_reads_out_chain", "WHEN near" in keys and "DO" in keys and "THEN relay" in keys and readout.filter(func(line: Array) -> bool: return line[0] == "LINK").size() == 2)
	# Host: matter acting on machines. Weapons and the build's own triggers are held off.
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	for node: Node in run.machines.get_children(): node.queue_free()
	await frames(2)
	run.clocks[1]["shot"] = 1000.0
	for i: int in 4: run.clocks[1]["r%d" % i] = 1000.0
	var me: Vector3 = player.global_position
	var still := func(serial: int, offset: Vector3) -> Node:
		run.spawn_machine(serial, me + offset + Vector3(0, -1.1, 0), 0, 6.0)
		var made: Node = run.machines.get_node("Machine%d" % serial)
		made.speed = 0.0
		return made
	run.builds[1]["routines"] = [
		{"when": "cerca", "steps": ["well"], "then": ""},
		{"when": "cerca", "steps": ["repel"], "then": ""},
		{"when": "cerca", "steps": ["raise", "cold", "drop"], "then": ""},
		{"when": "cerca", "steps": [], "then": "fragmentos"},
	]
	var pulled: Node = still.call(980, Vector3(4.5, 0, -4))
	await frames(2)
	var well: int = run.run_routine(1, 0, me + Vector3(0, 0, -4), Vector3.LEFT)
	var before: float = pulled.global_position.distance_to(run.world.records[well]["position"])
	await frames(40)
	check("well_pulls_machines", run.world.records.has(well) and int(run.world.records[well].get("grav", 0)) > 0 and pulled.global_position.distance_to(run.world.records[well]["position"]) < before - 0.5)
	pulled.queue_free()
	run.world.execute(1, "remove", well)
	var pushed: Node = still.call(981, Vector3(5.5, 0, 2.5))
	await frames(2)
	var repulsor: int = run.run_routine(1, 1, me + Vector3(4, 0, 2.5), Vector3.LEFT)
	await frames(20)
	check("repel_pushes_machines", pushed.global_position.distance_to(run.world.records[repulsor]["position"]) > 2.2)
	pushed.queue_free()
	run.world.execute(1, "remove", repulsor)
	var crushed: Node = still.call(982, Vector3(0, 0, -5.4))
	await frames(2)
	var health: float = crushed.health
	var slab: int = run.run_routine(1, 2, me + Vector3(0, 0, -3.6), Vector3.FORWARD)
	check("dropped_wall_crushes", crushed.health < health)
	check("dropped_wall_shatters", not run.world.records.has(slab) or run.world.records[slab]["shape"] == "fragments")
	crushed.queue_free()
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	var splashed: Node = still.call(983, Vector3(3, 0, 3))
	await frames(2)
	var puddle: int = run.run_routine(1, 3, me + Vector3(3, 0, 3), Vector3.RIGHT)
	await frames(3)
	check("shrapnel_on_water_splashes", not run.world.records.has(puddle) and splashed.soaked > 0.0)
	splashed.queue_free()
	# A relay fires whatever THEN the other routine has; here, scalding steam's gust.
	run.builds[1]["routines"] = [
		{"when": "cerca", "steps": ["raise", "cold"], "then": "cadena", "on": "broken"},
		{"when": "cerca", "steps": ["fire"], "then": "fragmentos", "on": "pulse"},
		{"when": "cerca", "steps": ["raise"], "then": ""},
		{"when": "eco", "steps": ["fire"], "then": ""},
	]
	var cloud: int = run.run_routine(1, 1, me + Vector3(-3, 0, 2), Vector3.LEFT)
	var relay: int = run.run_routine(1, 0, me + Vector3(0, 0, -3.5), Vector3.FORWARD)
	check("relay_wired_to_next_routine", relay > 0 and run.world.records[relay].get("link", 0) == cloud)
	run.world.damage_construct(relay, 999.0)
	await frames(80)
	check("relay_fires_any_then", run.world.records.has(cloud) and not run.world.records[cloud].has("reaction"))
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	var count: int = run.world.records.size()
	run.run_routine(1, 2, me + Vector3(-3, 0, -2), Vector3.FORWARD)
	check("echo_fires_after_the_routine_above", run.world.records.size() == count + 2 and run.world.records.values().any(func(r: Dictionary) -> bool: return r["material"] == "steam"))
	# Earlier combat checks leave legitimate queued deaths. Isolate this event so
	# accelerated test runs do not mistake a different death for a duplicate firing.
	run.spellwork._kills.clear()
	var fallen_at: Vector3 = me + Vector3(3, 0, 0)
	run.spellwork.note_kill(fallen_at)
	var nobody: Array[Node3D] = []
	var kill_placement: Variant = run._placement(player, run.clocks[1], "derribo", nobody)
	check("on_kill_fires_where_it_fell", kill_placement != null and kill_placement[0] == fallen_at and run._placement(player, run.clocks[1], "derribo", nobody) == null)
	# On cue: nothing until a click, then there; a click beyond reach comes back to its edge.
	run.clocks[1].erase("cue")
	var idle_cue: Variant = run._placement(player, run.clocks[1], "mano", nobody)
	run.cue(me + Vector3(5, 0, 2))
	var near_cue: Variant = run._placement(player, run.clocks[1], "mano", nobody)
	run.cue(me + Vector3(40, 0, 0))
	var far_cue: Variant = run._placement(player, run.clocks[1], "mano", nobody)
	run.clocks[1].erase("cue")
	check("on_cue_fires_where_clicked", idle_cue == null and near_cue != null and Vector2(near_cue[0].x - me.x, near_cue[0].z - me.z).is_equal_approx(Vector2(5, 2)) and far_cue != null and absf(Vector2(far_cue[0].x - me.x, far_cue[0].z - me.z).length() - Build.DRAW_REACH) < 0.01)
	# A click on a machine marks it: it leads the list every routine picks from. «on near» still
	# answers the nearest when the mark is out of its reach.
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	var close: Node = still.call(995, Vector3(-3, 0, 0))
	var marked: Node = still.call(996, Vector3(0, 0, 7))
	await frames(2)
	var plain_first: bool = run.targets(player)[0] == close
	run.cue(marked.global_position + Vector3(1, 0, 0))
	run.clocks[1].erase("cue")
	var mark_first: bool = run.targets(player)[0] == marked
	var near_on_mark: Variant = run._placement(player, run.clocks[1], "cerca", run.targets(player))
	marked.global_position = me + Vector3(0, -1.1, 12)
	var near_falls_back: Variant = run._placement(player, run.clocks[1], "cerca", run.targets(player))
	# A mark out past the routines' reach is let go; a click that springs a trap marks nothing.
	marked.global_position = me + Vector3(0, -1.1, 20)
	run._automate(player, 1, 0.0)
	var unmarked: bool = not run.clocks[1].has("mark")
	marked.global_position = me + Vector3(0, -1.1, 12)
	var kept_routine: Dictionary = run.builds[1]["routines"][0].duplicate(true)
	run.builds[1]["routines"][0] = {"when": "cerca", "steps": [], "then": "estallar", "on": "mano"}
	var trap: int = run.spellwork.cast(1, 0, marked.global_position + Vector3(1.5, 0, 0), Vector3.RIGHT)
	if run.world.records.has(trap): run.world.records[trap]["reaction"]["after"] = 0.0
	run.cue(marked.global_position)
	var sprung_unmarked: bool = trap > 0 and not run.clocks[1].has("mark") and not (run.world.records.has(trap) and run.world.records[trap].has("reaction"))
	run.clocks[1].erase("cue")
	# The click aims what it lets go, and a mark nearby steers every throw; else the nearest.
	var plain_aim: Vector3 = run.spellwork._aim(me, Vector3.FORWARD)
	var clicked_aim: Vector3 = run.spellwork._aim(me, Vector3.FORWARD, 1, marked.global_position)
	run.clocks[1]["mark"] = marked
	var far_mark_aim: Vector3 = run.spellwork._aim(me, Vector3.FORWARD, 1)
	marked.global_position = me + Vector3(0, -1.1, 7)
	var mark_aim: Vector3 = run.spellwork._aim(me, Vector3.FORWARD, 1)
	var crew_aim: Vector3 = run.spellwork._aim(me, Vector3.FORWARD, 2)
	run.clocks[1].erase("mark")
	check("click_and_mark_aim_throws", plain_aim.x < -0.9 and clicked_aim.z > 0.9 and far_mark_aim.x < -0.9 and mark_aim.z > 0.9 and crew_aim.x < -0.9)
	run.builds[1]["routines"][0] = kept_routine
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	marked.queue_free()
	await frames(2)
	var after_gone: bool = run.targets(player)[0] == close
	close.queue_free()
	run.clocks[1].erase("mark")
	# On crowd: the group around your mark, once it is three, before a bigger group elsewhere.
	var crowd: Array[Node] = []
	for i: int in 3: crowd.append(still.call(980 + i, Vector3(6 + i * 1.2, 0, 0)))
	for i: int in 4: crowd.append(still.call(985 + i, Vector3(-6 - i * 1.2, 0, 0)))
	await frames(2)
	var crowd_seen: Array[Node3D] = run.targets(player)
	var biggest: Variant = run._placement(player, run.clocks[1], "grupo", crowd_seen)
	run.clocks[1]["mark"] = crowd[1]
	var marked_group: Variant = run._placement(player, run.clocks[1], "grupo", run.targets(player))
	run.clocks[1].erase("mark")
	for machine: Node in crowd: machine.queue_free()
	await frames(2)
	check("on_crowd_takes_the_marked_group", biggest != null and biggest[0].x < me.x and marked_group != null and marked_group[0].x > me.x)
	check("click_marks_a_machine", plain_first and mark_first and near_on_mark != null and near_on_mark[1].z > 0.9 and near_falls_back != null and near_falls_back[1].x < -0.9 and after_gone and unmarked and sprung_unmarked)
	# An edited routine runs once as play resumes, on the house: no cooldown spent.
	var before_edit: Array = run.builds[1]["routines"].duplicate(true)
	var after_edit: Array = before_edit.duplicate(true)
	after_edit[0]["steps"] = ["cold"]
	run.trials.clear()
	run._note_changes(1, before_edit, after_edit)
	var queued_ok: bool = run.trials.get(1, []) == [0]
	var clock_before: float = float(run.clocks[1].get("r0", 0.0))
	var heard_before: Dictionary = Sfx.of(run).played.duplicate()
	run._run_trials(1.0)
	check("edited_routine_runs_once", queued_ok and run.trials.is_empty() and run.spellwork.casting(1) and is_equal_approx(float(run.clocks[1].get("r0", 0.0)), clock_before))
	# The program is heard: the trial's WHEN and its DO play where the HUD lights them.
	for i: int in 90:
		await get_tree().physics_frame
		if not run.spellwork.casting(1): break
	var heard: Dictionary = Sfx.of(run).played
	check("program_is_heard", int(heard.get("draw", 0)) > int(heard_before.get("draw", 0)) and int(heard.get("step", 0)) + int(heard.get("idle", 0)) > int(heard_before.get("step", 0)) + int(heard_before.get("idle", 0)))
	run.spellwork._casts.clear()
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	await rule_checks(Build, me)
	for i: int in 4: run.clocks[1]["r%d" % i] = 0.0
	run.clocks[1]["shot"] = 0.2

## The four rules, each on its own, on machines held still. Rule beats are driven by hand so a
## physics frame cannot spend a charge or a temp before the check reads it.
func rule_checks(Build: GDScript, me: Vector3) -> void:
	var Recipe = preload("res://scripts/survivor/recipe.gd")
	var Catalog = preload("res://scripts/matter/materials.gd")
	var rules: Node = run.spellwork.rules
	var world: Node = run.world
	var make := func(kind: int, serial: int, offset: Vector3) -> Node:
		run.spawn_machine(serial, me + offset + Vector3(0, -1.1, 0), kind, 6.0)
		var made: Node = run.machines.get_node("Machine%d" % serial)
		made.speed = 0.0
		return made
	var beat := func(list: Array[Node3D]) -> void:
		rules._clock = 0.0
		rules.tick(0.0, list)
	var lay := func(at: Vector3) -> int:
		return int(world.execute(1, "create", 0, {"point": Vector3(at.x, me.y - 1.08, at.z)}).get("id", 0))
	var clean := func() -> void:
		for id: int in world.records.keys(): world.execute(1, "remove", id)
	# Heat. A wet machine on ice freezes in place; boiling steam burns; the flame dries what is wet
	# before it heats it; a machine burning at +2 boils the water it stands in.
	var dog: Node = make.call(0, 990, Vector3(-4, 0, 5))
	await frames(2)
	var one: Array[Node3D] = [dog]
	# Water does not freeze under a machine; the sheet is made beside it and the machine set on it.
	var ice: int = 0
	for spot: Vector3 in [Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4), Vector3(4, 0, 4)]:
		ice = lay.call(me + spot)
		if world.execute(1, "freeze", ice).get("ok", false): break
		world.execute(1, "remove", ice)
	dog.global_position = Vector3(world.records[ice]["position"].x, dog.global_position.y, world.records[ice]["position"].z) if world.records.has(ice) else dog.global_position
	dog.soak(Vector3.ZERO)
	beat.call(one)
	check("rule_heat_wet_machine_freezes_on_ice", dog.frozen > 0.0 and dog.temp == -1 and not dog.wet())
	clean.call()
	var steam: int = lay.call(dog.global_position)
	world.execute(1, "heat", steam)
	world.execute(1, "scald", steam)
	var health: float = dog.health
	dog.soaked = 0.0
	beat.call(one)
	check("rule_heat_boiling_steam_burns", dog.health < health and dog.temp == 1)
	clean.call()
	dog.temp = 0
	dog.soak(Vector3.ZERO)
	rules.ignite(dog, me)
	var dried: bool = not dog.wet() and dog.temp == 0
	rules.ignite(dog, me)
	check("rule_heat_flame_dries_then_heats", dried and dog.temp == 1)
	dog.temp = 2
	var puddle: int = lay.call(dog.global_position)
	beat.call(one)
	check("rule_heat_burning_machine_boils_water", world.records.has(puddle) and world.records[puddle]["material"] == "steam")
	clean.call()
	dog.queue_free()
	# Conduction. A charged puddle beside a wet pack: one charge runs 3 jumps, two run 6; dry
	# flesh takes the first hit and stops it.
	var pack: Array[Node3D] = []
	for i: int in 4: pack.append(make.call(0, 991 + i, Vector3(-6.0 + i * 2.0, 0, -6)))
	await frames(2)
	var hurt := func() -> int:
		var hit: int = 0
		for machine: Node3D in pack: if machine.health < 66.0 - 0.01: hit += 1
		return hit
	var reset := func(wet: bool) -> void:
		for machine: Node3D in pack:
			machine.health = 66.0
			machine.soaked = 1.6 if wet else 0.0
	reset.call(true)
	var pool: int = lay.call(pack[0].global_position + Vector3(-2.0, 0, 0))
	world.execute(1, "arc", pool)
	beat.call(pack)
	check("rule_arc_runs_through_wet_pack", hurt.call() == 3 and int(world.records[pool].get("charge", 0)) == 0)
	reset.call(true)
	world.execute(1, "arc", pool)
	world.execute(1, "arc", pool)
	beat.call(pack)
	check("rule_arc_double_charge_runs_further", hurt.call() == 4 and int(rules.stats["longest"]) >= 4)
	reset.call(false)
	world.execute(1, "arc", pool)
	beat.call(pack)
	check("rule_arc_stops_at_dry_flesh", hurt.call() == 1)
	clean.call()
	for machine: Node3D in pack: machine.queue_free()
	# Gravity by mass: the same well drags the heavy wax shrine harder than a quiltro; charged, it
	# is a magnet and holds the metal courier.
	var light: Node = make.call(0, 996, Vector3(4, 0, -9))
	var heavy: Node = make.call(2, 997, Vector3(-4, 0, -9))
	var courier: Node = make.call(1, 998, Vector3(1.0, 0, -8.6))
	await frames(2)
	var well: int = lay.call(me + Vector3(0, 0, -9))
	world.execute(1, "well", well)
	for machine: Node3D in [light, heavy, courier]:
		machine.shove = Vector3.ZERO
		machine.frozen = 0.0
	run.spellwork._forces(world.records[well], 0.05)
	check("rule_gravity_same_acceleration", absf(heavy.shove.length() - light.shove.length()) < 0.15)
	world.execute(1, "arc", well)
	run.spellwork._forces(world.records[well], 0.05)
	check("rule_charge_does_not_invent_magnet", courier.frozen == 0.0 and light.frozen == 0.0)
	clean.call()
	for machine: Node3D in [light, heavy, courier]: machine.queue_free()
	# Impulse: mass times speed. Ice hits about twice as hard as water at the same speed; steam barely.
	var body := func(material: String, shape: String) -> Dictionary: return {"material": material, "shape": shape}
	check("rule_impulse_mass_times_speed", Catalog.impact(body.call("ice", "patch"), 7.0) > Catalog.impact(body.call("water", "patch"), 7.0) * 1.8 and Catalog.impact(body.call("steam", "cloud"), 7.0) < 2.0 and Catalog.impact(body.call("ice", "fragments"), 30.0) <= Catalog.IMPULSE_CAP)
	# The editor says it from the same rules: fire and cold move temp, arc charges, and every
	# routine reads out what its matter does to what it touches.
	var cold: Dictionary = Recipe.simulate(["cold", "cold"])["state"]
	var fire: Dictionary = Recipe.simulate(["fire", "fire"])["state"]
	check("fire_and_cold_move_temp", cold["temp"] == -2 and cold["hard"] and fire["temp"] == 2 and fire["scald"] and Build.PIECES["fire"]["name"] == "heat" and Build.PIECES["cold"]["name"] == "cold")
	var arc_lines: Array = Build.explain({"routines": [{"when": "cerca", "steps": ["arc"], "then": ""}], "box": [], "tools": {"pressure": 0}}, 0)
	var cold_lines: Array = Build.explain({"routines": [{"when": "cerca", "steps": ["cold"], "then": ""}], "box": [], "tools": {"pressure": 0}}, 0)
	var said := func(lines: Array, word: String) -> bool: return lines.any(func(line: Array) -> bool: return line[0] == "TOUCH" and word in line[1])
	check("editor_touch_line_from_rules", said.call(arc_lines, "3 saltos") and said.call(cold_lines, "congela") and Recipe.simulate(["arc", "arc", "arc"])["idle"] == [2])
	# DO gates ask the machine nearest the matter. A dry, cold one: «if wet» and «if hot» say no,
	# and the DO after the gate is skipped. Soaked, then hot: they say yes and it runs.
	var asked: Node = make.call(0, 993, Vector3(6, 0, -6))
	await frames(2)
	asked.soaked = 0.0
	asked.temp = 0
	var spot: int = lay.call(asked.global_position + Vector3(1.2, 0, 0))
	var dry_no: bool = not run.spellwork.gate("si_mojada", spot) and not run.spellwork.gate("si_arde", spot)
	asked.soak(Vector3.ZERO)
	var wet_yes: bool = run.spellwork.gate("si_mojada", spot)
	asked.soaked = 0.0
	asked.temp = 1
	var hot_yes: bool = run.spellwork.gate("si_arde", spot)
	var unmarked_no: bool = not run.spellwork.gate("si_marcada", spot)
	run.clocks[1]["mark"] = asked
	var marked_yes: bool = run.spellwork.gate("si_marcada", spot)
	run.clocks[1].erase("mark")
	world.execute(1, "remove", spot)
	check("do_gate_asks_the_nearest_machine", dry_no and wet_yes and hot_yes and unmarked_no and marked_yes)
	var kept: Dictionary = run.builds[1]["routines"][0].duplicate(true)
	run.builds[1]["routines"][0] = {"when": "cerca", "steps": ["si_arde", "cold"], "then": "", "on": "contact"}
	var passed: int = run.spellwork.cast(1, 0, asked.global_position + Vector3(1.2, 0, 0), Vector3.FORWARD)
	var passed_left: String = world.records[passed]["material"] if world.records.has(passed) else ""
	if world.records.has(passed): world.execute(1, "remove", passed)
	asked.temp = 0
	var plain: int = run.spellwork.cast(1, 0, asked.global_position + Vector3(1.2, 0, 0), Vector3.FORWARD)
	var plain_left: String = world.records[plain]["material"] if world.records.has(plain) else ""
	if world.records.has(plain): world.execute(1, "remove", plain)
	# Two conditions stacked add up: the first one's no skips the second and the DO they guard.
	run.builds[1]["routines"][0] = {"when": "cerca", "steps": ["si_arde", "si_mojada", "cold"], "then": "", "on": "contact"}
	var stacked: int = run.spellwork.cast(1, 0, asked.global_position + Vector3(1.2, 0, 0), Vector3.FORWARD)
	var stacked_left: String = world.records[stacked]["material"] if world.records.has(stacked) else ""
	if world.records.has(stacked): world.execute(1, "remove", stacked)
	check("stacked_gates_add_up", stacked_left == "water")
	run.builds[1]["routines"][0] = kept
	asked.queue_free()
	check("do_gate_skips_the_next_do", passed_left == "ice" and plain_left == "water" and Build.problem({"when": "cerca", "steps": ["cold", "si_mojada"], "then": ""}) != "" and Build.put(Build.fresh(), "si_mojada", {"routine": Build.ATTACK, "index": 0}).is_empty())
	# Combos: fire from routine 1 put out on water from routine 2 joins the two rows; matter from
	# one routine reacting with itself does not.
	var heard: Array = []
	var listen := func(peer: int, a: int, b: int) -> void: heard.append([peer, a, b])
	run.spellwork.combo.connect(listen)
	run.spellwork._combo_at.clear()
	var pond: int = lay.call(me + Vector3(-6, 0, -6))
	var flame: int = int(world.execute(1, "create", 0, {"point": Vector3(me.x - 6, me.y - 1.08, me.z - 6), "material": "fire"}).get("id", 0))
	if world.records.has(pond): world.records[pond]["routine"] = 1
	if world.records.has(flame): world.records[flame]["routine"] = 0
	var none: Array[Node3D] = []
	rules._contact(none)
	run.spellwork.combo.disconnect(listen)
	clean.call()
	check("combo_joins_two_routines", heard.size() == 1 and heard[0] == [1, 0, 1])
	# Through a machine: wet by routine 2's water, then shocked by routine 1's charge, or frozen
	# by routine 3's cold, while still wet. A weapon's zap credits nobody.
	heard.clear()
	run.spellwork.combo.connect(listen)
	run.spellwork._combo_at.clear()
	var target: Node = make.call(0, 994, Vector3(-6, 0, 6))
	await frames(2)
	target.soak(Vector3.ZERO)
	run.spellwork.wet_by(target, {"owner": 1, "routine": 1})
	rules._acting = {"owner": 1, "routine": 0}
	rules._shock(target, {}, PackedVector3Array())
	var shock_heard: bool = heard.size() == 1 and heard[0] == [1, 0, 1]
	target.soak(Vector3.ZERO)
	rules._heat({"id": -1, "owner": 1, "routine": 2, "material": "ice", "shape": "patch", "temp": -1, "states": ["solid"], "attachments": {}}, target)
	var freeze_heard: bool = heard.size() == 2 and heard[1] == [1, 1, 2]
	heard.clear()
	if is_instance_valid(target) and not target.down:
		target.soak(Vector3.ZERO)
		rules.zap(target, 0, [] as Array[Node3D])
	run.spellwork.combo.disconnect(listen)
	if is_instance_valid(target): target.queue_free()
	check("combo_through_a_wet_machine", shock_heard and freeze_heard and heard.is_empty())

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
	check("manual_console_removed", not scene.has_node("MatterConsole"))
	check("industrial_worker_present", player.has_node("ShiftWorker") and not player.animated_sprite_3d.visible)
	check("old_editor_hidden", not player.programming_block.visible and not player.programming_block.is_processing_input())
	# Existing floor/solid validation must still apply to automatic construction.
	run.builds[1] = preload("res://scripts/survivor/build.gd").fresh()
	run.clocks[1] = {"shot": 0.2, "heal": 3.0, "trail": player.global_position, "made": {}, "r0": 0.0}
	check("placement_rejects_invalid_ground", run.run_routine(1, 0, Vector3(200, 0, 200), Vector3.FORWARD) == 0)
	# Routines draw the yard's water: a burst main beside the operator.
	var main: int = run.world.add_source(Vector3(-1, 0.1, -2))
	run.spawn_machine(990, Vector3(-3, 0.05, -7), 0, 1.0)
	var enemy: Node = run.machines.get_node("Machine990")
	var initial: float = enemy.health
	await frames(70)
	check("attacks_without_input", not is_instance_valid(enemy) or enemy.health < initial)
	check("automatic_barrier_placed", run.world.records.values().any(func(record: Dictionary) -> bool: return record["owner"] == 1))
	check("automatic_routine_drew_water", run.world.records.has(main) and float(run.world.records[main]["volume"]) < 3.0)
	# Armed once its last step lands, a beat after the water arrives; the thrown orb may already
	# have broken and spent it.
	await frames(40)
	check("barrier_has_reaction", run.clocks[1]["made"].has(0))
	for node: Node in run.machines.get_children(): node.queue_free()
	await frames(2)
	# Pursuit is checked independently of killing speed.
	run.clocks[1]["shot"] = 100
	run.spawn_machine(991, Vector3(-3, 0.05, 4), 1, 1.0)
	enemy = run.machines.get_node("Machine991")
	var before: float = enemy.global_position.distance_to(player.global_position)
	await frames(30)
	check("mobile_enemy_pursues", enemy.global_position.distance_to(player.global_position) < before)
	enemy.take_damage(1000)
	await frames(2)
	check("kill_earns_pickup", run.kills > 0 and run.pickups.get_child_count() > 0)
	for pickup: Node3D in run.pickups.get_children(): pickup.global_position = player.global_position
	await frames(3)
	check("movement_collects_xp", run.collected > 0)
	# A real level-up pauses the world, validates offers and resumes after a choice.
	run.gain_xp(20)
	await frames(2)
	check("level_up_pauses", run.phase == "upgrade" and get_tree().paused)
	var time_before: float = run.elapsed
	await frames(3)
	check("upgrade_freezes_clock", run.elapsed == time_before)
	var offered: Array = run.offers.get(1, [])
	check("three_legal_choices", offered.size() == 3)
	var Build = preload("res://scripts/survivor/build.gd")
	var original: Dictionary = run.builds[1].duplicate(true)
	run.choose_upgrade("not_an_upgrade")
	check("rejects_unoffered_choice", run.builds[1] == original)
	var piece: String = ""
	for key: String in offered:
		if not Build.is_tool_key(key): piece = key
	check("offers_include_pieces", piece != "")
	if piece != "":
		var owned_before: int = int(Build.owned(run.builds[1]).get(piece, 0))
		run.choose_upgrade(piece, 1)
		var routine: Dictionary = run.builds[1]["routines"][1]
		check("piece_lands_where_asked", int(Build.owned(run.builds[1]).get(piece, 0)) == owned_before + 1 and (piece in routine["steps"] or routine["when"] == piece or routine["then"] == piece))
	# Clear a second queued level, if excess XP earned it.
	while run.phase == "upgrade": run.choose_upgrade(run.offers[1][0])
	check("choice_resumes", run.phase == "running" and not get_tree().paused)
	# The player's own routines, built from pieces, run through real world operations.
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	run.builds[1]["routines"] = [
		{"when": "cerca", "steps": ["raise", "cold", "coat"], "then": "cadena", "on": "broken"},
		{"when": "rastro", "steps": ["coat"], "then": "detonar"},
		{"when": "grupo", "steps": ["fire"], "then": ""},
	]
	run.builds[1]["box"] = []
	var mine: int = run.run_routine(1, 1, player.global_position + Vector3(4, 0, 3), Vector3.FORWARD)
	check("routine_trail_mine", mine > 0 and run.world.records[mine].get("reaction", {}).get("action", "") == "detonar" and run.world.records[mine]["attachments"].has("nanites"))
	var wall: int = run.run_routine(1, 0, player.global_position + Vector3(0, 0, -3.2), Vector3.FORWARD)
	check("routine_ice_orb", wall > 0 and run.world.records[wall]["material"] == "ice" and run.world.records[wall]["shape"] == "orb")
	check("routine_reaction_armed", wall > 0 and run.world.records[wall].has("reaction"))
	check("routine_relay_links", wall > 0 and run.world.records[wall].get("link", 0) == mine)
	var cloud: int = run.run_routine(1, 2, player.global_position + Vector3(-4, 0, 3), Vector3.FORWARD)
	check("routine_steam", cloud > 0 and run.world.records[cloud]["material"] == "steam")
	check("idle_step_explains", Build.problem({"when": "cada", "steps": ["raise", "raise"], "then": ""}).contains("raise"))
	await systemic_checks(Build)
	# Triggers fire on their own: a machine walking up arms the "cerca" routine with no input.
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	run.clocks[1]["r0"] = 0
	run.spawn_machine(992, player.global_position + Vector3(0, -1.1, -6), 0, 1)
	await frames(3)
	run._automate(player, 1, 0.1)
	check("trigger_draws_without_input", run.spellwork.casting(1))
	for beat: int in 8: run.spellwork.tick(0.5)
	check("trigger_fires_without_input", run.world.records.values().any(func(r: Dictionary) -> bool: return r["material"] == "ice"))
	# Workshop: rearranging owned pieces is accepted, inventing pieces is not.
	run.set_phase("paused")
	var moved: Dictionary = Build.unplace(run.builds[1], 0, "then")
	run.submit_build(moved)
	check("workshop_accepts_rearrange", run.builds[1]["box"] == ["cadena"] and run.builds[1]["routines"][0]["then"] == "")
	var forged: Dictionary = run.builds[1].duplicate(true)
	forged["box"].append("estallar")
	run.submit_build(forged)
	check("workshop_rejects_new_pieces", "estallar" not in run.builds[1]["box"])
	run.set_phase("running")
	# The corner plate: a click on a routine's row pauses and opens the workshop on it.
	var plate: Rect2 = run.hud._program_rect()
	var on_first: Variant = run.hud.row_at(plate.position + Vector2(20, 4 * run.hud.PX + run.hud.LINE_H + 4))
	var on_weapon: Variant = run.hud.row_at(plate.position + Vector2(20, 4 * run.hud.PX))
	var off_plate: Variant = run.hud.row_at(plate.end + Vector2(40, 40))
	run.hud.open_row(on_first)
	await frames(3)
	var opened: bool = run.phase == "paused" and run.hud._editor != null and run.hud._editor.focus == 0
	run.set_phase("running")
	check("plate_row_opens_workshop", on_first == 0 and on_weapon == Build.ATTACK and off_plate == null and opened)
	# Node editor model: lifting and setting pieces keeps exactly the pieces owned.
	var sample: Dictionary = Build.fresh()
	sample["box"] = ["push", "detonar"]
	var lifted: Array = Build.take(sample, {"routine": -1, "index": 0})
	var inserted: Dictionary = Build.put(lifted[0], lifted[1], {"routine": 0, "slot": "step", "index": 0})
	check("editor_inserts_step_in_order", inserted["routines"][0]["steps"] == ["push", "raise", "cold", "push"] and Build.same_pieces(inserted, sample))
	var swapped: Dictionary = Build.put(Build.take(sample, {"routine": -1, "index": 1})[0], "detonar", {"routine": 0, "slot": "then"})
	check("editor_replaced_piece_returns_to_box", swapped["routines"][0]["then"] == "detonar" and "fragmentos" in swapped["box"])
	check("editor_rejects_wrong_slot", Build.put(sample, "push", {"routine": 0, "slot": "when"}).is_empty())
	# A level-up placed through the editor: the host takes the whole rearranged build.
	run.gain_xp(Build.threshold(run.level))
	await frames(2)
	var piece_offer: String = ""
	for key: String in run.offers.get(1, []):
		if not Build.is_tool_key(key) and Build.PIECES[key]["slot"] == "step": piece_offer = key
	if piece_offer != "":
		var proposal: Dictionary = run.builds[1].duplicate(true)
		proposal["routines"][2]["steps"].insert(0, piece_offer)
		run.choose_upgrade(piece_offer, -1, proposal)
		check("levelup_accepts_editor_build", run.builds[1]["routines"][2]["steps"][0] == piece_offer)
	while run.phase == "upgrade": run.choose_upgrade(run.offers[1][0])
	# Weapons: the torch burns in a short cone, the ánimas push machines back and leave water.
	for node: Node in run.machines.get_children(): node.queue_free()
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	await frames(2)
	run.spawn_machine(993, player.global_position + Vector3(0, -1.1, -3.5), 2, 4.0)
	run.spawn_machine(994, player.global_position + Vector3(0, -1.1, -9.5), 2, 4.0)
	await frames(2)
	var close: Node = run.machines.get_node("Machine993")
	var distant: Node = run.machines.get_node("Machine994")
	var close_health: float = close.health
	var distant_health: float = distant.health
	run.clocks[1]["shot"] = 0
	run._flame(player, 1, run.clocks[1], run.builds[1]["tools"])
	check("flame_burns_close", close.health < close_health)
	check("flame_is_short_range", distant.health == distant_health)
	run.spawn_machine(995, player.global_position + Vector3(0, -1.1, -5.7), 2, 4.0)
	await frames(2)
	var mid: Node = run.machines.get_node("Machine995")
	var mid_health: float = mid.health
	run.clocks[1]["shot"] = 0
	run._flame(player, 1, run.clocks[1], run.builds[1]["tools"])
	check("flame_reaches_mid_range", mid.health < mid_health)
	mid.take_damage(1000)
	close.take_damage(1000)
	await frames(2)
	run._animas(player, 1, run.clocks[1], run.builds[1]["tools"])
	run._land_animas(1.0)
	check("animas_shove_and_soak", distant.shove.length() > 0.5 and distant.soaked > 0.0)
	check("animas_leave_puddle", run.world.records.values().any(func(r: Dictionary) -> bool: return r["owner"] == run.world.YARD and not r.get("source", false)))
	for node: Node in run.machines.get_children(): node.queue_free()
	# Normal spawns must actually find usable floor.
	var count: int = run.machines.get_child_count()
	for i: int in 5: run.spawn_near_player()
	check("director_spawns_on_map", run.machines.get_child_count() > count)
	# Hit protection and run death replace infinite respawns.
	player.health = 100
	player.hurt_time = 0
	player.receive_health(-9)
	player.receive_health(-9)
	check("contact_has_invulnerability", player.health == 91)
	player.hurt_time = 0
	player.receive_health(-100)
	await frames(3)
	check("death_does_not_respawn", player.eliminated and player.health == 0)
	check("death_ends_run", run.phase == "lost")
	run.set_phase("running")
	player.eliminated = false
	player.health = 100
	run.elapsed = run.DURATION - 0.01
	await frames(3)
	check("surviving_finishes_shift", run.phase == "won")
	get_tree().paused = false
	print("SURVIVOR CHECKS ", JSON.stringify(checks))
	get_tree().quit(1 if false in checks.values() else 0)
