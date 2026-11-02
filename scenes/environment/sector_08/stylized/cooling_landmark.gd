## The depot's old concrete water tank, standing in the authored stack's footprint. Visuals only.
## It used to read as a sci-fi "COOLANT 08" machine with cyan status bars and its own fill light;
## it is now plain stained concrete with a rusted access hatch and a ladder, lit only by the scene.
extends Node3D

func metal(hex: String, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.92
	m.metallic = 0.0
	if emission > 0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = emission
	return m

func box(at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)

func shell(y: float, height: float, bottom: float, top: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	node.mesh = mesh
	node.position.y = y
	node.rotation.y = PI / 8.0
	node.material_override = material
	add_child(node)

func setup() -> void:
	position = Vector3(-21.79335,0,-14.81795)
	rotation.y = deg_to_rad(35)
	var body := metal("5d5b55")
	var dark := metal("3a3a36")
	var edge := metal("6d6a62")
	var rust := metal("4a3e35")
	shell(0.8,1.6,6.0,5.5,dark)
	shell(5.4,7.6,4.8,4.0,body)
	shell(13.0,7.6,4.0,3.2,body)
	shell(20.2,6.8,3.2,2.6,body)
	for band: Vector3 in [Vector3(1.65,4.9,4.85),Vector3(9.2,4.12,4.07),Vector3(16.8,3.32,3.27),Vector3(23.6,2.8,2.8)]:
		shell(band.x,0.24,band.y,band.z,dark)
	# Broad structural ribs; no luminous rings or fine rivet noise.
	for x: float in [-3.05,3.05]:
		box(Vector3(x,4.3,3.25),Vector3(0.32,5.4,0.45),edge)
		box(Vector3(x,1.85,3.65),Vector3(0.8,0.5,1.3),dark)
	# The access hatch, rusted shut, and ladder rungs up the first ring.
	box(Vector3(0,4.7,4.13),Vector3(3.1,3.5,0.35),dark)
	box(Vector3(0,4.7,4.33),Vector3(1.1,1.6,0.06),rust)
	box(Vector3(0,3.13,4.34),Vector3(2.85,0.16,0.08),rust)
	for y: float in [3.6, 4.1, 4.6, 5.1, 5.6]:
		box(Vector3(1.3,y,4.42),Vector3(0.5,0.05,0.05),edge)
	# One service duct, visibly connected to the solid base.
	box(Vector3(3.85,3.4,0.5),Vector3(0.65,4.2,0.75),dark)
	box(Vector3(3.85,1.65,1.8),Vector3(0.65,0.65,3.0),dark)
