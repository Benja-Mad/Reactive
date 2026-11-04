## Real-engine frames of every interface screen, for art review: the menu, host, join, credits,
## the crew screen, then a run with its HUD, a level-up, placing the new piece, the workshop and
## the end of the shift. LOOK_DIR picks the folder; LOOK_ONLY=menu,hud,... limits the set.
extends Node
var output: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "user://ui_look"
var only: PackedStringArray = OS.get_environment("LOOK_ONLY").split(",", false) if OS.has_environment("LOOK_ONLY") else PackedStringArray()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("start")

func frames(count: int) -> void:
	for i: int in count: await get_tree().process_frame

func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(title + ".png"))
	print("UI LOOK ", title)

func wanted(title: String) -> bool:
	return only.is_empty() or title in only

func screen(path: String, title: String) -> void:
	if not wanted(title): return
	var node: Node = load(path).instantiate()
	add_child(node)
	await frames(30)
	await shot(title)
	node.queue_free()
	await frames(2)

func start() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size = Vector2i(1600, 900)
	Game.instance.multiplayer_test = false
	await screen("res://ui/main_menu.tscn", "menu")
	await screen("res://lobby/host_screen.tscn", "host")
	await screen("res://lobby/join_screen.tscn", "join")
	await screen("res://ui/credits.tscn", "credits")
	Game.instance.solo = true
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Operador", 0, Statics.Role.SUPPORT)]
	await screen("res://lobby/waiting_screen.tscn", "crew")
	if not (wanted("hud") or wanted("pulse") or wanted("levelup") or wanted("place") or wanted("workshop") or wanted("end")):
		get_tree().quit()
		return
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	var run: Node = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(90)
	var build: Dictionary = run.builds[1]
	build["routines"] = [
		{"when": "cerca", "steps": ["raise", "si_marcada", "cold"], "then": "cadena"},
		{"when": "grupo", "steps": ["si_mojada", "arc", "si_marcada", "fire"], "then": ""},
		{"when": "eco", "steps": ["fire", "fire"], "then": "fragmentos", "on": "mano"},
		{"when": "mano", "steps": ["well", "arc"], "then": ""},
	]
	build["box"] = ["push", "drop", "estallar"]
	run.level = 3
	run.kills = 37
	run.publish()
	await frames(40)
	if wanted("hud"): await shot("hud")
	if wanted("pulse"):
		# Routines 1 and 2 fired by hand (3 echoes 2), a frame every three: the program in the
		# corner lighting each piece as the yard carries it out.
		var me: Vector3 = run.local_player().global_position
		run.spellwork.begin(1, 0, me + Vector3(4, 0, 0), Vector3(1, 0, 0))
		run.spellwork.begin(1, 1, me + Vector3(-3, 0, 3), Vector3(-1, 0, 0))
		for i: int in 48:
			# A combo between routines 1 and 3 partway, as the rules would report one.
			if i == 6: run.spellwork.combo_fx(1, 0, 2)
			await frames(3)
			await shot("pulse_%02d" % i)
	run.offers[1] = ["arc", "pressure", "eco"]
	run.set_phase("upgrade")
	await frames(10)
	if wanted("levelup"): await shot("levelup")
	run.hud._picking = "arc"
	await frames(10)
	if wanted("place"): await shot("place")
	run.hud._picking = ""
	run.offers.clear()
	run.set_phase("paused")
	await frames(10)
	if wanted("workshop"): await shot("workshop")
	run.set_phase("won")
	await frames(10)
	if wanted("end"): await shot("end")
	get_tree().quit()
