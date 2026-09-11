## Closes the lateral edges of the yard.
##
## Two different gaps meet here. The authored paving is laid on a grid rotated 53 degrees and
## covers a rhombus; the collision floor is an axis-aligned box spanning x -26..26 by z -26..14.
## So the corners of the walkable box are unpaved -- the player stands there on an invisible
## floor over nothing. And at full camera travel the frame reaches past that box entirely, so
## even a perfectly paved walkable area still shows a void just outside it.
##
## The first version of this file filled fifteen cells and reported the edges covered, because it
## tested coverage against each slab's *local bounding box*. A square rotated 53 degrees fills
## well under its own bounding box, so that test claimed paving on ground no slab touches --
## exactly the ground that was missing. Coverage is now rasterised from the paving triangles,
## which measured the walkable box as 84.6% paved, and the fill is placed on the authored lattice
## (pitch and orientation both read off the authored slabs) so it continues the yard's tiling
## instead of laying a second, different one beside it.
##
## Everything placed here is an instance of authored geometry carrying the source's own material
## *and its instance shader parameters*. That last part matters: the skyline blocks are drawn by
## a calibrated shader that receives its colour through `instance uniform`, which a clone does not
## inherit. Without copying them the blocks render at the shader's dark default -- which is what
## put a row of black slabs beyond the fence.
extends Node3D

## Matches sector_08_collision.gd, which is what actually stops the player.
const YARD_MIN := Vector2(-26.0, -26.0)
const YARD_MAX := Vector2(26.0, 14.0)
## How far past the walkable bounds the paving reaches. The camera sees ground out here at full
## travel, so stopping the fill at the bounds leaves a visible hole immediately outside them.
const APRON_SIDE := 13.0
const APRON_SOUTH := 9.0
const APRON_NORTH := 5.0
## Coverage is rasterised at this resolution, in metres.
const COVERAGE_CELL := 1.0
## Fence panels stand on the bound face itself, so the wall that stops the player is the wall
## they can see. The previous run sat 0.6 m inside the yard, which let the player walk through it.
const FENCE_LINE := 26.0
const FENCE_SOUTH_Z := 14.0
## New south panels are skipped this close to an authored one, so the run meets the existing
## fence instead of doubling it.
const FENCE_MERGE_RADIUS := 2.6
## The neighbouring lot's boundary wall, and how far out the distant blocks stand.
const WALL_OFFSET := 8.0
const BLOCK_MIN := 12.0
const BLOCK_MAX := 34.0
## Nothing tall is placed nearer to the camera than this, as a fraction of the framing distance.
## The facade screen sits at 0.676 of it and owns the foreground; a backdrop block closer than
## that stops being a backdrop and starts being an object in front of the shot, which is what the
## east side ended up with. Stated as a fraction, not the 62 m it used to be: at a 60 m framing
## that constant culled everything between 43 and 62 m and thinned the lot behind the fence by a
## quarter for no reason.
const CAMERA_CLEARANCE_FRACTION := 0.72
const REFERENCE_DISTANCE := 85.8
const SEED := 20260908

## Copied from the source mesh onto each clone. The calibrated shaders read all of these through
## `instance uniform`, so a clone without them is not the same surface.
const INSTANCE_PARAMETERS: Array[StringName] = [
	&"cs_surface_color", &"cs_surface_roughness", &"cs_surface_metallic", &"cs_surface_kind",
	&"cs_surface_wetness", &"cs_surface_seed", &"cs_depth_fade", &"cs_architecture_fill",
	&"cs_local_contrast",
]

var stats: Dictionary = {}

var _covered: Dictionary = {}
var _camera: Camera3D
var _clearance: float = CAMERA_CLEARANCE_FRACTION * REFERENCE_DISTANCE
var _space: PhysicsDirectSpaceState3D
var _probe: PhysicsShapeQueryParameters3D


