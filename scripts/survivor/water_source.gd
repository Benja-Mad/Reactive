## A burst main in the yard paving: a stub of iron pipe sheared off at the flange, a valve wheel
## nobody turns any more, and water welling up out of it into the puddle the yard keeps full. It
## is the answer to «where does the water come from»: the crew's routines draw from puddles, and
## these are the puddles that are always there. Drawn on every peer from the replicated record.
extends Node3D
const Fx = preload("res://scripts/matter/matter_fx.gd")
const IRON := Color("2a2622")
const RUST := Color("6b3a22")
const WATER := Color(0.55, 0.85, 0.95, 0.85)
var _well: GPUParticles3D

func _ready() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.roughness = 0.55
	iron.metallic = 0.6
	var rust := StandardMaterial3D.new()
	rust.albedo_color = RUST
	rust.roughness = 0.9
	# A riser up out of the paving, collared where it meets the floor.
	_part(_cylinder(0.42, 0.46, 0.12), rust, Vector3(0, 0.06, 0))
	_part(_cylinder(0.26, 0.26, 0.78), iron, Vector3(0, 0.39, 0))
	# The sheared flange, tilted where the main snapped.
	var flange := _part(_cylinder(0.38, 0.38, 0.09), rust, Vector3(0.03, 0.8, 0))
	flange.rotation_degrees = Vector3(11, 0, -8)
	# The valve on its spindle, off to one side.
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
	if DisplayServer.get_name() == "headless": return
	# Water welling over the lip and falling back: a short, steady fountain of pixel drops.
	_well = GPUParticles3D.new()
	_well.amount = 48
	_well.lifetime = 0.9
	_well.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.24
	process.emission_ring_inner_radius = 0.1
	process.emission_ring_height = 0.02
	process.direction = Vector3.UP
	process.spread = 28.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 3.6
	process.gravity = Vector3(0, -9.0, 0)
	process.scale_min = 0.6
	process.scale_max = 1.1
	_well.process_material = process
	_well.draw_pass_1 = Fx.quad(0.1)
	_well.material_override = Fx.spark_material(WATER)
	_well.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_well)
	_well.position.y = 0.84

## How hard it runs, by how full its puddle is: a drawn-down source gushes to refill.
func set_fill(fraction: float) -> void:
	if _well == null: return
	_well.amount_ratio = lerpf(1.0, 0.45, clampf(fraction, 0.0, 1.0))

func _part(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	add_child(part)
	part.position = at
	return part

static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	return mesh
