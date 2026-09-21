## What the game frame actually costs, and how much of the diorama look is actually reaching it.
##
## Two things get measured here because both were being asserted from intent rather than from a
## number. First the presentation: whether the pixel filter and the world depth filter are on, and
## how much blur each depth band is really receiving -- normalised by the band's own detail, so a
## magnified foreground cannot masquerade as focus. Second the cost of the night-rain pass: screen
## space reflections at 128 steps, a reflection probe, four fog volumes and rain, none of which
## had a frame time next to them.
##
## Cost is sampled per configuration in a *separate run* of this script, selected by the second
## argument, because measuring two configurations inside one process measures shader warm-up.
extends Node

const WARMUP_FRAMES: int = 150
const SAMPLE_FRAMES: int = 240

var scene: Node
var arena: Node
var out: String
var mode: String


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


## Mean absolute neighbour difference in a patch: how much detail survives there.
func detail(image: Image, box: Rect2i) -> float:
	var sum: float = 0.0
	var count: int = 0
	for y in range(box.position.y, box.end.y, 2):
		for x in range(box.position.x, box.end.x - 2, 2):
			var a: Color = image.get_pixel(x, y)
			var b: Color = image.get_pixel(x + 2, y)
			sum += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			count += 3
	return sum / maxf(float(count), 1.0)


func grab() -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBF)
	return image


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out = args[0]
	mode = args[1] if args.size() > 1 else "shipped"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	# Without this the measurement is the vsync wait: every configuration came back at 60.0 fps and
	# 16.67 ms, which is the frame period, and the differences between them were noise around it.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(90)
	arena = scene.get_node("Arena")
	var report: Dictionary = {"mode": mode}

	# --- what configuration is this run measuring? --------------------------------------------
	# The compositor pins every configuration to 60 fps, and neither vsync-off nor the viewport's
	# GPU timer works on Metal here, so a like-for-like millisecond figure is not available at
	# native resolution. Rendering the 3D at 2x instead -- four times the pixels -- pushes the
	# frame past the cap and makes the configurations separable by fps.
	if mode.begins_with("stress"):
		get_viewport().scaling_3d_scale = 2.0
	var polish: Node = arena.get_node_or_null("YardPolish")
	var environment: Environment = arena.runtime_environment.environment
	match mode:
		"stress_no_polish", "no_polish":
			if polish != null:
				polish.visible = false
				for child: Node in polish.get_children():
					(child as Node3D).visible = false
			environment.ssr_enabled = false
		"stress_no_ssr", "no_ssr":
			environment.ssr_enabled = false
		"no_diorama":
			arena.pixel_presentation.set_diorama(false)
		"free_motes", "free_dust", "free_rain", "free_all":
			# Which particle system still holds a generated shader at shutdown. Freeing a node and
			# letting a few frames pass is the only way to tell them apart: the exit-time message
			# names a type, never an owner.
			if mode in ["free_motes", "free_all"] and arena.sector_runtime.particles != null:
				arena.sector_runtime.particles.queue_free()
			if mode in ["free_dust", "free_all"] and arena.cinematic_dust != null:
				arena.cinematic_dust.queue_free()
			if mode in ["free_rain", "free_all"] and polish != null:
				polish.queue_free()
			await frames(30)
	await frames(40)

	report["presentation"] = arena.pixel_presentation.get_report()
	report["ssr_enabled"] = environment.ssr_enabled
	report["ssr_max_steps"] = environment.ssr_max_steps
	report["volumetric_fog_density"] = snappedf(environment.volumetric_fog_density, 0.0001)
	report["fog_density"] = snappedf(environment.fog_density, 0.0001)
	report["tonemap"] = environment.tonemap_mode

	# --- how much blur each band receives ------------------------------------------------------
	# Anchored on screen bands rather than world points: the question is what the player sees at
	# the top, middle and bottom of the frame, which is what "diorama" means here.
	var bands: Dictionary = {
		"far_architecture": Rect2i(520, 90, 900, 220),
		"gameplay_plane": Rect2i(620, 560, 700, 200),
		"near_foreground": Rect2i(320, 880, 900, 150),
	}
	var was_diorama: bool = arena.pixel_presentation.diorama_enabled
	arena.pixel_presentation.set_diorama(true)
	await frames(12)
	var with_filter: Image = await grab()
	arena.pixel_presentation.set_diorama(false)
	await frames(12)
	var without_filter: Image = await grab()
	arena.pixel_presentation.set_diorama(was_diorama)
	var softening: Dictionary = {}
	for key: String in bands:
		var sharp: float = detail(without_filter, bands[key])
		var soft: float = detail(with_filter, bands[key])
		# 0 means the filter left the band alone; 1 means it removed all of its detail.
		softening[key] = snappedf(1.0 - soft / maxf(sharp, 0.00001), 0.001)
	report["detail_removed_by_filter"] = softening

	# --- cost ----------------------------------------------------------------------------------
	# The frame period is useless here: the compositor holds every configuration at exactly 60.0
	# fps and 16.67 ms, and disabling vsync on this platform does not lift it. The viewport's own
	# render timer measures the work instead of the wait.
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	await frames(WARMUP_FRAMES)
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var samples: Array[float] = []
	var draw_calls: Array[float] = []
	var primitives: Array[float] = []
	for i in SAMPLE_FRAMES:
		await get_tree().process_frame
		# Frame period from the engine's own counter, which includes the render the process time
		# leaves out.
		samples.append(1000.0 / maxf(float(Performance.get_monitor(Performance.TIME_FPS)), 1.0))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	samples.sort()
	gpu.sort()
	cpu.sort()
	draw_calls.sort()
	primitives.sort()
	report["gpu_ms_p50"] = snappedf(gpu[gpu.size() / 2], 0.001)
	report["gpu_ms_p95"] = snappedf(gpu[int(gpu.size() * 0.95)], 0.001)
	report["render_cpu_ms_p50"] = snappedf(cpu[cpu.size() / 2], 0.001)
	report["frame_ms_p50"] = snappedf(samples[samples.size() / 2], 0.01)
	report["frame_ms_p95"] = snappedf(samples[int(samples.size() * 0.95)], 0.01)
	report["draw_calls_p50"] = int(draw_calls[draw_calls.size() / 2])
	report["primitives_p50"] = int(primitives[primitives.size() / 2])
	report["objects"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	report["fps"] = snappedf(float(Performance.get_monitor(Performance.TIME_FPS)), 0.1)

	# The east shed holds the right edge of the frame. Its own material is authored PBR and so
	# sits outside the calibrated fill, which is why it reads as a black shape; measured against
	# a patch of lit architecture in the same frame, so exposure cancels.
	var frame: Image = await grab()
	var shed: float = 0.0
	var reference: float = 0.0
	for entry: Array in [["shed", Rect2i(1580, 300, 300, 260)], ["reference", Rect2i(1000, 120, 300, 220)]]:
		var box: Rect2i = entry[1]
		var sum: float = 0.0
		var count: int = 0
		for y in range(box.position.y, box.end.y, 3):
			for x in range(box.position.x, box.end.x, 3):
				var c: Color = frame.get_pixel(x, y)
				sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				count += 1
		if str(entry[0]) == "shed": shed = sum / float(count)
		else: reference = sum / float(count)
	report["east_edge_luma"] = snappedf(shed, 0.0001)
	report["lit_architecture_luma"] = snappedf(reference, 0.0001)
	report["east_edge_ratio"] = snappedf(shed / maxf(reference, 0.0001), 0.001)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % mode))
	print("PRESENTATION ", JSON.stringify(report))
	get_tree().quit()
