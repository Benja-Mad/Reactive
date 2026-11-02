## Shared environment finish for the main scene and comparison; collision changes are reversible.
## Original mesh resources are never edited. F6 in the trial swaps the two presentations.
extends Node3D

const PAINT = preload("res://scenes/environment/sector_08/stylized/painted_surface.gdshader")
const DepotYard = preload("res://scenes/environment/sector_08/stylized/depot_yard.gd")
const DepotEdges = preload("res://scenes/environment/sector_08/stylized/depot_edges.gd")
const DepotLighting = preload("res://scenes/environment/sector_08/stylized/depot_lighting.gd")
const COURT := Rect2(-20, -22, 36, 34)
var enabled: bool = false
var changed: Array[Dictionary] = []
var replacements: Array[Node3D] = []
var collision_changes: Array[Dictionary] = []
var replacement_collisions: Array[CollisionShape3D] = []
var atmosphere_changes: Array[Dictionary] = []
var stats: Dictionary = {"surfaces": 0, "details_hidden": 0, "models_rebuilt": 0}
var _paints: Dictionary = {}
var district_lighting: Node3D

func _exit_tree() -> void:
	# Release overrides while the source geometry and original materials still
	# exist. Otherwise destruction can leave queued renderer updates using freed RIDs.
	for item: Dictionary in changed:
		var mesh: GeometryInstance3D = item["node"]
		if is_instance_valid(mesh):
			mesh.material_override = item["original"]

func _paint(color: String, floor_surface: bool = false, low_roof: bool = false, obstacle: bool = false) -> ShaderMaterial:
	var key: String = color + str(floor_surface) + str(low_roof) + str(obstacle)
	if not _paints.has(key):
		var material := ShaderMaterial.new()
		material.shader = PAINT
		material.set_shader_parameter("paint", Color(color))
		material.set_shader_parameter("pavement", floor_surface)
		material.set_shader_parameter("replace_south", floor_surface)
		material.set_shader_parameter("obstacle_readability", obstacle)
		material.set_shader_parameter("roof_cutoff", 5.0 if low_roof else 10000.0)
		material.set_shader_parameter("city_aperture", low_roof)
		_paints[key] = material
	return _paints[key]

