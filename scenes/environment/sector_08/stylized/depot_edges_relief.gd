## The relief: the bus that ends the shift. Its headlights come down the cerro's switchback road
## over the five minutes; in the last half minute it comes in along the street from the east end,
## slowing, and stops at the gate as the clock reaches 0:00. The gate lamp lights as it pulls up; when the run is won the gate
## rolls open behind the zinc.
##
## Everything here is a pure function of SurvivorRun.elapsed / DURATION (read-only) and its phase,
## so a joining client, a camera toggle or a paused tree all see the same frame. Nothing pops in:
## the lights come over the ridge, the bus enters from beyond the right edge of the gameplay frame.
extends Node3D

## Seconds of the shift spent on the cerro road; the rest is the district below and the street.
const CERRO_END := 0.83
## When the bus comes round the street corner, as a fraction of the shift.
const STREET_START := 0.885
## How long the gate takes to roll open once the shift is won.
const GATE_SECONDS := 7.0
## How far the leaf rolls (local x of the edge frame), parking behind the zinc run.
const GATE_TRAVEL := 6.4
## Floor top (DepotEdges.FLOOR_Y).
const FLOOR_Y := 0.06
## World height of the street and yard asphalt, where the headlight pools lie.
const GROUND_Y := 0.06
const BEAM_SHADER := preload("res://scenes/environment/sector_08/stylized/depot_edges_beam.gdshader")
## The bus's street path in the edge frame (a, b): in from the east end of the street, along the
## fence, stopping with its nose inside the gate span and short of the north block's outside stair
## (a ~ 9.5-10.6), which stands in the street. The bus's origin is its centre; the nose leads by 5.2 m.
const STREET_PATH: Array[Vector2] = [Vector2(48.0, 18.65), Vector2(16.0, 18.65)]

var edges: Node3D
var run: Node
var headlights: Node3D
var bus: Node3D
var _street_lengths: PackedFloat32Array = PackedFloat32Array()
var _road_lengths: PackedFloat32Array = PackedFloat32Array()
var _gate_closed_x: float = 0.0
var _gate_open_time: float = -1.0
## One entry per headlamp: {pivot, aim, spot, cone, pool, target: Vector2 (a, b), min_toe, max_toe}.
var _beams: Array[Dictionary] = []


func setup(owner_edges: Node3D) -> void:
	edges = owner_edges
	run = edges.run
	process_mode = Node.PROCESS_MODE_ALWAYS
	_road_lengths = _cumulative(edges.cerro_road)
	var street := PackedVector3Array()
	for p: Vector2 in STREET_PATH:
		street.append(Vector3(p.x, 0.0, -p.y))
	_street_lengths = _cumulative(street)
	_build_headlights()
	_build_bus()
	if edges.gate_leaf != null:
		_gate_closed_x = edges.gate_leaf.position.x
	_apply(0.0, "running")


func _process(delta: float) -> void:
	if run == null or not is_instance_valid(run):
		run = get_tree().get_first_node_in_group("survivor_run") if is_inside_tree() else null
		if run == null:
			return
	var duration: float = float(run.get("DURATION")) if run.get("DURATION") != null else 300.0
	var progress: float = clampf(float(run.get("elapsed")) / maxf(duration, 1.0), 0.0, 1.0)
	var phase: String = str(run.get("phase"))
	if phase == "won":
		if _gate_open_time < 0.0: _gate_open_time = 0.0
		_gate_open_time += delta
	else:
		_gate_open_time = -1.0
	_apply(progress, phase)


