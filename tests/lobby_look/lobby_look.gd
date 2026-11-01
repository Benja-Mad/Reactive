## Captures the crew selection screen solo, with the given role picked (LOOK_DIR, LOOK_WIDTH).
extends Node
func _ready() -> void:
	call_deferred("capture")
func capture() -> void:
	var width: int = int(OS.get_environment("LOOK_WIDTH")) if OS.has_environment("LOOK_WIDTH") else 2304
	get_window().size = Vector2i(width, width * 9 / 16)
	var out: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/survivor_20261016"
	Game.instance.multiplayer_test = false
	Game.instance.solo = true
	var role: int = Statics.Role.DAMAGE if "damage" in OS.get_cmdline_user_args() else Statics.Role.SUPPORT
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Operador", 0, role)]
	add_child(load("res://lobby/waiting_screen.tscn").instantiate())
	for i: int in 40: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("seleccion_%d.png" % role))
	print("LOBBY SHOT ", role)
	get_tree().quit()
