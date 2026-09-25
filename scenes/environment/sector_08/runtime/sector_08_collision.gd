## Static collision for the Sector 08 yard, derived from the imported geometry.
##
## The authored GLB ships no collision, and generating trimesh bodies for 2990 meshes would be
## both slow to build and pointless: at P30 the player moves on a flat yard against blocky
## industrial props. So this builds convex hulls from the mesh vertices, which are cheap and,
## unlike world AABBs, do not turn a sloped stair stringer or a diagonal brace into a solid box
## several times its real size.
##
## Nothing here touches the meshes themselves - it only reads their transforms and bounds, so
## the GLB, UVs, cs_* metadata and materials are untouched.
extends StaticBody3D

## Walkable footprint of the yard. Anything centred outside this is scenery, not level.
var YARD_MIN := Vector2(-26.0, -26.0)
var YARD_MAX := Vector2(26.0, 14.0)
const FLOOR_TOP := 0.06
const WALL_HEIGHT := 6.0

## Below this an object is a decal, a kerb or a slab: the player walks over it.
const OBSTACLE_MIN_HEIGHT := 0.45
## Below this an object is a cable tie or a bracket: too small to be worth a shape.
const OBSTACLE_MIN_FOOTPRINT := 0.10
## Above this an object is a gantry, a catwalk or a pipe run overhead: the player walks under it.
const OVERHEAD_CLEARANCE := 2.6

## Slack cables sag from high anchors, so their bounds dip to head height and span the yard
## while the wire itself is millimetres thick. They are scenery: never collidable.
const NON_BLOCKING := ["strand", "Cable", "Trace", "Wire", "Catenary"]

var stats: Dictionary = {}


func build(environment: Node3D) -> void:
	var obstacles: int = 0
	var skipped_vegetation: int = 0
	var skipped_overhead: int = 0
	var skipped_flat: int = 0
	var skipped_cables: int = 0
	for node: Node in environment.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		var centre: Vector3 = bounds.get_center()
		if centre.x < YARD_MIN.x or centre.x > YARD_MAX.x or centre.z < YARD_MIN.y or centre.z > YARD_MAX.y:
			continue
		# Grass must never stop the player, however tall the clump happens to be.
		if str(mesh.get_meta("cs_system", "")) == "bio":
			skipped_vegetation += 1
			continue
		if bounds.size.y < OBSTACLE_MIN_HEIGHT:
			skipped_flat += 1
			continue
		if bounds.size.x * bounds.size.z < OBSTACLE_MIN_FOOTPRINT:
			continue
		if bounds.position.y > OVERHEAD_CLEARANCE:
			skipped_overhead += 1
			continue
		if _is_non_blocking(str(mesh.name)):
			skipped_cables += 1
			continue
		if _hull(mesh, "Obstacle_" + str(mesh.name)):
			obstacles += 1
		else:
			_box(bounds.get_center(), bounds.size, "Obstacle_" + str(mesh.name))
			obstacles += 1

	var span: Vector2 = YARD_MAX - YARD_MIN
	var mid: Vector2 = (YARD_MIN + YARD_MAX) * 0.5
	_box(Vector3(mid.x, FLOOR_TOP - 1.0, mid.y), Vector3(span.x, 2.0, span.y), "Floor")
	# Perimeter, so the player cannot walk out of the diorama and off the authored ground.
	_box(Vector3(mid.x, WALL_HEIGHT * 0.5, YARD_MIN.y - 0.5), Vector3(span.x + 2.0, WALL_HEIGHT, 1.0), "BoundNorth")
	_box(Vector3(mid.x, WALL_HEIGHT * 0.5, YARD_MAX.y + 0.5), Vector3(span.x + 2.0, WALL_HEIGHT, 1.0), "BoundSouth")
	_box(Vector3(YARD_MIN.x - 0.5, WALL_HEIGHT * 0.5, mid.y), Vector3(1.0, WALL_HEIGHT, span.y + 2.0), "BoundWest")
	_box(Vector3(YARD_MAX.x + 0.5, WALL_HEIGHT * 0.5, mid.y), Vector3(1.0, WALL_HEIGHT, span.y + 2.0), "BoundEast")

	stats = {
		"obstacle_shapes": obstacles,
		"total_shapes": obstacles + 5,
		"skipped_vegetation": skipped_vegetation,
		"skipped_flat_walkable": skipped_flat,
		"skipped_overhead": skipped_overhead,
		"skipped_cables": skipped_cables,
		"floor_top_y": FLOOR_TOP,
	}


func _is_non_blocking(mesh_name: String) -> bool:
	for token: String in NON_BLOCKING:
		if mesh_name.contains(token):
			return true
	return false


## Convex hull in the body's own space. Returns false when the mesh has no usable vertex array,
## so the caller can fall back to a box.
func _hull(mesh: MeshInstance3D, id: String) -> bool:
	if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		return false
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
		return false
	var local: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if local.size() < 4:
		return false
	var world := PackedVector3Array()
	world.resize(local.size())
	var to_world: Transform3D = mesh.global_transform
	for i in local.size():
		world[i] = to_world * local[i]
	var shape := ConvexPolygonShape3D.new()
	shape.points = world
	var collider := CollisionShape3D.new()
	collider.name = id
	collider.shape = shape
	add_child(collider)
	return true


func _box(centre: Vector3, size: Vector3, id: String) -> void:
	var shape := BoxShape3D.new()
	shape.size = size.maxf(0.05)
	var collider := CollisionShape3D.new()
	collider.name = id
	collider.shape = shape
	add_child(collider)
	collider.global_position = centre
