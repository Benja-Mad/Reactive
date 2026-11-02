## The lower district behind the depot: tower silhouettes with sparse lit rooms, the elevated line,
## the arcade bays across the street. No camera-follow planes or gameplay geometry.
##
## It used to carry the stock cyberpunk dressing (English ad screens, a vertical DREAM neon, a
## STAY HUMAN mural, violet and rose spill lights, coloured accent uplights). All of that is gone:
## the district now lives in the depot's narrow band (sodium, white-green fluorescent, dim tungsten,
## blue-grey) so the reserved colours stay game signals. The street's own signs are DepotEdges'.
extends Node3D
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

func setup() -> void:
	_steel = _material("262c2f")
	_city_layers()
	_street_vista()
	_district_edges()
	var roof := Node3D.new()
	roof.name = "NorthArcadeRoof"
	add_child(roof)
	roof.position = Vector3(-13.0,5.0,-29.0)
	roof.rotation.y = deg_to_rad(43)
	_box(roof, Vector3.ZERO, Vector3(17.6,0.28,16.1), _material("22282b"))
	_box(roof, Vector3(0,0.1,8), Vector3(17.6,0.2,0.18), _material("464c4c"))
	_box(roof, Vector3(-3,0.85,-3.5), Vector3(5.8,1.7,4.0), _material("33393a"))
	for z: float in [-4.7,-3.5,-2.3]:
		_box(roof, Vector3(-3,1.73,z), Vector3(5.0,0.08,0.32), _material("484e4e"))

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
	_box(transit, Vector3.ZERO, Vector3(76,1.0,3.0), _material("2b3235"))
	_box(transit, Vector3(0,0.65,1.35), Vector3(76,0.34,0.23), _material("3a4245"))
	# Sodium lamps along the deck, every other one dead.
	var sodium := _material("d8c46a", 0.35)
	for x: float in [-32,-16,0,16,32]:
		_box(transit, Vector3(x,-9,0), Vector3(1.4,18,1.8), _material("272e31"))
		if int(x) % 32 == 0:
			_box(transit, Vector3(x,0.65,1.49), Vector3(1.2,0.08,0.08), sodium)
	# The last train of the night stands on the line, cabins fluorescent and nearly empty.
	for i: int in 3:
		var x: float = -10 + i * 6.4
		_box(transit, Vector3(x,1.45,0), Vector3(6,1.8,2.1), _material("4b5254"))
		_box(transit, Vector3(x,1.6,1.07), Vector3(4.7,0.55,0.04), _material("cfe6d2",0.28))

func _tower(parent: Node3D, at: Vector3, size: Vector3, tier: int, seed_value: int) -> void:
	var tower := Node3D.new()
	tower.name = "DistrictTower%02d" % seed_value
	parent.add_child(tower)
	tower.position = at
	tower.rotation.y = deg_to_rad(43)
	# Blue-grey concrete that recedes with distance; no self-lit bodies.
	var body: Material = _material(["283034", "2c3438", "30393d"][tier])
	var rim: Material = _material(["384144", "3d4649", "434c4f"][tier])
	_box(tower, Vector3(0,size.y * 0.5,0), size, body)
	# Deep service recess and one asymmetric balcony give the skyline a readable face.
	_box(tower,Vector3(-size.x*0.12,size.y*0.58,size.z*0.5+0.035),Vector3(size.x*0.30,size.y*0.72,0.08),_material("1c2225"))
	for side: float in [-1,1]:
		_box(tower,Vector3(-size.x*0.12+side*size.x*0.17,size.y*0.58,size.z*0.5+0.25),Vector3(0.3,size.y*0.72,0.5),rim)
	_box(tower,Vector3(size.x*0.18,size.y*0.72,size.z*0.5+0.65),Vector3(size.x*0.58,0.35,1.3),rim)
	_box(tower,Vector3(size.x*0.18,size.y*0.72-0.15,size.z*0.5+1.31),Vector3(size.x*0.4,0.06,0.035),_material("c9a76f",0.3))
	# Unequal rooftop setbacks keep silhouettes architectural rather than box stacks.
	var crown_height: float = 2.5 + float(seed_value % 3) * 1.6
	_box(tower, Vector3(-size.x*0.12,size.y+crown_height*0.5,0), Vector3(size.x*0.66,crown_height,size.z*0.65), rim)
	_box(tower, Vector3(0,size.y-0.3,0), Vector3(size.x+0.3,0.45,size.z+0.3), rim)
	if seed_value % 3 == 0:
		# Rooftop water tank on its stand, not an antenna beacon.
		_box(tower, Vector3(size.x*0.2,size.y+crown_height+0.9,0), Vector3(1.6,1.8,1.6), rim)
	# Group windows into a single MultiMesh per tower instead of hundreds of draw calls.
	var transforms: Array[Transform3D] = []
	for row: int in range(2, int(size.y/2.4)):
		for column: int in 5:
			if (row * 7 + column * 11 + seed_value * 3) % 9 > 2: continue
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
	# Domestic tungsten and the odd fluorescent kitchen; never violet, cyan or lime.
	var window_color: String = ["d6b183","c9a76f","bfcdbf","b89a70"][seed_value % 4]
	windows.material_override = _material(window_color, 0.22 if tier == 2 else 0.4)
	windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tower.add_child(windows)


