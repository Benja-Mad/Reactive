## The depot's furniture: the taller's tool lockers, the electric micros' chargers, the drivers'
## shelter. (Node names are the old ones; tests and the trial look them up.) Solid parts create
## matching box collision; trim and overhead canopy never block circulation. No lights: the old
## clinic booth, memory bank and Nightline shelter each threw a coloured shadowed spot.
extends Node3D
const PLATE_FONT := preload("res://ui/kit/font.fnt")
var shapes: Array[CollisionShape3D] = []

## Painted or printed lettering in the crew's pixel font; `height` is the capital height in metres.
func plate(parent: Node3D, words: String, at: Vector3, height: float, hex: String, yaw_deg: float = 0.0, lit: bool = false) -> Label3D:
	var label := Label3D.new()
	label.font = PLATE_FONT
	label.font_size = 12
	label.text = words
	label.pixel_size = height / 7.0
	label.modulate = Color(hex)
	label.outline_size = 0
	label.shaded = not lit
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = at
	label.rotation_degrees.y = yaw_deg
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(label)
	return label

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
	box(lockers,Vector3(0,1.25,0),Vector3(3.4,2.5,1.5),material("8f9690",0.05),true)
	box(lockers,Vector3(0,2.58,0.22),Vector3(3.75,0.16,2.05),edge)
	for x: float in [-1.27,-0.42,0.42,1.27]:
		box(lockers,Vector3(x,1.3,0.766),Vector3(0.78,2.2,0.035),material("858d88",0.05))
		box(lockers,Vector3(x+0.28,1.35,0.79),Vector3(0.04,0.16,0.03),dark)
		for y: float in [2.2,2.28,2.36]:
			box(lockers,Vector3(x,y,0.79),Vector3(0.5,0.03,0.02),dark)
	var ajar := box(lockers,Vector3(1.62,1.3,1.12),Vector3(0.035,2.2,0.78),material("858d88",0.05))
	ajar.rotation.y = deg_to_rad(-8)
	for x: float in [-1.58,1.58]:
		box(lockers,Vector3(x,0.48,0.78),Vector3(0.12,0.65,0.06),warm)
	fixture(lockers,Vector3(0,2.46,1.14),"cfe6d2",0.6,1.2)
	# Pressed ribs, numbers and a padlock hasp on each door; the kick zone scuffed to bare steel.
	var seam := material("3c4441",0.01)
	var scuff := material("aab0a8",0.05)
	var rust := material("6b4a33",0.02)
	for i: int in 4:
		var x: float = [-1.27,-0.42,0.42,1.27][i]
		box(lockers,Vector3(x,1.62,0.787),Vector3(0.6,0.025,0.012),seam)
		box(lockers,Vector3(x,0.92,0.787),Vector3(0.6,0.025,0.012),seam)
		box(lockers,Vector3(x,1.95,0.79),Vector3(0.26,0.16,0.01),material("ddd5bb",0.08))
		plate(lockers,str(i + 1),Vector3(x,1.95,0.797),0.09,"2a3236")
		box(lockers,Vector3(x+0.28,1.18,0.8),Vector3(0.05,0.09,0.04),material("8d8b80",0.02))
		box(lockers,Vector3(x+0.02*float(i%2),0.32,0.787),Vector3(0.6,0.22-0.05*float(i%3),0.01),scuff)
	# Rust weeping from the vents of the two end doors, and a band of it along the plinth.
	for x: float in [-1.27,1.27]:
		box(lockers,Vector3(x+0.12,1.98,0.789),Vector3(0.05,0.36,0.008),rust)
	box(lockers,Vector3(0,0.06,0.77),Vector3(3.4,0.1,0.02),rust)
	# Stencil on the cap and a sticker from the taller.
	box(lockers,Vector3(0,2.58,1.255),Vector3(3.5,0.13,0.01),material("ddd5bb",0.08))
	plate(lockers,"HERRAMIENTAS · NO SE PRESTAN",Vector3(0,2.58,1.262),0.07,"27313a")
	# Hazard tape along the kick plate, half peeled on the second door.
	for k: int in 14:
		if k in [4,5]: continue
		box(lockers,Vector3(-1.62+float(k)*0.25,0.16,0.79),Vector3(0.125,0.07,0.008),material("d6b23a",0.05))
	box(lockers,Vector3(-0.42,1.38,0.79),Vector3(0.36,0.24,0.01),material("b02f72",0.06))
	plate(lockers,"EL CHISPA\nMECÁNICA",Vector3(-0.42,1.38,0.797),0.045,"f2e6dc")
	# Side faces: vertical seams and a dent line, seen from the west.
	for side: float in [-1.0,1.0]:
		for z: float in [-0.35,0.35]:
			box(lockers,Vector3(side*1.705,1.25,z),Vector3(0.012,2.3,0.025),seam)
		box(lockers,Vector3(side*1.705,0.7,0.0),Vector3(0.012,0.04,1.3),seam)
	# Two chargers for the electric micros: one cabinet each, a fan, a coiled cable on its hook. They
	# stand at the head of bay 01, behind the first micro's tail, facing the yard; the right one is
	# plugged into it.
	var chargers := anchor("MemoryCoolingBank",Vector3(10.33,0,-14.97),35)
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
		# Round guard over the fan: a steel rim, horizontal bars cut to the circle, a small hub.
		var rim := MeshInstance3D.new()
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.5
		hoop.outer_radius = 0.56
		hoop.rings = 16
		hoop.ring_segments = 4
		rim.mesh = hoop
		rim.material_override = edge
		rim.position = Vector3(x,1.65,0.84)
		rim.rotation.x = PI/2
		chargers.add_child(rim)
		for bar: int in 7:
			var dy: float = -0.39 + float(bar) * 0.13
			box(chargers,Vector3(x,1.65+dy,0.85),Vector3(2.0*sqrt(0.25-dy*dy),0.03,0.02),edge)
		box(chargers,Vector3(x,1.65,0.86),Vector3(0.14,0.14,0.03),material("8d8b80",0.02))
		# Charging LEDs, the one live colour on the cabinets: a cyan strip under the cap and a ladder by
		# the socket (the left charger is still filling, its top segments dark). DepotEdges hangs the
		# neon marker that gives them a light.
		box(chargers,Vector3(x,2.36,0.78),Vector3(1.66,0.1,0.04),cyan)
		for step: int in 5:
			box(chargers,Vector3(x-0.66,1.0+float(step)*0.17,0.79),Vector3(0.3,0.11,0.03),cyan if (x > 0 or step < 3) else dark)
		box(chargers,Vector3(x+0.45,1.0,0.9),Vector3(0.22,0.22,0.03),cyan)
		# Rating plate and a warning sticker.
		box(chargers,Vector3(x+0.2,2.08,0.765),Vector3(0.9,0.2,0.01),material("c9c1a8",0.02))
		plate(chargers,"CARGADOR %d · 80 kW" % (1 if x < 0 else 2),Vector3(x+0.2,2.08,0.772),0.05,"27313a")
		box(chargers,Vector3(x-0.62,1.95,0.765),Vector3(0.26,0.26,0.01),material("d6b23a",0.03))
		plate(chargers,"ALTO\nVOLTAJE",Vector3(x-0.62,1.95,0.772),0.04,"1d1f20")
		if x > 0.0:
			# In use: the cable runs from the socket across the floor into the micro's tail.
			var black := material("1d1f20")
			box(chargers,Vector3(x+0.47,0.52,0.95),Vector3(0.06,0.96,0.06),black)
			var run_cable := box(chargers,Vector3(1.885,0.035,1.29),Vector3(1.04,0.06,0.06),black)
			run_cable.rotation.y = deg_to_rad(-36.8)
			box(chargers,Vector3(2.3,0.42,1.6),Vector3(0.06,0.74,0.06),black)
			box(chargers,Vector3(2.3,0.82,1.6),Vector3(0.14,0.14,0.18),dark)
			continue
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
	# Wear and print on the bench and the timetable post, added after the composition repaints the
	# massing so they keep their own values: slat seams, a sticker-plastered backrest, scuffs.
	var slat_seam := composition.ink("2c2826")
	for k: int in 4:
		box(shelter,Vector3(0,0.615,-0.93+0.19*float(k)),Vector3(3.7,0.008,0.025),slat_seam)
	for x: float in [-1.2,0.0,1.2]:
		box(shelter,Vector3(x,0.95,-0.918),Vector3(0.025,0.53,0.006),slat_seam)
	box(shelter,Vector3(0,1.08,-0.917),Vector3(3.58,0.02,0.006),slat_seam)
	box(shelter,Vector3(-0.55,0.95,-0.915),Vector3(0.9,0.36,0.006),composition.ink("c9c1a8"))
	plate(shelter,"RECORRIDO 08\nTERMINAL · PLAZA",Vector3(-0.55,0.95,-0.909),0.05,"27313a")
	box(shelter,Vector3(0.75,0.98,-0.915),Vector3(0.34,0.22,0.006),composition.ink("b02f72"))
	plate(shelter,"SE BUSCA\nCHOFER",Vector3(0.75,0.98,-0.909),0.04,"f2e6dc")
	box(shelter,Vector3(1.35,0.88,-0.915),Vector3(0.22,0.16,0.006),composition.ink("d6b23a"))
	plate(shelter,"NO\nFUMAR",Vector3(1.35,0.88,-0.909),0.03,"1d1f20")
	for x: float in [-1.6,-0.2,1.05]:
		box(shelter,Vector3(x,0.618,-0.5),Vector3(0.4,0.006,0.3),composition.ink("6e5e4b"))
	# The roof slab: seams between its sheets, grime gathered at the fall, leaves on the low edge,
	# and the stop's name on a fascia facing the yard.
	for x: float in [-2.26,-1.13,0.0,1.13,2.26]:
		box(shelter,Vector3(x,4.296,0),Vector3(0.04,0.012,2.5),slat_seam)
	for patch: Vector3 in [Vector3(-2.0,0.75,1.5),Vector3(0.6,0.95,1.1),Vector3(2.3,0.85,0.7)]:
		box(shelter,Vector3(patch.x,4.294,patch.y),Vector3(patch.z,0.006,0.5),composition.ink("2f3431"))
	for k: int in 7:
		box(shelter,Vector3(-2.9+float(k)*0.93+0.2*sin(float(k)*2.3),4.3,1.0+0.15*cos(float(k)*1.7)),Vector3(0.12,0.01,0.08),composition.ink("6e5e3b"))
	box(shelter,Vector3(0,4.12,1.28),Vector3(6.6,0.26,0.03),composition.ink("b9b19b"))
	plate(shelter,"PARADERO · LÍNEA 08 NOCTURNA",Vector3(0,4.12,1.3),0.11,"27313a")
	box(shelter,Vector3(2.9,4.12,1.3),Vector3(0.3,0.2,0.006),composition.ink("6b4a33"))
	# Timetable on the post plate: the night service's frequencies, sun-faded.
	plate(shelter,"HORARIO\nNOCTURNO\n\n08  CADA 20'\n08N CADA 40'",Vector3(-2.494,2.0,0.35),0.035,"2a3236",90.0)
	box(shelter,Vector3(-2.495,2.32,0.35),Vector3(0.004,0.04,0.4),composition.ink("2c2826"))
