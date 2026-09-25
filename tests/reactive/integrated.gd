extends Node
var checks: Dictionary = {}
var scene: Node
var world: Node
var out: String
func _ready() -> void: call_deferred("run")
func wait_frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func check(key: String, value: bool) -> void:
	checks[key] = value
	if not value: push_error("REACTIVE: " + key)
func shot(sentry: Node, player: Node) -> void:
	sentry.cycle = 3.7
	sentry.target_path = player.get_path()
	sentry.warning.global_position = player.global_position
	sentry._physics_process(0.01)
func capture(file: String) -> void:
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file+".png"))
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920,1080)
	Game.instance.players = [Statics.PlayerData.new(1,"Operador",0,Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	world = scene.get_node("WorldMatter")
	await wait_frames(60)
	var player: Character = scene.get_node("Players").get_child(0)
	player.programming_block.code_block.release_focus()
	player.global_position = Vector3(-3,0.1,-2)
	var sentries: Array = get_tree().get_nodes_in_group("yard_sentries")
	for sentry: Node in sentries: sentry.set_physics_process(false)
	var gun: Node3D = sentries[0]
	gun.global_position = Vector3(-3,0.05,-12)
	await wait_frames(3)
	var runner: Node = world.get_node("Programs")
	check("reject_arbitrary_program",not runner.valid({"steps":["eval"],"trigger":"broken","action":"push"}))
	var result: Dictionary = runner.start(1,{"steps":["raise","freeze","coat"],"trigger":"broken","action":"push"},Vector3(-3,0.07,-6),Vector3.FORWARD)
	check("routine_started",result.get("ok",false))
	var id: int = result.get("id",0)
	await wait_frames(60)
	check("routine_built_and_armed",world.records.has(id) and world.records[id].has("reaction") and world.records[id]["material"] == "ice")
	if not world.records.has(id): get_tree().quit(1); return
	var hp: float = player.health
	shot(gun,player)
	check("cover_protects_player",player.health == hp)
	check("enemy_damages_cover",world.records[id]["integrity"] == 12.0)
	if DisplayServer.get_name() != "headless":
		scene.get_node("MatterConsole").selected = id
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.pressed = true
		scene.get_node("MatterConsole")._unhandled_input(key)
		check("preparation_panel_opens",scene.get_node("MatterConsole").panel.visible)
		await capture("01_reactive_cover")
	scene.get_node("MatterConsole").panel.hide()
	shot(gun,player)
	shot(gun,player)
	await wait_frames(2)
	check("enemy_break_causes_impulse",world.records.has(id) and world.records[id]["velocity"].length() > 1.0)
	check("reaction_consumed",world.records.has(id) and not world.records[id].has("reaction"))
	check("coating_survives_reaction",world.records.has(id) and world.records[id]["attachments"].has("nanites"))
	var gun_hp: float = gun.health
	await wait_frames(45)
	check("defense_returns_damage",gun.health < gun_hp)
	check("collision_cleanup",not world.records.has(id))
	check("south_landmark_present",scene.get_node("Arena").has_node("ContainmentCourt"))
	check("camera_preserved",is_equal_approx(scene.get_node("Arena").gameplay_camera.fov,30.0))
	# Keep screenshots representative: a second composition, rather than every primitive.
	if DisplayServer.get_name() != "headless":
		player.global_position = Vector3(0,0.1,12)
		await wait_frames(150)
		await capture("02_south_court")
		var environment: Environment = scene.get_node("Arena").runtime_environment.environment
		environment.glow_enabled = false
		environment.volumetric_fog_enabled = false
		for material: ShaderMaterial in scene.get_node("Arena/YardPolish").water_materials:
			material.set_shader_parameter("reflection_strength",0.0)
		await capture("03_without_optical_effects")
	FileAccess.open(out.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("REACTIVE INTEGRATION ",checks)
	get_tree().quit(1 if false in checks.values() else 0)
