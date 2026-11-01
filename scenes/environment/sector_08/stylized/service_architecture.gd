## Purpose-built street furniture replaces the disconnected ribbed gates and block walls.
## Solid parts create matching box collision; trim and overhead canopy never block circulation.
extends Node3D
var shapes: Array[CollisionShape3D] = []

## Fixtures live on existing furniture, above circulation. Broad diffuse cones
## make the district colours reach pavement and silhouettes without wet highlights.
func fixture(parent: Node3D, at: Vector3, toward: Vector3, color: String, energy: float, width: float) -> void:
	box(parent, at + Vector3(0,0.06,0), Vector3(width + 0.18,0.14,0.28), material("263c46"))
	box(parent, at, Vector3(width,0.045,0.18), material(color,1.3))
	var lamp := SpotLight3D.new()
	lamp.name = "ServiceLight"
	parent.add_child(lamp)
	lamp.position = at - Vector3(0,0.12,0)
	lamp.look_at(parent.to_global(toward), Vector3.UP)
	lamp.light_color = Color(color)
	lamp.light_energy = energy * 1.6
	lamp.light_specular = 0.0
	lamp.light_volumetric_fog_energy = 0.0
	lamp.spot_range = 14.0
	lamp.spot_angle = 65.0
	# Fade before reaching the cone/range boundary; sub-unit exponents made
	# the previous pools keep too much energy right up to their cutoff.
	lamp.spot_attenuation = 1.5
	lamp.spot_angle_attenuation = 2.0
	lamp.light_size = 0.35
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.03

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
	var body := material("50666d",0.06)
	var edge := material("93a39a",0.07)
	var dark := material("223941",0.025)
	var warm := material("a29370",0.05)
	var cyan := material("61b7b0",0.4)
	# A compact clinic service booth belongs beside the western building, not across the route.
	var clinic := anchor("ClinicServiceBooth",Vector3(-21,0,10),0)
	box(clinic,Vector3(0,1.25,0),Vector3(3.4,2.5,1.5),material("3f6465",0.025),true)
	box(clinic,Vector3(0,2.58,0.22),Vector3(3.75,0.16,2.05),edge)
	box(clinic,Vector3(0,1.64,0.766),Vector3(2.85,0.88,0.035),dark)
	box(clinic,Vector3(0,1.16,0.88),Vector3(3.05,0.12,0.28),edge)
	box(clinic,Vector3(-1.5,1.65,0.8),Vector3(0.06,0.8,0.04),cyan)
	box(clinic,Vector3(1.22,0.55,0.766),Vector3(0.32,0.6,0.04),dark)
	for x: float in [-1.58,1.58]:
		box(clinic,Vector3(x,0.48,0.78),Vector3(0.12,0.65,0.06),warm)
	fixture(clinic,Vector3(0,2.46,1.14),Vector3(0,0,3.4),"65dccb",15.0,2.5)
	# Two coherent cooling cabinets: one enclosure each, a circular fan and a broad intake.
	var cooling := anchor("MemoryCoolingBank",Vector3(23.5,0,6.7),43)
	for x: float in [-1.0,1.0]:
		box(cooling,Vector3(x,1.25,0),Vector3(1.8,2.5,1.5),material("535c76",0.025),true)
		box(cooling,Vector3(x,2.54,0),Vector3(1.92,0.12,1.62),edge)
		box(cooling,Vector3(x,0.5,0.77),Vector3(1.35,0.65,0.06),dark)
		for y: float in [0.33,0.55,0.77]:
			box(cooling,Vector3(x,y,0.81),Vector3(1.25,0.045,0.05),edge)
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
		cooling.add_child(fan)
		for angle: float in [0,PI/2]:
			var blade := box(cooling,Vector3(x,1.65,0.86),Vector3(0.82,0.12,0.04),edge)
			blade.rotation.z = angle + 0.4
		box(cooling,Vector3(x-0.72,1.3,0.8),Vector3(0.06,0.38,0.04),cyan)
	fixture(cooling,Vector3(0,2.72,0.95),Vector3(0,1.0,0.78),"ff658d",14.0,2.7)
	var cabinet_light := cooling.get_child(-1) as SpotLight3D
	cabinet_light.set_meta("architectural_fixture",true)
	cabinet_light.spot_range = 5.0
	# Transit shelter: slender posts at the back, a single low bench, and an open front.
	var shelter := anchor("NightlineShelter",Vector3(12,0,16),34.38)
	box(shelter,Vector3(0,3.3,0),Vector3(6.8,0.18,2.5),material("314954",0.025))
	box(shelter,Vector3(0,3.19,1.22),Vector3(6.6,0.07,0.12),edge)
	# Repeated roof ribs and an asymmetric rear spine read as a transit canopy.
	box(shelter,Vector3(0,3.48,-0.85),Vector3(6.8,0.28,0.22),edge)
	for x: float in [-2.65,0,2.65]:
		box(shelter,Vector3(x,3.15,0.25),Vector3(0.12,0.16,2.05),edge)
	for x: float in [-2.65,2.65]:
		box(shelter,Vector3(x,1.6,-0.8),Vector3(0.22,3.2,0.22),edge,true)
		box(shelter,Vector3(x,0.35,-0.8),Vector3(0.27,0.22,0.27),warm)
	for x: float in [-1.4,1.4]:
		box(shelter,Vector3(x,0.25,-0.65),Vector3(0.2,0.5,0.48),edge,true)
	box(shelter,Vector3(0,0.55,-0.65),Vector3(3.72,0.12,0.75),warm,true)
	box(shelter,Vector3(0,0.95,-0.98),Vector3(3.6,0.55,0.12),material("65515a",0.025),true)
	var composition := preload("res://scenes/environment/sector_08/stylized/transit_composition.gd").new()
	composition.name = "TransitComposition"
	shelter.add_child(composition)
	composition.compose(shelter)
