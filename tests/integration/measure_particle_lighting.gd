## Does the scene dust actually respond to light?
##
## Real dust is close to invisible until it crosses a beam. The way to check that here is to
## isolate the particles' own contribution -- render the frame with them and without them, and
## subtract -- then compare how much they contribute inside a lit cone against how much they
## contribute in shadow. If the ratio is near 1 they are not responding to the lighting at all.
extends Node

## Screen regions in the approved P30 framing.
const REGIONS := {
	"sodium_beam": Rect2i(1150, 250, 210, 310),
	"beam_pool": Rect2i(1120, 430, 260, 150),
	"open_shadow": Rect2i(200, 560, 320, 200),
	"deep_shadow": Rect2i(60, 120, 240, 220),
}

var out: String
var report: Dictionary = {}


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func grab() -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBF)
	return image


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "L", 0, Statics.Role.SUPPORT)]
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(80)
	var arena = scene.get_node("Arena")
	var motes: Node3D = arena.sector_runtime.particles
	# The optical layers are a separate system and would pollute the measurement.
	arena.cinematic_dust.visible = false
	await frames(20)

	# The billboard screen, the light shafts and the hologram all animate on TIME, so two captures
	# ten frames apart differ for reasons that have nothing to do with dust. Take three frames one
	# apart -- off, off, on -- so the first pair measures that noise floor and it can be subtracted.
	motes.visible = false
	await frames(4)
	var noise_a: Image = await grab()
	await get_tree().process_frame
	var noise_b: Image = await grab()
	get_viewport().get_texture().get_image().save_png(out.path_join("without_motes.png"))
	motes.visible = true
	await get_tree().process_frame
	var with_motes: Image = await grab()
	get_viewport().get_texture().get_image().save_png(out.path_join("with_motes.png"))
	var without: Image = noise_b

	var contribution := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	var sums: Dictionary = {}
	var noise: Dictionary = {}
	for label: String in REGIONS:
		sums[label] = [0.0, 0]
		noise[label] = 0.0
	for y in 1080:
		for x in 1920:
			var a: Color = with_motes.get_pixel(x, y)
			var b: Color = without.get_pixel(x, y)
			var delta: float = maxf(0.0, maxf(maxf(a.r - b.r, a.g - b.g), a.b - b.b))
			var n: Color = noise_a.get_pixel(x, y)
			var floor_delta: float = maxf(0.0, maxf(maxf(b.r - n.r, b.g - n.g), b.b - n.b))
			contribution.set_pixel(x, y, Color(delta * 6.0, delta * 6.0, delta * 6.0))
			for label: String in REGIONS:
				var rect: Rect2i = REGIONS[label]
				if rect.has_point(Vector2i(x, y)):
					sums[label][0] += delta
					sums[label][1] += 1
					noise[label] += floor_delta
	contribution.save_png(out.path_join("contribution.png"))

	for label: String in REGIONS:
		var count: float = maxf(float(sums[label][1]), 1.0)
		report[label] = snappedf(1000.0 * (float(sums[label][0]) - float(noise[label])) / count, 0.001)
		report[label + "_noise_floor"] = snappedf(1000.0 * float(noise[label]) / count, 0.001)
	var lit: float = (float(report["sodium_beam"]) + float(report["beam_pool"])) * 0.5
	var dark: float = (float(report["open_shadow"]) + float(report["deep_shadow"])) * 0.5
	report["lit_mean"] = snappedf(lit, 0.001)
	report["shadow_mean"] = snappedf(dark, 0.001)
	report["lit_over_shadow"] = snappedf(lit / maxf(dark, 0.0001), 0.01)
	FileAccess.open(out.path_join("particle_lighting.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("PARTICLE LIGHTING ", JSON.stringify(report))
	get_tree().quit()
