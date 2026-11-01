## How fire, current and scrap look in the world, whatever shape a routine gave them. Water, ice
## and steam have their own shaders in construct_view; these three are drawn from pixel sparks,
## puffs and plain metal so they sit beside them in the same idiom.
## - Fire: a dark slick of fuel with flames licking up off it and embers lifting; a stoked fire
##   burns taller. It lights its surroundings, so the yard sees where it is.
## - Current: no body of its own, only a pale glow on whatever it lies on and sparks crawling over
##   it; held up it is a white-hot core in a halo. Plasma (heated current) turns rose.
## - Scrap: plates, bars and bolts in a heap, a ball, a barricade. Heated, it goes dull red and
##   then orange from inside; that glow is the only sign of its heat.
extends Node3D
const Fx = preload("res://scripts/matter/matter_fx.gd")
const FLAME := Color("ff7a2a")
const FLAME_CORE := Color("ffd27a")
const FUEL := Color("1a110c")
const SPARK := Color("f4e86a")
const SPARK_CORE := Color("fffdf0")
const PLASMA := Color("ff6fb0")
const IRON := Color("2f2a26")
const RUST := Color("5e3420")
const RED_HOT := Color("ff3a10")

var material: String = ""
var shape: String = ""
var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _light: OmniLight3D
var _metal: Array[StandardMaterial3D] = []
var _base_energy: float = 0.0
var _time: float = 0.0
var _plasma: bool = false

## Rebuilds the body for `kind` in `form` at `size`. `pattern` keeps a construct's heap the same heap.
func build(kind: String, form: String, size: Vector3, pattern: int) -> void:
	for child: Node in get_children(): child.queue_free()
	_flames = null
	_embers = null
	_light = null
	_metal.clear()
	material = kind
	shape = form
	match kind:
		"fire": _fire(size)
		"current": _current(size)
		"scrap": _scrap(size, pattern)

## Heat and charge as they show: a stoked fire burns taller, metal glows, plasma turns rose.
func set_state(temp: int, fierce: bool, charge: int) -> void:
	if material == "fire" and _flames != null:
		_flames.amount_ratio = 1.0 if fierce else 0.7
		(_flames.process_material as ParticleProcessMaterial).initial_velocity_max = 3.4 if fierce else 2.4
		if _light != null: _base_energy = 2.2 if fierce else 1.5
	if material == "scrap":
		var glow: Color = Color.BLACK if temp <= 0 else (RED_HOT * (0.6 if temp == 1 else 1.4))
		for metal: StandardMaterial3D in _metal:
			metal.emission_enabled = temp > 0
			metal.emission = glow
		if _light != null: _light.visible = temp > 0
	if material == "current":
		_plasma = temp >= 1
		var tint: Color = PLASMA if _plasma else SPARK
		if _flames != null: (_flames.material_override as StandardMaterial3D).albedo_color = tint
		if _light != null:
			_light.light_color = tint
			_base_energy = 0.4 + 0.35 * charge

func _process(delta: float) -> void:
	_time += delta
	if _light == null: return
	match material:
		"fire": _light.light_energy = _base_energy * (0.85 + 0.15 * sin(_time * 17.0) * sin(_time * 5.3))
		"current": _light.light_energy = _base_energy * (1.0 if fmod(_time * 7.0, 1.0) < 0.6 else 0.35)

# --- Fire ---------------------------------------------------------------------------------------

func _fire(size: Vector3) -> void:
	var area: float = maxf(1.0, size.x * size.z)
	if shape == "patch":
		_slab(Vector3(size.x * 0.9, 0.02, size.z * 0.9), FUEL, 0.012)
	elif shape == "orb":
		# A knot of burning fuel, small and hot, inside its own flames.
		var core := _sphere(size.x * 0.16, FLAME, true)
		core.position.y = size.y * 0.5
	var head: float = size.y * 0.5 if shape == "orb" else 0.0
	_flames = _particles(int(clampf(area * 12.0, 40.0, 128.0)), 0.55, FLAME, _extents(size), head, Vector2(1.2, 2.4), Vector3(0, 2.5, 0), Vector2(2.6, 4.2))
	_embers = _particles(int(clampf(area * 3.0, 8.0, 32.0)), 1.3, FLAME_CORE, _extents(size), head, Vector2(0.8, 2.0), Vector3(0, 0.6, 0), Vector2(0.6, 1.0))
	(_embers.process_material as ParticleProcessMaterial).spread = 35.0
	_light = _lamp(FLAME, 3.5 + sqrt(area), head + 0.8)
	_base_energy = 1.5

# --- Current ------------------------------------------------------------------------------------

