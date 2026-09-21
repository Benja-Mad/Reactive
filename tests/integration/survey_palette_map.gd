## The palette of the whole map, not of one frame.
##
## The yard is now 68 x 54 m and the rig travels 40 x 24 m on the ground plane, so the camera
## really does roam it: a reading taken at the composed framing describes one corner of the
## district and nothing else. This walks the camera across its full travel, samples the frame at
## each stop, and reports the colour per region as well as the aggregate -- plus every light in
## the scene grouped by where it actually stands, since that is where the colour comes from.
extends Node

## Camera offsets sampled, as fractions of the rig's own travel limit.
const GRID: Array[Vector2] = [
	Vector2(-1.0, 0.6), Vector2(0.0, 0.6), Vector2(1.0, 0.6),
	Vector2(-1.0, 0.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0),
	Vector2(-1.0, -1.0), Vector2(0.0, -1.0), Vector2(1.0, -1.0),
]
const NAMES: Array[String] = [
	"noroeste", "norte", "noreste",
	"oeste", "centro", "este",
	"suroeste", "sur", "sureste",
]

var scene: Node
var arena: Node
var out: String


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func hex(color: Color) -> String:
	return "#%02X%02X%02X" % [int(clampf(color.r, 0, 1) * 255), int(clampf(color.g, 0, 1) * 255), int(clampf(color.b, 0, 1) * 255)]


## Colour statistics of the current frame: where its values sit, how much of its chroma is warm,
## and which hue wedges carry it.
func sample() -> Dictionary:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBF)
	var luma: Array[float] = []
	var warm: float = 0.0
	var cool: float = 0.0
	var wedges: Dictionary = {}
	var accumulated := Color(0, 0, 0)
	var counted: int = 0
	for y in range(40, 1000, 4):
		for x in range(60, 1860, 4):
			var c: Color = image.get_pixel(x, y)
			luma.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
			var chroma: float = maxf(maxf(c.r, c.g), c.b) - minf(minf(c.r, c.g), c.b)
			if c.r > c.b: warm += chroma
			else: cool += chroma
			if chroma > 0.03:
				var wedge: int = int(c.h * 360.0) / 20 * 20
				wedges[wedge] = float(wedges.get(wedge, 0.0)) + chroma
			accumulated += c
			counted += 1
	luma.sort()
	var lead: int = -1
	var best: float = 0.0
	for wedge: int in wedges:
		if float(wedges[wedge]) > best:
			best = wedges[wedge]
			lead = wedge
	var total: float = 0.0
	for wedge: int in wedges: total += float(wedges[wedge])
	return {
		"p05": snappedf(luma[int(luma.size() * 0.05)], 0.001),
		"p50": snappedf(luma[int(luma.size() * 0.50)], 0.001),
		"p95": snappedf(luma[int(luma.size() * 0.95)], 0.001),
		"warm_share": snappedf(warm / maxf(warm + cool, 0.0001), 0.001),
		"lead_hue": lead,
		"lead_share": snappedf(best / maxf(total, 0.0001), 0.001),
		"average": hex(accumulated / float(counted)),
	}


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(140)
	arena = scene.get_node("Arena")
	var report: Dictionary = {}

	var runtime: Node = arena.sector_runtime
	report["yard"] = {
		"walkable_x": str(Vector2(runtime.collision.YARD_MIN.x, runtime.collision.YARD_MAX.x)),
		"walkable_z": str(Vector2(runtime.collision.YARD_MIN.y, runtime.collision.YARD_MAX.y)),
		"area_m2": int((runtime.collision.YARD_MAX.x - runtime.collision.YARD_MIN.x) * (runtime.collision.YARD_MAX.y - runtime.collision.YARD_MIN.y)),
		"camera_travel_m": str(arena.follow_limit),
	}

	# Every light, with where it stands, so the palette can be attributed to places on the map.
	var lights: Array = []
	for node: Node in arena.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if not light.is_visible_in_tree() or light.light_energy <= 0.05:
			continue
		var at: Vector3 = light.global_position
		var region: String = ("oeste" if at.x < -12.0 else "este" if at.x > 12.0 else "centro")
		if light is DirectionalLight3D:
			region = "global"
		elif at.z > 12.0:
			region = "sur"
		lights.append({
			"name": str(light.name), "region": region, "hex": hex(light.light_color),
			"energy": snappedf(light.light_energy, 0.01), "at": str(at.snappedf(0.1)),
		})
	lights.sort_custom(func(a, b): return float(a["energy"]) > float(b["energy"]))
	report["lights"] = lights

	# Walk the camera across its own travel and read the frame at each stop.
	arena.camera_rig.set_enabled(true)
	var stops: Array = []
	for index in GRID.size():
		var fraction: Vector2 = GRID[index]
		arena.camera_rig.offset = Vector2(fraction.x * arena.follow_limit.x, fraction.y * arena.follow_limit.y)
		arena.camera_rig._apply()
		await frames(26)
		var stop: Dictionary = await sample()
		stop["region"] = NAMES[index]
		stop["offset"] = str(arena.camera_rig.offset)
		stops.append(stop)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % NAMES[index]))
	report["stops"] = stops
	arena.camera_rig.offset = Vector2.ZERO
	arena.camera_rig._apply()

	print("MAP PALETTE ", JSON.stringify(report))
	get_tree().quit()