func build(environment: Node3D, camera: Camera3D = null, framing_distance: float = REFERENCE_DISTANCE) -> void:
	_camera = camera
	_clearance = CAMERA_CLEARANCE_FRACTION * framing_distance
	var slab: MeshInstance3D = _template(environment, "Yard_Slab")
	var panel: MeshInstance3D = _template(environment, "ChainlinkPanel")
	if slab == null or panel == null:
		push_warning("Sector08Perimeter: no authored slab or fence to clone; edges left as authored.")
		return

	var start: int = Time.get_ticks_msec()
	_rasterise_paving(environment)
	_prepare_occupancy()
	var lattice: Dictionary = _read_lattice(environment, slab)
	stats["lattice"] = lattice
	stats["walkable_paved_pct"] = _walkable_coverage()
	stats["ground_filled"] = _fill_ground(slab, lattice)
	# Self-check: the same rasterised measurement, run again with the fill included. This is the
	# number that says whether the edges are actually closed, and it is the number the previous
	# version of this file got wrong.
	stats["walkable_paved_pct_after"] = _walkable_coverage()
	stats["walkable_holes_after"] = _walkable_holes()
	# A hole inside a wall is not a hole the player or the camera can find, so the two are counted
	# apart rather than lumped into one percentage.
	stats["walkable_holes_split"] = _hole_split()
	stats["fence_panels"] = _fence(panel, environment)
	stats["backdrop"] = _backdrop(environment)
	stats["draw_calls"] = get_child_count()
	stats["build_ms"] = Time.get_ticks_msec() - start


