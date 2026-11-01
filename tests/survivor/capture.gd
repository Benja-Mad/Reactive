extends Node
var scene: Node
var run: Node
var out: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/survivor_20261016"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("capture")
func frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame
func shot(file: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("SURVIVOR SHOT ", file)
func capture() -> void:
	get_window().size = _wide()
	Game.instance.multiplayer_test = false
	var support: bool = "support" in OS.get_cmdline_user_args()
	Game.instance.players = [Statics.PlayerData.new(1, "Operador", 0, Statics.Role.SUPPORT if support else Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(60)
	var player: Character = scene.get_node("Players").get_child(0)
	player.global_position = Vector3(-3, 1.15, -2)
	await frames(100)
	if "rules" in OS.get_cmdline_user_args():
		await capture_rules(player)
		return
	run.builds[1]["routines"] = [
		{"when": "cerca", "steps": ["raise", "cold", "push"], "then": "fragmentos", "on": "broken"},
		{"when": "grupo", "steps": ["well", "coat"], "then": "detonar", "on": "timer"},
		{"when": "eco", "steps": ["fire", "fire"], "then": "fragmentos"},
		{"when": "rastro", "steps": ["raise", "arc", "push"], "then": "estallar", "on": "contact"},
	]
	run.builds[1]["box"] = ["push", "repel", "colapso", "derribo"]
	for i: int in 12:
		var angle: float = i * TAU / 12
		run.spawn_machine(100 + i, player.global_position + Vector3(cos(angle), 0, sin(angle)) * (7 + i % 3), i % 3, 2)
	for i: int in 7:
		run.spawn_pickup(i + 100, player.global_position + Vector3(-4 + i * 1.5, -1, -3.5 - i % 2), 1)
	run.clocks[1]["trail"] = player.global_position + Vector3.RIGHT * 5
	player.velocity = Vector3.RIGHT * 3
	run._automate(player, 1, 0.1)
	await frames(45)
	# Stop just the simulation to inspect an actual gameplay frame, with the HUD in its play state.
	run.set_physics_process(false)
	for node: Node in run.machines.get_children(): node.set_physics_process(false)
	await shot("gameplay")
	# Gravity in the yard: a well (with the echo's scalding steam beside it) among the machines.
	run.spellwork.cast(1, 1, player.global_position + Vector3(3.5, -1.1, 1.5), Vector3.RIGHT)
	var repulsor: int = run.spellwork.cast(1, 0, player.global_position + Vector3(-3.5, -1.1, -2.0), Vector3.LEFT)
	if run.world.records.has(repulsor): run.world.execute(1, "repel", repulsor, {"vector": Vector3.LEFT})
	await frames(12)
	await shot("gravity")
	run.hud.hide()
	await shot("yard")
	run.hud.show()
	run.offers[1] = ["cold", "estallar", "pressure"]
	run.set_phase("upgrade")
	await shot("upgrades")
	run.hud._picking = "estallar"
	await shot("placement")
	run.hud._picking = ""
	get_window().size = Vector2i(960, 540)
	await shot("upgrades_small")
	get_window().size = _wide()
	run.set_phase("paused")
	await shot("pause")
	# Each routine on the preview screen, caught at its reaction.
	for row: int in 4:
		run.hud._editor.focus = row
		run.hud._editor._time = [3.15, 3.0, 3.2, 3.62][row]
		await shot("workshop_row%d" % (row + 1))
	# A piece in hand from the box, hovering the first slot that would take it.
	var editor: Control = run.hud._editor
	for node: Dictionary in editor._nodes:
		if node["key"] != "" and int(node["where"]["routine"]) < 0:
			editor._pick(node)
			break
	for target: Dictionary in editor._targets:
		if target.has("result"):
			editor._mouse = (target["rect"] as Rect2).get_center()
			break
	editor.queue_redraw()
	await shot("workshop_place")
	editor.cancel()
	run.set_phase("lost")
	await shot("result")
	get_tree().paused = false
	scene.queue_free()
	await frames(3)
	get_tree().quit()

## LOOK_WIDTH captures at another 16:9 window width (2304 is the default window on a Retina Mac).
func _wide() -> Vector2i:
	var width: int = int(OS.get_environment("LOOK_WIDTH")) if OS.get_environment("LOOK_WIDTH") != "" else 1600
	return Vector2i(width, width * 9 / 16)

## The rules at work in the yard, and the workshop reading them out (`-- rules`).
func capture_rules(player: Character) -> void:
	run.builds[1]["routines"] = [
		{"when": "cerca", "steps": ["raise", "cold", "push"], "then": "fragmentos", "on": "broken"},
		{"when": "grupo", "steps": ["arc", "arc"], "then": ""},
		{"when": "eco", "steps": ["fire", "fire"], "then": "fragmentos"},
		{"when": "rastro", "steps": ["well", "arc"], "then": ""},
	]
	run.builds[1]["box"] = ["push", "repel", "cold", "derribo"]
	var me: Vector3 = player.global_position
	var rules: Node = run.spellwork.rules
	var world: Node = run.world
	var fx: Node3D = run.spellwork._fx
	fx.steady = true
	var still: Array[Node3D] = []
	var place := func(serial: int, kind: int, at: Vector3) -> Node3D:
		run.spawn_machine(serial, Vector3(at.x, me.y - 1.1, at.z), kind, 6)
		var made: Node3D = run.machines.get_node("Machine%d" % serial)
		made.speed = 0.0
		still.append(made)
		return made
	# A wet pack beside a charged puddle (conduction), two soaked quiltros on an ice sheet (heat:
	# frozen), and two machines burning near a scalding cloud.
	var pack: Array[Node3D] = []
	for i: int in 4: pack.append(place.call(200 + i, i % 2, me + Vector3(3.0 + i * 1.9, 0, -2.5 + (i % 2) * 0.8)))
	var cold: Array[Node3D] = [place.call(210, 0, me + Vector3(-5.0, 0, 2.6)), place.call(211, 0, me + Vector3(-3.6, 0, 3.4))]
	var hot: Array[Node3D] = [place.call(220, 0, me + Vector3(3.2, 0, 4.2)), place.call(221, 1, me + Vector3(5.0, 0, 3.6))]
	await frames(4)
	for machine: Node3D in still: machine.set_physics_process(false)
	var lay := func(at: Vector3) -> int:
		return int(world.execute(1, "create", 0, {"point": Vector3(at.x, me.y - 1.08, at.z)}).get("id", 0))
	var ice: int = lay.call(me + Vector3(-4.3, 0, 3.0))
	world.execute(1, "freeze", ice)
	world.execute(1, "harden", ice)
	var cloud: int = lay.call(me + Vector3(4.2, 0, 5.6))
	world.execute(1, "heat", cloud)
	world.execute(1, "scald", cloud)
	var pool: int = lay.call(me + Vector3(1.2, 0, -2.2))
	for machine: Node3D in pack + cold: machine.soaked = 30.0
	for machine: Node3D in hot:
		machine.temp = 2
		machine.temp_hold = 99.0
	rules._clock = 0.0
	rules.tick(0.0, cold)
	for machine: Node3D in cold: machine.temp_hold = 99.0
	world.execute(1, "arc", pool)
	world.execute(1, "arc", pool)
	rules._clock = 0.0
	rules.tick(0.0, pack)
	for machine: Node3D in pack: machine.charge_hold = 99.0
	# A charged well a little apart: a magnet, sparking, its rings drawn.
	var magnet: int = lay.call(me + Vector3(-4.5, 0, -3.5))
	world.execute(1, "well", magnet)
	world.execute(1, "arc", magnet)
	run.set_physics_process(false)
	world.set_physics_process(false)
	for arc: Dictionary in fx._arcs: arc["left"] = 99.0
	await frames(2)
	world._publish()
	await shot("rules_yard")
	run.hud.hide()
	await shot("rules_yard_clean")
	run.hud.show()
	run.set_phase("paused")
	await frames(3)
	if run.hud._editor == null: run.hud._rebuild()
	for row: int in 4:
		run.hud._editor.focus = row
		run.hud._editor._time = [3.15, 3.6, 3.2, 3.6][row]
		await shot("rules_workshop_row%d" % (row + 1))
	get_tree().paused = false
	scene.queue_free()
	await frames(3)
	get_tree().quit()

