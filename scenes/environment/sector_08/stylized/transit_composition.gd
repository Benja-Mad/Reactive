## Local art-direction study: silhouette roof, luminous recess, warm side key
## and a restrained mineral-green rear rim. No new ground obstacles or signs.
extends Node3D
const INK = preload("res://scenes/environment/sector_08/stylized/transit_material.gdshader")

func ink(hex: String, fill: float = 0.18) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = INK
	m.set_shader_parameter("pigment",Color(hex))
	m.set_shader_parameter("ink_fill",fill)
	return m

func compose(shelter: Node3D) -> void:
	# Different value families establish a hierarchy before any local light is on.
	for mesh: MeshInstance3D in shelter.find_children("*","MeshInstance3D",true,false):
		var size: Vector3 = mesh.mesh.size if mesh.mesh is BoxMesh else Vector3.ONE
		var hex := "64736c"
		if size.x > 6.0 and size.z > 2.0: hex = "3e454b"
		elif mesh.position.y < 1.2: hex = "85715a"
		elif size.x > 5.0: hex = "59655e"
		mesh.material_override = ink(hex)
		if mesh.position.y > 3.0: mesh.position.y += 0.9
	for x: float in [-2.65,2.65]:
		box(shelter,Vector3(x,3.65,-0.8),Vector3(0.22,0.9,0.22),ink("64736c"))
	# A real architectural recess above head height. Its battens interrupt the
	# luminous plane, so the brightest shape is embedded in the shelter itself.
	box(shelter,Vector3(0,2.90,0.78),Vector3(5.2,0.52,0.13),ink("3f3331"))
	box(shelter,Vector3(0,2.90,0.87),Vector3(4.8,0.36,0.035),material("d0e85c",0.85))
	for x: float in [-1.8,-0.6,0.6,1.8]:
		box(shelter,Vector3(x,2.90,0.92),Vector3(0.12,0.46,0.13),ink("332f31"))
	box(shelter,Vector3(0,2.64,1.03),Vector3(5.25,0.1,0.42),ink("615444"))
	for x: float in [-2.4,2.4]:
		box(shelter,Vector3(x,3.5,0.78),Vector3(0.10,1.4,0.1),ink("39423e"))
	# Low-key signage: the structure now carries the focal point.
	box(shelter,Vector3(-2.53,2.45,0.35),Vector3(0.065,1.12,0.11),material("d7ee72",1.2))
	var key := SpotLight3D.new()
	key.name = "TransitSideKey"
	shelter.add_child(key)
	key.position = Vector3(-2.48,2.45,0.48)
	key.look_at(shelter.to_global(Vector3(1.6,0.65,-0.7)),Vector3.UP)
	key.light_color = Color("d7ee72")
	key.light_energy = 25.0
	key.spot_range = 8.0
	key.spot_angle = 44.0
	key.spot_attenuation = 1.0
	key.spot_angle_attenuation = 0.65
	key.light_specular = 0.0
	key.light_volumetric_fog_energy = 0.0
	key.light_size = 0.09
	key.shadow_enabled = true
	# A shutter limits the side-key to the architectural faces, not a floor pool.
	var aperture := Image.create(32,32,false,Image.FORMAT_RGB8)
	for y: int in 32:
		for x: int in 32:
			var edge: float = minf(minf(x-2.0,29.0-x),minf(y-7.0,24.0-y))
			var v: float = smoothstep(0.0,2.0,edge)
			aperture.set_pixel(x,y,Color(v,v,v))
	key.light_projector = ImageTexture.create_from_image(aperture)
	# Opposing rim catches the roof lip and rear posts. It does not light the playfield.
	var rim := SpotLight3D.new()
	rim.name = "TransitRearRim"
	shelter.add_child(rim)
	rim.position = Vector3(2.42,6.32,0.55)
	rim.look_at(shelter.to_global(Vector3(-1.3,4.30,0.55)),Vector3.UP)
	rim.light_color = Color("ff4d91")
	rim.light_energy = 85.0
	rim.spot_range = 9.0
	rim.spot_angle = 65.0
	rim.spot_attenuation = 1.3
	rim.light_size = 0.12
	rim.light_specular = 0.0
	rim.light_volumetric_fog_energy = 0.0
	rim.shadow_enabled = true

	# The roof rake comes from a bracket rooted in the existing rear post.
	# Its luminous lens sits at the light origin, above the walking clearance.
	box(shelter,Vector3(2.65,4.30,-0.125),Vector3(0.12,0.12,1.35),ink("46505d"))
	box(shelter,Vector3(2.65,5.30,0.55),Vector3(0.12,2.3,0.12),ink("46505d"))
	box(shelter,Vector3(2.48,6.49,0.55),Vector3(0.48,0.16,0.38),ink("252d3c"))
	box(shelter,Vector3(2.42,6.39,0.55),Vector3(0.32,0.045,0.25),material("ff4d91",1.5))
	# A recessed luminous seam makes the roof silhouette readable from combat.
	box(shelter,Vector3(0,4.03,1.20),Vector3(6.2,0.055,0.07),material("ec3f83",0.85))

func material(hex: String, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.emission_enabled = true
	m.emission = Color(hex)
	m.emission_energy_multiplier = glow
	return m

func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.position = at
	mesh.material_override = mat
	parent.add_child(mesh)
