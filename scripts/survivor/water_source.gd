## Where a yard puddle comes from: each of the yard's water sources has its own fixture, the thing
## that broke tonight and keeps its puddle full. Which fixture is chosen by where the source lies
## (run.gd SOURCES), so every peer draws the same yard from the replicated record:
## - the lifted cámara on the drain line, its lid shoved off, water welling out of the shaft;
## - a burst main: an iron riser sheared at the flange, a valve wheel nobody turns any more;
## - the squat grifo by the bays, cap knocked off, spraying sideways;
## - the wash bay's outlet, the pipe from the burst cistern bent up out of the pad and gushing;
## - the canal overflow grate, the drain backing up through its bars;
## - the estanque's overflow, falling from the pipe over the puddle (the tank is depot_yard.gd's).
## Drawn on every peer; nothing here touches gameplay. Fixtures are painted the way the water
## company paints them (blue-grey mains, an ochre grifo, galvanised pipe) with a pale worn edge so
## they hold their silhouette at night, and each mouth carries a little pale-cyan wet sheen: the
## element's colour, quiet, where the water actually leaves the iron.
extends Node3D
const Fx = preload("res://scripts/matter/matter_fx.gd")
const IRON := Color("4a5f6b")
const MAIN_EDGE := Color("8a9ba3")
const RUST := Color("7a4a33")
const STEEL := Color("7f8986")
const CONCRETE := Color("85837c")
const GRIFO := Color("b39b52")
const GRIFO_CAP := Color("cfc8b8")
const WATER := Color(0.66, 0.86, 0.9, 0.75)
## The wet sheen at a mouth: unshaded, half there.
const SHEEN := Color(0.62, 0.86, 0.92, 0.5)
## The yard's sources, in run.gd's order, and the fixture each one is.
const FIXTURES := [
	[Vector2(-7.75, -1.7), "camara"], [Vector2(-17, -4), "main"], [Vector2(14.5, -8), "grifo"],
	[Vector2(-14, 15), "outlet"], [Vector2(5, 19.5), "grate"], [Vector2(18.5, 13), "overflow"],
]
var fixture: String = ""
var _well: GPUParticles3D
var _fill: float = 1.0

func _ready() -> void:
	# The record places this node after adding it; choose the fixture once it stands there.
	_build.call_deferred()

func _build() -> void:
	if fixture == "":
		fixture = "main"
		var here := Vector2(global_position.x, global_position.z)
		for entry: Array in FIXTURES:
			if here.distance_to(entry[0]) < 1.5: fixture = entry[1]
	match fixture:
		"camara": _camara()
		"grifo": _grifo()
		"outlet": _outlet()
		"grate": _grate()
		"overflow": _overflow()
		_: _main()
	set_fill(_fill)

## How hard it runs, by how full its puddle is: a drawn-down source gushes to refill.
func set_fill(fraction: float) -> void:
	_fill = clampf(fraction, 0.0, 1.0)
	if _well == null: return
	_well.amount_ratio = lerpf(1.0, 0.45, _fill)

# --- Fixtures -------------------------------------------------------------------------------

func _camara() -> void:
	var iron := _paint(IRON, 0.5, 0.6)
	var concrete := _paint(CONCRETE, 0.0, 0.95)
	# The frame round the shaft, flush with the paving, and the black of the shaft itself.
	for side: int in 4:
		var bar := _part(_box(Vector3(1.0, 0.06, 0.12)), concrete, Vector3(sin(side * PI * 0.5) * 0.44, 0.03, cos(side * PI * 0.5) * 0.44))
		bar.rotation.y = side * PI * 0.5
	_part(_box(Vector3(0.76, 0.02, 0.76)), _paint(Color("0b0d0e"), 0.0, 0.3), Vector3(0, 0.015, 0))
	# The lid, shoved half off and propped on the frame's edge.
	var lid := _part(_cylinder(0.36, 0.36, 0.05), _paint(STEEL, 0.5, 0.5), Vector3(0.62, 0.12, 0.35))
	lid.rotation_degrees = Vector3(14, 30, -10)
	# Water brimming at the shaft's mouth.
	_part(_cylinder(0.34, 0.34, 0.01), _sheen(), Vector3(0, 0.03, 0))
	_well_at(Vector3(0, 0.04, 0), 0.24, 1.6, 2.6, 30.0, 40)

