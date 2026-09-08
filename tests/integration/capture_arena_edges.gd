## What the player actually sees at the limits of camera travel. The rig can dolly 9 m each way,
## which is far enough to expose whatever the authored yard does or does not extend to.
extends Node

var scene: Node
var arena: Node
var out: String


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(id + ".png"))


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.SUPPORT)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(70)
	arena = scene.get_node("Arena")
	var report: Dictionary = {}
	for entry: Array in [["left", -9.0], ["centre", 0.0], ["right", 9.0]]:
		arena.camera_rig.set_enabled(true)
		arena.camera_rig.offset = Vector2(float(entry[1]), 0.0)
		arena.camera_rig._apply()
		await frames(8)
		await shot("edge_" + str(entry[0]))
		# How much of the lower half of the frame is empty background rather than world?
		var image: Image = get_viewport().get_texture().get_image()
		image.convert(Image.FORMAT_RGBF)
		var empty: int = 0
		var total: int = 0
		for y in range(540, 1080, 4):
			for x in range(0, 1920, 4):
				var c: Color = image.get_pixel(x, y)
				if 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b < 0.02:
					empty += 1
				total += 1
		report[str(entry[0])] = snappedf(100.0 * float(empty) / float(total), 0.1)
	arena.camera_rig.offset = Vector2.ZERO
	arena.camera_rig._apply()
	report["perimeter"] = arena.sector_runtime.perimeter.stats if arena.sector_runtime.perimeter != null else {}
	print("ARENA EDGES ", JSON.stringify(report))
	get_tree().quit()
