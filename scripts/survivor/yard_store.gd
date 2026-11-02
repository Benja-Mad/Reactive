## The yard's stores that are not water, each the answer to «where does this come from»:
## - fire: a night-shift warming drum, holes punched round its waist, a grill laid across the top,
##   the depot's stencil half burnt off; the flames over it are the fire a routine draws. People
##   lit these (depot_yard.gd dresses the sereno's chair and thermos round the west one).
## - current, by where it lies: the pole transformer that came down with the snapped pole, on its
##   side on a broken plinth, cables torn short; or the guts of the substation cabinet by the fence
##   (its rack of busbars and fuse carriers, ripped out and dragged into the yard). Either way the
##   current jumping between the terminals is what says it is live, and how often it jumps says
##   how much is left. No warning lamp: red belongs to the machines.
## - scrap: the heap the last crew left, plates, bars, a wheel rim, a seat frame, an engine cover.
##   The pile a routine draws from lies around it.
## Drawn on every peer from the replicated record; nothing here touches gameplay.
extends Node3D
const Fx = preload("res://scripts/matter/matter_fx.gd")
const CombatFx = preload("res://scenes/actions/combat_fx.gd")
const IRON := Color("2a2622")
const RUST := Color("6b3a22")
const STENCIL := Color("7d7663")
const PORCELAIN := Color("cfc8b8")
const FLAME := Color("ff7a2a")
const SPARK := Color("f4e86a")
## The light of a live arc between terminals: blue-white. The tool amber stays the UI's signal.
const ARC := Color("d4e2ff")
## The cabinet whose guts these are (run.gd STORES current); everything else is the fallen transformer.
const CABINET_STORE := Vector2(-7, -11)

var kind: String = "fire"
var _fire_light: OmniLight3D
var _fire_glow: StandardMaterial3D
var _lit: bool = true
var _flames: GPUParticles3D
var _fill: float = 1.0
var _time: float = 0.0
var _next_arc: float = 0.5
var _terminals: Array[Vector3] = []

func _ready() -> void:
	# The record places this node after adding it; build once it stands where it belongs.
	_build.call_deferred()

func _build() -> void:
	match kind:
		"fire": _drum()
		"current":
			if Vector2(global_position.x, global_position.z).distance_to(CABINET_STORE) < 1.5: _guts()
			else: _transformer()
		"scrap": _heap()
	set_fill(_fill)
	set_lit(_lit)

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
	if kind == "current" and DisplayServer.get_name() != "headless":
		_next_arc -= delta
		if _next_arc <= 0.0 and _terminals.size() >= 2:
			_next_arc = lerpf(2.2, 0.35, _fill) * randf_range(0.6, 1.4)
			var a: Vector3 = to_global(_terminals[randi() % _terminals.size()])
			var b: Vector3 = to_global(_terminals[randi() % _terminals.size()])
			if a != b: CombatFx.beam(get_parent(), a, b, ARC, 0.12, 0.03)
			CombatFx.spark(get_parent(), a, SPARK, 4)

# --- Fire: the warming drum ---------------------------------------------------------------------

func _drum() -> void:
	var iron := _paint(IRON, 0.6, 0.55)
	var rust := _paint(RUST, 0.2, 0.9)
	var band := _paint(STENCIL, 0.1, 0.9)
	_part(_cylinder(0.42, 0.42, 0.95), rust, Vector3(0, 0.475, 0))
	_part(_cylinder(0.43, 0.43, 0.06), iron, Vector3(0, 0.05, 0))
	_part(_cylinder(0.43, 0.43, 0.06), iron, Vector3(0, 0.92, 0))
	# What is left of the depot's stencil band, burnt off on the fire side.
	var stripe := _part(_cylinder(0.425, 0.425, 0.08), band, Vector3(0, 0.66, 0))
	stripe.rotation_degrees = Vector3(4, 20, 2)
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
	# Galvanised grey with a pale worn edge, so the can holds its shape in the dark beside its arcs.
	var iron := _paint(Color("5a6462"), 0.55, 0.5)
	var edge := _paint(Color("9aa29e"), 0.4, 0.5)
	var concrete := _paint(Color("6f6d68"), 0.0, 0.95)
	var porcelain := _paint(PORCELAIN, 0.0, 0.35)
	var cable := _paint(Color("111111"), 0.0, 0.9)
	# The broken plinth it fell from: two concrete chunks, one tipped.
	_part(_box(Vector3(0.7, 0.14, 0.5)), concrete, Vector3(-0.75, 0.07, 0.35)).rotation_degrees = Vector3(0, 22, 4)
	_part(_box(Vector3(0.4, 0.12, 0.35)), concrete, Vector3(-0.95, 0.12, -0.25)).rotation_degrees = Vector3(18, -10, 12)
	# The can on its side, dented, oil weeping from a split seam.
	var body := _part(_box(Vector3(1.1, 0.8, 0.7)), iron, Vector3(0, 0.38, 0))
	body.rotation_degrees = Vector3(0, 12, 14)
	for i: int in 5: _part(_box(Vector3(0.04, 0.58, 0.2)), iron, Vector3(-0.35 + i * 0.17, 0.38, 0.45)).rotation_degrees = Vector3(0, 12, 14)
	# The worn top edge and the enamel warning plate on its flank, the two pale things on it.
	_part(_box(Vector3(1.12, 0.05, 0.72)), edge, Vector3(-0.1, 0.78, 0)).rotation_degrees = Vector3(0, 12, 14)
	_part(_box(Vector3(0.34, 0.24, 0.02)), _paint(Color("a8a290"), 0.0, 0.6), Vector3(0.05, 0.42, 0.36)).rotation_degrees = Vector3(0, 12, 14)
	_part(_box(Vector3(0.9, 0.02, 0.5)), _paint(Color("161412"), 0.0, 0.2), Vector3(0.2, 0.01, 0.3))
	# Three insulators on top, one snapped; cables torn short. Current jumps between their caps.
	for i: int in 3:
		var at := Vector3(-0.3 + i * 0.3, 0.86 - i * 0.05, -0.05)
		var insulator := _part(_cylinder(0.07, 0.09, 0.26 if i != 1 else 0.14), porcelain, at)
		insulator.rotation_degrees.z = 14
		_part(_cylinder(0.04, 0.04, 0.05), iron, at + Vector3(0.03, 0.15, 0))
		var lead := _part(_cylinder(0.025, 0.025, 0.45), cable, at + Vector3(0.12, 0.24, 0.1))
		lead.rotation_degrees = Vector3(30, 0, -55 + i * 20)
		_terminals.append(at + Vector3(0.03, 0.2, 0))