## Pose everything for a shift fraction in [0, 1].
func _apply(progress: float, phase: String) -> void:
	# On the cerro: two lamps riding the switchback, from the ridge to the foot of the hill.
	var on_cerro: bool = progress < CERRO_END
	headlights.visible = on_cerro
	if on_cerro:
		var s: float = (progress / CERRO_END) * _road_lengths[_road_lengths.size() - 1]
		var pose: Array = _along(edges.cerro_road, _road_lengths, s)
		headlights.position = pose[0]
		headlights.rotation.y = atan2(-pose[1].z, pose[1].x)
	# In the street: the last stretch, decelerating to a stop at the gate on the final second.
	var on_street: bool = progress >= STREET_START or phase == "won"
	bus.visible = on_street
	if on_street:
		var u: float = clampf((progress - STREET_START) / (1.0 - STREET_START), 0.0, 1.0)
		if phase == "won": u = 1.0
		var eased: float = 1.0 - pow(1.0 - u, 2.2)
		var total: float = _street_lengths[_street_lengths.size() - 1]
		var pose: Array = _along(_street_points(), _street_lengths, eased * total)
		bus.position = pose[0]
		bus.rotation.y = atan2(-pose[1].z, pose[1].x)
	_aim_beams(on_street)
	# The gate lamp lights as the bus pulls up; it stays on.
	edges.depot_edges_set_gate_lamp(progress >= 0.997 or phase == "won")
	# The gate rolls open once the shift is won.
	if edges.gate_leaf != null:
		var open: float = 0.0
		if _gate_open_time >= 0.0:
			var g: float = clampf(_gate_open_time / GATE_SECONDS, 0.0, 1.0)
			open = g * g * (3.0 - 2.0 * g)
		edges.gate_leaf.position.x = _gate_closed_x + GATE_TRAVEL * open


## The dipped beams lead the bus in: each lamp holds its toe on a patch of the yard behind the gate,
## so while the bus is still beyond the frame's right edge its cones already reach across the street
## and through the bars, and as it pulls up they swing in toward the fence and the pools slide onto
## the apron. Pure function of the bus pose.
func _aim_beams(on: bool) -> void:
	if not is_inside_tree():
		return
	var forward: Vector3 = bus.global_basis.x
	forward.y = 0.0
	forward = forward.normalized()
	var fence_side: Vector3 = -bus.global_basis.z
	fence_side.y = 0.0
	fence_side = fence_side.normalized()
	for beam: Dictionary in _beams:
		var pool: MeshInstance3D = beam.pool
		pool.visible = on
		if not on:
			continue
		var pivot: Node3D = beam.pivot
		var origin: Vector3 = pivot.global_position
		var target: Vector3 = edges.depot_edges_ab(beam.target.x, beam.target.y, 0.0)
		var flat: Vector3 = target - origin
		flat.y = 0.0
		var toe: float = clampf(atan2(flat.dot(fence_side), flat.dot(forward)), deg_to_rad(beam.min_toe), deg_to_rad(beam.max_toe))
		var reach: float = clampf(flat.length(), 4.0, 30.0)
		var drop: float = maxf(origin.y - GROUND_Y, 0.3)
		var pitch: float = atan2(drop, reach)
		pivot.rotation.y = toe
		(beam.aim as Node3D).rotation.z = -pitch
		var length: float = minf(reach / cos(pitch), 28.0)
		var cone: MeshInstance3D = beam.cone
		cone.position = Vector3(length * 0.5, 0.0, 0.0)
		cone.scale = Vector3.ONE * length
		var spot: SpotLight3D = beam.spot
		spot.spot_range = maxf(22.0, reach + 10.0)
		# The pool where the beam lands: longer and wider the flatter the beam, dimmer the farther the lamp.
		var heading: Vector3 = (forward * cos(toe) + fence_side * sin(toe)).normalized()
		var hit: Vector3 = origin + heading * reach
		var across: Vector3 = Vector3.UP.cross(heading).normalized()
		var size := Vector2(clampf(reach * 0.36, 1.8, 5.5), clampf(reach * 0.7, 2.8, 9.0))
		pool.global_transform = Transform3D(Basis(across * size.x, Vector3.UP, heading * size.y), Vector3(hit.x, GROUND_Y + 0.03, hit.z))
		var near: float = 1.0 - smoothstep(10.0, 30.0, reach)
		(pool.material_override as ShaderMaterial).set_shader_parameter("strength", lerpf(0.35, 1.0, near))
		(cone.material_override as ShaderMaterial).set_shader_parameter("strength", lerpf(0.7, 1.0, near))


func _street_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for p: Vector2 in STREET_PATH:
		points.append(Vector3(p.x, FLOOR_Y, -p.y))
	return points


static func _cumulative(points: PackedVector3Array) -> PackedFloat32Array:
	var lengths := PackedFloat32Array([0.0])
	for i: int in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i - 1].distance_to(points[i]))
	return lengths


