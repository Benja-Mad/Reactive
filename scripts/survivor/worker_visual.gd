## Lit, articulated workwear. Same materials and scale for both members of the night shift.
extends Node3D
var support: bool = false
var torso: Node3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var tool: Node3D
var phase: float = 0.0
var recoil: float = 0.0
var facing := Vector3.FORWARD
var flash: float = 0.0
var cloth: StandardMaterial3D

static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.metallic = metal
	return m
static var _mesh_cache: Dictionary = {}

static func box(parent: Node3D, point: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh: ArrayMesh = chamfered_box(size)
	node.mesh = mesh
	node.material_override = m
	node.position = point
	parent.add_child(node)
	return node
static func chamfered_box(size: Vector3) -> ArrayMesh:
	if _mesh_cache.has(size): return _mesh_cache[size]
	var half: Vector3 = size * 0.5
	var bevel: float = minf(size.x, minf(size.y, size.z)) * 0.16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for layer: int in 4:
		var y: float = [-half.y, -half.y + bevel, half.y - bevel, half.y][layer]
		var inset: float = bevel * 0.55 if layer in [0, 3] else 0.0
		var x: float = half.x - inset
		var z: float = half.z - inset
		var ring := PackedVector3Array([Vector3(-x + bevel,y,-z), Vector3(x-bevel,y,-z), Vector3(x,y,-z+bevel), Vector3(x,y,z-bevel), Vector3(x-bevel,y,z), Vector3(-x+bevel,y,z), Vector3(-x,y,z-bevel), Vector3(-x,y,-z+bevel)])
		rings.append(ring)
	for layer: int in 3:
		for i: int in 8:
			var j: int = (i + 1) % 8
			var a: Vector3 = rings[layer][i]
			var b: Vector3 = rings[layer][j]
			var c: Vector3 = rings[layer+1][i]
			var d: Vector3 = rings[layer+1][j]
			for v: Vector3 in [a,c,b,b,c,d]: st.add_vertex(v)
	for cap: int in [0,3]:
		for i: int in range(1,7):
			var points: Array = [rings[cap][0], rings[cap][i], rings[cap][i+1]] if cap == 0 else [rings[cap][0], rings[cap][i+1], rings[cap][i]]
			for v: Vector3 in points: st.add_vertex(v)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[size] = mesh
	return mesh
static func cylinder(parent: Node3D, point: Vector3, radius: float, height: float, m: Material, top: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 8
	node.mesh = mesh
	node.material_override = m
	node.position = point
	parent.add_child(node)
	return node
func _ready() -> void:
	var rubber := material(Color("263236"))
	var steel := material(Color("788784"), 0.4)
	var tape := material(Color("ded9bb"))
	var skin := material(Color("b18569"))
	cloth = material(Color("628b87") if support else Color("c6794b"))
	torso = Node3D.new()
	add_child(torso)
	# Broad waterproof jacket, split tails and a deliberately asymmetric shoulder tank.
	box(torso, Vector3(0, 1.15, 0), Vector3(0.72, 0.65, 0.42), cloth)
	box(torso, Vector3(0, 0.83, 0), Vector3(0.77, 0.23, 0.46), cloth)
	box(torso, Vector3(0, 1.09, -0.221), Vector3(0.69, 0.075, 0.018), tape)
	box(torso, Vector3(-0.2, 1.34, -0.224), Vector3(0.055, 0.35, 0.019), tape)
	box(torso, Vector3(0.2, 1.34, -0.224), Vector3(0.055, 0.35, 0.019), tape)
	box(torso, Vector3(0.19, 1.27, -0.247), Vector3(0.14, 0.12, 0.03), rubber)
	cylinder(torso, Vector3(-0.22, 1.24, 0.34), 0.16, 0.82, steel)
	cylinder(torso, Vector3(-0.22, 1.68, 0.34), 0.08, 0.09, rubber)
	box(torso, Vector3(-0.22, 1.27, 0.49), Vector3(0.24, 0.08, 0.02), cloth)
	cylinder(torso, Vector3(0, 1.65, 0), 0.23, 0.33, skin)
	# Oilskin hood / low hardhat, not a glowing sci-fi visor.
	cylinder(torso, Vector3(0, 1.84, 0.015), 0.27, 0.20, cloth, 0.17)
	cylinder(torso, Vector3(0, 1.76, -0.035), 0.32 if support else 0.28, 0.055, rubber)
	box(torso, Vector3(0, 1.65, -0.205), Vector3(0.34, 0.08, 0.055), rubber)
	box(torso, Vector3(0, 1.65, -0.238), Vector3(0.23, 0.045, 0.015), steel)
	box(torso, Vector3(0, 1.52, -0.2), Vector3(0.18, 0.12, 0.10), rubber)
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.19, 0.79, 0)
		torso.add_child(leg)
		box(leg, Vector3(0, -0.22, 0), Vector3(0.25, 0.43, 0.28), rubber)
		box(leg, Vector3(0, -0.48, -0.02), Vector3(0.27, 0.16, 0.29), cloth)
		box(leg, Vector3(0, -0.66, -0.065), Vector3(0.29, 0.24, 0.42), rubber)
		legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.46, 1.42, 0)
		torso.add_child(arm)
		box(arm, Vector3(0, -0.22, 0), Vector3(0.24, 0.42, 0.3), cloth)
		box(arm, Vector3(0, -0.3, -0.07), Vector3(0.25, 0.065, 0.3), tape)
		box(arm, Vector3(0, -0.48, -0.08), Vector3(0.21, 0.17, 0.25), rubber)
		arms.append(arm)
	tool = Node3D.new()
	tool.position = Vector3(0.45, 0.92, -0.32)
	torso.add_child(tool)
	box(tool, Vector3.ZERO, Vector3(0.22, 0.25, 0.38), steel)
	box(tool, Vector3(0, 0.04, -0.35), Vector3(0.14, 0.14, 0.48), rubber)
	var light_material := material(Color("9fbfb7") if support else Color("e5ab63"))
	light_material.emission_enabled = true
	light_material.emission = light_material.albedo_color
	light_material.emission_energy_multiplier = 0.7
	cylinder(tool, Vector3(0, 0.15, -0.13), 0.11, 0.24, light_material)
	if support:
		# The watchman's oilskin hangs lower; his cable reel and caged lamp identify the role.
		cylinder(torso, Vector3(0, 0.79, 0), 0.52, 0.47, cloth, 0.35)
		var reel := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.20
		ring.outer_radius = 0.29
		ring.rings = 12
		ring.ring_segments = 6
		reel.mesh = ring
		reel.material_override = rubber
		reel.position = Vector3(0.2,1.30,0.31)
		reel.rotation.x = PI * 0.5
		torso.add_child(reel)
		box(tool, Vector3(0.04, -0.13, -0.36), Vector3(0.055,0.84,0.055), steel)
		for side: float in [-1.0,1.0]:
			box(tool, Vector3(side * 0.11,0.15,-0.13), Vector3(0.025,0.3,0.025), rubber)
	else:
		# A hinged welding shield, with a wide dark glass strip above the respirator.
		box(torso, Vector3(0,1.89,-0.21), Vector3(0.38,0.22,0.07), rubber)
		box(torso, Vector3(0,1.90,-0.252), Vector3(0.25,0.055,0.012), steel)
	# Painted crew number, physically on the back of the coat.
	var number := Label3D.new()
	number.text = "08"
	number.font_size = 40
	number.pixel_size = 0.006
	number.position = Vector3(0.04, 1.25, 0.225)
	number.rotation.y = PI
	number.modulate = Color("ded9bb")
	number.outline_size = 0
	number.no_depth_test = false
	torso.add_child(number)