func _current(size: Vector3) -> void:
	var head: float = size.y * 0.5 if shape == "orb" else 0.0
	if shape == "orb":
		var core := _sphere(size.x * 0.18, SPARK_CORE, true)
		core.position.y = head
		var halo := _sphere(size.x * 0.42, Color(SPARK, 0.22), true)
		halo.position.y = head
	elif shape == "wall":
		# A live fence: three iron posts with the current strung between them.
		for x: float in [-0.45, 0.0, 0.45]:
			var post := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(0.1, size.y, 0.1)
			post.mesh = bar
			post.material_override = _iron(false)
			post.position = Vector3(x * size.x, size.y * 0.5, 0)
			add_child(post)
	else:
		_slab(Vector3(size.x * 0.85, 0.01, size.z * 0.85), Color(SPARK, 0.12), 0.01, true)
	_flames = _particles(int(clampf(size.x * size.z * 4.0, 16.0, 48.0)), 0.18, SPARK, _extents(size), head, Vector2(1.5, 4.0), Vector3.ZERO, Vector2(0.7, 1.2))
	(_flames.process_material as ParticleProcessMaterial).spread = 180.0
	_light = _lamp(SPARK, 3.0, head + 0.5)
	_base_energy = 0.9

# --- Scrap --------------------------------------------------------------------------------------

func _scrap(size: Vector3, pattern: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern * 7919 + 13
	var iron := _iron(false)
	var rust := _iron(true)
	var pieces: int = 14 if shape == "wall" else (9 if shape == "orb" else int(clampf(size.x * size.z * 1.2, 6.0, 22.0)))
	for i: int in pieces:
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		# Plates, bars and lumps: one long side, one thin.
		var kind: int = i % 3
		box.size = [Vector3(rng.randf_range(0.5, 0.9), 0.05, rng.randf_range(0.3, 0.6)), Vector3(rng.randf_range(0.6, 1.1), 0.09, 0.09), Vector3.ONE * rng.randf_range(0.2, 0.35)][kind]
		piece.mesh = box
		piece.material_override = rust if rng.randf() < 0.45 else iron
		var spot: Vector3
		match shape:
			"orb":
				spot = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).limit_length(1.0) * size.x * 0.32 + Vector3.UP * size.y * 0.5
			"wall":
				spot = Vector3(rng.randf_range(-0.5, 0.5) * size.x, (float(i) / pieces) * size.y * 0.9 + 0.1, rng.randf_range(-0.12, 0.12))
				box.size = Vector3(rng.randf_range(0.7, 1.3), rng.randf_range(0.18, 0.4), 0.12)
			_:
				spot = Vector3(rng.randf_range(-0.42, 0.42) * size.x, 0.05 + rng.randf_range(0.0, 0.12), rng.randf_range(-0.42, 0.42) * size.z)
		piece.position = spot
		piece.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-PI, PI), rng.randf_range(-0.5, 0.5)) if shape != "wall" else Vector3(0, rng.randf_range(-0.08, 0.08), rng.randf_range(-0.12, 0.12))
		add_child(piece)
	_light = _lamp(RED_HOT, 3.0, size.y * 0.5 if shape == "orb" else 0.5)
	_light.light_energy = 1.0
	_light.visible = false

func _iron(rusted: bool) -> StandardMaterial3D:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = RUST if rusted else IRON
	metal.metallic = 0.25 if rusted else 0.65
	metal.roughness = 0.9 if rusted else 0.5
	_metal.append(metal)
	return metal

# --- Pieces -------------------------------------------------------------------------------------

func _extents(size: Vector3) -> Vector3:
	match shape:
		"orb": return Vector3.ONE * size.x * 0.3
		"wall": return Vector3(size.x * 0.45, size.y * 0.4, 0.08)
	return Vector3(size.x * 0.4, 0.04, size.z * 0.4)

func _particles(amount: int, lifetime: float, color: Color, extents: Vector3, height: float, speed: Vector2, gravity: Vector3, scale_range: Vector2) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.UP
	process.spread = 14.0
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
	process.gravity = gravity
	process.scale_min = scale_range.x
	process.scale_max = scale_range.y
	process.scale_curve = Fx.grow_curve(1.0, 0.2)
	process.color_ramp = Fx.hold_ramp(0.05, 0.6)
	particles.process_material = process
	particles.draw_pass_1 = Fx.quad(0.1)
	particles.material_override = Fx.spark_material(color)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(-extents - Vector3(1, 0, 1), extents * 2.0 + Vector3(2, 4, 2))
	add_child(particles)
	particles.position.y = height + 0.05
	return particles

func _slab(size: Vector3, color: Color, lift: float, glow: bool = false) -> MeshInstance3D:
	var slab := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	slab.mesh = plane
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 1.0
	if glow or color.a < 1.0:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slab.material_override = paint
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slab)
	slab.position.y = lift
	return slab

func _sphere(radius: float, color: Color, glow: bool) -> MeshInstance3D:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	ball.mesh = sphere
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	if glow:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if color.a < 1.0:
			paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ball.material_override = paint
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ball)
	return ball

func _lamp(color: Color, reach: float, height: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_color = color
	lamp.omni_range = reach
	lamp.light_energy = 1.0
	lamp.shadow_enabled = false
	add_child(lamp)
	lamp.position.y = height
	return lamp
