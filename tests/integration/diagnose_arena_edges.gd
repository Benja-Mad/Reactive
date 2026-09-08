## Locates what is actually wrong at the lateral edges, rather than guessing from a render.
##
## The frame's left and right are not world -x and +x: the framing is yawed 35 degrees, so the
## first thing this reports is where the walkable corners actually land on screen. Every other
## measurement here depends on getting that right.
##
## Then: which emitter owns the blown-out spot on the pavement (found by hiding one field at a
## time and differencing that patch, not by eyeballing a render), how far the paving and the
## fence really reach, and what the player collides with out there.
extends Node

var scene: Node
var arena: Node
var runtime: Node
var out: String
var _hot: Vector2i


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


## Mean luminance of a screen patch, which is what tells a blown-out mote from a dim one.
func patch(rect: Rect2i) -> float:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBF)
	var sum: float = 0.0
	var count: int = 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			var c: Color = image.get_pixel(x, y)
			sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
	return sum / maxf(float(count), 1.0)


## Brightest pixel below the HUD, so the score is world content rather than UI text.
func hotspot() -> Dictionary:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBF)
	var best: float = -1.0
	var at := Vector2i.ZERO
	for y in range(200, 900, 2):
		for x in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			if l > best:
				best = l
				at = Vector2i(x, y)
	_hot = at
	return {"luminance": snappedf(best, 0.001), "at": str(at)}


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.SUPPORT)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(70)
	arena = scene.get_node("Arena")
	runtime = arena.sector_runtime
	var camera: Camera3D = arena.gameplay_camera
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var report: Dictionary = {}

	# --- 0. which way is screen left? ---------------------------------------------------------
	var corners: Dictionary = {}
	for corner: Vector3 in [Vector3(-26, 0, -26), Vector3(26, 0, -26), Vector3(-26, 0, 14), Vector3(26, 0, 14)]:
		corners[str(corner)] = str(Vector2i(camera.unproject_position(corner)))
	report["walkable_corners_on_screen"] = corners
	report["screen_right_in_world"] = str((camera.global_basis.x * Vector3(1, 0, 1)).normalized().snappedf(0.01))

	# --- 1. who owns the blown-out patch on the pavement? -------------------------------------
	var spot: Dictionary = await hotspot()
	report["hotspot"] = spot
	var rect := Rect2i(_hot - Vector2i(28, 28), Vector2i(56, 56))
	report["hotspot_patch"] = snappedf(await patch(rect), 0.0001)
	var contributions: Dictionary = {}
	for emitter: GPUParticles3D in runtime.particles.emitters:
		emitter.visible = false
		await frames(3)
		contributions[str(emitter.name)] = snappedf(await patch(rect), 0.0001)
		emitter.visible = true
	if arena.cinematic_dust != null:
		arena.cinematic_dust.visible = false
		await frames(3)
		contributions["CinematicDust"] = snappedf(await patch(rect), 0.0001)
		arena.cinematic_dust.visible = true
	runtime.particles.visible = false
	if arena.cinematic_dust != null:
		arena.cinematic_dust.visible = false
	await frames(3)
	contributions["all_particles_off"] = snappedf(await patch(rect), 0.0001)
	runtime.particles.visible = true
	if arena.cinematic_dust != null:
		arena.cinematic_dust.visible = true
	report["hotspot_patch_with_field_hidden"] = contributions

	# The patch barely moves when every emitter is hidden, so the blown-out spot is geometry.
	# Find it: drop the hotspot ray onto the ground plane and name what is sitting there.
	var origin: Vector3 = camera.project_ray_origin(Vector2(_hot))
	var direction: Vector3 = camera.project_ray_normal(Vector2(_hot))
	var ground: Vector3 = origin + direction * ((0.05 - origin.y) / direction.y)
	report["hotspot_ground_point"] = str(ground.snappedf(0.01))
	var near: Array = []
	for node: Node in runtime.imported_environment.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if box.get_center().distance_to(ground) > 3.5:
			continue
		var entry: Dictionary = {"name": str(mesh.name), "centre": str(box.get_center().snappedf(0.01)), "size": str(box.size.snappedf(0.01))}
		var active: Material = mesh.get_active_material(0)
		if active is StandardMaterial3D:
			var standard := active as StandardMaterial3D
			entry["material"] = "standard:" + str(standard.resource_name)
			entry["emission"] = standard.emission_enabled
			entry["emission_energy"] = snappedf(standard.emission_energy_multiplier, 0.01)
			entry["albedo"] = str(standard.albedo_color)
		elif active is ShaderMaterial:
			entry["material"] = "shader:" + str((active as ShaderMaterial).resource_name)
		near.append(entry)
	report["meshes_at_hotspot"] = near
	# Lights close to that point, since a saturated patch on flat pavement usually means one.
	var lights: Array = []
	for node: Node in arena.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.global_position.distance_to(ground) > 22.0:
			continue
		lights.append({
			"name": str(light.name), "type": light.get_class(),
			"at": str(light.global_position.snappedf(0.01)),
			"distance_m": snappedf(light.global_position.distance_to(ground), 0.01),
			"energy": snappedf(light.light_energy, 0.01),
			"range_m": snappedf(light.omni_range, 0.01) if light is OmniLight3D else -1.0,
		})
	report["lights_near_hotspot"] = lights

	# --- 2. how far does authored paving reach, per side? --------------------------------------
	# By raycast against the yard's own geometry is not possible (no collision on paving), so this
	# tests the authored pieces in their own local space and reports the extreme paved x per z row.
	report["paving_triangles"] = runtime.perimeter.stats.get("paving_triangles", 0)
	var reach: Dictionary = {}
	for zi in range(-26, 15, 4):
		var west: float = 99.0
		var east: float = -99.0
		for xi in range(-40, 41):
			if runtime.perimeter.is_paved(Vector3(float(xi), 0.05, float(zi))):
				west = minf(west, float(xi))
				east = maxf(east, float(xi))
		reach[str(zi)] = "%d .. %d" % [int(west), int(east)]
	report["paved_x_range_per_z"] = reach

	# --- 3. what stops the player near each lateral bound? ------------------------------------
	var body := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	body.shape = capsule
	var sweeps: Dictionary = {}
	for zi in [-20, -10, 0, 10]:
		var row: Dictionary = {}
		for xi in range(-27, 28):
			body.transform = Transform3D(Basis(), Vector3(float(xi), 1.0, float(zi)))
			var overlaps: Array[Dictionary] = space.intersect_shape(body, 4)
			if overlaps.is_empty():
				continue
			var names: Array = []
			for o: Dictionary in overlaps:
				var owner_body: CollisionObject3D = o["collider"]
				var owner_id: int = owner_body.shape_find_owner(int(o["shape"]))
				var shape_node: Object = owner_body.shape_owner_get_owner(owner_id)
				names.append(str((shape_node as Node).name))
			row[str(xi)] = names
		sweeps["z=" + str(zi)] = row
	report["blocked_x_by_row"] = sweeps

	print("ARENA DIAGNOSIS ", JSON.stringify(report, "  "))
	get_tree().quit()