## [position, direction] at arc length s along a polyline.
static func _along(points: PackedVector3Array, lengths: PackedFloat32Array, s: float) -> Array:
	for i: int in range(1, points.size()):
		if s <= lengths[i] or i == points.size() - 1:
			var span: float = maxf(lengths[i] - lengths[i - 1], 0.001)
			var t: float = clampf((s - lengths[i - 1]) / span, 0.0, 1.0)
			var direction: Vector3 = points[i] - points[i - 1]
			direction.y = 0.0
			return [points[i - 1].lerp(points[i], t), direction.normalized()]
	return [points[0], Vector3.RIGHT]


## Two warm lamps and a faint spill on the road under them, big enough to read from the yard's wide views.
func _build_headlights() -> void:
	headlights = Node3D.new()
	headlights.name = "CerroHeadlights"
	add_child(headlights)
	var lamp := SphereMesh.new()
	lamp.radius = 0.55
	lamp.height = 1.1
	lamp.radial_segments = 8
	lamp.rings = 4
	var glow: StandardMaterial3D = edges.depot_edges_glow("eadfb8", 2.4)
	for side: float in [-1.0, 1.0]:
		var part := MeshInstance3D.new()
		part.name = "Lamp"
		part.mesh = lamp
		part.material_override = glow
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.position = Vector3(1.4, 1.2, side * 0.9)
		headlights.add_child(part)
	var pool := MeshInstance3D.new()
	pool.name = "RoadPool"
	var quad := PlaneMesh.new()
	quad.size = Vector2(9.0, 4.0)
	pool.mesh = quad
	pool.material_override = edges.depot_edges_glow("8c8462", 0.35)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3(6.0, 0.35, 0.0)
	headlights.add_child(pool)
	# The road and its lamps live in the cerro frame; the lights ride in the same frame.
	var cerro: Node3D = edges.get_node_or_null("Cerro")
	if cerro != null:
		remove_child(headlights)
		cerro.add_child(headlights)


