## The yard's stores that are not water, each the answer to «where does this come from»:
## - fire: a night-shift warming drum, holes punched round its waist, a grill laid across the top
##   and a hazard band half burnt off; the flames over it are the fire a routine draws.
## - current: a substation transformer knocked off its pole and still live, cooling fins, three
##   ceramic insulators with their cables torn short, and current jumping between the terminals.
##   Its red lamp is the one thing that says it is live.
## - scrap: the heap the last crew left, plates and bars round the carcass of an older machine whose
##   eye never quite went out. The pile a routine draws from lies around it.
## Drawn on every peer from the replicated record; nothing here touches gameplay.
extends Node3D
const Fx = preload("res://scripts/matter/matter_fx.gd")
const CombatFx = preload("res://scenes/actions/combat_fx.gd")
const IRON := Color("2a2622")
const RUST := Color("6b3a22")
const HAZARD := Color("c9a227")
const PORCELAIN := Color("cfc8b8")
const FLAME := Color("ff7a2a")
const SPARK := Color("f4e86a")
const LAMP := Color("ff3b3b")
const EYE := Color("ff5a3a")

var kind: String = "fire"
var _fire_light: OmniLight3D
var _fire_glow: StandardMaterial3D
var _lit: bool = true
var _flames: GPUParticles3D
var _lamp: OmniLight3D
var _lamp_mesh: StandardMaterial3D
var _eye: StandardMaterial3D
var _fill: float = 1.0
var _time: float = 0.0
var _next_arc: float = 0.5
var _terminals: Array[Vector3] = []

func _ready() -> void:
	match kind:
		"fire": _drum()
		"current": _transformer()
		"scrap": _heap()

## How much it holds, 0..1: a drawn-down drum burns low, a drained transformer arcs seldom.
func set_fill(fraction: float) -> void:
	_fill = clampf(fraction, 0.0, 1.0)
	if _flames != null: _flames.amount_ratio = lerpf(0.35, 1.0, _fill)

func set_lit(value: bool) -> void:
	_lit = value
	if _flames != null: _flames.emitting = value
	if _fire_light != null: _fire_light.light_energy = 1.6 if value else 0.0
	if _fire_glow != null: _fire_glow.emission_energy_multiplier = 2.5 if value else 0.0

func _process(delta: float) -> void:
	_time += delta
	if _lamp != null:
		var on: bool = fmod(_time, 1.2) < 0.5
		_lamp.light_energy = 1.2 if on else 0.0
		_lamp_mesh.emission_energy_multiplier = 3.0 if on else 0.2
	if _eye != null: _eye.emission_energy_multiplier = 0.6 + 0.5 * absf(sin(_time * 0.7)) * (1.0 if fmod(_time, 5.0) > 0.15 else 0.0)
	if kind == "current" and DisplayServer.get_name() != "headless":
		_next_arc -= delta
		if _next_arc <= 0.0 and _terminals.size() >= 2:
			_next_arc = lerpf(2.2, 0.35, _fill) * randf_range(0.6, 1.4)
			var a: Vector3 = to_global(_terminals[randi() % _terminals.size()])
			var b: Vector3 = to_global(_terminals[randi() % _terminals.size()])
			if a != b: CombatFx.beam(get_parent(), a, b, SPARK, 0.12, 0.03)
			CombatFx.spark(get_parent(), a, SPARK, 4)

# --- Fire: the warming drum ---------------------------------------------------------------------

func _drum() -> void:
	var iron := _paint(IRON, 0.6, 0.55)
	var rust := _paint(RUST, 0.2, 0.9)
	var band := _paint(HAZARD, 0.1, 0.8)
	_part(_cylinder(0.42, 0.42, 0.95), rust, Vector3(0, 0.475, 0))
	_part(_cylinder(0.43, 0.43, 0.06), iron, Vector3(0, 0.05, 0))
	_part(_cylinder(0.43, 0.43, 0.06), iron, Vector3(0, 0.92, 0))
	var stripe := _part(_cylinder(0.425, 0.425, 0.12), band, Vector3(0, 0.62, 0))
	stripe.rotation_degrees.y = 20
	# Holes punched round the waist, glowing from the fire inside.
	var glow := _paint(FLAME, 0.0, 1.0, 2.5)
	_fire_glow = glow
	for i: int in 7:
		var angle: float = i * TAU / 7.0
		var hole := _part(_box(Vector3(0.09, 0.07, 0.02)), glow, Vector3(cos(angle) * 0.425, 0.32, sin(angle) * 0.425))
		hole.rotation.y = -angle + PI * 0.5
	# A grill laid across the top.
	for x: float in [-0.24, -0.08, 0.08, 0.24]: _part(_box(Vector3(0.025, 0.025, 0.9)), iron, Vector3(x, 0.97, 0))
	if DisplayServer.get_name() == "headless": return
	_flames = GPUParticles3D.new()
	_flames.amount = 56
	_flames.lifetime = 0.6
	_flames.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.34
	process.emission_ring_inner_radius = 0.0
	process.emission_ring_height = 0.02
	process.direction = Vector3.UP
	process.spread = 10.0
	process.initial_velocity_min = 1.4
	process.initial_velocity_max = 2.6
	process.gravity = Vector3(0, 2.0, 0)
	process.scale_min = 1.4
	process.scale_max = 2.4
	process.scale_curve = Fx.grow_curve(1.0, 0.2)
	process.color_ramp = Fx.hold_ramp(0.05, 0.6)
	_flames.process_material = process
	_flames.draw_pass_1 = Fx.quad(0.1)
	_flames.material_override = Fx.spark_material(FLAME)
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flames)
	_flames.position.y = 0.95
	var light := OmniLight3D.new()
	_fire_light = light
	light.light_color = FLAME
	light.omni_range = 5.0
	light.light_energy = 1.6
	add_child(light)
	light.position.y = 1.4