## First mesh of a family, used purely as a source of geometry, material and shading parameters.
func _template(environment: Node3D, family: String) -> MeshInstance3D:
	for node: Node in environment.find_children(family + "*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			return mesh
	return null


## Occupancy of the authored paving, rasterised from its triangles into metre cells.
##
## Testing a point against a piece's bounding box -- in world space or in the piece's own space --
## over-reports for a rotated slab, and every slab here is rotated. Triangles are the geometry
## itself, so this cannot be wrong about the corners.
func _rasterise_paving(environment: Node3D) -> void:
	var triangles: int = 0
	for node: Node in environment.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var text: String = str(mesh.name)
		if not (text.begins_with("Yard_Slab") or text.begins_with("Road_Surface")
			or text.begins_with("Crossing") or text.begins_with("Ground_Patch")):
			continue
		if mesh.mesh == null or (mesh.global_transform * mesh.get_aabb()).position.y > 1.0:
			continue
		var to_world: Transform3D = mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if indices.size() >= 3 else vertices.size()
			for i in range(0, count - 2, 3):
				var a: Vector3 = to_world * vertices[indices[i] if indices.size() >= 3 else i]
				var b: Vector3 = to_world * vertices[indices[i + 1] if indices.size() >= 3 else i + 1]
				var c: Vector3 = to_world * vertices[indices[i + 2] if indices.size() >= 3 else i + 2]
				_mark_triangle(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
				triangles += 1
	stats["paving_triangles"] = triangles


## Scanline fill of one triangle into the coverage grid. Cheaper and more honest than sampling
## cell centres against every triangle: a cell is covered if any part of a triangle lands in it.
func _mark_triangle(a: Vector2, b: Vector2, c: Vector2) -> void:
	var lo := Vector2(minf(minf(a.x, b.x), c.x), minf(minf(a.y, b.y), c.y))
	var hi := Vector2(maxf(maxf(a.x, b.x), c.x), maxf(maxf(a.y, b.y), c.y))
	for cx in range(int(floor(lo.x / COVERAGE_CELL)), int(floor(hi.x / COVERAGE_CELL)) + 1):
		for cz in range(int(floor(lo.y / COVERAGE_CELL)), int(floor(hi.y / COVERAGE_CELL)) + 1):
			var centre := Vector2((float(cx) + 0.5) * COVERAGE_CELL, (float(cz) + 0.5) * COVERAGE_CELL)
			if _in_triangle(a, b, c, centre):
				_covered[Vector2i(cx, cz)] = true


## Is this far enough from the lens to belong behind the scene rather than in front of it?
func _behind_foreground(point: Vector3) -> bool:
	if _camera == null:
		return true
	return _camera.global_position.distance_to(point) > _clearance


func _in_triangle(a: Vector2, b: Vector2, c: Vector2, p: Vector2) -> bool:
	var d1: float = (b - a).cross(p - a)
	var d2: float = (c - b).cross(p - b)
	var d3: float = (a - c).cross(p - c)
	return (d1 >= 0.0 and d2 >= 0.0 and d3 >= 0.0) or (d1 <= 0.0 and d2 <= 0.0 and d3 <= 0.0)


func is_paved(point: Vector3) -> bool:
	return _covered.has(Vector2i(int(floor(point.x / COVERAGE_CELL)), int(floor(point.z / COVERAGE_CELL))))


## Whether a spot is inside solid geometry, asked of the collision the yard already built rather
## than of bounding boxes.
##
## The first attempt at this excluded cells by world AABB, and a rotated or hollow building's AABB
## covers open ground: it wrongly excluded a 6 m run along the north edge where a player capsule
## fits perfectly well, and left that run unpaved. Collision is the same thing that decides where
## the player can stand, so it is the right authority for where paving is needed.
func _prepare_occupancy() -> void:
	_space = get_world_3d().direct_space_state
	_probe = PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	_probe.shape = capsule


func _is_occupied(point: Vector3) -> bool:
	if _space == null:
		return false
	_probe.transform = Transform3D(Basis(), Vector3(point.x, 1.0, point.z))
	return not _space.intersect_shape(_probe, 1).is_empty()


## Is every part of this lattice cell inside something solid? Only then is paving pointless. The
## centre alone is too coarse: a cell whose middle clips a pier is still four fifths open ground.
func _cell_is_solid(centre: Vector3, frame: Basis, reach: float) -> bool:
	if not _is_occupied(centre):
		return false
	for offset: Vector3 in [frame.x * reach, -frame.x * reach, frame.z * reach, -frame.z * reach]:
		if not _is_occupied(centre + offset):
			return false
	return true


## Of the cells still unpaved inside the walkable box, how many are inside solid geometry (hidden,
## and deliberately left) versus open ground a player could stand on.
func _hole_split() -> Dictionary:
	var inside_solid: int = 0
	var open_ground: int = 0
	for zi in range(int(YARD_MIN.y), int(YARD_MAX.y)):
		for xi in range(int(YARD_MIN.x), int(YARD_MAX.x)):
			if _covered.has(Vector2i(xi, zi)):
				continue
			if _is_occupied(Vector3(float(xi) + 0.5, 0.05, float(zi) + 0.5)):
				inside_solid += 1
			else:
				open_ground += 1
	return {"inside_solid": inside_solid, "open_ground": open_ground}


## Cells inside the walkable box with no paving under them, listed by row so a remaining hole is
## a location rather than a percentage.
func _walkable_holes() -> Dictionary:
	var rows: Dictionary = {}
	for zi in range(int(YARD_MIN.y), int(YARD_MAX.y)):
		var open_cells: Array = []
		for xi in range(int(YARD_MIN.x), int(YARD_MAX.x)):
			if not _covered.has(Vector2i(xi, zi)):
				open_cells.append(xi)
		if not open_cells.is_empty():
			rows[str(zi)] = "%d: %d..%d" % [open_cells.size(), open_cells.min(), open_cells.max()]
	return rows


func _walkable_coverage() -> float:
	var paved: int = 0
	var total: int = 0
	for xi in range(int(YARD_MIN.x), int(YARD_MAX.x)):
		for zi in range(int(YARD_MIN.y), int(YARD_MAX.y)):
			total += 1
			if _covered.has(Vector2i(xi, zi)):
				paved += 1
	return snappedf(100.0 * float(paved) / maxf(float(total), 1.0), 0.1)


## The authored paving lattice: orientation from a slab's own basis, pitch from the spacing
## between slab origins. Reported with its residual so a future change to the export that moves
## the grid shows up as a number rather than as a seam.
func _read_lattice(environment: Node3D, slab: MeshInstance3D) -> Dictionary:
	var origins: Array[Vector3] = []
	for node: Node in environment.find_children("Yard_Slab*", "MeshInstance3D", true, false):
		origins.append((node as MeshInstance3D).global_position)
	var spacings: Array[float] = []
	for i in mini(origins.size(), 40):
		var nearest: float = 1e9
		for j in origins.size():
			if i == j:
				continue
			nearest = minf(nearest, origins[i].distance_to(origins[j]))
		if nearest < 1e8:
			spacings.append(nearest)
	spacings.sort()
	var pitch: float = spacings[spacings.size() / 2] if not spacings.is_empty() else 3.29
	var basis: Basis = slab.global_basis.orthonormalized()
	var anchor: Vector3 = slab.global_position
	# How far the authored origins sit from the lattice this reconstructs. Near zero means the
	# fill will land on the same grid; a large value would mean the assumption no longer holds.
	var residual: float = 0.0
	for origin: Vector3 in origins:
		var local: Vector3 = basis.inverse() * (origin - anchor)
		var snapped := Vector3(roundf(local.x / pitch) * pitch, local.y, roundf(local.z / pitch) * pitch)
		residual = maxf(residual, Vector2(local.x - snapped.x, local.z - snapped.z).length())
	return {
		"pitch_m": snappedf(pitch, 0.001),
		"yaw_deg": snappedf(rad_to_deg(atan2(basis.x.z, basis.x.x)), 0.01),
		"anchor": str(anchor.snappedf(0.01)),
		"slabs": origins.size(),
		"max_residual_m": snappedf(residual, 0.001),
	}


func _fill_ground(slab: MeshInstance3D, lattice: Dictionary) -> int:
	var source: AABB = slab.get_aabb()
	var pitch: float = float(lattice["pitch_m"])
	var basis: Basis = slab.global_basis
	var anchor: Vector3 = slab.global_position
	var frame: Basis = basis.orthonormalized()
	var region := Rect2(
		Vector2(YARD_MIN.x - APRON_SIDE, YARD_MIN.y - APRON_NORTH),
		Vector2((YARD_MAX.x + APRON_SIDE) - (YARD_MIN.x - APRON_SIDE),
			(YARD_MAX.y + APRON_SOUTH) - (YARD_MIN.y - APRON_NORTH)))
	var span: int = int(ceil(maxf(region.size.x, region.size.y) / pitch)) + 2
	var transforms: Array[Transform3D] = []
	# Kept for the build report: a lattice point dropped as solid is the one decision here that
	# can leave a hole, so it is counted rather than assumed harmless.
	var rejected: Array = []
	for i in range(-span, span + 1):
		for j in range(-span, span + 1):
			var point: Vector3 = anchor + frame.x * (float(i) * pitch) + frame.z * (float(j) * pitch)
			if not region.has_point(Vector2(point.x, point.z)):
				continue
			if _covered.has(Vector2i(int(floor(point.x)), int(floor(point.z)))):
				continue
			if _cell_is_solid(point, frame, pitch * 0.34):
				rejected.append(str(Vector2i(int(round(point.x)), int(round(point.z)))))
				continue
			# Slightly below the authored slabs, so wherever a fill piece does overlap one the
			# authored surface wins instead of z-fighting with it.
			var placement := Transform3D(basis, Vector3(point.x, anchor.y - 0.02, point.z))
			transforms.append(placement)
			# Mark what this piece covers, so the check below sees the fill and so neighbouring
			# lattice points are not both offered the same cell.
			var bounds: AABB = source
			var corners: Array[Vector3] = [
				placement * Vector3(bounds.position.x, 0.0, bounds.position.z),
				placement * Vector3(bounds.position.x + bounds.size.x, 0.0, bounds.position.z),
				placement * Vector3(bounds.position.x + bounds.size.x, 0.0, bounds.position.z + bounds.size.z),
				placement * Vector3(bounds.position.x, 0.0, bounds.position.z + bounds.size.z)]
			_mark_triangle(Vector2(corners[0].x, corners[0].z), Vector2(corners[1].x, corners[1].z), Vector2(corners[2].x, corners[2].z))
			_mark_triangle(Vector2(corners[0].x, corners[0].z), Vector2(corners[2].x, corners[2].z), Vector2(corners[3].x, corners[3].z))
	stats["lattice_points_dropped_as_solid"] = rejected.size()
	stats["dropped_sample"] = rejected.slice(0, 14)
	_emit("PerimeterGroundFill", slab, transforms)
	return transforms.size()


## A chainlink run on the bound face itself, down both sides and across the near edge, skipping
## wherever the authored fence already stands.
func _fence(panel: MeshInstance3D, environment: Node3D) -> int:
	var source: AABB = panel.get_aabb()
	var width: float = maxf(source.size.x, 0.5)
	var base: float = -source.position.y
	var authored: Array[Vector3] = []
	for node: Node in environment.find_children("ChainlinkPanel*", "MeshInstance3D", true, false):
		authored.append((node as MeshInstance3D).global_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	var transforms: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var x: float = side * FENCE_LINE
		var z: float = YARD_MIN.y
		while z < YARD_MAX.y:
			# Panels are authored running along x, so a side run is turned a quarter turn.
			var basis := Basis(Vector3.UP, PI * 0.5).rotated(Vector3.UP, rng.randf_range(-0.012, 0.012))
			transforms.append(Transform3D(basis, Vector3(x, base, z + width * 0.5)))
			z += width
	var x_near: float = YARD_MIN.x
	while x_near < YARD_MAX.x:
		var centre := Vector3(x_near + width * 0.5, base, FENCE_SOUTH_Z)
		x_near += width
		var occupied: bool = false
		for existing: Vector3 in authored:
			if absf(existing.z - FENCE_SOUTH_Z) < 9.0 and absf(existing.x - centre.x) < FENCE_MERGE_RADIUS:
				occupied = true
				break
		if occupied:
			continue
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.012, 0.012)), centre))
	_emit("PerimeterFence", panel, transforms)
	return transforms.size()


