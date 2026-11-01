## One-shot effects for matter events. Spawned on every peer from the replicated event stream;
## nothing here touches gameplay state.
extends RefCounted

const Meshes = preload("res://scripts/matter/matter_meshes.gd")

static var _shard_mesh: ArrayMesh
static var _puff_texture: ImageTexture
static var _spark_texture: ImageTexture

static func shard_mesh() -> ArrayMesh:
	if _shard_mesh == null: _shard_mesh = Meshes.shard(424242)
	return _shard_mesh

## A puff for steam, frost and dust, drawn like the cast's pixels: a lumpy cloud of three hard
## tones (lit from the top left), a darker edge, no soft falloff. Particles tint it with their colour.
static func puff_texture() -> ImageTexture:
	if _puff_texture != null: return _puff_texture
	const SIZE: int = 20
	var lobes: Array[Vector3] = [Vector3(10.0, 11.5, 7.0), Vector3(6.5, 9.0, 4.6), Vector3(13.5, 8.5, 4.8), Vector3(9.5, 6.0, 4.2)]
	var inside := func(x: float, y: float) -> bool:
		for lobe: Vector3 in lobes:
			if Vector2(x - lobe.x, y - lobe.y).length() <= lobe.z: return true
		return false
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var px: float = x + 0.5
			var py: float = y + 0.5
			if not inside.call(px, py): continue
			# The edge: any neighbour outside the cloud.
			var edge: bool = not (inside.call(px - 1, py) and inside.call(px + 1, py) and inside.call(px, py - 1) and inside.call(px, py + 1))
			# Light from the top left: how far into the cloud toward the light this pixel sits.
			var lit: bool = inside.call(px - 2.5, py - 2.5) == false
			var shade: bool = inside.call(px + 2.5, py + 2.5) == false
			var tone: float = 0.78
			if lit: tone = 1.0
			elif shade: tone = 0.56
			if edge and not lit: tone = 0.42
			image.set_pixel(x, y, Color(tone, tone, tone, 1.0))
	_puff_texture = ImageTexture.create_from_image(image)
	return _puff_texture

## A spark is one solid pixel-square; the particle's size makes it two or three texels.
static func spark_texture() -> ImageTexture:
	if _spark_texture != null: return _spark_texture
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_spark_texture = ImageTexture.create_from_image(image)
	return _spark_texture