func _main() -> void:
	var iron := _paint(IRON, 0.5, 0.6)
	var rust := _paint(RUST, 0.1, 0.9)
	_part(_cylinder(0.42, 0.46, 0.12), rust, Vector3(0, 0.06, 0))
	_part(_cylinder(0.26, 0.26, 0.78), iron, Vector3(0, 0.39, 0))
	var flange := _part(_cylinder(0.38, 0.38, 0.09), _paint(MAIN_EDGE, 0.5, 0.5), Vector3(0.03, 0.8, 0))
	flange.rotation_degrees = Vector3(11, 0, -8)
	# Wet down the side facing the camera, and brimming in the sheared mouth.
	_part(_box(Vector3(0.12, 0.7, 0.02)), _sheen(), Vector3(-0.05, 0.42, 0.265))
	var mouth := _part(_cylinder(0.22, 0.22, 0.01), _sheen(), Vector3(0.03, 0.85, 0))
	mouth.rotation_degrees = Vector3(11, 0, -8)
	_part(_cylinder(0.05, 0.05, 0.5), iron, Vector3(0.48, 0.25, 0.08))
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.14
	torus.rings = 12
	torus.ring_segments = 6
	wheel.mesh = torus
	wheel.material_override = rust
	add_child(wheel)
	wheel.position = Vector3(0.48, 0.52, 0.08)
	wheel.scale = Vector3.ONE * 1.4
	_well_at(Vector3(0, 0.84, 0), 0.24, 2.0, 3.6, 28.0, 48)

func _grifo() -> void:
	var body := _paint(GRIFO, 0.1, 0.75)
	var iron := _paint(IRON, 0.5, 0.6)
	# The squat Chilean hydrant: a fat barrel, a dome, two side nozzles -- one cap gone.
	_part(_cylinder(0.24, 0.26, 0.1), iron, Vector3(0, 0.05, 0))
	_part(_cylinder(0.19, 0.2, 0.5), body, Vector3(0, 0.35, 0))
	_part(_cylinder(0.12, 0.2, 0.12), body, Vector3(0, 0.66, 0))
	_part(_cylinder(0.05, 0.05, 0.06), _paint(GRIFO_CAP, 0.2, 0.6), Vector3(0, 0.75, 0))
	# A pale band of paint round the dome, the thing that catches the light first.
	_part(_cylinder(0.205, 0.205, 0.05), _paint(GRIFO_CAP, 0.1, 0.7), Vector3(0, 0.58, 0))
	var nozzle := _part(_cylinder(0.07, 0.07, 0.16), body, Vector3(0.24, 0.42, 0))
	nozzle.rotation_degrees.z = 90
	var capped := _part(_cylinder(0.08, 0.08, 0.12), body, Vector3(-0.22, 0.42, 0))
	capped.rotation_degrees.z = 90
	# The knocked-off cap lying on the paving.
	var cap := _part(_cylinder(0.08, 0.08, 0.06), body, Vector3(0.75, 0.04, 0.4))
	cap.rotation_degrees.x = 80
	var mouth := _part(_cylinder(0.075, 0.075, 0.01), _sheen(), Vector3(0.325, 0.42, 0))
	mouth.rotation_degrees.z = 90
	_part(_box(Vector3(0.5, 0.01, 0.3)), _sheen(), Vector3(0.55, 0.02, 0.0))
	var spray := _well_at(Vector3(0.32, 0.42, 0), 0.04, 3.0, 4.6, 10.0, 56)
	if spray != null:
		var process := spray.process_material as ParticleProcessMaterial
		process.direction = Vector3(1, 0.35, 0)

