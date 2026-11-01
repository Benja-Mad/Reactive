## A solid, faceted replacement in the authored stack's footprint. Visuals only.
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

func label(words: String, at: Vector3, size: int, color: String) -> void:
	var text := Label3D.new()
	text.text = words
	text.font_size = size
	text.pixel_size = 0.014
	text.outline_size = 0
	text.modulate = Color(color)
	text.shaded = false
	text.position = at
	add_child(text)

func setup() -> void:
	position = Vector3(-21.79335,0,-14.81795)
	rotation.y = deg_to_rad(35)
	var body := metal("3f515a")
	var dark := metal("23323d")
	var edge := metal("647079")
	var warm := metal("a3875b")
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
	# A readable maintenance panel makes the landmark a machine with a purpose.
	box(Vector3(0,4.7,4.13),Vector3(3.1,3.5,0.35),dark)
	box(Vector3(0,3.13,4.34),Vector3(2.85,0.16,0.08),warm)
	label("08",Vector3(0,4.6,4.34),120,"85938b")
	label("COOLANT",Vector3(0,5.95,4.34),28,"72817b")
	var status := metal("66b9be",0.8)
	for x: float in [-1.14,1.14]:
		box(Vector3(x,4.65,4.34),Vector3(0.08,1.2,0.06),status)
	# One service duct, visibly connected to the solid base.
	box(Vector3(3.85,3.4,0.5),Vector3(0.65,4.2,0.75),dark)
	box(Vector3(3.85,1.65,1.8),Vector3(0.65,0.65,3.0),dark)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0,5.3,6.0)
	fill.light_color = Color("8bb8bc")
	fill.light_energy = 7.0
	fill.omni_range = 12.0
	fill.omni_attenuation = 1.0
	fill.light_specular = 0.0
	fill.light_volumetric_fog_energy = 0.0
	add_child(fill)
