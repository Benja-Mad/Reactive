## Dumps the palette the game scene actually ends up with.
##
## The values are spread across three layers that each override the last -- the calibrated
## environment, the authored-PBR lighting pass, and the night-rain pass -- so reading any one file
## gives the wrong answer. This boots the real scene and reports what survived, alongside the
## surface albedos the material calibration assigns by family and the distribution of the frame
## itself, so the written palette can be checked against the pixels.
extends Node

var scene: Node
var arena: Node
var out: String


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func srgb(color: Color) -> String:
	return "#%02X%02X%02X" % [int(clampf(color.r, 0, 1) * 255), int(clampf(color.g, 0, 1) * 255), int(clampf(color.b, 0, 1) * 255)]


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(120)
	arena = scene.get_node("Arena")
	var report: Dictionary = {}

	# Variants, so "it feels flat" can be tested against something rather than argued about. The
	# night-rain pass thinned the distance fog to a quarter, cut the glow and greyed the
	# volumetric albedo; those three together are what separates the depth planes and what makes
	# a lamp read as a lamp.
	var variant: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "current"
	var environment_now: Environment = arena.runtime_environment.environment
	if variant in ["fog", "both"]:
		environment_now.fog_density = 0.0042
		environment_now.volumetric_fog_albedo = Color(0.25, 0.38, 0.46)
	if variant in ["glow", "both", "all"]:
		environment_now.glow_intensity = 0.85
		environment_now.glow_hdr_threshold = 0.85
		environment_now.glow_bloom = 0.12
	if variant in ["ambient", "all"]:
		# Ambient lifts every surface equally regardless of orientation, so it is the one dial
		# that removes darks everywhere at once.
		environment_now.ambient_light_energy = 0.17
	if variant in ["warm", "all"]:
		# Codex halved the sodium: the streetlight went 38 -> 16 and the central amber 12 -> 5,
		# while the wet floor started returning cyan everywhere. The two-temperature opposition is
		# what this district looks like; without it the frame is just blue.
		var street := arena.motivated_lights.get_node_or_null("YardStreetlight") as SpotLight3D
		if street != null:
			street.light_energy = 30.0
			arena._art_light_base_energy[street] = 30.0
		arena.industrial_amber_center.light_energy = 11.0
		arena._art_light_base_energy[arena.industrial_amber_center] = 11.0
		arena.industrial_amber_west.light_energy = 5.5
		arena._art_light_base_energy[arena.industrial_amber_west] = 5.5
	if variant in ["magenta", "all"]:
		var magenta := arena.find_child("CorruptionMagenta", true, false) as OmniLight3D
		if magenta != null:
			magenta.light_energy = 6.0
			magenta.omni_range = 16.0
			arena._art_light_base_energy[magenta] = 6.0
	report["variant"] = variant
	await frames(30)

	var lights: Array = []
	for node: Node in arena.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if not light.is_visible_in_tree() or light.light_energy <= 0.01:
			continue
		lights.append({
			"name": str(light.name), "type": light.get_class().replace("Light3D", ""),
			"hex": srgb(light.light_color), "energy": snappedf(light.light_energy, 0.01),
			"specular": snappedf(light.light_specular, 0.01),
			"fog": snappedf(light.light_volumetric_fog_energy, 0.01),
		})
	lights.sort_custom(func(a, b): return float(a["energy"]) > float(b["energy"]))
	report["lights"] = lights

	var environment: Environment = arena.runtime_environment.environment
	report["environment"] = {
		"tonemap": ["LINEAR", "REINHARD", "FILMIC", "ACES", "AGX"][environment.tonemap_mode],
		"exposure": snappedf(environment.tonemap_exposure, 0.01),
		"white": snappedf(environment.tonemap_white, 0.01),
		"ambient_hex": srgb(environment.ambient_light_color),
		"ambient_energy": snappedf(environment.ambient_light_energy, 0.01),
		"fog_hex": srgb(environment.fog_light_color),
		"fog_density": snappedf(environment.fog_density, 0.0001),
		"volumetric_fog_density": snappedf(environment.volumetric_fog_density, 0.0001),
		"volumetric_fog_albedo": srgb(environment.volumetric_fog_albedo),
		"glow_intensity": snappedf(environment.glow_intensity, 0.01),
		"glow_hdr_threshold": snappedf(environment.glow_hdr_threshold, 0.01),
		"saturation": snappedf(environment.adjustment_saturation, 0.01),
		"contrast": snappedf(environment.adjustment_contrast, 0.01),
		"ssr": environment.ssr_enabled,
		"ssr_steps": environment.ssr_max_steps,
	}

	# The albedo the material calibration hands each family, which is the scene's surface palette.
	var families: Array = ["silhouette", "asphalt", "asphalt_wet", "concrete", "concrete_dark",
		"concrete_pale", "steel", "galv", "rust", "paint_red", "paint_yellow", "foliage",
		"foliage_dry", "bark", "plastic"]
	var surfaces: Dictionary = {}
	for family: String in families:
		var settings: Dictionary = arena.sector_runtime._surface_settings("CS_" + family + "_PLAY")
		surfaces[family] = {
			"hex": srgb(settings["color"]),
			"roughness": snappedf(float(settings["roughness"]), 0.01),
			"metallic": snappedf(float(settings["metallic"]), 0.01),
		}
	report["surface_albedo"] = surfaces

	report["presentation"] = arena.pixel_presentation.get_report()
	report["framing"] = arena.get_framing_report()

	# Depth planes, as the frame presents them. The framing is fixed, so screen bands are a fair
	# stand-in for depth: sky and far architecture at the top, the yard in the middle, the near
	# rail at the bottom. What matters is the spread between them -- a flat image is one where
	# every plane lands on the same luminance.
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.convert(Image.FORMAT_RGBF)
	var planes: Dictionary = {}
	var means: Array[float] = []
	for entry: Array in [["background", 60, 260], ["midground", 300, 500], ["gameplay", 560, 760], ["foreground", 800, 960]]:
		var sum: float = 0.0
		var squares: float = 0.0
		var count: int = 0
		for y in range(int(entry[1]), int(entry[2]), 3):
			for x in range(120, 1800, 3):
				var c: Color = frame.get_pixel(x, y)
				var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				sum += l
				squares += l * l
				count += 1
		var mean: float = sum / float(count)
		means.append(mean)
		planes[str(entry[0])] = {"luma": snappedf(mean, 0.0001), "contrast": snappedf(sqrt(maxf(squares / float(count) - mean * mean, 0.0)), 0.0001)}
	means.sort()
	report["planes"] = planes
	report["plane_separation"] = snappedf(means[means.size() - 1] - means[0], 0.0001)

	# How much of the available range the image actually uses. Plane separation said every
	# variant was the same; the tails are where "flat" really lives -- a picture with no darks and
	# no highlights is low contrast however its planes are arranged.
	var luma: Array[float] = []
	var warm: float = 0.0
	var cool: float = 0.0
	for y in range(40, 1000, 4):
		for x in range(60, 1860, 4):
			var c: Color = frame.get_pixel(x, y)
			luma.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
			var weight: float = maxf(maxf(c.r, c.g), c.b) - minf(minf(c.r, c.g), c.b)
			if c.r > c.b: warm += weight
			else: cool += weight
	luma.sort()
	var p05: float = luma[int(luma.size() * 0.05)]
	var p50: float = luma[int(luma.size() * 0.50)]
	var p95: float = luma[int(luma.size() * 0.95)]
	var mean: float = 0.0
	for value: float in luma: mean += value
	mean /= float(luma.size())
	var variance: float = 0.0
	for value: float in luma: variance += (value - mean) * (value - mean)
	report["luma_p05"] = snappedf(p05, 0.0001)
	report["luma_p50"] = snappedf(p50, 0.0001)
	report["luma_p95"] = snappedf(p95, 0.0001)
	report["luma_range_p05_p95"] = snappedf(p95 - p05, 0.0001)
	report["luma_stddev"] = snappedf(sqrt(variance / float(luma.size())), 0.0001)
	report["warm_share"] = snappedf(warm / maxf(warm + cool, 0.0001), 0.001)

	# Where the magenta actually is. Raising its energy moved nothing, which points at placement.
	var magenta_light := arena.find_child("CorruptionMagenta", true, false) as OmniLight3D
	if magenta_light != null:
		var camera: Camera3D = arena.gameplay_camera
		report["magenta"] = {
			"at": str(magenta_light.global_position.snappedf(0.1)),
			"range_m": snappedf(magenta_light.omni_range, 0.1),
			"energy": snappedf(magenta_light.light_energy, 0.01),
			"on_screen": str(Vector2i(camera.unproject_position(magenta_light.global_position))),
			"reaches_ground": magenta_light.global_position.y < magenta_light.omni_range,
		}

	get_viewport().get_texture().get_image().save_png(out.path_join("palette_%s.png" % variant))
	print("PALETTE ", JSON.stringify(report))
	get_tree().quit()