## Local operator only: a silhouette through scenery and machines, and a ring painted at the feet.
func mark_local() -> void:
	var xray := ShaderMaterial.new()
	xray.shader = preload("res://scripts/survivor/xray.gdshader")
	xray.set_shader_parameter("tint", Color(0.42, 0.68, 0.65, 0.8) if support else Color(0.9, 0.55, 0.33, 0.8))
	xray.render_priority = 1
	for mesh: Node in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = xray
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.7
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.04
	var paint := material(Color("9fbfb7") if support else Color("e5ab63"))
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.albedo_color.a = 0.85
	paint.no_depth_test = true
	paint.render_priority = 2
	ring.material_override = paint
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
func kick() -> void:
	recoil = 1.0
func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var speed: float = Vector2(body.velocity.x, body.velocity.z).length() if body != null else 0.0
	phase += delta * (10.0 if speed > 0.1 else 2.0)
	recoil = move_toward(recoil, 0, delta * 6)
	if speed > 0.15: facing = Vector3(body.velocity.x, 0, body.velocity.z).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-delta * 12))
	torso.position.y = sin(phase * 2) * (0.035 if speed > 0.1 else 0.008)
	for i: int in 2:
		legs[i].rotation.x = sin(phase + i * PI) * minf(speed / 3.5, 1.0) * 0.55
		arms[i].rotation.x = -0.35 - recoil * 0.3 + sin(phase + i * PI) * minf(speed / 3.5, 1.0) * 0.2
	tool.position.z = -0.32 + recoil * 0.13
	if body is Character:
		visible = not body.eliminated
		flash = maxf(0, flash - delta)
		cloth.albedo_color = Color("e5c3a3") if body.hurt_time > 0.4 else (Color("628b87") if support else Color("c6794b"))