func setup(arena: Node3D) -> void:
	assert(changed.is_empty(), "Apply the art trial once per arena")
	for node: Node in arena.sector_runtime.imported_environment.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var title: String = str(mesh.name)
		var path: String = str(arena.get_path_to(mesh))
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		var center: Vector3 = bounds.get_center()
		var in_court: bool = COURT.has_point(Vector2(center.x, center.z))
		var crosses_court: bool = COURT.intersects(Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)))
		var facade: bool = "north_block_ROOT" in path or title.begins_with("north_block_")
		var vent: bool = "OWNER_B02/B02_vents" in path and title.begins_with("Ground_Louvres")
		var wall_along: float = center.x * 0.731354 - center.z * 0.681998
		var opening_vent: bool = "OWNER_B02/B02_vents" in path and wall_along > 3.0 and wall_along < 12.0
		if title.begins_with("Drum_Fire"):
			# Imported fire card renders as an opaque luminous square across the lid.
			_remember(mesh,null,true)
			stats["details_hidden"] += 1
		elif title.begins_with("Stack_") or title.begins_with("Ladder_") or "OWNER_SPINE/SPINE_status_nodes" in path:
			_remember(mesh, null, true)
			stats["details_hidden"] += 1
		elif opening_vent or "bg_block_b_ROOT" in path or title.begins_with("Viaduct_") or (facade and bounds.position.y >= 5.0) or (crosses_court and bounds.position.y > 5.0 and (title.begins_with("Catwalk_") or title.begins_with("Tray_"))):
			_remember(mesh, null, true)
			stats["details_hidden"] += 1
		elif title.begins_with("TrafficCone") or (title.begins_with("Pipe_Bracket") and bounds.position.y < 2.6):
			_remember(mesh, null, true)
			stats["details_hidden"] += 1
		elif _is_inert_scatter(mesh) and not _keep_edge_scatter(center, title):
			_remember(mesh, null, true)
			stats["details_hidden"] += 1
		elif crosses_court and bounds.position.y > 5.0 and center.z > -5.0 and (title.begins_with("Pipe_Seg") or title.begins_with("Pipe_Bracket") or title.begins_with("Pipe_Flange")):
			# The southern overhead pipe bundle cuts across the combat camera; no ground collision.
			_remember(mesh, null, true)
			stats["details_hidden"] += 1
		elif title.begins_with("Drain_Lip") or title.begins_with("Crossing_trench_grate_west_Lip"):
			_remember(mesh, _paint("33464e"))
		elif in_court and title.begins_with("ChainlinkPanel"):
			_rebuild_fence(mesh)
		elif vent:
			_rebuild(mesh, true)
		elif title.begins_with("Crate"):
			_rebuild(mesh, false)
		elif (facade and ("Streak" in title or "RoomProp" in title)) or (crosses_court and bounds.position.y < 12.0 and ("strand" in title or "_Tie" in title)):
			_remember(mesh, null, true)
			stats["details_hidden"] += 1
		elif title.begins_with("Road_Surface") or title.begins_with("Yard_Substrate"):
			_remember(mesh, _paint("45505b", true))
		elif title.begins_with("Yard_Slab") or title.begins_with("Apron"):
			_remember(mesh, _paint("59616a", true))
		elif title.begins_with("Puddle") or title.begins_with("Ground_Damp") or title.begins_with("Ground_Patch") or title.begins_with("Road_Patch"):
			# Decorative reflection planes only; player-created water is a separate system.
			_remember(mesh, null, true)
			stats["details_hidden"] += 1
		elif facade:
			var pale: bool = "Trim" in title or "Lintel" in title or "Pier" in title
			_remember(mesh, _paint("837676" if pale else "55515b", false, true))
		elif title.begins_with("JerseyBarrier"):
			_remember(mesh, _paint("81745b", false, false, true))
		elif title.begins_with("OilDrum"):
			_rebuild_drum(mesh)
		elif title.begins_with("Dumpster") or title.begins_with("Bollard") or title.begins_with("Standpipe"):
			_remember(mesh, _paint("85928c", false, false, true))
	# Apply the same quiet ground finish to the generated extension, including its instanced slabs.
	for node: Node in arena.sector_runtime.perimeter.get_children():
		if node is GeometryInstance3D and str(node.name) in ["PerimeterGroundFill", "Ground_Patch_ExtensionFoundation"]:
			changed.append({"node": node, "original": node.material_override, "visible": node.visible, "paint": _paint("59616a", true), "hide": false})
			stats["surfaces"] += 1
	_replace_service_court(arena)
	# Visibility overrides survive controller-driven light-energy updates and remain reversible.
	for node: Node in arena.find_children("*", "Node3D", true, false):
		if str(node.name) in ["SpineCyan", "SpineAir", "SpineHalo", "SpineAsh", "ReactorCondensate", "ReactorRearVapour"] or str(node.name).begins_with("spine_node_2_shaft"):
			atmosphere_changes.append({"node": node, "visible": node.visible})
	var tower := preload("res://scenes/environment/sector_08/stylized/cooling_landmark.gd").new()
	tower.name = "CoolingLandmark"
	add_child(tower)
	tower.setup()
	replacements.append(tower)
	# Old tank and removed viaduct/vent panels must not leave invisible obstacles.
	for item: Dictionary in changed:
		if not item["hide"]: continue
		var source: Node = item["node"]
		if has_node("Painted_" + str(source.name)): continue
		var collider: CollisionShape3D = arena.sector_runtime.collision.get_node_or_null("Obstacle_" + str(source.name))
		if collider != null:
			collision_changes.append({"node": collider, "disabled": collider.disabled})
	# Convex shells reproduce the new tank's visible lower footprint, not its old silhouette.
	for mesh: MeshInstance3D in tower.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		if bounds.position.y > 2.6: continue
		var body := StaticBody3D.new()
		mesh.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_convex_shape()
		body.add_child(shape)
		replacement_collisions.append(shape)
	_repair_sparse_colliders(arena)
	var district := preload("res://scenes/environment/sector_08/stylized/cyberpunk_depth.gd").new()
	district.name = "CyberpunkDepth"
	add_child(district)
	district.setup()
	replacements.append(district)
	var south := preload("res://scenes/environment/sector_08/stylized/south_transit.gd").new()
	south.name = "SouthTransitArchitecture"
	add_child(south)
	south.setup_district(arena.sector_runtime.collision.YARD_MIN, arena.sector_runtime.collision.YARD_MAX)
	replacements.append(south)
	var ground_lo: Vector2 = arena.sector_runtime.collision.YARD_MIN
	var ground_hi: Vector2 = arena.sector_runtime.collision.YARD_MAX
	for paint_material: ShaderMaterial in _paints.values():
		paint_material.set_shader_parameter("south_bounds", Vector4(ground_lo.x,ground_lo.y,ground_hi.x,ground_hi.y))
	district_lighting = preload("res://scenes/environment/sector_08/stylized/district_lighting.gd").new()
	district_lighting.name = "DistrictLightingComposition"
	add_child(district_lighting)
	district_lighting.setup(arena,self)
	# The depot: Línea 08's night lot. The yard and its edges go first so the light can see them.
	for layer: Array in [["DepotYard", DepotYard], ["DepotEdges", DepotEdges], ["DepotLighting", DepotLighting]]:
		var depot: Node3D = layer[1].new()
		depot.name = layer[0]
		add_child(depot)
		depot.setup(arena, self)
		replacements.append(depot)
	# The visibility helper collected the original yard before these replacement meshes existed.
	# Register only this new subtree, so foreground fences still fade around the operator.
	var sightline: Node = arena.get_parent().get_node_or_null("SurvivorRun/Sightline")
	if sightline != null: sightline.register_environment_extension(self)
	var patrol := preload("res://scenes/environment/sector_08/stylized/aerial_patrol.gd").new()
	patrol.name = "AerialPatrol"
	add_child(patrol)
	patrol.setup(arena)
	replacements.append(patrol)
	set_enabled(true)
	print("ART TRIAL ", JSON.stringify(stats))

