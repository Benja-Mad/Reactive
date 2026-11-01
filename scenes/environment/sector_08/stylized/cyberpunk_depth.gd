## World-anchored signage and depth cues. No camera-follow planes or gameplay geometry.
extends Node3D
const ART = preload("res://scenes/environment/sector_08/stylized/district_screen_art.gd")
const SCREEN = preload("res://scenes/environment/sector_08/stylized/district_screen.gdshader")
var _steel: StandardMaterial3D

func _material(color: String, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.85
	if energy > 0:
		m.emission_enabled = true
		m.emission = Color(color)
		m.emission_energy_multiplier = energy
	return m

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

# A fixture is attached to a facade or soffit; its beam points back into the
# architecture. Real shadows supply the silhouette, with no projector stripes.
func _architectural_light(parent: Node3D, at: Vector3, target: Vector3, color: String, energy: float, reach: float) -> void:
	var lamp := SpotLight3D.new()
	lamp.name = "FacadeFixture"
	lamp.set_meta("architectural_fixture",true)
	parent.add_child(lamp)
	lamp.position = at
	lamp.look_at(parent.to_global(target),Vector3.UP)
	lamp.light_color = Color(color)
	lamp.light_energy = energy
	# Keep the default receiver mask for fixtures owned by geometry subtrees.
	# A custom mask plus reversible mesh layers broke renderer unpairing at exit.
	lamp.light_specular = 0.0
	lamp.light_volumetric_fog_energy = 0.0
	lamp.spot_range = reach
	lamp.spot_angle = 62.0
	lamp.spot_attenuation = 1.3
	lamp.spot_angle_attenuation = 1.5
	lamp.light_size = 0.16
	lamp.shadow_enabled = true

func setup() -> void:
	_steel = _material("1c2635")
	# Attached to the north facade, above the working-yard fence and ventilation bays.
	_city_layers()
	_street_vista()
	_district_edges()
	var roof := Node3D.new()
	roof.name = "NorthArcadeRoof"
	add_child(roof)
	roof.position = Vector3(-13.0,5.0,-29.0)
	roof.rotation.y = deg_to_rad(43)
	_box(roof, Vector3.ZERO, Vector3(17.6,0.28,16.1), _material("152331"))
	_box(roof, Vector3(0,0.1,8), Vector3(17.6,0.2,0.18), _material("425969"))
	_box(roof, Vector3(-3,0.85,-3.5), Vector3(5.8,1.7,4.0), _material("293b48"))
	for z: float in [-4.7,-3.5,-2.3]:
		_box(roof, Vector3(-3,1.73,z), Vector3(5.0,0.08,0.32), _material("435969"))
	_screen("AfterhumanFacade", Vector3(-2.8, 3.8, -26.0), 43.0, Vector2(6.8, 2.65), 0, 0.72)
	# The smaller transit display belongs to a deeper return wall, not to the play plane.
	_screen("GhostRamen", Vector3(-21.4, 3.7, -8.4), 43.0, Vector2(4.8, 2.0), 1, 0.60)
	_hotel_sign(Vector3(3.2, 4.1, -24.0))
	# Violet grazing light separates the back facade from the warm yard and cold tank.
	_spill(Vector3(-5.0, 5.8, -18.5), Color("b574ef"), 11.0, 12.0)
	_spill(Vector3(-20.0, 3.5, -8.0), Color("d174c1"), 4.5, 8.0)
	# A narrow canopy and its supports give the advertising wall thickness and a shadow line.
	var canopy := Node3D.new()
	canopy.name = "FacadeServiceCanopy"
	add_child(canopy)
	canopy.position = Vector3(-2.8, 2.1, -25.7)
	canopy.rotation.y = deg_to_rad(43)
	_box(canopy, Vector3(0, 0, 0.4), Vector3(7.3, 0.18, 0.65), _steel)
	for x: float in [-3.1, 3.1]:
		_box(canopy, Vector3(x, -0.35, 0), Vector3(0.16, 0.7, 0.45), _steel)
	_box(canopy, Vector3(0, -0.10, 0.93), Vector3(6.8, 0.055, 0.055), _material("9a53d5", 1.4))

func _screen(id: String, at: Vector3, yaw: float, size: Vector2, variant: int, brightness: float) -> void:
	var frame := Node3D.new()
	frame.name = id
	add_child(frame)
	frame.position = at
	frame.rotation.y = deg_to_rad(yaw)
	_box(frame, Vector3.ZERO, Vector3(size.x + 0.35, size.y + 0.35, 0.32), _steel)
	var viewport := SubViewport.new()
	viewport.name = "SignArtwork"
	viewport.size = Vector2i(960, 400)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	frame.add_child(viewport)
	var art := ART.new()
	art.variant = variant
	art.size = Vector2(960, 400)
	viewport.add_child(art)
	var material := ShaderMaterial.new()
	material.shader = SCREEN
	material.set_shader_parameter("artwork", viewport.get_texture())
	material.set_shader_parameter("luminance", brightness)
	var face := MeshInstance3D.new()
	face.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = size
	face.mesh = quad
	face.material_override = material
	face.position.z = 0.175
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.add_child(face)
	# Brackets and lower service rail make it a mounted object with a visible side profile.
	for x: float in [-size.x * 0.43, size.x * 0.43]:
		_box(frame, Vector3(x, 0, -0.35), Vector3(0.22, size.y + 0.7, 0.65), _steel)
	_box(frame, Vector3(0, -size.y * 0.5 - 0.25, 0), Vector3(size.x + 0.6, 0.10, 0.60), _steel)

func _hotel_sign(at: Vector3) -> void:
	var sign := Node3D.new()
	sign.name = "ReverieVerticalNeon"
	add_child(sign)
	sign.position = at
	sign.rotation.y = deg_to_rad(43)
	_box(sign, Vector3.ZERO, Vector3(1.3, 5.8, 0.40), _steel)
	var neon: Material = _material("bd61ef", 0.9)
	for x: float in [-0.58, 0.58]:
		_box(sign, Vector3(x, 0, 0.23), Vector3(0.055, 5.5, 0.055), neon)
	var text := Label3D.new()
	text.name = "HotelLetters"
	text.text = "D\nR\nE\nA\nM"
	text.font_size = 80
	text.pixel_size = 0.009
	text.outline_size = 0
	text.modulate = Color("b88dcc")
	text.position = Vector3(0, 0.1, 0.24)
	text.no_depth_test = false
	text.shaded = false
	sign.add_child(text)
	for y: float in [-2.4, 2.4]:
		_box(sign, Vector3(0, y, -0.8), Vector3(0.18, 0.18, 1.6), _steel)
	_spill(at + Vector3(0, -1.0, 1.8), Color("bb57ee"), 3.0, 7.0)

func _spill(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.light_specular = 0.3
	light.light_volumetric_fog_energy = 0.22
	light.shadow_enabled = false
	add_child(light)

## The yard sits above a lower district. Large silhouettes, sparse lit rooms and a
## transport deck establish three depths without scattering props through combat.
func _city_layers() -> void:
	var city := Node3D.new()
	city.name = "LowerCityArchitecture"
	add_child(city)
	# Base positions are below the yard; all footprints remain outside its court.
	var towers: Array[Dictionary] = [
		{"p": Vector3(-34,-20,-15), "s": Vector3(9,29,10), "tier": 0},
		{"p": Vector3(-40,-24,-28), "s": Vector3(12,39,11), "tier": 1},
		{"p": Vector3(-25,-25,-42), "s": Vector3(10,34,13), "tier": 1},
		{"p": Vector3(-9,-25,-48), "s": Vector3(13,41,12), "tier": 1},
		{"p": Vector3(8,-22,-41), "s": Vector3(9,35,11), "tier": 1},
		{"p": Vector3(20,-19,-27), "s": Vector3(8,25,10), "tier": 0},
		{"p": Vector3(33,-26,-38), "s": Vector3(12,41,12), "tier": 1},
		{"p": Vector3(-45,-34,-52), "s": Vector3(13,53,12), "tier": 2},
		{"p": Vector3(-23,-34,-64), "s": Vector3(15,48,14), "tier": 2},
		{"p": Vector3(0,-34,-71), "s": Vector3(12,59,12), "tier": 2},
		{"p": Vector3(24,-34,-63), "s": Vector3(14,52,13), "tier": 2},
		{"p": Vector3(48,-34,-48), "s": Vector3(12,46,12), "tier": 2},
	]
	for i: int in towers.size():
		_tower(city, towers[i]["p"], towers[i]["s"] + Vector3(0, float(towers[i]["tier"])*4.0, 0), towers[i]["tier"], i)
	var transit := Node3D.new()
	transit.name = "DistrictElevatedLine"
	city.add_child(transit)
	transit.position = Vector3(-4,7,-42)
	transit.rotation.y = deg_to_rad(43)
	_box(transit, Vector3.ZERO, Vector3(76,1.0,3.0), _material("263b4c"))
	_box(transit, Vector3(0,0.65,1.35), Vector3(76,0.34,0.23), _material("354c5b"))
	var cyan := _material("518b9b", 0.5)
	for x: float in [-32,-16,0,16,32]:
		_box(transit, Vector3(x,-9,0), Vector3(1.4,18,1.8), _material("223543"))
		_box(transit, Vector3(x,0.65,1.49), Vector3(7,0.08,0.08), cyan)
	# A train silhouette sits on the elevated line, behind the courtyard architecture.
	for i: int in 3:
		var x: float = -10 + i * 6.4
		_box(transit, Vector3(x,1.45,0), Vector3(6,1.8,2.1), _material("4b6070"))
		_box(transit, Vector3(x,1.6,1.07), Vector3(4.7,0.55,0.04), _material("5ea9b1",0.6))

func _tower(parent: Node3D, at: Vector3, size: Vector3, tier: int, seed_value: int) -> void:
	var tower := Node3D.new()
	tower.name = "DistrictTower%02d" % seed_value
	parent.add_child(tower)
	tower.position = at
	tower.rotation.y = deg_to_rad(43)
	var body: Material = _material(["263846", "304454", "3a5060"][tier], 0.06 + tier * 0.06)
	var rim: Material = _material(["3a4c5a", "415868", "486170"][tier], 0.08 + tier * 0.06)
	_box(tower, Vector3(0,size.y * 0.5,0), size, body)
	# Deep service recess and one asymmetric balcony give the skyline a readable face.
	# These are attached architectural planes, not scattered rooftop prop piles.
	_box(tower,Vector3(-size.x*0.12,size.y*0.58,size.z*0.5+0.035),Vector3(size.x*0.30,size.y*0.72,0.08),_material("17242d"))
	for side: float in [-1,1]:
		_box(tower,Vector3(-size.x*0.12+side*size.x*0.17,size.y*0.58,size.z*0.5+0.25),Vector3(0.3,size.y*0.72,0.5),rim)
	_box(tower,Vector3(size.x*0.18,size.y*0.72,size.z*0.5+0.65),Vector3(size.x*0.58,0.35,1.3),rim)
	_box(tower,Vector3(size.x*0.18,size.y*0.72-0.15,size.z*0.5+1.31),Vector3(size.x*0.4,0.06,0.035),_material("bda379",0.45))
	# Sparse balcony-mounted uplights articulate two skyline landmarks.
	if seed_value in [3,6]:
		var accent: String = "d2ea78" if seed_value == 3 else "d874ff"
		var light_at := Vector3(size.x*0.18,size.y*0.72+0.28,size.z*0.5+1.05)
		_box(tower,light_at-Vector3(0,0.10,0),Vector3(1.1,0.18,0.45),_steel)
		_box(tower,light_at,Vector3(0.85,0.035,0.30),_material(accent,1.0))
		_architectural_light(tower,light_at+Vector3(0,0.06,0),Vector3(0,size.y-1,size.z*0.5+0.1),accent,55.0,18.0)
	# Unequal rooftop setbacks keep silhouettes architectural rather than box stacks.
	var crown_height: float = 2.5 + float(seed_value % 3) * 1.6
	_box(tower, Vector3(-size.x*0.12,size.y+crown_height*0.5,0), Vector3(size.x*0.66,crown_height,size.z*0.65), rim)
	_box(tower, Vector3(0,size.y-0.3,0), Vector3(size.x+0.3,0.45,size.z+0.3), rim)
	if seed_value % 3 == 0:
		_box(tower, Vector3(0,size.y+crown_height+2,0), Vector3(0.15,4,0.15), rim)
		_box(tower, Vector3(0,size.y+crown_height+4,0), Vector3(0.23,0.18,0.23), _material("c77d98",0.7))
	# Group windows into a single MultiMesh per tower instead of hundreds of draw calls.
	var transforms: Array[Transform3D] = []
	for row: int in range(2, int(size.y/2.4)):
		for column: int in 5:
			if (row * 7 + column * 11 + seed_value * 3) % 9 > 3: continue
			var x: float = (float(column)-2) * size.x * 0.16
			transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size.x*0.09,0.6,0.06)), Vector3(x,row*2.4,size.z*0.5+0.04)))
	var windows := MultiMeshInstance3D.new()
	windows.name = "GroupedLitWindows"
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = BoxMesh.new()
	mesh.instance_count = transforms.size()
	for i: int in transforms.size(): mesh.set_instance_transform(i, transforms[i])
	windows.multimesh = mesh
	var window_color: String = ["cd9d66","9b82bd","69b6ac","b6c96b"][seed_value % 4]
	windows.material_override = _material(window_color, 0.30 if tier == 2 else 0.60)
	windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tower.add_child(windows)
	if tier == 0:
		_box(tower, Vector3(size.x*0.39,size.y*0.65,size.z*0.5+0.08), Vector3(0.12,size.y*0.5,0.10), _material("9873c6",1.0))