# --- Current: the fallen transformer ------------------------------------------------------------

func _transformer() -> void:
	scale = Vector3.ONE * 1.35
	var iron := _paint(Color("39403f"), 0.55, 0.5)
	# The plinth it fell off, hazard-striped, still bolted to the paving.
	var band := _paint(HAZARD, 0.1, 0.8)
	for i: int in 4:
		var stripe := _part(_box(Vector3(0.16, 0.05, 1.3)), band if i % 2 == 0 else _paint(Color("161616"), 0.0, 0.9), Vector3(-0.72 + i * 0.16, 0.025, 0.1))
		stripe.rotation_degrees.y = 25
	var rust := _paint(RUST, 0.2, 0.9)
	var porcelain := _paint(PORCELAIN, 0.0, 0.35)
	var body := _part(_box(Vector3(1.1, 0.8, 0.7)), iron, Vector3(0, 0.42, 0))
	body.rotation_degrees = Vector3(0, 12, 6)
	# Cooling fins down one side.
	for i: int in 5: _part(_box(Vector3(0.04, 0.6, 0.22)), iron, Vector3(-0.35 + i * 0.17, 0.4, 0.46)).rotation_degrees.y = 12
	_part(_box(Vector3(1.0, 0.04, 0.6)), rust, Vector3(0, 0.02, 0))
	# Three insulators on top, cables torn short; current jumps between their caps.
	for i: int in 3:
		var at := Vector3(-0.32 + i * 0.32, 0.9, -0.05)
		_part(_cylinder(0.07, 0.09, 0.26), porcelain, at)
		_part(_cylinder(0.04, 0.04, 0.05), iron, at + Vector3(0, 0.15, 0))
		var cable := _part(_cylinder(0.025, 0.025, 0.45), _paint(Color("111111"), 0.0, 0.9), at + Vector3(0.12, 0.24, 0.1))
		cable.rotation_degrees = Vector3(30, 0, -55 + i * 20)
		_terminals.append(at + Vector3(0, 0.2, 0))
	# The lamp that says it is live.
	_lamp_mesh = _paint(LAMP, 0.0, 0.4, 3.0)
	_part(_box(Vector3(0.1, 0.1, 0.1)), _lamp_mesh, Vector3(0.48, 0.88, 0.2))
	if DisplayServer.get_name() == "headless": return
	_lamp = OmniLight3D.new()
	_lamp.light_color = LAMP
	_lamp.omni_range = 2.5
	add_child(_lamp)
	_lamp.position = Vector3(0.48, 1.0, 0.2)

# --- Scrap: the junk heap ------------------------------------------------------------------------

func _heap() -> void:
	var iron := _paint(IRON, 0.6, 0.55)
	var rust := _paint(RUST, 0.2, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1971
	# The carcass: an older machine's head, half sunk, its eye not quite out.
	var head := _part(_box(Vector3(0.9, 0.6, 0.75)), rust, Vector3(0.1, 0.3, -0.1))
	head.rotation_degrees = Vector3(-14, 28, 9)
	_eye = _paint(EYE, 0.0, 0.5, 0.8)
	var eye := MeshInstance3D.new()
	eye.mesh = _cylinder(0.11, 0.11, 0.05)
	eye.material_override = _eye
	head.add_child(eye)
	eye.position = Vector3(0, 0, 0.39)
	eye.rotation_degrees.x = 90
	for i: int in 12:
		var piece := _part(_box([Vector3(0.8, 0.06, 0.5), Vector3(1.1, 0.1, 0.1), Vector3(0.35, 0.3, 0.35)][i % 3]), rust if i % 2 == 0 else iron,
			Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.05, 0.5), rng.randf_range(-0.9, 0.9)))
		piece.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-PI, PI), rng.randf_range(-0.6, 0.6))

# --- Pieces -------------------------------------------------------------------------------------

func _paint(color: Color, metallic: float, roughness: float, glow: float = 0.0) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = metallic
	paint.roughness = roughness
	if glow > 0.0:
		paint.emission_enabled = true
		paint.emission = color
		paint.emission_energy_multiplier = glow
	return paint

func _part(mesh: Mesh, paint: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = paint
	add_child(part)
	part.position = at
	return part

static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	return mesh