## Convex hulls close the empty space under lamp arms and inside open frames.
## Use static triangle collision for these few sparse structures; projections have no solid body.
func _repair_sparse_colliders(arena: Node3D) -> void:
	for mesh: MeshInstance3D in arena.sector_runtime.imported_environment.find_children("*", "MeshInstance3D", true, false):
		var title := str(mesh.name)
		var projection: bool = title.begins_with("Hologram") or "Diagnostic" in title or title == "Barrier_Field" or title.begins_with("District_Plate") or title.begins_with("BladeSign_Face")
		var sparse: bool = title == "Barrier_Frame" or title == "UtilityPole" or title.begins_with("Streetlight") or title.begins_with("Stair_Rail_Rail")
		if not projection and not sparse: continue
		var source: CollisionShape3D = arena.sector_runtime.collision.get_node_or_null("Obstacle_" + title)
		if source == null: continue
		var already_retired: bool = false
		for item: Dictionary in collision_changes:
			if item["node"] == source: already_retired = true
		if not already_retired: collision_changes.append({"node":source,"disabled":source.disabled})
		if not sparse: continue
		var holder := StaticBody3D.new()
		holder.name = "Precise_" + title
		add_child(holder)
		holder.global_transform = mesh.global_transform
		var shape := CollisionShape3D.new()
		if title == "Barrier_Frame":
			# The low threshold is walk-over trim, like the yard's kerbs; it must not snag feet.
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			var kept := PackedVector3Array()
			for i: int in range(0, faces.size(), 3):
				if maxf(faces[i].y, maxf(faces[i+1].y, faces[i+2].y)) < 0.45: continue
				kept.append_array(PackedVector3Array([faces[i],faces[i+1],faces[i+2]]))
			var precise := ConcavePolygonShape3D.new()
			precise.set_faces(kept)
			shape.shape = precise
		else:
			shape.shape = mesh.mesh.create_trimesh_shape()
		holder.add_child(shape)
		replacement_collisions.append(shape)
	# Low planter rims keep their exact shapes but gain the same readable finish as other cover.
	var court: Node = arena.find_child("SouthRainCourt", true, false)
	if court != null:
		for mesh: MeshInstance3D in court.find_children("*", "MeshInstance3D", true, false):
			if mesh.get_parent() is StaticBody3D and str(mesh.name) in ["North","South","West","East"]:
				var center: Vector3 = (mesh.global_transform * mesh.get_aabb()).get_center()
				var near_transit: bool = Vector2(center.x-12.0,center.z-16.0).length() < 14.0
				_remember(mesh, _paint("6d807b" if near_transit else "89968e", false, false, true))

## Keep wear in a few edge pockets, leaving the circulation surface quiet.
func _keep_edge_scatter(center: Vector3, title: String) -> bool:
	for pocket: Vector2 in [Vector2(-23, -7), Vector2(15, -19), Vector2(20, 9)]:
		if Vector2(center.x, center.z).distance_to(pocket) < 3.5:
			return title.hash() % 3 == 0
	return false

func _replace_service_court(arena: Node3D) -> void:
	var court: Node = arena.find_child("ContainmentCourt", true, false)
	if court == null: return
	# Retire the complete block assembly, including its solid cores; hiding meshes alone leaves ghosts.
	for mesh: MeshInstance3D in court.find_children("*", "MeshInstance3D", true, false):
		_remember(mesh, null, true)
		stats["details_hidden"] += 1
	for shape: CollisionShape3D in court.find_children("*", "CollisionShape3D", true, false):
		collision_changes.append({"node":shape,"disabled":shape.disabled})
	var furniture := preload("res://scenes/environment/sector_08/stylized/service_architecture.gd").new()
	furniture.name = "DistrictServiceArchitecture"
	add_child(furniture)
	furniture.setup()
	replacements.append(furniture)
	replacement_collisions.append_array(furniture.shapes)

