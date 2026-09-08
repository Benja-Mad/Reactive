## Lighting audit for the fixed P30 framing.
##
## Two questions this answers:
##   1. Does every light that produces a visible shaft have a physical emitter the viewer can
##      see, and does its beam reach its target without driving through opaque geometry?
##   2. How much value separation is there between the depth planes? A diorama reads as flat
##      when foreground, gameplay, midground and background all land on the same luminance.
extends SceneTree

const PLANES := {
	"foreground": Rect2i(120, 830, 1680, 210),
	"gameplay": Rect2i(560, 590, 800, 210),
	"midground": Rect2i(380, 400, 1180, 170),
	"background": Rect2i(360, 40, 1200, 250),
}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	var scene: Node = load("res://scenes/environment/sector_08/Sector08LookDev.tscn").instantiate()
	root.add_child(scene)
	scene.debug_layer.visible = false
	scene.controller.auto_demo = false
	scene.controller.set_process(false)
	scene.controller.preset_normal()
	for i in 180: scene.controller._process(1.0 / 60.0)
	scene.pixel_presentation.set_mode(0)
	scene.pixel_presentation.set_diorama(true)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw

	var report: Dictionary = {}
	report["lights"] = _audit_lights(scene)
	report["shafts"] = _audit_shafts(scene)
	report["planes"] = _audit_planes()
	report["environment"] = _audit_environment(scene)
	root.get_texture().get_image().save_png(out.path_join("lighting.png"))
	FileAccess.open(out.path_join("lighting.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("SECTOR08 LIGHTING ", JSON.stringify(report))
	quit()


func _audit_lights(scene: Node) -> Array:
	var rows: Array = []
	for node: Node in scene.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if not light.is_visible_in_tree():
			continue
		var kind: String = "directional" if light is DirectionalLight3D else ("spot" if light is SpotLight3D else "omni")
		rows.append({
			"name": str(light.name),
			"type": kind,
			"energy": snappedf(light.light_energy, 0.01),
			"color": str(light.light_color),
			"fog": snappedf(light.light_volumetric_fog_energy, 0.01),
			"shadow": light.shadow_enabled,
			"position": str(light.global_position.snappedf(0.01)),
		})
	return rows


## A shaft is only motivated if something solid sits at its origin. Raycast from the shaft
## origin to its target and report the first opaque hit, so a beam driving through a wall shows.
func _audit_shafts(scene: Node) -> Array:
	var air: Node3D = scene.pixel_presentation.atmosphere
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var rows: Array = []
	for beam: SpotLight3D in air.beams:
		var origin: Vector3 = beam.global_position
		var reach: Vector3 = origin - beam.global_basis.z * beam.spot_range
		var query := PhysicsRayQueryParameters3D.create(origin, reach)
		var hit: Dictionary = space.intersect_ray(query)
		var emitter: String = ""
		for child: Node in air.get_children():
			if child is MeshInstance3D and child.global_position.distance_to(origin) < 1.5:
				emitter = str(child.name)
				break
		rows.append({
			"beam": str(beam.name),
			"energy": snappedf(beam.light_energy, 0.01),
			"fog_energy": snappedf(beam.light_volumetric_fog_energy, 0.01),
			"spot_angle": beam.spot_angle,
			"spot_range": beam.spot_range,
			"visible_emitter": emitter,
			"first_opaque_hit_m": snappedf(origin.distance_to(hit["position"]), 0.01) if hit.has("position") else -1.0,
		})
	return rows


## Mean luminance and its spread per depth plane. Separation is the metric that matters:
## a diorama needs the planes to sit on different values, not merely to be individually pretty.
func _audit_planes() -> Dictionary:
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBF)
	var result: Dictionary = {}
	var means: Array[float] = []
	for label: String in PLANES:
		var rect: Rect2i = PLANES[label]
		var total: float = 0.0
		var squares: float = 0.0
		var count: int = 0
		for y in range(rect.position.y, rect.end.y, 3):
			for x in range(rect.position.x, rect.end.x, 3):
				var c: Color = image.get_pixel(x, y)
				var luma: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				total += luma
				squares += luma * luma
				count += 1
		var mean: float = total / float(count)
		result[label] = {"mean_luma": snappedf(mean, 0.0001), "stddev": snappedf(sqrt(maxf(squares / float(count) - mean * mean, 0.0)), 0.0001)}
		means.append(mean)
	means.sort()
	result["plane_separation"] = snappedf(means[means.size() - 1] - means[0], 0.0001)
	return result


func _audit_environment(scene: Node) -> Dictionary:
	var environment: Environment = scene.runtime_environment.environment
	return {
		"ambient_energy": snappedf(environment.ambient_light_energy, 0.01),
		"ambient_color": str(environment.ambient_light_color),
		"ambient_source": environment.ambient_light_source,
		"ssao": environment.ssao_enabled,
		"ssil": environment.ssil_enabled,
		"sdfgi": environment.sdfgi_enabled,
		"glow": environment.glow_enabled,
		"fog": environment.fog_enabled,
		"volumetric_fog": environment.volumetric_fog_enabled,
		"volumetric_fog_density": snappedf(environment.volumetric_fog_density, 0.0001),
		"tonemap": environment.tonemap_mode,
		"exposure": snappedf(environment.tonemap_exposure, 0.01),
		"white": snappedf(environment.tonemap_white, 0.01),
	}