## The cabinet's guts: the busbar rack wrenched out of the substation cabinet, lying tipped on the
## paving, fuse carriers hanging off it, the torn cable bundle (depot_yard.gd runs it back to the
## cabinet). Low enough to walk round and read as the thing that is live.
func _guts() -> void:
	var steel := _paint(Color("59605d"), 0.5, 0.55)
	var copper := _paint(Color("7a5c3a"), 0.6, 0.45)
	var porcelain := _paint(PORCELAIN, 0.0, 0.35)
	var rack := Node3D.new()
	add_child(rack)
	rack.rotation_degrees = Vector3(0, -18, 62)
	rack.position = Vector3(0, 0.32, 0)
	for x: float in [-0.5, 0.5]:
		var post := MeshInstance3D.new()
		post.mesh = _box(Vector3(0.06, 1.0, 0.06))
		post.material_override = steel
		rack.add_child(post)
		post.position = Vector3(x, 0, 0)
	for i: int in 3:
		var bar := MeshInstance3D.new()
		bar.mesh = _box(Vector3(1.0, 0.05, 0.03))
		bar.material_override = copper
		rack.add_child(bar)
		bar.position = Vector3(0, -0.3 + i * 0.3, 0.05)
	# Fuse carriers: porcelain blocks still clipped to the bars, one dangling on the floor.
	for i: int in 3:
		var at := Vector3(-0.35 + i * 0.35, 0.22, 0.25)
		_part(_box(Vector3(0.14, 0.18, 0.1)), porcelain, at).rotation_degrees = Vector3(0, -18, 10 * i)
		_terminals.append(at + Vector3(0, 0.14, 0))
	_part(_box(Vector3(0.14, 0.1, 0.18)), porcelain, Vector3(0.6, 0.05, -0.35)).rotation_degrees.y = 40

# --- Scrap: the junk heap ------------------------------------------------------------------------

func _heap() -> void:
	var iron := _paint(IRON, 0.6, 0.55)
	var rust := _paint(RUST, 0.2, 0.9)
	var zinc := _paint(Color("6a7372"), 0.4, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1971
	# The heap's back: an engine cover and a seat frame, the two big pieces everything leans on.
	var cover := _part(_box(Vector3(0.95, 0.5, 0.7)), rust, Vector3(0.1, 0.25, -0.15))
	cover.rotation_degrees = Vector3(-14, 28, 9)
	var seat := _part(_box(Vector3(0.9, 0.06, 0.45)), iron, Vector3(-0.55, 0.42, 0.2))
	seat.rotation_degrees = Vector3(35, -20, 0)
	for x: float in [-0.4, 0.4]:
		_part(_box(Vector3(0.04, 0.45, 0.04)), iron, Vector3(-0.55 + x, 0.22, 0.32)).rotation_degrees.x = 20
	# A wheel rim on its edge.
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.3
	torus.rings = 12
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = zinc
	add_child(rim)
	rim.position = Vector3(0.75, 0.28, 0.35)
	rim.rotation_degrees = Vector3(80, 30, 0)
	for i: int in 12:
		var piece := _part(_box([Vector3(0.8, 0.06, 0.5), Vector3(1.1, 0.1, 0.1), Vector3(0.35, 0.3, 0.35)][i % 3]), [rust, iron, zinc][i % 3],
			Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.05, 0.45), rng.randf_range(-0.9, 0.9)))
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
