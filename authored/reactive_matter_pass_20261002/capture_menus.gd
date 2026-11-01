## Screenshots of the front-end screens, for the menu pass.
extends Node
var out: String
func _ready() -> void: call_deferred("run")
func shot(file: String) -> void:
	for i in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("SHOT ", file)
func run() -> void:
	# Step out of the current scene, so changing scenes does not free the capture itself.
	var stand_in := Node.new()
	get_tree().root.add_child(stand_in)
	get_tree().current_scene = stand_in
	reparent(get_tree().root)
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "user://menus"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.multiplayer_test = false
	for path: String in ["res://ui/main_menu.tscn", "res://lobby/host_screen.tscn", "res://lobby/join_screen.tscn"]:
		get_tree().change_scene_to_file(path)
		await shot(path.get_file().get_basename())
	Game.instance.players = [Statics.PlayerData.new(1, "Operador", 0, Statics.Role.DAMAGE), Statics.PlayerData.new(2, "Vigía", 1, Statics.Role.SUPPORT)]
	get_tree().change_scene_to_file("res://lobby/waiting_screen.tscn")
	await shot("waiting_screen")
	get_tree().quit()
