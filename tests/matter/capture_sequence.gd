extends Node
var world: Node
var arena: Node
var out: String
var events: Array = []
func _ready() -> void: call_deferred("run")
func capture(name: String, frames: int = 25) -> void:
	for i in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920,1080)
	Game.instance.players = [Statics.PlayerData.new(1,"Operador",0,Statics.Role.DAMAGE)]
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	arena = scene.get_node("Arena")
	world = scene.get_node("WorldMatter")
	world.matter_event.connect(func(event: Dictionary): events.append(event))
	for i in 90: await get_tree().physics_frame
	var player: Character = scene.get_node("Players").get_child(0)
	player.programming_block.code_block.release_focus()
	# Freeze only the test actors' attacks so the primitive sequence stays visible.
	for sentry: Node in get_tree().get_nodes_in_group("yard_sentries"): sentry.set_physics_process(false)
	var origin := Vector3(-3,0.06,-6)
	var result: Dictionary = world.execute(1,"create",0,{"point":origin})
	assert(result["ok"])
	var id: int = result["id"]
	await capture("01_water")
	assert(world.execute(1,"raise",id,{"vector":Vector3(4,0,-1)})["ok"])
	await capture("02_raised")
	assert(world.execute(1,"freeze",id)["ok"])
	await capture("03_ice")
	assert(world.execute(1,"coat",id,{"coating":"nanites"})["ok"])
	await capture("04_coated")
	assert(world.execute(1,"impact",id)["ok"])
	await capture("05_fragments",8)
	assert(world.execute(1,"push",id,{"vector":Vector3(-9,0,-2)})["ok"])
	await capture("06_impulse",10)
	if world.records.has(id):
		world.execute(1,"command",id,{"command":"detonate"})
		await capture("07_detonation",1)
	var sentry: Node3D = get_tree().get_nodes_in_group("yard_sentries")[0]
	var health_before: float = sentry.health
	var near_sentry: Vector3 = sentry.global_position + Vector3(1.8,0.0,1.0)
	var created: Dictionary = world.execute(1,"create",0,{"point":near_sentry})
	assert(created["ok"])
	world.execute(1,"coat",created["id"])
	world.execute(1,"command",created["id"],{"command":"detonate"})
	assert(sentry.health < health_before)
	FileAccess.open(out.path_join("sentry_damage.json"),FileAccess.WRITE).store_string(JSON.stringify({"before":health_before,"after":sentry.health},"  "))
	FileAccess.open(out.path_join("events.json"),FileAccess.WRITE).store_string(JSON.stringify(events,"  "))
	print("MATTER CAPTURE COMPLETE ",out)
	get_tree().quit()
