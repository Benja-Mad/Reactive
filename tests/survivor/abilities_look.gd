## Real-engine frames of the crew's abilities in use, for art review: Brasa's flame or El Sereno's
## ánimas (LOOK_ROLE=support) on a held pack, with the impact bursts, and the matter the routines
## make -- a puddle, an ice wall, ice shards and a steam cloud -- set down beside them.
extends Node
const Enemy = preload("res://scripts/survivor/enemy.gd")
var scene: Node
var run: Node
var player: Character
var output: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "user://abilities_look"
var support: bool = OS.get_environment("LOOK_ROLE") == "support"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("start")
func frames(count: int) -> void:
	for i: int in count: await get_tree().process_frame
func start() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size = Vector2i(1600, 900)
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Prueba", 0, Statics.Role.SUPPORT if support else Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(100)
	player = run.local_player()
	player.global_position = Vector3(-3, 1.15, 2)
	run.builds[1]["routines"] = []
	run.builds[1]["tools"]["split"] = 2
	run.hud.hide()
	await frames(30)
	var me: Vector3 = player.global_position - Vector3(0, 1.1, 0)
	# The routines' matter, off to the side.
	var floor_y: float = me.y + 0.02
	var puddle: Dictionary = run.world.execute(1, "create", 0, {"point": Vector3(me.x - 6.0, floor_y, me.z - 3.5)})
	var wall: Dictionary = run.world.execute(1, "create", 0, {"point": Vector3(me.x - 6.5, floor_y, me.z + 1.0)})
	run.world.execute(1, "raise", wall.get("id", 0), {"vector": Vector3.RIGHT * 4})
	run.world.execute(1, "freeze", wall.get("id", 0))
	var steam: Dictionary = run.world.execute(1, "create", 0, {"point": Vector3(me.x + 6.0, floor_y, me.z - 4.0)})
	run.world.execute(1, "heat", steam.get("id", 0))
	var shards: Dictionary = run.world.execute(1, "create", 0, {"point": Vector3(me.x + 6.5, floor_y, me.z + 1.5)})
	run.world.execute(1, "raise", shards.get("id", 0), {"vector": Vector3.RIGHT * 4})
	run.world.execute(1, "freeze", shards.get("id", 0))
	for id: int in run.world.records: run.world.records[id]["ttl"] = 1000.0
	if shards.get("ok", false): run.world.damage_construct(shards["id"], 1000.0)
	# A pack to fire at, held where it stands.
	var id: int = 700
	for offset: Vector3 in [Vector3(2.2, 0, -1.0), Vector3(3.2, 0, 0.6), Vector3(2.6, 0, -2.4), Vector3(-2.4, 0, -2.0)]:
		id += 1
		run.spawn_machine(id, me + offset, Enemy.PUMP, 1.0)
		run.machines.get_node("Machine%d" % id).health = 100000.0
		run.machines.get_node("Machine%d" % id).speed = 0.0
	await frames(6)
	# LOOK_STRIP=n saves n frames in a row instead (LOOK_MOVE=1 walks the operator meanwhile), to
	# judge motion: the flame holding to the palm, the ánimas' paths.
	var strip: int = int(OS.get_environment("LOOK_STRIP")) if OS.has_environment("LOOK_STRIP") else 0
	if strip > 0:
		var walking: bool = OS.get_environment("LOOK_MOVE") == "1"
		for i: int in strip:
			if walking: player.global_position += Vector3(0.05, 0, 0.02)
			await frames(1)
			await shot("strip_%02d" % i)
		get_tree().quit()
		return
	for i: int in 3:
		await frames(9 if i == 0 else 5)
		await shot(("animas_%d" if support else "flame_%d") % i)
	get_tree().quit()
func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(title + ".png"))
	print("ABILITY LOOK ", title)