## A street-depth reveal composed inside the normal combat frame. The original
## foreground fence remains the boundary; no new scenery enters the play court.
func _street_vista() -> void:
	var street := Node3D.new()
	street.name = "CombatStreetVista"
	add_child(street)
	street.position = Vector3(-8.88, 0, -20.53)
	street.rotation.y = deg_to_rad(43)
	var dark := _material("172d3b")
	var edge := _material("3b5665")
	# Foreground piers and lintel reveal side thickness, then a recessed service arcade.
	for x: float in [-4.35,4.35]:
		_box(street, Vector3(x,2.35,-0.5), Vector3(0.35,4.7,1.0), edge)
	_box(street, Vector3(0,4.75,-0.5), Vector3(9.05,0.35,1.0), dark)
	# Low sill and handrail identify this as a background overlook, not a new exit.
	_box(street, Vector3(0,0.4,0), Vector3(8.5,0.8,0.45), dark)
	_box(street, Vector3(0,1.15,0.1), Vector3(8.5,0.07,0.08), edge)
	for x: float in [-2.8,0,2.8]:
		_box(street, Vector3(x,0.92,0.1), Vector3(0.07,0.5,0.08), edge)
	# Receding service portals reveal actual side walls and negative space.
	# All geometry is beyond the existing boundary, not in the combat court.
	var mineral := _material("526963")
	var concrete := _material("73685e")
	var recess := _material("20272f")
	for bay: int in 3:
		var z: float = -1.6 - bay*2.0
		var width: float = 5.6 - bay*0.55
		var height: float = 3.1 + bay*0.55
		for side: float in [-1,1]:
			_box(street,Vector3(side*width*0.5,height*0.5,z),Vector3(0.48,height,2.4),concrete if side < 0 else mineral)
			_box(street,Vector3(side*(width*0.5+0.65),height*0.5,z-0.6),Vector3(0.8,height,3.0),recess)
		_box(street,Vector3(0,height,z),Vector3(width+0.5,0.35,0.7),mineral)
		_box(street,Vector3(0,-0.25-bay*0.22,z),Vector3(width,0.18,3.4),recess)
		# A restrained underside light picks out successive lintels, without signs.
		var bay_color: String = ["ff7359","df69cf","6acbd1"][bay]
		_box(street,Vector3(-0.8,height-0.2,z+0.15),Vector3(2.2,0.055,0.16),_material(bay_color,0.8))
		if bay != 1:
			_architectural_light(street,Vector3(-0.8,height-0.28,z+0.15),Vector3(-width*0.5,1.2,z-0.7),bay_color,12.0,6.5)
	_box(street,Vector3(0,2.8,-8.0),Vector3(6.2,6.4,0.6),_material("485f60"))
	for x: float in [-1.5,0,1.5]:
		_box(street,Vector3(x,0.7,-7.66),Vector3(0.62,1.5,0.05),_material("bba17c",0.6))