## The arcade bays across the street (behind DepotEdges' fuente de soda fascia): piers, a lintel,
## receding bays lit by plain fluorescent tubes. All geometry is beyond the boundary.
func _street_vista() -> void:
	var street := Node3D.new()
	street.name = "CombatStreetVista"
	add_child(street)
	street.position = Vector3(-8.88, 0, -20.53)
	street.rotation.y = deg_to_rad(43)
	var dark := _material("262c2e")
	var edge := _material("4a5051")
	for x: float in [-4.35,4.35]:
		_box(street, Vector3(x,2.35,-0.5), Vector3(0.35,4.7,1.0), edge)
	_box(street, Vector3(0,4.75,-0.5), Vector3(9.05,0.35,1.0), dark)
	# Low sill and handrail: the counter window of the fuente de soda.
	_box(street, Vector3(0,0.4,0), Vector3(8.5,0.8,0.45), dark)
	_box(street, Vector3(0,1.15,0.1), Vector3(8.5,0.07,0.08), edge)
	for x: float in [-2.8,0,2.8]:
		_box(street, Vector3(x,0.92,0.1), Vector3(0.07,0.5,0.08), edge)
	var plaster := _material("5f5e57")
	var concrete := _material("6b655d")
	var recess := _material("1f2426")
	var tube := _material("cfe6d2", 0.45)
	for bay: int in 3:
		var z: float = -1.6 - bay*2.0
		var width: float = 5.6 - bay*0.55
		var height: float = 3.1 + bay*0.55
		for side: float in [-1,1]:
			_box(street,Vector3(side*width*0.5,height*0.5,z),Vector3(0.48,height,2.4),concrete if side < 0 else plaster)
			_box(street,Vector3(side*(width*0.5+0.65),height*0.5,z-0.6),Vector3(0.8,height,3.0),recess)
		_box(street,Vector3(0,height,z),Vector3(width+0.5,0.35,0.7),plaster)
		_box(street,Vector3(0,-0.25-bay*0.22,z),Vector3(width,0.18,3.4),recess)
		# One bare tube per lintel; the middle one is dead.
		if bay != 1:
			_box(street,Vector3(-0.8,height-0.2,z+0.15),Vector3(1.2,0.045,0.045),tube)
	_box(street,Vector3(0,2.8,-8.0),Vector3(6.2,6.4,0.6),_material("4f5250"))
	for x: float in [-1.5,0,1.5]:
		_box(street,Vector3(x,0.7,-7.66),Vector3(0.62,1.5,0.05),_material("b89a70",0.4))

## Side streets carry the city's scale past the central facade. Footprints lie outside bounds.
func _district_edges() -> void:
	var sides := Node3D.new()
	sides.name = "OuterDistrictBlocks"
	add_child(sides)
	_tower(sides, Vector3(-44,-10,9), Vector3(9,19,10), 1, 12)
	_tower(sides, Vector3(-51,-14,26), Vector3(10,23,9), 2, 13)
	_tower(sides, Vector3(44,-10,7), Vector3(9,18,10), 1, 14)
	_tower(sides, Vector3(52,-14,23), Vector3(10,24,9), 2, 15)
