## The depot's furniture: the taller's tool lockers, the electric micros' chargers, the drivers'
## shelter. (Node names are the old ones; tests and the trial look them up.) Solid parts create
## matching box collision; trim and overhead canopy never block circulation. No lights: the old
## clinic booth, memory bank and Nightline shelter each threw a coloured shadowed spot.
extends Node3D
var shapes: Array[CollisionShape3D] = []

## A mounted tube fixture: housing and a dim white-green tube, no light of its own (the depot's
## lights belong to DepotLighting; these used to throw cyan, rose and violet shadowed spots).
func fixture(parent: Node3D, at: Vector3, color: String, glow: float, width: float) -> void:
	box(parent, at + Vector3(0,0.06,0), Vector3(width + 0.18,0.14,0.28), material("33393a"))
	box(parent, at, Vector3(width,0.045,0.18), material(color,glow))

func material(hex: String, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.95
	m.metallic_specular = 0.0
	m.emission_enabled = true
	m.emission = Color(hex)
	m.emission_energy_multiplier = glow
	return m

func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.position = at
	mesh.material_override = mat
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		mesh.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		shapes.append(collision)
	return mesh

func anchor(id: String, at: Vector3, yaw: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = id
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw)
	add_child(holder)
	return holder

func setup() -> void:
	var edge := material("7d827a",0.03)
	var dark := material("262b2c",0.01)
	var warm := material("8f8370",0.03)
	var cyan := material("1fc8ff",1.6)
	# The taller's tool lockers against the western building: grey-green steel, one door ajar.
	var lockers := anchor("ClinicServiceBooth",Vector3(-21,0,10),0)
	box(lockers,Vector3(0,1.25,0),Vector3(3.4,2.5,1.5),material("56625c",0.02),true)
	box(lockers,Vector3(0,2.58,0.22),Vector3(3.75,0.16,2.05),edge)
	for x: float in [-1.27,-0.42,0.42,1.27]:
		box(lockers,Vector3(x,1.3,0.766),Vector3(0.78,2.2,0.035),material("4c5852",0.02))
		box(lockers,Vector3(x+0.28,1.35,0.79),Vector3(0.04,0.16,0.03),dark)
		for y: float in [2.2,2.28,2.36]:
			box(lockers,Vector3(x,y,0.79),Vector3(0.5,0.03,0.02),dark)
	var ajar := box(lockers,Vector3(1.62,1.3,1.12),Vector3(0.035,2.2,0.78),material("4c5852",0.02))
	ajar.rotation.y = deg_to_rad(-8)
	for x: float in [-1.58,1.58]:
		box(lockers,Vector3(x,0.48,0.78),Vector3(0.12,0.65,0.06),warm)
	fixture(lockers,Vector3(0,2.46,1.14),"cfe6d2",0.6,1.2)
	# Two chargers for the electric micros: one cabinet each, a fan, a coiled cable on its hook.
	var chargers := anchor("MemoryCoolingBank",Vector3(23.5,0,6.7),43)
	for x: float in [-1.0,1.0]:
		box(chargers,Vector3(x,1.25,0),Vector3(1.8,2.5,1.5),material("62686a",0.02),true)
		box(chargers,Vector3(x,2.54,0),Vector3(1.92,0.12,1.62),edge)
		box(chargers,Vector3(x,0.5,0.77),Vector3(1.35,0.65,0.06),dark)
		for y: float in [0.33,0.55,0.77]:
			box(chargers,Vector3(x,y,0.81),Vector3(1.25,0.045,0.05),edge)
		var fan := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 0.54
		disk.bottom_radius = 0.54
		disk.height = 0.08
		disk.radial_segments = 12
		fan.mesh = disk
		fan.material_override = dark
		fan.position = Vector3(x,1.65,0.8)
		fan.rotation.x = PI/2
		chargers.add_child(fan)
		for angle: float in [0,PI/2]:
			var blade := box(chargers,Vector3(x,1.65,0.86),Vector3(0.82,0.12,0.04),edge)
			blade.rotation.z = angle + 0.4
		# Charging LEDs, the one live colour on the cabinets: a cyan strip under the cap and a ladder by
		# the socket (the left charger is still filling, its top segments dark). DepotEdges hangs the
		# neon marker that gives them a light.
		box(chargers,Vector3(x,2.42,0.78),Vector3(1.62,0.035,0.03),cyan)
		for step: int in 5:
			box(chargers,Vector3(x-0.72,1.05+float(step)*0.13,0.79),Vector3(0.16,0.06,0.02),cyan if (x > 0 or step < 3) else dark)
		box(chargers,Vector3(x+0.45,1.0,0.9),Vector3(0.14,0.14,0.03),cyan)
		# Cable coiled on its hook, connector hanging.
		var coil := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.26
		ring.outer_radius = 0.34
		ring.rings = 12
		ring.ring_segments = 6
		coil.mesh = ring
		coil.material_override = material("1d1f20")
		coil.position = Vector3(x+0.45,1.0,0.85)
		coil.rotation.x = PI/2
		chargers.add_child(coil)
	# Drivers' shelter: slender posts at the back, a single low bench, an open front.
	var shelter := anchor("NightlineShelter",Vector3(12,0,16),34.38)
	box(shelter,Vector3(0,3.3,0),Vector3(6.8,0.18,2.5),material("3a4144",0.02))
	box(shelter,Vector3(0,3.19,1.22),Vector3(6.6,0.07,0.12),edge)
	box(shelter,Vector3(0,3.48,-0.85),Vector3(6.8,0.28,0.22),edge)
	for x: float in [-2.65,0,2.65]:
		box(shelter,Vector3(x,3.15,0.25),Vector3(0.12,0.16,2.05),edge)
	for x: float in [-2.65,2.65]:
		box(shelter,Vector3(x,1.6,-0.8),Vector3(0.22,3.2,0.22),edge,true)
		box(shelter,Vector3(x,0.35,-0.8),Vector3(0.27,0.22,0.27),warm)
	for x: float in [-1.4,1.4]:
		box(shelter,Vector3(x,0.25,-0.65),Vector3(0.2,0.5,0.48),edge,true)
	box(shelter,Vector3(0,0.55,-0.65),Vector3(3.72,0.12,0.75),warm,true)
	box(shelter,Vector3(0,0.95,-0.98),Vector3(3.6,0.55,0.12),material("5a5650",0.02),true)
	var composition := preload("res://scenes/environment/sector_08/stylized/transit_composition.gd").new()
	composition.name = "TransitComposition"
	shelter.add_child(composition)
	composition.compose(shelter)