func _is_inert_scatter(mesh: MeshInstance3D) -> bool:
	var title: String = str(mesh.name)
	if not (title.begins_with("Weeds") or title.begins_with("Moss") or title.begins_with("Yard_Fragment")): return false
	for key: String in ["cs_hazard", "cs_states", "cs_fx", "cs_prog", "cs_local_u", "cs_group"]:
		if mesh.has_meta(key): return false
	return str(mesh.get_meta("cs_system", "")) == "bio" or (mesh.global_transform * mesh.get_aabb()).size.y < 0.4

func _remember(mesh: MeshInstance3D, material: Material, hide_piece: bool = false) -> void:
	changed.append({"node": mesh, "original": mesh.material_override, "visible": mesh.visible, "paint": material, "hide": hide_piece})
	if material != null: stats["surfaces"] += 1

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	part.mesh = shape
	part.position = at
	part.material_override = material
	parent.add_child(part)

## Replace the complete imported prop, including any geometry baked into its mesh.
## Keep the original transform and envelope so the existing obstacle stays aligned.
func _rebuild_drum(source: MeshInstance3D) -> void:
	if (source.global_transform * source.get_aabb()).position.y > 2.0:
		_remember(source,null,true)
		stats["details_hidden"] += 1
		return
	var holder := Node3D.new()
	holder.name = "Painted_" + str(source.name)
	add_child(holder)
	holder.global_transform = source.global_transform
	var bounds := source.get_aabb()
	var center := bounds.get_center()
	var radius: float = minf(bounds.size.x,bounds.size.z)*0.48
	for part: int in 4:
		var cylinder := CylinderMesh.new()
		cylinder.radial_segments = 12
		cylinder.rings = 1
		cylinder.top_radius = radius * (0.90 if part == 3 else 1.0)
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = bounds.size.y * (0.91 if part == 0 else 0.045)
		var mesh := MeshInstance3D.new()
		mesh.name = ["DrumBody","LowerHoop","UpperHoop","InsetLid"][part]
		mesh.mesh = cylinder
		mesh.position = center
		if part > 0: mesh.position.y += bounds.size.y * [-0.35,0.34,0.465][part-1]
		mesh.material_override = _paint("879389" if part == 0 else ("b8a98b" if part < 3 else "39464a"),false,false,true)
		holder.add_child(mesh)
	# Small flush bung on the lid; no rectangular slab crossing the body.
	var bung := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.radial_segments = 8
	cap.top_radius = radius*0.14
	cap.bottom_radius = cap.top_radius
	cap.height = bounds.size.y*0.025
	bung.mesh = cap
	bung.position = center + Vector3(radius*0.45,bounds.size.y*0.49,0)
	bung.material_override = _paint("a49b83")
	holder.add_child(bung)
	replacements.append(holder)
	_remember(source,null,true)
	stats["models_rebuilt"] += 1

func _rebuild(source: MeshInstance3D, vent: bool) -> void:
	var holder := Node3D.new()
	holder.name = "Painted_" + str(source.name)
	add_child(holder)
	holder.global_transform = source.global_transform
	var bounds: AABB = source.get_aabb()
	var c: Vector3 = bounds.get_center()
	var s: Vector3 = bounds.size
	if vent:
		# Four chunky louvers replace dozens of fine fins, in the same authored envelope.
		var depth: int = 0 if s.x < s.z else 2
		var width: int = 2 if depth == 0 else 0
		var back: Vector3 = s
		back[depth] *= 0.35
		_box(holder, c, back, _paint("25383f"))
		for i: int in 4:
			var at: Vector3 = c
			at.y += s.y * (-0.36 + i * 0.24)
			var fin: Vector3 = s
			fin.y *= 0.10
			fin[width] *= 0.92
			_box(holder, at, fin, _paint("738184"))
	else:
		_box(holder, c, s * Vector3(0.94, 0.88, 0.94), _paint("87958a", false, false, true))
		for y: float in [-0.42, 0.42]:
			_box(holder, c + Vector3(0, s.y * y, 0), s * Vector3(1, 0.16, 1), _paint("303f43"))
		for x: float in [-0.35, 0.35]:
			_box(holder, c + Vector3(s.x * x, 0, 0), s * Vector3(0.10, 0.78, 1.01), _paint("a69a78"))
	_remember(source, null, true)
	replacements.append(holder)
	stats["models_rebuilt"] += 1