## The relief micro: the same body as the parked ones, its LED boards reading «08 RELEVO», its cabin
## lit and its dipped beams on: two unshadowed spots with soft cones and ground pools that reach the
## yard through the gate before the bus is in frame (the body would block a shadowed source in its nose).
func _build_bus() -> void:
	var frame: Node3D = edges.get_node_or_null("Street")
	bus = Node3D.new()
	bus.name = "ReliefBus"
	(frame if frame != null else edges).add_child(bus)
	edges.depot_edges_build_micro(bus, "c4c0b0", "4c5f6a", "08 RELEVO", false, false)
	var length: float = 10.4
	var width: float = 2.5
	var y: float = FLOOR_Y
	# The flank the camera sees (local -z: the bus drives toward -a) carries the route plate; the
	# destination itself is on the roof marquee.
	edges.depot_edges_box(bus, "RoutePlate", Vector3(0.6, y + 2.88, -width * 0.5 - 0.02), Vector3(3.2, 0.3, 0.02), edges.depot_edges_paint("c9c1a8"))
	edges.depot_edges_text(bus, "08 · TERMINAL - PLAZA", Vector3(0.6, y + 2.88, -width * 0.5 - 0.035), 0.12, "27313a", false, 180.0)
	# Headlamps: dipped, warm. Small camera-facing flares so they read although the nose is edge-on.
	var flare := QuadMesh.new()
	flare.size = Vector2(0.55, 0.38)
	var flare_material: StandardMaterial3D = edges.depot_edges_glow("efe3bf", 1.8).duplicate()
	flare_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flare_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flare_material.albedo_color = Color("efe3bf")
	var cone_mesh := CylinderMesh.new()
	cone_mesh.height = 1.0
	cone_mesh.top_radius = 0.2
	cone_mesh.bottom_radius = 0.004
	cone_mesh.radial_segments = 16
	cone_mesh.rings = 1
	cone_mesh.cap_top = false
	cone_mesh.cap_bottom = false
	var pool_mesh := PlaneMesh.new()
	pool_mesh.size = Vector2(1.0, 1.0)
	for side: float in [-1.0, 1.0]:
		edges.depot_edges_box(bus, "HeadlampLit", Vector3(length * 0.5 + 0.035, y + 1.0, side * 0.85), Vector3(0.03, 0.18, 0.32), edges.depot_edges_glow("efe3bf", 1.4))
		var part := MeshInstance3D.new()
		part.name = "HeadlampFlare"
		part.mesh = flare
		part.material_override = flare_material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.position = Vector3(length * 0.5 + 0.12, y + 1.0, side * 0.85)
		bus.add_child(part)
		# Each lamp: a pivot that toes the beam (yaw toward the fence side, local -z), an aim node that
		# dips it, the unshadowed spot itself, a soft cone of lit air and a pool where it lands.
		var pivot := Node3D.new()
		pivot.name = "HeadlightFence" if side < 0.0 else "HeadlightStreet"
		pivot.position = Vector3(length * 0.5 + 0.2, y + 1.0, side * 0.85)
		bus.add_child(pivot)
		var aim := Node3D.new()
		aim.name = "Aim"
		pivot.add_child(aim)
		var beam := SpotLight3D.new()
		beam.name = "HeadlightBeam"
		aim.add_child(beam)
		beam.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
		beam.light_color = Color("f1e2b8")
		beam.light_energy = 260.0 if side < 0.0 else 170.0
		beam.spot_range = 22.0
		beam.spot_angle = 30.0
		beam.spot_attenuation = 0.9
		beam.spot_angle_attenuation = 1.6
		beam.light_specular = 0.35
		beam.light_volumetric_fog_energy = 1.0
		beam.shadow_enabled = false
		var cone := MeshInstance3D.new()
		cone.name = "BeamCone"
		cone.mesh = cone_mesh
		cone.rotation_degrees = Vector3(0.0, 0.0, -90.0)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cone_material := ShaderMaterial.new()
		cone_material.shader = BEAM_SHADER
		cone.material_override = cone_material
		aim.add_child(cone)
		var pool := MeshInstance3D.new()
		pool.name = "BeamPool"
		pool.mesh = pool_mesh
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pool_material := ShaderMaterial.new()
		pool_material.shader = BEAM_SHADER
		pool_material.set_shader_parameter("pool", true)
		pool.material_override = pool_material
		pool.visible = false
		add_child(pool)
		# The fence-side lamp holds a patch of apron just inside the gate; the street-side one a patch
		# further west, so the two pools part as the bus swings in.
		_beams.append({"pivot": pivot, "aim": aim, "spot": beam, "cone": cone, "pool": pool,
			"target": Vector2(8.5, 12.0) if side < 0.0 else Vector2(6.2, 14.6),
			"min_toe": 4.0 if side < 0.0 else 2.0, "max_toe": 60.0 if side < 0.0 else 38.0})
	# Roof marquee: the relief's LED destination board on a rack over the cabin, tilted back to the
	# street so «08 RELEVO» reads from the yard over the fence.
	var marquee_at := Vector3(0.3, y + 3.5, -0.25)
	for rack_x: float in [-1.7, 2.3]:
		edges.depot_edges_box(bus, "MarqueeRack", Vector3(rack_x, y + 3.25, -0.1), Vector3(0.08, 0.36, 0.5), edges.depot_edges_paint("2c3132"))
	edges.depot_edges_box(bus, "MarqueeBack", marquee_at, Vector3(4.6, 0.7, 0.12), edges.depot_edges_paint("1c1f20"), false, Vector3(35.0, 0.0, 0.0))
	var face_normal := Vector3(0.0, sin(deg_to_rad(35.0)), -cos(deg_to_rad(35.0)))
	edges.depot_edges_box(bus, "MarqueeFace", marquee_at + face_normal * 0.065, Vector3(4.4, 0.56, 0.01), edges.depot_edges_glow("3a2a12", 0.55), false, Vector3(35.0, 0.0, 0.0))
	var marquee: Label3D = edges.depot_edges_text(bus, "08 RELEVO", marquee_at + face_normal * 0.08, 0.36, "f2cf86", true, 180.0)
	marquee.rotation_degrees = Vector3(-35.0, 180.0, 0.0)
	marquee.modulate = Color(2.1, 1.6, 0.85)
	# Lit cabin: the relief driver's shift is starting.
	edges.depot_edges_box(bus, "CabinGlowNear", Vector3(-0.3, y + 2.25, width * 0.5 + 0.012), Vector3(8.2, 0.84, 0.01), edges.depot_edges_glow("cfe6d2", 0.3))
	edges.depot_edges_box(bus, "CabinGlowFar", Vector3(-0.3, y + 2.25, -width * 0.5 - 0.012), Vector3(8.2, 0.84, 0.01), edges.depot_edges_glow("cfe6d2", 0.3))