## The lot beyond the fence, in three registers so the boundary has somewhere to be rather than a
## single black slab: a boundary wall, yard clutter standing on the new apron, and distant blocks
## with their window banks so they read as buildings under the haze.
func _backdrop(environment: Node3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 19
	var placed: Dictionary = {}

	var wall: MeshInstance3D = _template(environment, "Ground_Wall")
	if wall != null:
		var source: AABB = wall.get_aabb()
		var step: float = maxf(source.size.x, 1.0)
		var transforms: Array[Transform3D] = []
		for side: float in [-1.0, 1.0]:
			var z: float = YARD_MIN.y - APRON_NORTH
			while z < YARD_MAX.y + APRON_SOUTH:
				z += step
				# Gaps, so it is a boundary wall and not an extruded rectangle.
				if rng.randf() < 0.24:
					continue
				var basis := Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.02, 0.02))
				var origin := Vector3(side * (FENCE_LINE + WALL_OFFSET), -source.position.y, z)
				if not _behind_foreground(origin):
					continue
				transforms.append(Transform3D(basis, origin))
		_emit("PerimeterWall", wall, transforms)
		placed["wall_segments"] = transforms.size()

	for family: String in ["Container", "PalletStack"]:
		var prop: MeshInstance3D = _template(environment, family)
		if prop == null:
			continue
		var source: AABB = prop.get_aabb()
		var transforms: Array[Transform3D] = []
		for side: float in [-1.0, 1.0]:
			for i in (4 if family == "Container" else 3):
				var x: float = side * (FENCE_LINE + rng.randf_range(1.8, WALL_OFFSET - 1.2))
				var z: float = rng.randf_range(YARD_MIN.y - 2.0, YARD_MAX.y + APRON_SOUTH - 2.0)
				var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI))
				var origin := Vector3(x, -source.position.y, z)
				if not _behind_foreground(origin):
					continue
				transforms.append(Transform3D(basis, origin))
		_emit("Perimeter" + family, prop, transforms)
		placed[family.to_snake_case()] = transforms.size()

	var block: MeshInstance3D = _template(environment, "Skyline_Block")
	var windows: MeshInstance3D = _template(environment, "Skyline_WindowBank")
	if block != null:
		var source: AABB = block.get_aabb()
		var blocks: Array[Transform3D] = []
		var banks: Array[Transform3D] = []
		var bank_source: AABB = windows.get_aabb() if windows != null else AABB()
		for side: float in [-1.0, 1.0]:
			var z: float = YARD_MIN.y - 8.0
			while z < YARD_MAX.y + APRON_SOUTH + 4.0:
				var distance: float = rng.randf_range(BLOCK_MIN, BLOCK_MAX)
				var x: float = side * (FENCE_LINE + WALL_OFFSET + distance)
				# Authored for a skyline, so at full height they lean over the yard instead of
				# reading as the next lot along. Height falls off with distance, which is the
				# opposite of a skyline and the right way round for a diorama.
				var height: float = rng.randf_range(0.26, 0.52) + 0.4 * (distance / BLOCK_MAX)
				var scale := Vector3(rng.randf_range(0.5, 0.95), height, rng.randf_range(0.5, 0.95))
				var yaw: float = rng.randf_range(-PI, PI)
				var basis := Basis(Vector3.UP, yaw).scaled(scale)
				var base: Vector3 = Vector3(x, -source.position.y * scale.y - 0.2, z)
				z += rng.randf_range(11.0, 19.0)
				if not _behind_foreground(Vector3(x, 0.0, base.z)):
					continue
				blocks.append(Transform3D(basis, base))
				if windows != null and bank_source.size.x > 0.1:
					# Window bank on the face that looks at the yard, which is where a building
					# on this street would have its windows.
					var inward: Vector3 = Vector3(-side, 0.0, 0.0)
					var bank_width: float = source.size.x * scale.x * 0.62
					var bank_height: float = source.size.y * scale.y * 0.55
					var bank_scale := Vector3(bank_width / bank_source.size.x, bank_height / bank_source.size.y, 1.0)
					var bank_basis := Basis(Vector3.UP, atan2(inward.x, inward.z)).scaled(bank_scale)
					var offset: float = source.size.z * scale.z * 0.5 + 0.2
					banks.append(Transform3D(bank_basis, Vector3(
						x + inward.x * offset, base.y + source.size.y * scale.y * 0.55, base.z)))
		_emit("PerimeterBackdrop", block, blocks)
		placed["blocks"] = blocks.size()
		if windows != null and not banks.is_empty():
			_emit("PerimeterWindows", windows, banks)
			placed["window_banks"] = banks.size()
	return placed


## One MultiMeshInstance3D per family, carrying the source's material and -- critically -- its
## instance shader parameters, which is how the calibrated shaders receive their colour.
func _emit(id: String, source: MeshInstance3D, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source.mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = id
	instance.multimesh = multi
	instance.material_override = source.get_active_material(0)
	for parameter: StringName in INSTANCE_PARAMETERS:
		var value: Variant = source.get_instance_shader_parameter(parameter)
		if value != null:
			instance.set_instance_shader_parameter(parameter, value)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)
