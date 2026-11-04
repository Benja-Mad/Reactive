extends "res://tests/survivor/validate.gd"
const Recipe = preload("res://scripts/survivor/recipe.gd")
const Build = preload("res://scripts/survivor/build.gd")
var at := Vector3(1, 0.07, -1)
var detonations: int = 0
func clear_case() -> void:
	for id: int in run.world.records.keys(): run.world.execute(1, "remove", id)
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	await frames(2)
func cast(steps: Array, then: String, on: String) -> int:
	run.builds[1]["routines"] = [{"when": "cerca", "steps": steps, "then": then, "on": on}]
	return run.spellwork.cast(1, 0, at, Vector3.RIGHT)
func test() -> void:
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Prueba", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(50)
	player = run.local_player()
	player.global_position = Vector3(-3, 1.15, -2)
	run.set_physics_process(false)
	run.world.set_physics_process(false)
	run.spellwork.rules.enabled = false
	run.world.matter_event.connect(func(event: Dictionary):
		if event["kind"] == "detonated": detonations += 1)
	await clear_case()
	for steps: Array in [[], ["raise"], ["cold"], ["fire"]]:
		var id: int = cast(steps, "estallar", "timer")
		run.spellwork.tick(1.9)
		check("timer_waits_" + str(steps), run.world.records.has(id) and run.world.records[id].has("reaction"))
		run.spellwork.tick(0.11)
		check("timer_fires_" + str(steps), not run.world.records.has(id) or not run.world.records[id].has("reaction"))
		await clear_case()
	var id: int = cast(["raise", "cold"], "fragmentos", "broken")
	run.spellwork.tick(3)
	check("break_waits_for_actual_fracture", run.world.records[id].has("reaction"))
	run.world.damage_construct(id, 999)
	run.spellwork.tick(0.01)
	check("break_launches_shards_once", run.world.records[id]["shape"] == "fragments" and not run.world.records[id].has("reaction") and run.world.records[id]["velocity"].length() > 0)
	await clear_case()
	id = cast(["raise"], "estallar", "pulse")
	run.spellwork.tick(9)
	check("pulse_has_no_secret_timeout", run.world.records[id].has("reaction"))
	run.world.deliver_pulse(id)
	run.spellwork.tick(0.01)
	check("pulse_fires_selected_action", not run.world.records.has(id))
	await clear_case()
	id = cast(["raise"], "estallar", "contact")
	run.world.deliver_pulse(id)
	run.spellwork.tick(0.01)
	check("pulse_does_not_override_contact", run.world.records[id].has("reaction"))
	await clear_case()
	# Damage is tied to material/energy, not a generic explosion hidden in every reaction.
	for steps: Array in [[], ["fire"], ["fire", "fire"], ["coat"]]:
		id = cast(steps, "estallar", "contact")
		run.spawn_machine(910, at + Vector3(0.4, 0, 0), 0, 1)
		var enemy: Node = run.machines.get_node("Machine910")
		enemy.set_physics_process(false)
		enemy.temp = 0
		enemy.health = 100
		var blasts: int = detonations
		run.spellwork.tick(0.01)
		check("contact_fires_" + str(steps), not run.world.records.has(id) or not run.world.records[id].has("reaction"))
		check("scatter_never_detonates_" + str(steps), detonations == blasts)
		if steps == ["fire", "fire"]: check("hot_steam_burns", enemy.health < 100)
		else: check("no_free_explosion_" + str(steps), enemy.health == 100)
		if steps in [[], ["coat"]]: check("water_scatter_wets_" + str(steps), enemy.wet())
		await clear_case()
	for coated: bool in [false, true]:
		id = cast(["coat"] if coated else [], "detonar", "timer")
		var blasts: int = detonations
		run.spellwork.tick(2.1)
		check("detonation_requires_coat_" + str(coated), (detonations > blasts) == coated)
		check("detonation_keeps_water_" + str(coated), run.world.records.has(id) and run.world.records[id]["material"] == "water" and run.world.records[id]["attachments"].is_empty())
		await clear_case()
	# Heat melts solid ice rather than shattering it, and every water shape wets on touch.
	id = cast(["raise", "cold"], "", "contact")
	run.spawn_machine(911, at + Vector3(0.8, 0, 0), 0, 1)
	var hot: Node = run.machines.get_node("Machine911")
	hot.set_physics_process(false)
	hot.temp = 2
	run.spellwork.rules._heat(run.world.records[id], hot)
	check("heat_melts_without_shattering", run.world.records[id]["material"] == "water" and run.world.records[id]["shape"] == "orb")
	hot.temp = 0
	run.spellwork.rules._heat(run.world.records[id], hot)
	check("suspended_water_wets_on_contact", hot.wet())
	await clear_case()
	id = cast(["raise", "arc"], "estallar", "contact")
	run.spawn_machine(912, at + Vector3(0.4, 0, 0), 0, 1)
	var charged_target: Node = run.machines.get_node("Machine912")
	charged_target.set_physics_process(false)
	charged_target.health = 100
	run.spellwork.rules.enabled = true
	run.spellwork.rules._clock = 0.4
	run.spellwork.tick(0.01)
	check("contact_discharges_before_spending_carrier", charged_target.health < 100 and not run.world.records.has(id))
	# On click: the THEN waits for the player's click, not for a machine; a click right as it is
	# made does not spend it.
	await clear_case()
	var clicked: int = cast([], "estallar", "mano")
	var waits: bool = run.world.records.has(clicked) and run.world.records[clicked].has("reaction")
	var too_soon: int = run.spellwork.release(1)
	for i: int in 3: run.spellwork.tick(0.2)
	var still_waits: bool = run.world.records.has(clicked) and run.world.records[clicked].has("reaction")
	var not_theirs: int = run.spellwork.release(2)
	var let_go: int = run.spellwork.release(1)
	check("then_on_click_waits_for_the_click", waits and too_soon == 0 and still_waits and not_theirs == 0 and let_go == 1 and not (run.world.records.has(clicked) and run.world.records[clicked].has("reaction")))
	# Real editor input edits ON without changing owned pieces.
	var editor = preload("res://scripts/survivor/node_editor.gd").new()
	add_child(editor)
	editor.size = Vector2(1152, 600)
	editor.setup(Build.fresh())
	editor._reaction_button = Rect2(20, 400, 250, 30)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(30, 410)
	editor._gui_input(click)
	check("editor_click_changes_trigger", editor.draft["routines"][0]["on"] == "timer" and Build.same_pieces(editor.draft, Build.fresh()))
	print("BENDING REACTIONS ", JSON.stringify(checks))
	get_tree().quit(1 if false in checks.values() else 0)
