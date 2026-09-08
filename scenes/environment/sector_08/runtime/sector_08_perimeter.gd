## Closes the lateral edges of the yard.
##
## The authored yard is a rhombus: its paving is laid on a rotated grid. The collision floor,
## however, is an axis-aligned box spanning x -26..26 by z -26..14. So the four corners of the
## walkable area fall outside the paving entirely -- the player can stand there, held up by an
## invisible floor, with nothing underneath and an empty frame around them.
##
## Rather than shrink the camera's travel -- which would fix the symptom by making the arena
## smaller -- this fills the gap: missing slabs, a chainlink run along each side, and a few blocks
## standing beyond it so the fence reads as a boundary with a district behind it.
##
## Everything here is an *instance of authored geometry*. It clones the meshes and materials the
## GLB already ships -- Yard_Slab, ChainlinkPanel, Skyline_Block, Container -- so nothing is
## modelled by hand, no material is invented, and the edge matches the yard by construction.
## Each family is one MultiMeshInstance3D, so the whole perimeter costs four draw calls.
extends Node3D

## Matches sector_08_collision.gd, which is what actually stops the player.
const YARD_MIN := Vector2(-26.0, -26.0)
const YARD_MAX := Vector2(26.0, 14.0)
## Coarse grid used to decide whether a spot already has authored paving on it.
const CELL := 3.0
## Slabs are only added inside the walkable footprint, inset so they never poke past the bounds.
const GROUND_INSET := 1.0
const FENCE_INSET := 0.6
## How far beyond the fence the backdrop blocks stand. Near enough to read as the next lot along,
## far enough not to tower over the play space.
const BACKDROP_MIN := 9.0
const BACKDROP_MAX := 26.0
const SEED := 20260908

var stats: Dictionary = {}


func build(environment: Node3D) -> void:
	var slab: MeshInstance3D = _template(environment, "Yard_Slab")
	var panel: MeshInstance3D = _template(environment, "ChainlinkPanel")
	var block: MeshInstance3D = _template(environment, "Skyline_Block")
	var crate: MeshInstance3D = _template(environment, "Container")
	if slab == null or panel == null:
		push_warning("Sector08Perimeter: no authored slab or fence to clone; edges left as authored.")
		return

	var pieces: Array[Dictionary] = _survey_ground(environment)
	stats["authored_ground_pieces"] = pieces.size()
	stats["ground_filled"] = _fill_ground(slab, pieces)
	stats["fence_panels"] = _fence(panel)
	stats["backdrop_blocks"] = _backdrop(block, crate)
	stats["draw_calls"] = get_child_count()