## Broad openings remain readable at gameplay scale; keep the original panel envelope.
func _rebuild_fence(source: MeshInstance3D) -> void:
	var holder := Node3D.new()
	holder.name = "Painted_" + str(source.name)
	add_child(holder)
	holder.global_transform = source.global_transform
	var bounds: AABB = source.get_aabb()
	var c: Vector3 = bounds.get_center()
	var width: float = bounds.size.x
	var height: float = bounds.size.y
	var steel: Material = _paint("384c53")
	var edge: Material = _paint("617474")
	# Slim original mesh depth may include bent wire; use a consistent fabricated frame.
	for x: float in [-0.48, 0.48]:
		_box(holder, c + Vector3(width * x, 0, 0), Vector3(0.10, height, 0.10), edge)
		_box(holder, c + Vector3(width * x, height * 0.32, -0.065), Vector3(0.11, 0.22, 0.035), _paint("ad9561"))
	for y: float in [-0.47, 0.47]:
		_box(holder, c + Vector3(0, height * y, 0), Vector3(width, 0.09, 0.09), edge)
	# A narrow bottom rail leaves the mesh visible down to the ground.
	_box(holder, c + Vector3(0, -height * 0.44, 0), Vector3(width * 0.94, 0.12, 0.07), steel)
	# One combined mesh: open diamonds, not a screen of subpixel wires or hundreds of nodes.
	var weave := SurfaceTool.new()
	weave.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w: float = width * 0.46
	var half_h: float = height * 0.43
	var slope: float = 1.30
	var spacing: float = 0.55
	var rows: int = ceili((half_h + slope * half_w) / spacing)
	var seed: float = float(str(source.name).hash() % 97) * 0.13
	for direction: float in [-1.0, 1.0]:
		var m: float = slope * direction
		for row: int in range(-rows, rows + 1):
			var intercept: float = row * spacing
			var x0: float = maxf(-half_w, minf((-half_h - intercept) / m, (half_h - intercept) / m))
			var x1: float = minf(half_w, maxf((-half_h - intercept) / m, (half_h - intercept) / m))
			if x1 - x0 < 0.025: continue
			var first := Vector3(x0, m * x0 + intercept, 0)
			var last := Vector3(x1, m * x1 + intercept, 0)
			var middle: Vector3 = first.lerp(last, 0.5)
			# Small deterministic dents retain the worn-yard character without torn collision gaps.
			middle.z = sin(seed + row * 1.7) * 0.045
			middle.y -= 0.025 * (0.5 + 0.5 * sin(seed + row))
			_wire_prism(weave, c + first, c + middle, 0.032)
			_wire_prism(weave, c + middle, c + last, 0.032)
	weave.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "OpenDiamondWeave"
	mesh.mesh = weave.commit()
	mesh.material_override = _paint("6a7c79")
	holder.add_child(mesh)
	_remember(source, null, true)
	replacements.append(holder)
	stats["models_rebuilt"] += 1

## Four-sided wire with real depth, sharing one draw surface per panel.
func _wire_prism(surface: SurfaceTool, start: Vector3, finish: Vector3, thickness: float) -> void:
	var along: Vector3 = (finish - start).normalized()
	var across: Vector3 = along.cross(Vector3.FORWARD).normalized() * thickness * 0.5
	var depth: Vector3 = along.cross(across).normalized() * thickness * 0.5
	var offsets: Array[Vector3] = [across + depth, -across + depth, -across - depth, across - depth]
	for side: int in 4:
		var next: int = (side + 1) % 4
		for vertex: Vector3 in [start + offsets[side], finish + offsets[side], start + offsets[next], start + offsets[next], finish + offsets[side], finish + offsets[next]]:
			surface.add_vertex(vertex)

func set_enabled(value: bool) -> void:
	enabled = value
	if district_lighting != null: district_lighting.set_enabled(value)
	for item: Dictionary in changed:
		var mesh: GeometryInstance3D = item["node"]
		mesh.material_override = item["paint"] if enabled and item["paint"] != null else item["original"]
		mesh.visible = item["visible"] and not (enabled and item["hide"])
	for item: Dictionary in atmosphere_changes:
		item["node"].visible = false if enabled else item["visible"]
	for item: Dictionary in collision_changes:
		item["node"].disabled = true if enabled else item["disabled"]
	for shape: CollisionShape3D in replacement_collisions: shape.disabled = not enabled
	for replacement: Node3D in replacements: replacement.visible = enabled