func _outlet() -> void:
	var rust := _paint(STEEL, 0.5, 0.55)
	var iron := _paint(IRON, 0.5, 0.6)
	# The cistern's pipe, bent up out of the pad where it tore, open end gushing.
	var run := _part(_cylinder(0.07, 0.07, 0.7), rust, Vector3(-0.35, 0.08, -0.2))
	run.rotation_degrees = Vector3(0, 30, 90)
	var up := _part(_cylinder(0.07, 0.07, 0.4), rust, Vector3(0, 0.25, 0))
	up.rotation_degrees.z = -25
	_part(_cylinder(0.1, 0.1, 0.05), iron, Vector3(0.08, 0.44, 0))
	_part(_cylinder(0.08, 0.08, 0.01), _sheen(), Vector3(0.08, 0.47, 0))
	_part(_box(Vector3(0.03, 0.36, 0.03)), _sheen(), Vector3(0.1, 0.27, 0.07)).rotation_degrees.z = -25
	_well_at(Vector3(0.08, 0.46, 0), 0.08, 1.8, 3.0, 18.0, 44)

func _grate() -> void:
	var iron := _paint(Color("6a706d"), 0.5, 0.55)
	var dark := _paint(Color("0b0d0e"), 0.0, 0.3)
	_part(_box(Vector3(1.1, 0.02, 0.7)), dark, Vector3(0, 0.012, 0))
	# The backed-up water standing level with the bars.
	_part(_box(Vector3(1.04, 0.005, 0.64)), _sheen(), Vector3(0, 0.03, 0))
	for i: int in 7:
		_part(_box(Vector3(0.06, 0.04, 0.7)), iron, Vector3(-0.48 + i * 0.16, 0.025, 0))
	_part(_box(Vector3(1.22, 0.05, 0.08)), iron, Vector3(0, 0.025, 0.39))
	_part(_box(Vector3(1.22, 0.05, 0.08)), iron, Vector3(0, 0.025, -0.39))
	# The drain backing up: a low, wide boil through the bars.
	_well_at(Vector3(0, 0.05, 0), 0.4, 0.8, 1.5, 35.0, 40)

func _overflow() -> void:
	# The tank's pipe ends 3.2 m up, over the puddle (depot_yard.gd builds tank and pipe):
	# here is only the water falling from it and the splash where it lands, and the wet sheen at
	# the pipe's mouth, so the fall reads as leaving the iron and not the night air.
	_part(_cylinder(0.09, 0.09, 0.05), _sheen(), Vector3(0, 3.18, 0))
	var fall := _well_at(Vector3(0, 3.1, 0), 0.05, 0.0, 0.3, 6.0, 40)
	if fall != null:
		fall.lifetime = 0.8
		var process := fall.process_material as ParticleProcessMaterial
		process.direction = Vector3.DOWN
	_well = _well_at(Vector3(0, 0.05, 0), 0.25, 1.2, 2.0, 40.0, 24)

## Water leaving the fixture: a short, steady spray of pale pixel drops falling back.
func _well_at(at: Vector3, ring: float, speed_min: float, speed_max: float, spread: float, amount: int) -> GPUParticles3D:
	if DisplayServer.get_name() == "headless": return null
	var well := GPUParticles3D.new()
	well.amount = amount
	well.lifetime = 0.9
	well.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = maxf(ring, 0.02)
	process.emission_ring_inner_radius = ring * 0.4
	process.emission_ring_height = 0.02
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = Vector3(0, -9.0, 0)
	process.scale_min = 0.6
	process.scale_max = 1.1
	well.process_material = process
	well.draw_pass_1 = Fx.quad(0.1)
	well.material_override = Fx.spark_material(WATER)
	well.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(well)
	well.position = at
	_well = well
	return well

# --- Pieces -------------------------------------------------------------------------------

func _sheen() -> StandardMaterial3D:
	var wet := StandardMaterial3D.new()
	wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.albedo_color = SHEEN
	return wet

func _paint(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = metallic
	paint.roughness = roughness
	return paint

func _part(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
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
