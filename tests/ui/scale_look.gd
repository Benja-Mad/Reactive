## The UI at a given window size: the main menu, then the shift's HUD and the workshop, with the
## window's content scale printed. Run windowed, size in pixels as user args:
## godot --path . tests/ui/scale_look.tscn -- 2560 1440
extends Node
var out: String = "res://authored/ui_scale_20261021"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("capture")
func frames(count: int) -> void:
	for i: int in count: await get_tree().process_frame
func shot(file: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	var window := get_window()
	print("UI SCALE %s window %s mode %d factor %s visible %s screen %s dpi-scale %s" % [file, window.size, window.content_scale_mode, window.content_scale_factor, get_viewport().get_visible_rect().size, DisplayServer.screen_get_size(), DisplayServer.screen_get_scale()])
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var wanted := Vector2i(int(args[0]) if args.size() > 0 else 2560, int(args[1]) if args.size() > 1 else 1440)
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = wanted
	await frames(10)
	var tag: String = "%dx%d" % [wanted.x, wanted.y]
	var menu: Node = load("res://ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await frames(30)
	await shot(tag + "_menu")
	menu.queue_free()
	await frames(2)
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Operador", 0, Statics.Role.DAMAGE)]
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	var run: Node = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(90)
	await shot(tag + "_hud")
	run.set_phase("paused")
	await frames(10)
	await shot(tag + "_workshop")
	get_tree().quit()