## Fading is dithered (alpha hash), so a dying puff breaks into pixels instead of going see-through.
static func puff_material(color: Color, emission: float = 0.15, lit: bool = true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = puff_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = emission > 0.0
	material.emission = Color(color.r, color.g, color.b) * emission
	material.roughness = 1.0
	material.disable_receive_shadows = true
	return material

static func spark_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = spark_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	return material

static func fade_ramp(peak: float = 0.15) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(peak, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp

## Solid from `rise` to `hold`, then gone by the end: with a dithered material a puff stays a
## clean shape most of its life and only breaks into pixels as it arrives and leaves.
static func hold_ramp(rise: float, hold: float) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(rise, Color(1, 1, 1, 1))
	gradient.add_point(hold, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp

static func grow_curve(start: float, finish: float) -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0, start))
	curve.add_point(Vector2(1, finish))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture

## Generic one-shot burst. `mesh` decides the look: a shard, a puff quad or a spark quad.
static func burst(parent: Node, point: Vector3, amount: int, mesh: Mesh, material: Material, speed: Vector2, spread: float, gravity: Vector3, lifetime: float, scale_range: Vector2, extents: Vector3 = Vector3.ZERO, shrink: bool = true, damping: float = 0.0) -> GPUParticles3D:
	if parent == null or DisplayServer.get_name() == "headless": return null
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.92
	particles.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
	process.gravity = gravity
	process.damping_min = damping
	process.damping_max = damping * 1.4
	process.scale_min = scale_range.x
	process.scale_max = scale_range.y
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -280.0
	process.angular_velocity_max = 280.0
	if extents != Vector3.ZERO:
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = extents
	if shrink: process.scale_curve = grow_curve(1.0, 0.0)
	process.color_ramp = fade_ramp(0.08) if not shrink else null
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	particles.global_position = point
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles

static func quad(size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	return mesh

static func flash(parent: Node, point: Vector3, color: Color, energy: float, radius: float, duration: float) -> void:
	if parent == null or DisplayServer.get_name() == "headless": return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = point
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(light.queue_free)

static func shatter(parent: Node, point: Vector3, ice: Material) -> void:
	burst(parent, point + Vector3.UP * 0.8, 26, shard_mesh(), ice, Vector2(2.5, 6.5), 75.0, Vector3(0, -12, 0), 1.1, Vector2(0.5, 1.4), Vector3(1.6, 0.6, 0.15))
	burst(parent, point + Vector3.UP * 0.7, 14, quad(0.9), puff_material(Color(0.82, 0.9, 0.95, 0.55), 0.3), Vector2(0.4, 1.6), 90.0, Vector3(0, 0.2, 0), 1.4, Vector2(0.8, 1.8), Vector3(1.6, 0.6, 0.2), false, 1.5)
	flash(parent, point + Vector3.UP * 1.0, Color(0.6, 0.9, 1.0), 5.0, 6.0, 0.35)

static var _loose_ice: StandardMaterial3D

static func chips(parent: Node, point: Vector3, ice: Material) -> void:
	if ice == null:
		if _loose_ice == null:
			_loose_ice = StandardMaterial3D.new()
			_loose_ice.albedo_color = Color(0.55, 0.72, 0.78)
			_loose_ice.roughness = 0.15
			_loose_ice.emission_enabled = true
			_loose_ice.emission = Color(0.1, 0.3, 0.38)
		ice = _loose_ice
	burst(parent, point, 8, shard_mesh(), ice, Vector2(1.5, 3.5), 60.0, Vector3(0, -10, 0), 0.7, Vector2(0.18, 0.4), Vector3(0.3, 0.3, 0.1))
	flash(parent, point, Color(0.7, 0.92, 1.0), 2.0, 2.5, 0.18)

static func frost(parent: Node, point: Vector3, extents: Vector3) -> void:
	burst(parent, point, 30, quad(0.12), spark_material(Color(0.75, 0.95, 1.0, 0.9)), Vector2(0.3, 1.4), 90.0, Vector3(0, 0.6, 0), 1.0, Vector2(0.4, 1.0), extents)
	burst(parent, point, 10, quad(0.8), puff_material(Color(0.85, 0.94, 1.0, 0.4), 0.25), Vector2(0.2, 0.7), 90.0, Vector3(0, -0.2, 0), 1.3, Vector2(0.7, 1.4), extents, false, 1.0)
	flash(parent, point + Vector3.UP * 0.5, Color(0.55, 0.88, 1.0), 3.0, 4.5, 0.5)

static func boil(parent: Node, point: Vector3, extents: Vector3) -> void:
	burst(parent, point, 22, quad(1.1), puff_material(Color(0.88, 0.92, 0.94, 0.6), 0.2), Vector2(1.2, 3.2), 35.0, Vector3(0, 1.2, 0), 1.6, Vector2(0.6, 1.8), extents, false, 1.2)
	flash(parent, point + Vector3.UP * 0.8, Color(1.0, 0.62, 0.32), 3.5, 5.0, 0.45)

static func splash(parent: Node, point: Vector3, extents: Vector3) -> void:
	burst(parent, point + Vector3.UP * 0.05, 24, quad(0.09), spark_material(Color(0.55, 0.85, 0.95, 0.85)), Vector2(1.2, 2.8), 55.0, Vector3(0, -9, 0), 0.6, Vector2(0.5, 1.1), extents)

static func shockwave(parent: Node, point: Vector3, radius: float) -> void:
	if parent == null or DisplayServer.get_name() == "headless": return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.62, 0.26, 1.0)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = point + Vector3.UP * 0.08
	ring.scale = Vector3(0.3, 0.6, 0.3)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1.2, radius), 0.42).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)
	burst(parent, point + Vector3.UP * 0.4, 40, quad(0.1), spark_material(Color(1.0, 0.7, 0.32)), Vector2(4.0, 9.0), 80.0, Vector3(0, -6, 0), 0.8, Vector2(0.4, 1.1), Vector3.ZERO, true, 2.0)
	burst(parent, point + Vector3.UP * 0.5, 12, quad(1.2), puff_material(Color(0.36, 0.3, 0.24, 0.6), 0.4), Vector2(0.8, 2.4), 90.0, Vector3(0, 0.4, 0), 1.6, Vector2(0.8, 2.0), Vector3(0.6, 0.3, 0.6), false, 2.0)
	flash(parent, point + Vector3.UP * 1.0, Color(1.0, 0.6, 0.25), 9.0, radius * 2.0, 0.5)

static func arrival(parent: Node, point: Vector3) -> void:
	burst(parent, point, 16, quad(0.1), spark_material(Color(1.0, 0.74, 0.36)), Vector2(0.8, 2.2), 180.0, Vector3.ZERO, 0.45, Vector2(0.5, 1.0), Vector3.ZERO, true, 3.0)
	flash(parent, point, Color(1.0, 0.68, 0.3), 2.5, 3.0, 0.3)
