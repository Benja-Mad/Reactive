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
	# The gate lamp lights as the bus pulls up; it stays on.
	edges.depot_edges_set_gate_lamp(progress >= 0.997 or phase == "won")
	# The gate rolls open once the shift is won.
	if edges.gate_leaf != null:
		var open: float = 0.0
		if _gate_open_time >= 0.0:
			var g: float = clampf(_gate_open_time / GATE_SECONDS, 0.0, 1.0)
			open = g * g * (3.0 - 2.0 * g)
		edges.gate_leaf.position.x = _gate_closed_x + GATE_TRAVEL * open


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
## lit and its dipped beams on: two unshadowed spots throwing a warm pool down the street ahead and
## onto the gate it stops at (the body would block a shadowed source sitting in its own nose).
func _build_bus() -> void:
	var frame: Node3D = edges.get_node_or_null("Street")
	bus = Node3D.new()
	bus.name = "ReliefBus"
	(frame if frame != null else edges).add_child(bus)
	edges.depot_edges_build_micro(bus, "c4c0b0", "4c5f6a", "08 RELEVO", false, false)
	var length: float = 10.4
	var width: float = 2.5
	var y: float = FLOOR_Y
	# The flank the camera sees (local -z: the bus drives toward -a) carries the big LED board.
	edges.depot_edges_box(bus, "SideSignBoxFar", Vector3(0.6, y + 2.88, -width * 0.5 - 0.02), Vector3(3.9, 0.4, 0.03), edges.depot_edges_paint("1c1f20"))
	edges.depot_edges_box(bus, "SideSignFrame", Vector3(0.6, y + 2.88, -width * 0.5 - 0.03), Vector3(3.7, 0.32, 0.005), edges.depot_edges_glow("3a2f1c", 0.4))
	var board: Label3D = edges.depot_edges_text(bus, "08 RELEVO", Vector3(0.6, y + 2.88, -width * 0.5 - 0.045), 0.24, "f2cf86", true, 180.0)
	board.modulate = Color(1.9, 1.55, 0.95)
	# Headlamps: dipped, warm. Small camera-facing flares so they read although the nose is edge-on.
	var flare := QuadMesh.new()
	flare.size = Vector2(0.55, 0.38)
	var flare_material: StandardMaterial3D = edges.depot_edges_glow("efe3bf", 1.8).duplicate()
	flare_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flare_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flare_material.albedo_color = Color("efe3bf")
	for side: float in [-1.0, 1.0]:
		edges.depot_edges_box(bus, "HeadlampLit", Vector3(length * 0.5 + 0.035, y + 1.0, side * 0.85), Vector3(0.03, 0.18, 0.32), edges.depot_edges_glow("efe3bf", 1.4))
		var part := MeshInstance3D.new()
		part.name = "HeadlampFlare"
		part.mesh = flare
		part.material_override = flare_material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.position = Vector3(length * 0.5 + 0.12, y + 1.0, side * 0.85)
		bus.add_child(part)
		var beam := SpotLight3D.new()
		beam.name = "HeadlightBeam"
		bus.add_child(beam)
		beam.position = Vector3(length * 0.5 + 0.2, y + 1.0, side * 0.85)
		# Dipped; the fence-side lamp (local -z) is toed hard toward the gate so its pool lands on the
		# leaf and spills through the bars onto the apron, the other lights the street ahead.
		beam.rotation = Vector3(deg_to_rad(-16.0 if side < 0.0 else -10.0), deg_to_rad(-32.0 if side < 0.0 else -80.0), 0.0)
		beam.light_color = Color("f1e2b8")
		beam.light_energy = 260.0 if side < 0.0 else 150.0
		beam.spot_range = 22.0
		beam.spot_angle = 34.0
		beam.spot_attenuation = 0.9
		beam.spot_angle_attenuation = 1.6
		beam.light_specular = 0.35
		beam.light_volumetric_fog_energy = 1.0
		beam.shadow_enabled = false
	# Lit cabin: the relief driver's shift is starting.
	edges.depot_edges_box(bus, "CabinGlowNear", Vector3(-0.3, y + 2.25, width * 0.5 + 0.012), Vector3(8.2, 0.84, 0.01), edges.depot_edges_glow("cfe6d2", 0.3))
	edges.depot_edges_box(bus, "CabinGlowFar", Vector3(-0.3, y + 2.25, -width * 0.5 - 0.012), Vector3(8.2, 0.84, 0.01), edges.depot_edges_glow("cfe6d2", 0.3))