## First mesh of a family, used purely as a source of geometry and material.
func _template(environment: Node3D, family: String) -> MeshInstance3D:
	for node: Node in environment.find_children(family + "*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			return mesh
	return null


## The authored ground pieces, kept as transforms so coverage can be tested against their real
## oriented footprints. Testing world AABBs instead reports the rotated yard as covering its own
## bounding box, which is exactly the wrong answer: the corners it does not reach are the problem.
func _survey_ground(environment: Node3D) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for node: Node in environment.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var name_text: String = str(mesh.name)
		if not (name_text.begins_with("Yard_Slab") or name_text.begins_with("Road_Surface")
			or name_text.begins_with("Crossing") or name_text.begins_with("Ground_Patch")):
			continue
		var local: AABB = mesh.get_aabb()
		if (mesh.global_transform * local).position.y > 1.0:
			continue
		pieces.append({"inverse": mesh.global_transform.affine_inverse(), "local": local})
	return pieces


## Is this world point inside any authored paving piece, tested in that piece's own space?
func _is_paved(pieces: Array[Dictionary], point: Vector3) -> bool:
	for piece: Dictionary in pieces:
		var local: Vector3 = (piece["inverse"] as Transform3D) * point
		var bounds: AABB = piece["local"]
		if local.x >= bounds.position.x - 0.05 and local.x <= bounds.position.x + bounds.size.x + 0.05 \
			and local.z >= bounds.position.z - 0.05 and local.z <= bounds.position.z + bounds.size.z + 0.05:
			return true
	return false


func _fill_ground(slab: MeshInstance3D, pieces: Array[Dictionary]) -> int:
	var source: AABB = slab.get_aabb()
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var top: float = 0.05
	for cx in range(int(floor((YARD_MIN.x + GROUND_INSET) / CELL)), int(ceil((YARD_MAX.x - GROUND_INSET) / CELL))):
		for cz in range(int(floor((YARD_MIN.y + GROUND_INSET) / CELL)), int(ceil((YARD_MAX.y - GROUND_INSET) / CELL))):
			var centre := Vector3((float(cx) + 0.5) * CELL, top, (float(cz) + 0.5) * CELL)
			if _is_paved(pieces, centre):
				continue
			if absf(centre.x) > YARD_MAX.x - GROUND_INSET or centre.z < YARD_MIN.y + GROUND_INSET or centre.z > YARD_MAX.y - GROUND_INSET:
				continue
			# Scale the source slab to the cell so the fill tiles without gaps or overlap.
			var scale := Vector3(CELL / maxf(source.size.x, 0.01), 1.0, CELL / maxf(source.size.z, 0.01))
			var basis := Basis().scaled(scale).rotated(Vector3.UP, rng.randf_range(-0.02, 0.02))
			transforms.append(Transform3D(basis, centre - Vector3(source.get_center().x * scale.x, source.get_center().y, source.get_center().z * scale.z)))
	_emit("PerimeterGroundFill", slab, transforms)
	return transforms.size()


## A chainlink run down each side, following the line the invisible bound already occupies.
func _fence(panel: MeshInstance3D) -> int:
	var source: AABB = panel.get_aabb()
	var width: float = maxf(source.size.x, 0.5)
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	for side: float in [-1.0, 1.0]:
		var x: float = side * (YARD_MAX.x - FENCE_INSET)
		var z: float = YARD_MIN.y + 1.0
		while z < YARD_MAX.y - 1.0:
			# Panels run along z, so the source is turned a quarter turn about up.
			var basis := Basis(Vector3.UP, PI * 0.5).rotated(Vector3.UP, rng.randf_range(-0.012, 0.012))
			var origin := Vector3(x, -source.position.y, z + width * 0.5)
			transforms.append(Transform3D(basis, origin))
			z += width
	_emit("PerimeterFence", panel, transforms)
	return transforms.size()


## Blocks and crates standing past the fence, so the boundary has a district behind it rather
## than an empty plane. Kept outside the walkable footprint, so they need no collision.
func _backdrop(block: MeshInstance3D, crate: MeshInstance3D) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 19
	var placed: int = 0
	if block != null:
		var source: AABB = block.get_aabb()
		var transforms: Array[Transform3D] = []
		for side: float in [-1.0, 1.0]:
			var z: float = YARD_MIN.y - 2.0
			while z < YARD_MAX.y + 6.0:
				var distance: float = rng.randf_range(BACKDROP_MIN, BACKDROP_MAX)
				var x: float = side * (YARD_MAX.x + distance)
				# Shorter and slimmer than the skyline they were authored for, so they read as the
				# next lot along rather than as towers leaning over the yard.
				var scale := Vector3(rng.randf_range(0.45, 0.95), rng.randf_range(0.30, 0.72), rng.randf_range(0.45, 0.95))
				var basis := Basis().scaled(scale).rotated(Vector3.UP, rng.randf_range(-PI, PI))
				# Base on the ground: the source AABB is not centred on its own origin.
				transforms.append(Transform3D(basis, Vector3(x, -source.position.y * scale.y - 0.2, z)))
				z += rng.randf_range(9.0, 17.0)
				placed += 1
		_emit("PerimeterBackdrop", block, transforms)
	if crate != null:
		var source: AABB = crate.get_aabb()
		var transforms: Array[Transform3D] = []
		for side: float in [-1.0, 1.0]:
			for i in 5:
				var x: float = side * (YARD_MAX.x + rng.randf_range(2.5, 7.5))
				var z: float = rng.randf_range(YARD_MIN.y, YARD_MAX.y)
				var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI))
				transforms.append(Transform3D(basis, Vector3(x, -source.position.y, z)))
				placed += 1
		_emit("PerimeterCrates", crate, transforms)
	return placed


## One MultiMeshInstance3D per family: the whole perimeter is a handful of draw calls, and the
## source's own material comes along, so nothing new is instanced.
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
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)
