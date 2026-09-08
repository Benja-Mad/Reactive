## How dark the east shed's visible faces are, against the planes the scene is judged on.
##
## The district's emission is animated, so a single shot is not a measurement here: the same
## frame twenty frames later differs by nearly 30% in this region. Each configuration is
## therefore sampled four times and averaged, and the shed's own patch is compared against a
## reference patch of authored architecture in the same frame.
extends Node

## A patch on the shed's visible faces, and a patch of lit authored architecture to judge it by.
const SHED := Rect2i(1700, 340, 180, 200)
const REFERENCE := Rect2i(1180, 120, 180, 200)

var scene: Node
var arena: Node
var out: String


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func sample() -> Dictionary:
	await RenderingServer.frame_post_draw
	var full: Image = get_viewport().get_texture().get_image()
	var result: Dictionary = {}
	for entry: Array in [["shed", SHED], ["reference", REFERENCE]]:
		var region: Image = full.get_region(entry[1])
		region.convert(Image.FORMAT_RGBF)
		var sum: float = 0.0
		for y in region.get_height():
			for x in region.get_width():
				var c: Color = region.get_pixel(x, y)
				sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		result[entry[0]] = sum / float(region.get_width() * region.get_height())
	return result


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.SUPPORT)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(60)
	arena = scene.get_node("Arena")
	arena.camera_rig.set_enabled(true)
	arena.camera_rig.offset = Vector2(9.0, 0.0)
	arena.camera_rig._apply()
	await frames(30)
	var spill: OmniLight3D = arena.find_child("EastLotSpill", true, false) as OmniLight3D
	var report: Dictionary = {
		"present": spill != null,
		"energy": snappedf(spill.light_energy, 0.01) if spill != null else -1.0,
		"position": str(spill.global_position.snappedf(0.01)) if spill != null else "none",
		"range_m": snappedf(spill.omni_range, 0.01) if spill != null else -1.0,
	}
	for energy: float in [0.0, 8.0, 20.0, 45.0]:
		if spill != null:
			spill.light_energy = energy
		var shed: float = 0.0
		var reference: float = 0.0
		for i in 3:
			await frames(8)
			var measured: Dictionary = await sample()
			shed += float(measured["shed"])
			reference += float(measured["reference"])
		report["energy_%d" % int(energy)] = {
			"shed_luma": snappedf(shed / 3.0, 0.0001),
			"reference_luma": snappedf(reference / 3.0, 0.0001),
			"ratio": snappedf(shed / maxf(reference, 0.0001), 0.001),
		}
		if spill == null:
			break
	await frames(10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("east_edge.png"))
	print("EAST SHED ", JSON.stringify(report, "  "))
	get_tree().quit()
