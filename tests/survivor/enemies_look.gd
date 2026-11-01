## Staged real-engine frames of every enemy kind and each specialist's tell, for art review.
extends Node
const Enemy = preload("res://scripts/survivor/enemy.gd")
var scene: Node
var run: Node
var player: Character
var output: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "user://enemies_look"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("start")
func frames(count: int) -> void:
	for i: int in count: await get_tree().process_frame
func start() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var width: int = int(OS.get_environment("LOOK_WIDTH")) if OS.has_environment("LOOK_WIDTH") else 1600
	get_window().size = Vector2i(width, width * 9 / 16)
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Prueba", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(100)
	player = run.local_player()
	player.global_position = Vector3(-3, 1.15, 2)
	run.builds[1]["routines"] = []
	await frames(60)
	var me: Vector3 = player.global_position - Vector3(0, 1.1, 0)
	# Lineup: the walkers behind, the specialists in front of the operator.
	var id: int = 600
	for kind: int in [Enemy.PUMP, Enemy.RUNNER, Enemy.HAULER]:
		id += 1
		run.spawn_machine(id, me + Vector3(-3.5 + (kind) * 3.5, 0, -5.5), kind, 1.0)
	run.spawn_machine(611, me + Vector3(-4.0, 0, -2.0), Enemy.LEAPER, 1.0)
	run.spawn_machine(612, me + Vector3(3.5, 0, -2.5), Enemy.DIVER, 1.0)
	run.spawn_machine(613, me + Vector3(5.5, 0, -0.2), Enemy.DRINKER, 1.0)
	var puddle: Dictionary = run.world.execute(1, "create", 0, {"point": player.global_position + Vector3(6.8, -1.08, 0.4)})
	await frames(4)
	for enemy: Node in run.machines.get_children(): enemy.set_physics_process(false)
	run.set_physics_process(false)
	run.hud.hide()
	var leaper: Node = run.machines.get_node("Machine611")
	var diver: Node = run.machines.get_node("Machine612")
	var drinker: Node = run.machines.get_node("Machine613")
	for enemy: Node3D in [leaper, diver, drinker]: enemy.look_at(Vector3(me.x, enemy.global_position.y, me.z))
	# Tells: crouch with the landing ring, a locked dive lane, a planted drink.
	leaper.enter_state("crouch", leaper.global_position, me + Vector3(-1.0, 0.02, 0.4), 0)
	leaper.state_time = leaper.CROUCH * 0.7
	diver.enter_state("lock", Vector3(diver.global_position.x, me.y, diver.global_position.z), me + (me - Vector3(diver.global_position.x, me.y, diver.global_position.z)).normalized() * 3.5, 0)
	diver.state_time = diver.LOCK * 0.6
	drinker.enter_state("drink", drinker.global_position, run.world.records[puddle["id"]]["position"] if puddle.get("ok", false) else drinker.global_position, 1)
	drinker.state_time = 1.0
	await frames(30)
	await shot("01_tells")
	# Windows: leaper open after landing, diver grounded, drinker swollen and aiming.
	leaper.global_position = me + Vector3(-1.6, 0.02, -0.6)
	leaper.enter_state("exposed", leaper.global_position, leaper.global_position, 0)
	diver.global_position = me + Vector3(2.2, 0.05, 1.2)
	diver.enter_state("grounded", diver.global_position, diver.global_position, 0)
	drinker.enter_state("aim", drinker.global_position, drinker.global_position + (me - drinker.global_position).normalized() * 7.5, 3)
	drinker.state_time = 0.6
	await frames(60)
	await shot("02_windows")
	# Attacks: the gargoyle at the top of its leap, the ray mid-dive, the bride wailing the jet.
	leaper.enter_state("air", me + Vector3(-4.0, 0.02, -2.0), me + Vector3(-0.8, 0.02, 0.2), 0)
	leaper.global_position = leaper.state_from.lerp(leaper.state_to, 0.5) + Vector3.UP * leaper.APEX
	var start := Vector3(me.x + 4.5, me.y + diver.ALTITUDE, me.z - 3.0)
	diver.enter_state("dive", start, me + (me - Vector3(start.x, me.y, start.z)).normalized() * 3.5, 0)
	diver.ground_y = me.y
	diver.global_position = diver.dive_point(0.35)
	drinker.enter_state("spray", drinker.global_position, drinker.global_position + (me - drinker.global_position).normalized() * 7.5, 3)
	await frames(8)
	await shot("03_attacks")
	# The walkers' tells: a pack baring teeth, lunging and shaking off water, the rider's lane
	# pinging, and two shrines -- one burning, one doused with its door open.
	for enemy: Node in run.machines.get_children(): enemy.queue_free()
	await frames(2)
	var dogs: Array[Node] = []
	for i: int in 3:
		run.spawn_machine(620 + i, me + [Vector3(-2.6, 0, -1.4), Vector3(-1.4, 0, 1.8), Vector3(1.6, 0, -2.2)][i], Enemy.PUMP, 1.0)
		dogs.append(run.machines.get_node("Machine%d" % (620 + i)))
	run.spawn_machine(630, me + Vector3(-6.5, 0, -3.0), Enemy.RUNNER, 1.0)
	run.spawn_machine(640, me + Vector3(4.6, 0, -4.2), Enemy.HAULER, 1.0)
	run.spawn_machine(641, me + Vector3(5.2, 0, 0.8), Enemy.HAULER, 1.0)
	await frames(4)
	for enemy: Node in run.machines.get_children(): enemy.set_physics_process(false)
	dogs[0].enter_state("bare", dogs[0].global_position, me, 0)
	dogs[1].enter_state("lunge", dogs[1].global_position, me + Vector3(-0.4, 0, 0.6), 0)
	dogs[2].enter_state("shake", dogs[2].global_position, dogs[2].global_position, 0)
	var rider: Node = run.machines.get_node("Machine630")
	rider.enter_state("ping", rider.global_position, rider.global_position + (me - rider.global_position).normalized() * rider.DASH_REACH, 0)
	rider.state_time = rider.PING * 0.6
	run.machines.get_node("Machine641").enter_state("doused", run.machines.get_node("Machine641").global_position, run.machines.get_node("Machine641").global_position, 0)
	await frames(30)
	await shot("04_walkers")
	# The moments the attacks land: a slam's shockwave, the rider into a wall, a shrine put out.
	run.spawn_machine(650, me + Vector3(-1.2, 0, -3.4), Enemy.LEAPER, 1.0)
	await frames(2)
	var leaper2: Node = run.machines.get_node("Machine650")
	leaper2.set_physics_process(false)
	leaper2.enter_state("exposed", leaper2.global_position, leaper2.global_position, 0)
	rider.global_position = rider.state_to
	rider.enter_state("dazed", rider.state_from, rider.state_to, 1)
	run.machines.get_node("Machine641").enter_state("", run.machines.get_node("Machine641").global_position, run.machines.get_node("Machine641").global_position, 0)
	run.machines.get_node("Machine641").enter_state("doused", run.machines.get_node("Machine641").global_position, run.machines.get_node("Machine641").global_position, 0)
	await frames(7)
	await shot("05_impacts")
	get_tree().quit()
func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(title + ".png"))
	print("ENEMY LOOK ", title)
