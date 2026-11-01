## Ground marks that warn where a machine is about to hit. One language for every enemy: thin rose
## piping around the danger zone, the ground beneath only darkened, and a countdown carried by light
## until the hit lands (see telegraph.gdshader).
extends RefCounted
const ART = preload("res://scripts/survivor/telegraph.gdshader")
const DANGER := Color("ff3b6b")
const SHADOW := Color(0.02, 0.03, 0.05, 0.55)

static func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m

static func _flat(parent: Node3D, mesh: Mesh, m: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

## The drawn mark: a flat quad on the floor carrying the telegraph shader.
static func _mark(parent: Node, at: Vector3, size: Vector2, params: Dictionary) -> Node3D:
	var mark := Node3D.new()
	parent.add_child(mark)
	mark.global_position = at
	var art := ShaderMaterial.new()
	art.shader = ART
	for key: String in params: art.set_shader_parameter(key, params[key])
	var plane := PlaneMesh.new()
	plane.size = size
	var floor_art := _flat(mark, plane, art)
	floor_art.name = "Art"
	mark.set_meta("art", art)
	return mark

## A landing zone: a dashed rose ring with sight ticks and the seal at its centre. The fill is a
## hot ring growing out from the seal; it meets the edge when the hit lands.
static func ring(parent: Node, point: Vector3, radius: float, color: Color = DANGER) -> Node3D:
	var size: float = (radius + 0.4) * 2.0
	return _mark(parent, Vector3(point.x, point.y + 0.05, point.z), Vector2(size, size), {"shape": 0, "radius": radius, "danger": color})

## A lane on the ground from `from` to `to`: marching rose edges, chevrons that light one by one
## toward the end as the fill runs, and a bar where the run stops.
static func lane(parent: Node, from: Vector3, to: Vector3, width: float, color: Color = DANGER) -> Node3D:
	var flat: Vector3 = Vector3(to.x - from.x, 0, to.z - from.z)
	var length: float = maxf(flat.length(), 0.1)
	var mark := _mark(parent, Vector3(from.x, minf(from.y, to.y) + 0.05, from.z), Vector2(width + 0.1, length), {"shape": 1, "span": length, "width": width, "danger": color})
	mark.rotation.y = atan2(-flat.x, -flat.z)
	# The quad runs from the mark's origin down its -Z, where the lane points.
	mark.get_node("Art").position.z = -length * 0.5
	return mark

## Run a mark's countdown: 0 = just warned, 1 = the hit lands now.
static func fill(mark: Node3D, amount: float) -> void:
	if mark == null or not is_instance_valid(mark) or not mark.has_meta("art"): return
	(mark.get_meta("art") as ShaderMaterial).set_shader_parameter("fill", clampf(amount, 0.0, 1.0))

## A soft dark blot under something in the air, so its ground position always reads.
static func shadow(parent: Node, radius: float) -> Node3D:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 20
	var holder := Node3D.new()
	parent.add_child(holder)
	var blot := _flat(holder, disc, _glow(SHADOW, SHADOW.a))
	var core := CylinderMesh.new()
	core.top_radius = radius * 0.55
	core.bottom_radius = radius * 0.55
	core.height = 0.012
	core.radial_segments = 16
	_flat(blot, core, _glow(SHADOW, 0.35))
	return holder
