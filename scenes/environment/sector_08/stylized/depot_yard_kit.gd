## Builds one depot cluster as a single vertex-coloured mesh (one draw call, one shadow caster)
## and keeps, for every solid part, a collision shape of exactly that part's size and placement.
## Parts are placed in the yard's own frame: u along screen right, v toward the camera.
extends RefCounted

const AU := Vector3(0.8241, 0.0, -0.5664)
const AV := Vector3(0.5664, 0.0, 0.8241)
## Height of the painted floor; props stand on it.
const FLOOR := 0.06

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
## [Shape3D, Transform3D] for each solid part, in world space.
var solids: Array = []

## A world point from yard coordinates, on the floor unless lifted.
static func at(u: float, v: float, y: float = 0.0) -> Vector3:
	return AU * u + AV * v + Vector3.UP * (FLOOR + y)

## A basis turned `yaw` degrees from the yard frame (x along u, z along v), then tipped.
static func turn(yaw: float, tip_x: float = 0.0, tip_z: float = 0.0) -> Basis:
	var yard := Basis(AU, Vector3.UP, AV)
	return yard * Basis.from_euler(Vector3(deg_to_rad(tip_x), deg_to_rad(yaw), deg_to_rad(tip_z)))

func add_mesh(mesh: Mesh, xf: Transform3D, color: Color, surface: int = 0) -> void:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var base: int = verts.size()
	var normal_basis: Basis = xf.basis.inverse().transposed()
	var source_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source_norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for vertex: Vector3 in source_verts: verts.append(xf * vertex)
	for normal: Vector3 in source_norms: norms.append((normal_basis * normal).normalized())
	for i: int in source_verts.size(): cols.append(color)
	if arrays[Mesh.ARRAY_INDEX] != null and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
		for i: int in arrays[Mesh.ARRAY_INDEX]: idx.append(base + i)
	else:
		for i: int in source_verts.size(): idx.append(base + i)

func box(xf: Transform3D, size: Vector3, color: Color, solid: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	add_mesh(mesh, xf, color)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		solids.append([shape, xf])

## A collider with no mesh of its own, sized to the parts it stands for (a stack, a heap).
func solid_box(xf: Transform3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	solids.append([shape, xf])

func cylinder(xf: Transform3D, top: float, bottom: float, height: float, color: Color, solid: bool = false, segments: int = 10) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	add_mesh(mesh, xf, color)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(top, bottom)
		shape.height = height
		solids.append([shape, xf])

func torus(xf: Transform3D, inner: float, outer: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 12
	mesh.ring_segments = 6
	add_mesh(mesh, xf, color)

## A sagging cable from a to b: a few straight segments drooping toward the floor.
func cable(a: Vector3, b: Vector3, sag: float, radius: float, color: Color, pieces: int = 6) -> void:
	var points: Array[Vector3] = []
	for i: int in pieces + 1:
		var t: float = float(i) / pieces
		var p: Vector3 = a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		p.y = maxf(p.y, FLOOR + radius)
		points.append(p)
	for i: int in pieces:
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var length: float = from.distance_to(to)
		if length < 0.01: continue
		var up: Vector3 = (to - from) / length
		var side: Vector3 = up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		var basis := Basis(side, up, side.cross(up))
		cylinder(Transform3D(basis, (from + to) * 0.5), radius, radius, length + radius, color, false, 6)

func is_empty() -> bool:
	return verts.is_empty()

## The merged mesh under `parent`, plus a static body holding the solid parts. Returns the shapes
## so the trial can toggle them with the presentation.
func commit(parent: Node3D, title: String, material: Material) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	if verts.is_empty(): return shapes
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = title
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	if solids.is_empty(): return shapes
	var body := StaticBody3D.new()
	body.name = title + "Solid"
	parent.add_child(body)
	for solid: Array in solids:
		var shape := CollisionShape3D.new()
		shape.shape = solid[0]
		shape.transform = solid[1]
		body.add_child(shape)
		shapes.append(shape)
	return shapes