## Each extension gets one readable destination, mounted on existing service structures.
## No new ground props narrow the routes. Colors describe districts rather than every object.
func _district_edges() -> void:
	_screen("DriftClinic", Vector3(-21,2.95,10.8), 0, Vector2(3.0,1.0), 3, 0.58)
	_screen("MemoryBanks", Vector3(23.5,2.95,6.7), 43, Vector2(3.4,1.0), 4, 0.54)
	# A painted end-wall message gives the western approach a human trace, without another neon ad.
	var mural := Node3D.new()
	mural.name = "WestEndWallMural"
	add_child(mural)
	mural.position = Vector3(-29.62,4.0,8.87)
	mural.rotation.y = deg_to_rad(10)
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = preload("res://scenes/environment/sector_08/stylized/art/stay_human_graffiti.png")
	paint.albedo_color = Color(0.78,0.78,0.78,0.90)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.roughness = 1.0
	paint.metallic_specular = 0.0
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var graffiti := MeshInstance3D.new()
	graffiti.name = "SprayPaintDecal"
	var face := QuadMesh.new()
	face.size = Vector2(5.6,3.73)
	graffiti.mesh = face
	graffiti.material_override = paint
	graffiti.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mural.add_child(graffiti)
	# One wall-mounted service light reveals the facade plane and the painted
	# mural. The mural remains shaded paint, not another emissive advertisement.
	_box(mural,Vector3(0,2.45,0.52),Vector3(2.3,0.14,0.6),_steel)
	_box(mural,Vector3(0,2.36,0.68),Vector3(1.85,0.04,0.22),_material("c580ff",1.1))
	var wall_light := SpotLight3D.new()
	wall_light.name = "ClinicWallLight"
	mural.add_child(wall_light)
	wall_light.position = Vector3(0,2.25,1.1)
	wall_light.look_at(mural.to_global(Vector3(0,-1.8,0)),Vector3.UP)
	wall_light.light_color = Color("c580ff")
	wall_light.light_energy = 42.0
	wall_light.set_meta("architectural_fixture",true)
	wall_light.light_specular = 0.0
	wall_light.light_volumetric_fog_energy = 0.0
	wall_light.spot_range = 11.0
	wall_light.spot_angle = 63.0
	wall_light.spot_attenuation = 1.5
	wall_light.spot_angle_attenuation = 2.0
	wall_light.light_size = 0.25
	wall_light.shadow_enabled = true
	# Furniture owns its mounted lights so colour spill follows the actual fixtures.
	# Side streets carry the city's scale past the central facade. Footprints lie outside bounds.
	var sides := Node3D.new()
	sides.name = "OuterDistrictBlocks"
	add_child(sides)
	_tower(sides, Vector3(-44,-10,9), Vector3(9,19,10), 1, 12)
	_tower(sides, Vector3(-51,-14,26), Vector3(10,23,9), 2, 13)
	_tower(sides, Vector3(44,-10,7), Vector3(9,18,10), 1, 14)
	_tower(sides, Vector3(52,-14,23), Vector3(10,24,9), 2, 15)
