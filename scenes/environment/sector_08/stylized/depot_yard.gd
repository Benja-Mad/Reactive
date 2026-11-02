## The depot's play area: purposeful clusters, fixtures for every material store, the ground's history.
## Built last over the district trial; everything it adds or hides is undone by clear().
##
## Encierro y Taller, Línea 08, the night the seals were stolen. What the floor says, west to east:
## the sereno's warming drum by the taller with his chair, thermos and the quiltros' empty bed; the
## taller's bay (tyres, an engine block on the only pallets in the yard, chained gas cylinders, an
## oil fan); the wash bay with its burst cistern; the concrete pole the gárgola snapped, its live
## transformer lying in the road cordoned off with the yard's Jersey barriers; the substation
## cabinet by the fence with its door torn off and the seal plate; the scrap the mechanics piled
## against the light mast; numbered bays on the east; the desarmadero with a bus stripped for
## parts. Everything stands in clusters that touch and lean, on a floor with history (see
## depot_yard_ground.gdshader). The even scatter it replaces is hidden through the trial's own
## lists, colliders included, so F6 still swaps the presentations.
extends Node3D

const Kit = preload("res://scenes/environment/sector_08/stylized/depot_yard_kit.gd")
const GROUND = preload("res://scenes/environment/sector_08/stylized/depot_yard_ground.gdshader")
const PAINT = preload("res://scenes/environment/sector_08/stylized/depot_yard_paint.gdshader")
const FONT_PATH := "res://ui/kit/font.fnt"
const AU := Kit.AU
const AV := Kit.AV
## The north fence line (yard v); the painted floor stops there and the street beyond is the edge's.
const FENCE_V := -18.3
## The floor the depot paints, in world x/z: the whole walkable yard south of the fence.
const FLOOR_RECT := Rect2(-34.0, -26.0, 68.0, 54.0)
const FLOOR_Y := 0.062
## The one north-south bus lane (yard u of its centre, half width, last yard v): in through the
## vehicle gate (depot_edges.gd GATE_A, u 6.7..13.3) and down to the apron in front of the bays,
## passing the light mast (u 9.65) on its west line the way masts stand beside lanes.
const LANE_U := 11.75
const LANE_HALF := 1.5
const LANE_END_V := 3.0
## The bays under depot_edges.gd's micros (nose-in at edge a 23.6..25.6, b 2.6..-6.6, 10.4 m long):
## yard u from..to, first line v, pitch, count. Bay 01 is empty: its micro is out on the road.
const BAYS := Vector4(18.0, 31.5, -11.15, 4.6)
const BAY_COUNT := 4
## The wet asphalt apron the micros reverse out onto (u from..to, v from..to): east of the lane,
## from the first bay line to the kerb.
const APRON := Vector4(13.6, 33.0, -12.6, 7.5)
## The canaleta's centre line (yard v): it takes the line the old data trench drew across the yard.
const CANAL_V := -4.6
## The substation cabinet (yard u, v): against the fence west of the pedestrian door (u 0.5..3.9),
## so the door stays open; 6 m off the keep-clear point (-7,-9), 4.9 m from the guts it fed.
const CABINET_UV := Vector2(-2.5, -17.6)

# Palette: muted rust, zinc, ochre, concrete. Nothing here may read as a UI signal.
const CONCRETE := Color("7c7a73")
const CONCRETE_DARK := Color("5d5c57")
const ZINC := Color("6f7a7c")
const ZINC_DARK := Color("464f52")
const RUST := Color("6a4330")
const RUST_DARK := Color("3f2b22")
const IRON := Color("2e2c2a")
const RUBBER := Color("343538")
## A tyre's worn sidewall, the lighter ring that keeps a black tyre from reading as a hole.
const RUBBER_WALL := Color("5a5b5f")
const OCHRE := Color("8c7a4a")
const CREAM := Color("a8a290")
const CARDBOARD := Color("7a6449")
const BLANKET := Color("4c4f5c")
const PLASTIC_GREEN := Color("4f5f4c")
const PLASTIC_BLUE := Color("4a5866")
const WOOD := Color("6d5a43")
const SEAT_RED := Color("5e3a36")
const CYLINDER_GREY := Color("6c726e")
const PAINT_TEXT := Color(0.5, 0.5, 0.47, 0.42)

var trial: Node3D
var arena: Node3D
var material: ShaderMaterial
var ground: MeshInstance3D
var _font: Font
## What this pass retired that the trial does not toggle on its own (restored by clear()).
var _held: Array[Node3D] = []
var _held_shapes: Array[CollisionShape3D] = []

func setup(owner_arena: Node, owner_trial: Node3D) -> void:
	arena = owner_arena as Node3D
	trial = owner_trial
	material = ShaderMaterial.new()
	material.shader = PAINT
	_font = load(FONT_PATH)
	depot_yard_retire()
	depot_yard_ground()
	depot_yard_clusters()

## Undo what setup did outside the trial's lists; the trial's own toggles handle the rest.
func clear() -> void:
	for node: Node3D in _held:
		if is_instance_valid(node): node.visible = true
	for shape: CollisionShape3D in _held_shapes:
		if is_instance_valid(shape):
			shape.disabled = false
			if not trial.replacement_collisions.has(shape): trial.replacement_collisions.append(shape)
	_held.clear()
	_held_shapes.clear()
	for child: Node in get_children(): child.queue_free()

# --- Yard frame -----------------------------------------------------------------------------

static func yard_of(world: Vector3) -> Vector2:
	return Vector2(world.x * AU.x + world.z * AU.z, world.x * AV.x + world.z * AV.z)

static func at(u: float, v: float, y: float = 0.0) -> Vector3:
	return Kit.at(u, v, y)

static func xf(u: float, v: float, y: float = 0.0, yaw: float = 0.0, tip_x: float = 0.0, tip_z: float = 0.0) -> Transform3D:
	return Transform3D(Kit.turn(yaw, tip_x, tip_z), Kit.at(u, v, y))

# --- Retiring the even scatter ---------------------------------------------------------------

## Hide a piece through the trial's own list (every entry for it), and retire its obstacle.
func depot_yard_hide(mesh: GeometryInstance3D) -> void:
	var found: bool = false
	for item: Dictionary in trial.changed:
		if item["node"] == mesh:
			item["hide"] = true
			found = true
	if not found:
		trial.changed.append({"node": mesh, "original": mesh.material_override, "visible": mesh.visible, "paint": null, "hide": true})
	var collider: CollisionShape3D = arena.sector_runtime.collision.get_node_or_null("Obstacle_" + str(mesh.name))
	if collider != null: depot_yard_retire_shape(collider)

func depot_yard_retire_shape(shape: CollisionShape3D) -> void:
	for item: Dictionary in trial.collision_changes:
		if item["node"] == shape: return
	trial.collision_changes.append({"node": shape, "disabled": shape.disabled})

## A trial replacement (already toggled with the presentation) that this pass takes out: it
## leaves the trial's list and stays hidden, and so do its precise colliders.
func depot_yard_hold(node: Node3D) -> void:
	trial.replacements.erase(node)
	node.visible = false
	_held.append(node)

func depot_yard_hold_shape(shape: CollisionShape3D) -> void:
	trial.replacement_collisions.erase(shape)
	shape.disabled = true
	_held_shapes.append(shape)

func depot_yard_on_floor(world: Vector3) -> bool:
	return FLOOR_RECT.has_point(Vector2(world.x, world.z)) and yard_of(world).y > FENCE_V

func depot_yard_retire() -> void:
	var imported: Node = arena.sector_runtime.imported_environment
	# The trial takes the southern overhead pipe run out of the combat view but leaves its brackets
	# and flanges hanging in the air: from the camera they read as a row of black drips. They go
	# with the pipe they held.
	var hidden_pipes: Array[AABB] = []
	for item: Dictionary in trial.changed:
		var piece: Node = item["node"]
		if item.get("hide", false) and piece is MeshInstance3D and str(piece.name).begins_with("Pipe_Seg"):
			hidden_pipes.append(((piece as MeshInstance3D).global_transform * (piece as MeshInstance3D).get_aabb()).grow(0.8))
	for node: Node in imported.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		var title := str(mesh.name)
		var centre: Vector3 = (mesh.global_transform * mesh.get_aabb()).get_center()
		if title.begins_with("Pipe_Bracket") or title.begins_with("Pipe_Flange") or title.begins_with("Pipe_Elbow") or title.begins_with("Pipe_HeatSeam"):
			for run: AABB in hidden_pipes:
				if run.has_point(centre):
					depot_yard_hide(mesh)
					break
			continue
		if not depot_yard_on_floor(centre): continue
		var retire: bool = false
		# The two teal lines across the yard: the data trench (ducts, junction LEDs, slot glass) and its crossings.
		if title.begins_with("Trench_Data") or title.begins_with("Crossing_trench_grate"): retire = true
		# Stray discs and flush drains the canaleta replaces; road dashes, chevrons and the mid-yard stop's stripes.
		elif title.begins_with("Manhole") or title.begins_with("Drain_") or title.begins_with("Ground_Marking") or title.begins_with("Road_Paint") or title.begins_with("HazardZone"): retire = true
		# Lone props spaced like scatter; the Jerseys and one pallet come back as purposeful pieces.
		elif title.begins_with("JerseyBarrier") or title.begins_with("PalletStack"): retire = true
		# The near foreground: lamp posts, the gantry legs, the utility pole, the voxel trees, and the
		# transformer that looked like a store but was not one.
		elif title.begins_with("Streetlight") or title.begins_with("FG_GantryLeg") or title == "UtilityPole" or title.begins_with("Tree_") or title.begins_with("Transformer"): retire = true
		# The «C/S TRANSIT» frame: a bus stop with no street, planted mid-yard.
		elif title == "Barrier_Frame": retire = true
		# The old south fence line (yard v 13.4) across the near strip: its posts read as a row of
		# black drips over the fight and it fenced nothing (gaps either side). The low strip stays low.
		elif title.begins_with("ChainlinkPanel") and absf(yard_of(centre).y - 13.4) < 1.2: retire = true
		if retire: depot_yard_hide(mesh)
	# The frame's display panel is built by the lookdev; hide it the same reversible way.
	if arena.get("access_display") != null:
		trial.atmosphere_changes.append({"node": arena.access_display, "visible": arena.access_display.visible})
	# Precise colliders the trial built for retired sparse structures go with them.
	for shape: CollisionShape3D in trial.replacement_collisions.duplicate():
		var holder: Node = shape.get_parent()
		var title := str(holder.name)
		if not title.begins_with("Precise_"): continue
		var source := title.trim_prefix("Precise_")
		var fence: bool = source.begins_with("ChainlinkPanel") and absf(yard_of((holder as Node3D).global_position).y - 13.4) < 1.6
		if source == "Barrier_Frame" or source.begins_with("Streetlight") or source == "UtilityPole" or fence:
			if depot_yard_on_floor((holder as Node3D).global_position): depot_yard_hold_shape(shape)
	# The trial's rebuilt crates and pale drums were the same scatter: retire them and their obstacles.
	for child: Node in trial.get_children():
		var title := str(child.name)
		var south_fence: bool = title.begins_with("Painted_ChainlinkPanel") and absf(yard_of((child as Node3D).global_position).y - 13.4) < 1.6
		if not (title.begins_with("Painted_Crate") or title.begins_with("Painted_OilDrum") or south_fence): continue
		if not depot_yard_on_floor((child as Node3D).global_position): continue
		depot_yard_hold(child as Node3D)
		var collider: CollisionShape3D = arena.sector_runtime.collision.get_node_or_null("Obstacle_" + title.trim_prefix("Painted_"))
		if collider != null: depot_yard_retire_shape(collider)
	# The south court's garden planters, drain bed and light post: generic kit, and the post stands in the low strip.
	var court: Node = arena.find_child("SouthRainCourt", true, false)
	if court != null:
		for node: Node in court.find_children("*", "GeometryInstance3D", true, false):
			depot_yard_hide(node as GeometryInstance3D)
		for shape: Node in court.find_children("*", "CollisionShape3D", true, false):
			depot_yard_retire_shape(shape as CollisionShape3D)
		for light: Node in court.find_children("*", "Light3D", true, false):
			trial.atmosphere_changes.append({"node": light, "visible": (light as Node3D).visible})
	# The yard polish's flush paint and drain pieces on the floor would show through as old marks.
	var polish: Node = arena.find_child("YardPolish", true, false)
	if polish != null:
		for node: Node in polish.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			if box.end.y < 0.3 and depot_yard_on_floor(box.get_center()): depot_yard_hide(mesh)

# --- The floor -------------------------------------------------------------------------------

## One painted plane over the walkable yard south of the fence, just above the collision floor:
## the slab lattice, stray dashes, chevrons and discs all go under it.
func depot_yard_ground() -> void:
	var rect := PackedVector2Array([FLOOR_RECT.position, Vector2(FLOOR_RECT.end.x, FLOOR_RECT.position.y), FLOOR_RECT.end, Vector2(FLOOR_RECT.position.x, FLOOR_RECT.end.y)])
	# Everything south of the fence line v = FENCE_V, as a big quad in x/z.
	var far: float = 400.0
	var along := Vector2(AU.x, AU.z)
	var down := Vector2(AV.x, AV.z)
	var origin: Vector2 = down * FENCE_V
	var south := PackedVector2Array([origin - along * far, origin + along * far, origin + along * far + down * far, origin - along * far + down * far])
	var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(rect, south)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	for polygon: PackedVector2Array in clipped:
		var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		for i: int in range(0, triangles.size(), 3):
			var corners: Array[Vector3] = []
			for k: int in 3:
				var p: Vector2 = polygon[triangles[i + k]]
				corners.append(Vector3(p.x, FLOOR_Y, p.y))
			# Godot's front faces wind clockwise seen from the side they face: from above here.
			if (corners[1] - corners[0]).cross(corners[2] - corners[0]).y > 0.0: corners.reverse()
			for corner: Vector3 in corners: surface.add_vertex(corner)
	var paint := ShaderMaterial.new()
	paint.shader = GROUND
	paint.set_shader_parameter("lane", Vector3(LANE_U, LANE_HALF, 0.0))
	paint.set_shader_parameter("lane_v", Vector2(FENCE_V, LANE_END_V))
	paint.set_shader_parameter("canal", Vector4(CANAL_V, -19.5, BAYS.x - 0.4, 0.24))
	paint.set_shader_parameter("apron", APRON)
	paint.set_shader_parameter("bays", BAYS)
	paint.set_shader_parameter("bay_count", BAY_COUNT)
	var spots: Array[Vector4] = depot_yard_spots()
	var packed: Array = []
	for s: Vector4 in spots: packed.append(s)
	while packed.size() < 40: packed.append(Vector4.ZERO)
	paint.set_shader_parameter("spots", packed)
	paint.set_shader_parameter("spot_count", mini(spots.size(), 40))
	ground = MeshInstance3D.new()
	ground.name = "DepotFloor"
	ground.mesh = surface.commit()
	ground.material_override = paint
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# Floor lettering in the crew's pixel font: lane, bays. Paint, not light.
	depot_yard_floor_text("SOLO MICROS", LANE_U, -9.2, 0.05)
	for i: int in BAY_COUNT:
		depot_yard_floor_text("%02d" % (i + 1), BAYS.x + 0.9, BAYS.z + BAYS.w * (i + 0.5), 0.06)

## Residue and history on the floor, in yard (u, v, radius, kind); see depot_yard_ground.gdshader.
func depot_yard_spots() -> Array[Vector4]:
	var s: Array[Vector4] = []
	# Fire: the drums people lit leave char rings.
	s.append(Vector4(-15.76, -3.55, 1.25, 0))
	s.append(Vector4(5.72, 7.57, 1.2, 0))
	# Water: every source spreads a wet fan that runs off toward the canaleta.
	for p: Vector2 in [Vector2(-5.43, -5.79), Vector2(-11.74, -12.93), Vector2(16.48, 1.62), Vector2(-20.03, 4.43), Vector2(-6.92, 18.9), Vector2(7.88, 21.19)]:
		s.append(Vector4(p.x, p.y, 2.6, 1))
	# Current: scorch under the fallen transformer and under the torn cabinet guts; a drag scar between them and the cabinet.
	s.append(Vector4(-8.45, 8.76, 1.9, 2))
	s.append(Vector4(0.46, -13.03, 1.5, 2))
	s.append(Vector4(-1.1, -15.4, 0.7, 2))
	# Scrap: rust bleed under each heap, and the trail it was dragged along from the mast pile.
	s.append(Vector4(5.3, -2.42, 2.6, 3))
	s.append(Vector4(4.59, 28.64, 3.0, 3))
	s.append(Vector4(7.55, -7.6, 1.6, 3))
	for t: float in [0.25, 0.5, 0.75]:
		var p: Vector2 = Vector2(7.4, -6.6).lerp(Vector2(5.8, -3.3), t)
		s.append(Vector4(p.x, p.y, 0.55, 3))
	# Oil: the taller's engine block, the desarmadero's stripped bus.
	var engine: Vector2 = yard_of(Vector3(-21.3, 0, 0.4))
	s.append(Vector4(engine.x + 1.2, engine.y + 0.4, 1.7, 4))
	s.append(Vector4(11.6, 29.0, 1.6, 4))
	# Where the pole came down: the impact patch at its stub and where its head hit the road.
	s.append(Vector4(-10.5, 11.7, 2.4, 5))
	s.append(Vector4(-15.6, 12.3, 1.9, 5))
	# Low spots against the kerb where rain sits (the canaleta's own damp is drawn with it).
	for p: Vector3 in [Vector3(-1.8, 7.2, 1.4)]:
		s.append(Vector4(p.x, p.y, p.z, 6))
	# The wash pad under the burst cistern.
	s.append(Vector4(-20.6, 4.9, 4.6, 7))
	return s

func depot_yard_floor_text(text: String, u: float, v: float, pixel: float) -> void:
	var label := Label3D.new()
	label.name = "Floor_" + text.replace(" ", "_")
	label.text = text
	label.font = _font
	label.font_size = 12
	label.outline_size = 0
	label.pixel_size = pixel
	# Worn paint, pre-mixed with the concrete so it can be opaque: an opaque (alpha-cut) label is
	# drawn in the floor's pass and depth-tested, so dogs and operators stand over it, never under.
	label.modulate = Color(PAINT_TEXT.r, PAINT_TEXT.g, PAINT_TEXT.b).lerp(Color(0.3, 0.32, 0.34), 0.72)
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Lying flat, reading left to right on screen, its top toward the gate; stretched along the
	# camera's view like real road lettering so it does not look squashed at the 38° pitch.
	label.transform = Transform3D(Basis(AU, -AV * 1.6, Vector3.UP), at(u, v, FLOOR_Y - Kit.FLOOR + 0.006))
	add_child(label)

## Upright lettering on a fixture (seal plates, warning signs), facing the camera's side.
func depot_yard_sign(text: String, where: Transform3D, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 12
	label.outline_size = 0
	label.pixel_size = pixel
	label.modulate = color
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.transform = where
	add_child(label)
	return label

# --- Clusters --------------------------------------------------------------------------------

func depot_yard_clusters() -> void:
	depot_yard_commit(depot_yard_sereno_post(), "SerenoPost")
	depot_yard_commit(depot_yard_taller_bay(), "TallerBay")
	depot_yard_commit(depot_yard_wash_bay(), "WashBay")
	depot_yard_commit(depot_yard_fallen_pole(), "FallenPole")
	depot_yard_commit(depot_yard_substation(), "Substation")
	depot_yard_commit(depot_yard_mast_scrap(), "MastScrap")
	depot_yard_commit(depot_yard_desarmadero(), "Desarmadero")
	depot_yard_commit(depot_yard_tank_stand(), "TankStand")

func depot_yard_commit(kit: Kit, title: String) -> void:
	var shapes: Array[CollisionShape3D] = kit.commit(self, title, material)
	trial.replacement_collisions.append_array(shapes)

## A tyre lying flat (or on its tread when `standing`), as a ring of rubber with a dark hub.
func depot_yard_tyre(kit: Kit, where: Transform3D, standing: bool = false) -> void:
	var tread: Basis = Basis(Vector3.RIGHT, PI * 0.5) if standing else Basis()
	kit.torus(Transform3D(where.basis * tread, where.origin), 0.22, 0.46, RUBBER)
	# The sidewall facing up (or out): a worn grey ring just proud of the tread.
	kit.torus(Transform3D(where.basis * tread, where.origin + (where.basis * tread).y * 0.075), 0.25, 0.4, RUBBER_WALL)

## The sereno's warming post at the west drum (fire store (-15, 6)): a plastic chair turned to the
## fire, a thermos and a radio on an upturned crate, the corrugated sheet he props up against the
## wind, two bins, and the quiltros' bed of cardboard and blanket with its two bowls -- empty.
func depot_yard_sereno_post() -> Kit:
	var kit := Kit.new()
	var drum := Vector2(-15.76, -3.55)
	# Chair: seat, back, four legs; turned toward the drum.
	var chair: Transform3D = xf(drum.x + 1.55, drum.y + 1.75, 0.0, 38.0)
	for leg: Vector2 in [Vector2(-0.2, -0.2), Vector2(0.2, -0.2), Vector2(0.2, 0.2), Vector2(-0.2, 0.2)]:
		kit.box(chair * Transform3D(Basis(), Vector3(leg.x, 0.22, leg.y)), Vector3(0.04, 0.44, 0.04), PLASTIC_BLUE.darkened(0.1))
	kit.solid_box(chair * Transform3D(Basis(), Vector3(0, 0.45, 0.05)), Vector3(0.5, 0.9, 0.55))
	kit.box(chair * Transform3D(Basis(), Vector3(0, 0.47, 0)), Vector3(0.48, 0.05, 0.46), PLASTIC_BLUE.lightened(0.08))
	kit.box(chair * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-12), 0, 0)), Vector3(0, 0.72, 0.23)), Vector3(0.48, 0.42, 0.05), PLASTIC_BLUE.lightened(0.05))
	# A jacket hung over the back.
	kit.box(chair * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-12), 0, 0)), Vector3(0.04, 0.78, 0.27)), Vector3(0.36, 0.3, 0.06), Color("3b3a36"))
	# Upturned crate as a side table, thermos and radio on it.
	var table: Transform3D = xf(drum.x + 0.75, drum.y + 1.45, 0.0, 12.0)
	kit.box(table * Transform3D(Basis(), Vector3(0, 0.17, 0)), Vector3(0.42, 0.34, 0.32), PLASTIC_GREEN)
	kit.cylinder(table * Transform3D(Basis(), Vector3(-0.1, 0.46, 0.02)), 0.045, 0.05, 0.24, Color("7b2f2a"))
	kit.cylinder(table * Transform3D(Basis(), Vector3(-0.1, 0.6, 0.02)), 0.05, 0.05, 0.05, Color("2d2d2d"))
	kit.box(table * Transform3D(Basis(), Vector3(0.09, 0.42, -0.02)), Vector3(0.2, 0.13, 0.08), Color("343a3a"))
	# The radio's dial: a pinpoint of warm tungsten light (alpha < 1 glows).
	kit.box(table * Transform3D(Basis(), Vector3(0.12, 0.43, 0.043)), Vector3(0.05, 0.03, 0.01), Color(0.83, 0.69, 0.51, 0.9))
	# Windbreak: a galvanised corrugated sheet, one rusted rib, leaning on two bricks behind the chair -- the tall piece.
	var sheet: Transform3D = xf(drum.x + 2.6, drum.y + 2.65, 0.0, 38.0)
	for i: int in 6:
		kit.box(sheet * Transform3D(Basis.from_euler(Vector3(deg_to_rad(16), 0, 0)), Vector3(-0.55 + i * 0.22, 0.8, 0.0)), Vector3(0.13, 1.6, 0.03), (ZINC if i % 2 == 0 else ZINC_DARK) if i != 4 else RUST)
	kit.solid_box(sheet * Transform3D(Basis(), Vector3(0, 0.78, -0.2)), Vector3(1.3, 1.56, 0.4))
	# Two bins against the windbreak, one lid off and lying on the floor.
	var bins: Transform3D = xf(drum.x + 0.2, drum.y + 3.3, 0.0, -10.0)
	kit.cylinder(bins * Transform3D(Basis(), Vector3(-0.35, 0.44, 0)), 0.3, 0.27, 0.88, ZINC, true)
	kit.cylinder(bins * Transform3D(Basis(), Vector3(-0.35, 0.9, 0)), 0.32, 0.32, 0.05, ZINC_DARK)
	kit.cylinder(bins * Transform3D(Basis(), Vector3(0.33, 0.44, 0.08)), 0.3, 0.27, 0.88, ZINC.darkened(0.12), true)
	kit.cylinder(bins * Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(84))), Vector3(0.95, 0.3, 0.25)), 0.32, 0.32, 0.05, ZINC_DARK)
	kit.box(bins * Transform3D(Basis(), Vector3(0.36, 0.95, 0.1)), Vector3(0.3, 0.18, 0.22), Color("2f3230"))
	# The quiltros' bed: flattened cardboard, a balled blanket, two bowls (one tipped).
	var bed: Transform3D = xf(drum.x - 2.1, drum.y + 1.6, 0.0, -24.0)
	kit.box(bed * Transform3D(Basis(), Vector3(0, 0.015, 0)), Vector3(1.1, 0.03, 0.8), CARDBOARD)
	kit.box(bed * Transform3D(Basis.from_euler(Vector3(0, 0.3, 0)), Vector3(0.1, 0.07, 0.05)), Vector3(0.7, 0.11, 0.5), BLANKET)
	kit.box(bed * Transform3D(Basis.from_euler(Vector3(0.2, -0.4, 0.15)), Vector3(-0.2, 0.12, -0.1)), Vector3(0.4, 0.1, 0.35), BLANKET.darkened(0.15))
	kit.cylinder(bed * Transform3D(Basis(), Vector3(0.75, 0.03, -0.35)), 0.13, 0.1, 0.06, Color("6f6a5e"))
	kit.cylinder(bed * Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(70))), Vector3(0.95, 0.09, 0.1)), 0.13, 0.1, 0.06, Color("7a5246"))
	return kit

## The taller's bay in front of the west facade: tyres stacked and leaning, the engine block on the
## yard's only pallets, gas cylinders chained upright against the wall (the tall piece), a parts
## bin. Its oil fans out toward the yard (ground spots).
func depot_yard_taller_bay() -> Kit:
	var kit := Kit.new()
	var wall := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	# Tyre stacks: four, three, and two leaning on the stack.
	for stack: Array in [[Vector3(-22.6, 0, -2.4), 4], [Vector3(-21.75, 0, -3.15), 3]]:
		var base: Vector3 = stack[0] + Vector3.UP * Kit.FLOOR
		for i: int in stack[1]:
			var jitter := Vector3(0.03 * sin(i * 2.1), 0.0, 0.04 * cos(i * 1.7))
			depot_yard_tyre(kit, Transform3D(Basis(), base + jitter + Vector3.UP * (0.11 + i * 0.22)))
		var stack_shape := CylinderShape3D.new()
		stack_shape.radius = 0.46 + 0.22
		stack_shape.height = stack[1] * 0.22
		kit.solids.append([stack_shape, Transform3D(Basis(), base + Vector3.UP * stack_shape.height * 0.5)])
	for lean: Vector3 in [Vector3(-21.0, 0, -2.2), Vector3(-20.75, 0, -1.55)]:
		depot_yard_tyre(kit, Transform3D(Basis.from_euler(Vector3(0, 0.4, deg_to_rad(72))), lean + Vector3.UP * (Kit.FLOOR + 0.62)), false)
	# Two pallets (the GLB pallet shape is retired; these are plank boxes) with the engine block on top.
	var pallet := Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(8), 0)), Vector3(-21.3, Kit.FLOOR, 0.4))
	for level: int in 2:
		var y: float = level * 0.15
		for x: float in [-0.5, 0.0, 0.5]:
			kit.box(pallet * Transform3D(Basis(), Vector3(x, y + 0.05, 0)), Vector3(0.12, 0.1, 1.2), WOOD.darkened(0.1))
		for z: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			kit.box(pallet * Transform3D(Basis(), Vector3(0, y + 0.12, z)), Vector3(1.2, 0.03, 0.14), WOOD)
	var block := pallet * Transform3D(Basis(), Vector3(0, 0.3, 0))
	kit.box(block * Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.75, 0.6, 0.95), IRON.lightened(0.12))
	kit.box(block * Transform3D(Basis(), Vector3(0, 0.68, 0)), Vector3(0.6, 0.16, 0.85), IRON.lightened(0.2))
	kit.box(block * Transform3D(Basis(), Vector3(0.45, 0.35, 0.2)), Vector3(0.2, 0.35, 0.3), RUST)
	kit.cylinder(block * Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(-0.5, 0.35, -0.3)), 0.16, 0.16, 0.1, ZINC_DARK)
	kit.solid_box(pallet * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.2, 1.2, 1.2))
	# Gas cylinders chained against the wall beside the breaker cabinet: the bay's tall piece.
	for i: int in 4:
		var p := Vector3(-23.55, Kit.FLOOR, -0.9 - i * 0.42)
		var colour: Color = CYLINDER_GREY if i != 2 else Color("6b5f4a")
		kit.cylinder(Transform3D(Basis(), p + Vector3.UP * 0.66), 0.17, 0.17, 1.32, colour)
		kit.cylinder(Transform3D(Basis(), p + Vector3.UP * 1.36), 0.06, 0.12, 0.12, colour.darkened(0.2))
		kit.cylinder(Transform3D(Basis(), p + Vector3.UP * 1.45), 0.03, 0.03, 0.08, IRON)
	var rack_shape := BoxShape3D.new()
	rack_shape.size = Vector3(1.75, 1.32, 0.38)
	kit.solids.append([rack_shape, Transform3D(wall, Vector3(-23.55, Kit.FLOOR + 0.66, -1.53))])
	kit.box(Transform3D(wall, Vector3(-23.38, Kit.FLOOR + 0.95, -1.53)), Vector3(1.8, 0.03, 0.02), Color("8a8a84"))
	# A parts bin of plastic crates, one slewed.
	kit.box(Transform3D(Basis.from_euler(Vector3(0, 0.15, 0)), Vector3(-22.9, Kit.FLOOR + 0.17, 2.0)), Vector3(0.55, 0.34, 0.4), PLASTIC_BLUE)
	kit.box(Transform3D(Basis.from_euler(Vector3(0, -0.4, 0)), Vector3(-22.75, Kit.FLOOR + 0.5, 1.95)), Vector3(0.55, 0.32, 0.4), PLASTIC_GREEN)
	var crates := BoxShape3D.new()
	crates.size = Vector3(0.7, 0.66, 0.6)
	kit.solids.append([crates, Transform3D(Basis(), Vector3(-22.85, Kit.FLOOR + 0.33, 1.98))])
	return kit

## The wash bay (water source (-14, 15)): the pad is painted on the floor; the burst cistern
## stands on its plinth at the bay's back with the split facing the puddle, a pipe running from
## its foot to the outlet; a hose reel on its stand, the hose snaking out across the pad.
func depot_yard_wash_bay() -> Kit:
	var kit := Kit.new()
	var source := Vector2(-20.03, 4.43)
	var cistern: Vector3 = at(source.x - 3.4, source.y + 2.2)
	kit.box(Transform3D(Kit.turn(0), cistern + Vector3.UP * 0.12), Vector3(2.1, 0.24, 2.1), CONCRETE_DARK, true)
	kit.cylinder(Transform3D(Basis(), cistern + Vector3.UP * 1.19), 0.92, 0.92, 1.9, Color("5f6a68"), true, 14)
	kit.cylinder(Transform3D(Basis(), cistern + Vector3.UP * 2.17), 0.6, 0.94, 0.12, Color("4e5857"), false, 14)
	for y: float in [0.6, 1.2, 1.8]:
		kit.cylinder(Transform3D(Basis(), cistern + Vector3.UP * y), 0.94, 0.94, 0.05, Color("4a5352"), false, 14)
	# The split: a dark gash on the side facing the puddle, a plate peeled out of it.
	var facing: Vector3 = (at(source.x, source.y) - cistern).normalized()
	var face := Basis(facing.cross(Vector3.UP).normalized(), Vector3.UP, -facing)
	kit.box(Transform3D(face, cistern + facing * 0.9 + Vector3.UP * 0.75), Vector3(0.22, 0.9, 0.06), Color("101314"))
	kit.box(Transform3D(face * Basis.from_euler(Vector3(0, 0.7, 0.15)), cistern + facing * 1.02 + Vector3.UP * 0.85 + face.x * 0.18), Vector3(0.28, 0.6, 0.03), Color("6b7573"))
	# Pipe from its foot along the floor to the outlet at the source.
	kit.cable(cistern + facing * 0.95 + Vector3.UP * 0.12, at(source.x, source.y, 0.08), 0.0, 0.06, Color("3a3734"), 3)
	# «LAVADO / AGUA NO POTABLE», stencilled on the cistern facing the camera.
	var toward_camera := Basis(AU, Vector3.UP, AV)
	depot_yard_sign("LAVADO", Transform3D(toward_camera, cistern + AV * 0.94 + Vector3.UP * 1.45), 0.024, Color("9c978a"))
	depot_yard_sign("AGUA NO POTABLE", Transform3D(toward_camera, cistern + AV * 0.94 + Vector3.UP * 1.18), 0.012, Color("9c978a"))
	# Hose reel on its A-frame, hose paying out across the pad toward the puddle.
	var reel: Transform3D = xf(source.x - 1.2, source.y - 4.0, 0.0, 15.0)
	for side: float in [-0.32, 0.32]:
		kit.box(reel * Transform3D(Basis.from_euler(Vector3(0, 0, side * 0.5)), Vector3(side, 0.45, 0)), Vector3(0.05, 0.92, 0.05), ZINC_DARK)
	kit.cylinder(reel * Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(0, 0.62, 0)), 0.3, 0.3, 0.5, Color("37403d"))
	kit.cylinder(reel * Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(0, 0.62, 0)), 0.34, 0.34, 0.04, ZINC)
	var reel_shape := BoxShape3D.new()
	reel_shape.size = Vector3(0.75, 0.95, 0.7)
	kit.solids.append([reel_shape, reel * Transform3D(Basis(), Vector3(0, 0.475, 0))])
	# The hose: a thick, dark green rubber run that sags off the reel and lies in soft loops on the
	# pad (a Catmull-Rom through the lay points, so it never kinks into a zig-zag).
	var lay: Array[Vector3] = [reel * Vector3(0.1, 0.35, 0.3), at(source.x - 1.7, source.y - 2.9, 0.07), at(source.x - 0.7, source.y - 2.5, 0.07), at(source.x - 0.1, source.y - 1.5, 0.07), at(source.x - 0.4, source.y - 0.5, 0.07)]
	var run: Array[Vector3] = []
	for i: int in lay.size() - 1:
		var p0: Vector3 = lay[maxi(i - 1, 0)]
		var p3: Vector3 = lay[mini(i + 2, lay.size() - 1)]
		for k: int in 6:
			var t: float = k / 6.0
			var point: Vector3 = lay[i].cubic_interpolate(lay[i + 1], p0, p3, t)
			if i > 0: point.y = maxf(point.y, 0.07)
			run.append(point)
	run.append(lay[lay.size() - 1])
	for i: int in run.size() - 1:
		kit.cable(run[i], run[i + 1], 0.06 if i < 3 else 0.0, 0.065, Color("34502f"), 2 if i < 3 else 1)
	return kit

## The concrete pole the gárgola snapped (current store (-2, 12)): the stub with its rebar on the
## road's pole line, the top lying along the kerb with its crossarm, the cable run sagging from the
## stub down to the transformer that fell with it; the yard's Jersey barriers dragged into a cordon
## around it with a PELIGRO plate. The cordon stays open toward the yard so the store can be drawn.
func depot_yard_fallen_pole() -> Kit:
	var kit := Kit.new()
	var store := Vector2(-8.45, 8.76)
	var stub: Vector3 = at(-10.5, 11.7)
	kit.box(Transform3D(Basis(), stub + Vector3.UP * 0.06), Vector3(0.7, 0.12, 0.7), CONCRETE_DARK)
	kit.cylinder(Transform3D(Basis(), stub + Vector3.UP * 1.1), 0.17, 0.2, 2.2, CONCRETE, true)
	# The pole's painted base band, white over black like every pole on the avenue: the edge that
	# keeps the stub readable in the dark next to its sparking cable (slightly lit paint, alpha < 1).
	kit.cylinder(Transform3D(Basis(), stub + Vector3.UP * 0.55), 0.205, 0.205, 0.5, Color(0.12, 0.12, 0.12))
	kit.cylinder(Transform3D(Basis(), stub + Vector3.UP * 1.05), 0.2, 0.2, 0.5, Color(0.8, 0.79, 0.74, 0.975))
	# The break: a jagged lip of fresh, pale concrete and bent rebar.
	kit.box(Transform3D(Basis.from_euler(Vector3(0.3, 0.4, 0.2)), stub + Vector3.UP * 2.24), Vector3(0.22, 0.14, 0.18), Color("a8a49a"))
	kit.cylinder(Transform3D(Basis(), stub + Vector3.UP * 2.205), 0.165, 0.17, 0.03, Color("a8a49a"))
	for i: int in 4:
		var a: float = i * PI * 0.5 + 0.4
		kit.box(Transform3D(Basis.from_euler(Vector3(0.5 * cos(a), 0, 0.5 * sin(a))), stub + Vector3(cos(a) * 0.1, 2.38, sin(a) * 0.1)), Vector3(0.02, 0.4, 0.02), RUST)
	# The top: lying on the road, crossarm and insulators still on it, its foot shattered.
	var top_start: Vector3 = stub + AU * -0.6 + Vector3.UP * 0.2
	var top_end: Vector3 = at(-17.2, 12.6, 0.18)
	var along: Vector3 = (top_end - top_start).normalized()
	var lying := Basis(Vector3.UP.cross(along).normalized(), along, Vector3.UP.cross(along).normalized().cross(along))
	var length: float = top_start.distance_to(top_end)
	kit.cylinder(Transform3D(lying, (top_start + top_end) * 0.5), 0.15, 0.18, length, CONCRETE, true)
	var arm_at: Vector3 = top_start.lerp(top_end, 0.82)
	kit.box(Transform3D(Basis(Vector3.UP, 0.0) * Basis.looking_at(along, Vector3.UP), arm_at + Vector3.UP * 0.1), Vector3(1.5, 0.1, 0.1), Color("4a4540"))
	for k: float in [-0.6, 0.0, 0.6]:
		var side: Vector3 = Vector3.UP.cross(along).normalized()
		kit.cylinder(Transform3D(Basis(), arm_at + side * k + Vector3.UP * 0.22), 0.04, 0.06, 0.16, CREAM)
	# Rubble where the head hit and at the foot.
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for i: int in 9:
		var near: Vector3 = (top_end if i < 5 else stub) + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		kit.box(Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf() * 3.0, rng.randf())), near + Vector3.UP * 0.07), Vector3.ONE * rng.randf_range(0.08, 0.2), CONCRETE.darkened(rng.randf_range(0.0, 0.25)))
	# The cable run: from the stub's top, sagging to the floor, across it to the transformer terminals.
	var terminal: Vector3 = at(store.x, store.y, 1.1)
	for k: float in [-0.12, 0.0, 0.12]:
		var lift: Vector3 = AU * k
		kit.cable(stub + Vector3.UP * 2.1 + lift, at(-9.6, 10.4, 0.02) + lift, 1.2, 0.025, Color("161616"), 5)
		kit.cable(at(-9.6, 10.4, 0.02) + lift, terminal + lift * 0.5 + Vector3.DOWN * 0.3, 0.25, 0.025, Color("161616"), 4)
	# A second, dead cable trailing off the lying top.
	kit.cable(arm_at + Vector3.UP * 0.25, at(-14.0, 9.6, 0.02), 0.4, 0.022, Color("1a1a1a"), 4)
	# The cordon: the yard's Jersey barriers dragged into a U facing away from the yard.
	var jersey: Mesh = depot_yard_source_mesh("JerseyBarrier")
	for barrier: Array in [[-12.7, 8.4, 92.0], [-11.7, 12.1, 132.0], [-7.6, 13.0, 178.0], [-4.4, 11.6, 222.0]]:
		depot_yard_jersey(kit, jersey, xf(barrier[0], barrier[1], 0.0, barrier[2]))
	# PELIGRO plate wired to the barrier nearest the camera's line: faded enamel, dark lettering.
	var plate: Transform3D = xf(-7.6, 12.0, 0.0, 0.0)
	var facing := Basis(AU, Vector3.UP, AV)
	kit.box(Transform3D(facing, plate.origin + Vector3.UP * 0.62), Vector3(0.9, 0.42, 0.03), CREAM)
	depot_yard_sign("PELIGRO", Transform3D(facing, plate.origin + Vector3.UP * 0.7 + AV * 0.02), 0.016, Color("3a2b28"))
	depot_yard_sign("ALTA TENSIÓN", Transform3D(facing, plate.origin + Vector3.UP * 0.54 + AV * 0.02), 0.011, Color("3a2b28"))
	return kit

## The re-used Jersey barrier: the original shape in grey concrete with one worn stripe, standing on
## the floor, with a hull of exactly that shape as its collider.
func depot_yard_jersey(kit: Kit, mesh: Mesh, where: Transform3D) -> void:
	if mesh == null:
		kit.box(where * Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(2.0, 0.8, 0.6), CONCRETE, true)
		return
	var box: AABB = mesh.get_aabb()
	# Lay the long side along the transform's x and stand it on the floor.
	var long_x: bool = box.size.x >= box.size.z
	var spin := Basis() if long_x else Basis(Vector3.UP, PI * 0.5)
	var centre := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var placed := Transform3D(where.basis * spin, where.origin) * Transform3D(Basis(), -centre)
	kit.add_mesh(mesh, placed, Color("8a8780"))
	var stripe: Vector3 = Vector3(box.size.x if long_x else box.size.z, 0.08, (box.size.z if long_x else box.size.x) * 0.72)
	kit.box(where * Transform3D(Basis(), Vector3(0, box.size.y * 0.72, 0)), stripe, Color("8f8668"))
	kit.solids.append([mesh.create_convex_shape(), placed])

## A mesh from the imported yard by name prefix (its node is hidden; the resource is shared).
func depot_yard_source_mesh(prefix: String) -> Mesh:
	for node: Node in arena.sector_runtime.imported_environment.find_children(prefix + "*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null and mesh.get_surface_count() > 0: return mesh
	return null

## The substation cabinet by the fence (current store (-7, -11) is its guts, torn out and dragged
## into the yard): a grey cabinet with its door ripped off and lying face down, the bundle of
## cables running from its open belly across the floor to the guts, and the plate on its flank
## that says what was in it: SELLO 08-114 -- NO ROMPER.
func depot_yard_substation() -> Kit:
	var kit := Kit.new()
	var cabinet: Transform3D = xf(CABINET_UV.x, CABINET_UV.y, 0.0, 0.0)
	kit.box(cabinet * Transform3D(Basis(), Vector3(0, 0.06, 0)), Vector3(1.7, 0.12, 0.9), CONCRETE_DARK)
	kit.box(cabinet * Transform3D(Basis(), Vector3(0, 0.98, -0.05)), Vector3(1.5, 1.72, 0.62), Color("6d7672"), true)
	kit.box(cabinet * Transform3D(Basis(), Vector3(0, 1.87, -0.05)), Vector3(1.62, 0.07, 0.72), Color("596260"))
	# The open belly: dark, busbars, a few torn stubs.
	kit.box(cabinet * Transform3D(Basis(), Vector3(0, 0.95, 0.27)), Vector3(1.3, 1.45, 0.02), Color("111414"))
	for i: int in 3:
		kit.box(cabinet * Transform3D(Basis(), Vector3(-0.35 + i * 0.35, 1.2, 0.25)), Vector3(0.06, 0.8, 0.04), Color("6b5a3e"))
	# The door, wrenched off, lying on the floor at an angle.
	kit.box(cabinet * Transform3D(Basis.from_euler(Vector3(0, 0.5, 0)), Vector3(-1.1, 0.03, 1.15)), Vector3(1.4, 0.04, 0.72), Color("6a736f"))
	kit.box(cabinet * Transform3D(Basis.from_euler(Vector3(0, 0.5, 0)), Vector3(-1.1, 0.055, 1.15)), Vector3(0.3, 0.02, 0.12), Color("8a8577"))
	# Cables from the belly across the floor to the guts at the store.
	var store: Vector3 = at(0.46, -13.03, 0.3)
	for k: float in [-0.25, -0.1, 0.05, 0.2]:
		var from: Vector3 = cabinet * Vector3(k, 0.3, 0.3)
		kit.cable(from, at(-1.1 + k * 0.6, -15.4, 0.02), 0.25, 0.03, Color("181818"), 3)
		kit.cable(at(-1.1 + k * 0.6, -15.4, 0.02), store + AU * k * 0.5, 0.1, 0.03, Color("181818"), 4)
	# Plate on the flank facing the camera: the seal's number.
	var face := Basis(AU, Vector3.UP, AV)
	var plate_at: Vector3 = cabinet * Vector3(0.0, 1.32, 0.29)
	kit.box(Transform3D(face, plate_at), Vector3(0.82, 0.26, 0.02), CREAM)
	depot_yard_sign("SELLO 08-114", Transform3D(face, plate_at + Vector3.UP * 0.045 + AV * 0.015), 0.0105, Color("2e2a26"))
	depot_yard_sign("NO ROMPER", Transform3D(face, plate_at + Vector3.DOWN * 0.06 + AV * 0.015), 0.009, Color("2e2a26"))
	# A torn paper seal fluttering from the door edge.
	kit.box(cabinet * Transform3D(Basis.from_euler(Vector3(0, 0, 0.3)), Vector3(0.78, 1.4, 0.3)), Vector3(0.05, 0.22, 0.01), Color("c9c2ad"))
	return kit

## Scrap the mechanics dumped against the light mast's base (the mast is depot_lighting.gd's,
## at (4.5, -10.5)): plates, a wheel rim, bars, a bus door panel propped on the heap as the tall
## piece. Heaped on the mast's west side, off the bus lane, kept 0.6 m off the plinth. The scrap store (3, -5) is where a crew dragged some of it.
func depot_yard_mast_scrap() -> Kit:
	var kit := Kit.new()
	var mast: Vector2 = yard_of(Vector3(4.5, 0, -10.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4510
	var heap_centre := Vector2(mast.x - 2.1, mast.y - 1.5)
	# A bus door panel propped against the heap from the north; its own collider, it stands 1.8 m.
	var panel: Transform3D = xf(heap_centre.x - 0.2, heap_centre.y - 0.75, 0.0, 6.0, -18.0)
	kit.box(panel * Transform3D(Basis(), Vector3(0, 0.95, 0)), Vector3(0.95, 1.9, 0.06), Color("59625e"), true)
	kit.box(panel * Transform3D(Basis(), Vector3(0, 1.25, 0.035)), Vector3(0.75, 0.75, 0.01), Color("1c2324"))
	for i: int in 14:
		var u: float = heap_centre.x + rng.randf_range(-0.95, 0.95)
		var v: float = heap_centre.y + rng.randf_range(-0.55, 0.55)
		var size: Vector3 = [Vector3(0.8, 0.05, 0.5), Vector3(1.1, 0.08, 0.08), Vector3(0.35, 0.28, 0.35), Vector3(0.6, 0.04, 0.6)][i % 4]
		var colour: Color = [RUST, IRON, RUST_DARK, ZINC_DARK][rng.randi() % 4]
		kit.box(xf(u, v, 0.08 + rng.randf() * 0.35, rng.randf() * 180.0, rng.randf_range(-30, 30), rng.randf_range(-30, 30)), size, colour)
	depot_yard_tyre(kit, xf(heap_centre.x - 0.9, heap_centre.y + 0.2, 0.47, 20.0, 0.0, 70.0))
	kit.torus(xf(heap_centre.x + 0.8, heap_centre.y - 0.3, 0.12, 0.0, 12.0), 0.2, 0.32, Color("5e5f5c"))
	var heap := BoxShape3D.new()
	heap.size = Vector3(2.3, 0.7, 1.3)
	kit.solids.append([heap, xf(heap_centre.x, heap_centre.y, 0.35)])
	return kit

## The desarmadero round the far scrap store (20, 21): a micro shell stripped for parts lying on its
## belly (no wheels, roof half cut away, windows out), ripped-out seats in a row, tyres.
func depot_yard_desarmadero() -> Kit:
	var kit := Kit.new()
	var shell: Transform3D = xf(10.7, 28.4, 0.0, 90.0 + 4.0)
	var body := Color("5c6a66")
	var length: float = 7.6
	# Floor pan and lower body, solid.
	kit.box(shell * Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(length, 1.0, 2.4), body.darkened(0.25), true)
	# Side walls with window gaps: pillars between empty windows.
	for side: float in [-1.17, 1.17]:
		for i: int in 8:
			kit.box(shell * Transform3D(Basis(), Vector3(-length * 0.5 + 0.25 + i * (length - 0.5) / 7.0, 1.45, side)), Vector3(0.14, 0.9, 0.06), body)
		kit.box(shell * Transform3D(Basis(), Vector3(0, 1.0, side)), Vector3(length, 0.12, 0.08), body.lightened(0.08))
		kit.box(shell * Transform3D(Basis(), Vector3(0, 0.62, side)), Vector3(length, 0.1, 0.08), Color("6c5940"))
	# Half the roof cut away; the remaining half over the front.
	kit.box(shell * Transform3D(Basis(), Vector3(length * 0.25, 1.95, 0)), Vector3(length * 0.5, 0.08, 2.42), body.lightened(0.04))
	# The front end: dead destination box, empty windscreen frame.
	kit.box(shell * Transform3D(Basis(), Vector3(length * 0.5 - 0.03, 1.45, 0)), Vector3(0.06, 0.95, 2.3), Color("1e2425"))
	kit.box(shell * Transform3D(Basis(), Vector3(length * 0.5 - 0.02, 2.0, 0)), Vector3(0.08, 0.18, 1.6), Color("2b2f2e"))
	# Wheel arches without wheels.
	for x: float in [-length * 0.32, length * 0.3]:
		for side: float in [-1.2, 1.2]:
			kit.box(shell * Transform3D(Basis(), Vector3(x, 0.38, side)), Vector3(1.0, 0.52, 0.04), Color("161818"))
	# Seats in a row on the floor beside it, and tyres.
	for i: int in 3:
		var seat: Transform3D = xf(14.0, 25.6 + i * 0.9, 0.0, -80.0 + i * 9.0)
		kit.box(seat * Transform3D(Basis(), Vector3(0, 0.22, 0)), Vector3(0.9, 0.44, 0.45), SEAT_RED, true)
		kit.box(seat * Transform3D(Basis.from_euler(Vector3(-0.15, 0, 0)), Vector3(0, 0.62, 0.2)), Vector3(0.9, 0.55, 0.08), SEAT_RED.darkened(0.1))
		kit.box(seat * Transform3D(Basis(), Vector3(0.0, 0.08, 0.0)), Vector3(0.75, 0.04, 0.35), IRON)
	for i: int in 3:
		depot_yard_tyre(kit, xf(8.2, 25.0 - 0.15 * i, 0.11 + i * 0.22, 0.0))
	depot_yard_tyre(kit, xf(7.6, 25.9, 0.46, 30.0), true)
	var stack := CylinderShape3D.new()
	stack.radius = 0.68
	stack.height = 0.66
	kit.solids.append([stack, xf(8.2, 24.85, 0.33)])
	return kit

## The east source's estanque (water source (18.5, 13)): a cracked water tank on a steel stand
## north of its puddle, an overflow pipe reaching out over the puddle's middle where the water
## falls (water_source.gd draws the falling water).
func depot_yard_tank_stand() -> Kit:
	var kit := Kit.new()
	var source := Vector2(7.88, 21.19)
	var stand: Vector3 = at(source.x + 0.6, source.y - 3.9)
	for leg: Vector2 in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(0.6, 0.6), Vector2(-0.6, 0.6)]:
		var foot: Vector3 = stand + AU * leg.x + AV * leg.y
		kit.box(Transform3D(Kit.turn(0), foot + Vector3.UP * 1.4), Vector3(0.1, 2.8, 0.1), ZINC_DARK)
		var leg_shape := BoxShape3D.new()
		leg_shape.size = Vector3(0.1, 2.8, 0.1)
		kit.solids.append([leg_shape, Transform3D(Kit.turn(0), foot + Vector3.UP * 1.4)])
	for y: float in [0.9, 1.9]:
		for side: int in 4:
			var a: Vector2 = [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(0.6, 0.6), Vector2(-0.6, 0.6)][side]
			var b: Vector2 = [Vector2(0.6, -0.6), Vector2(0.6, 0.6), Vector2(-0.6, 0.6), Vector2(-0.6, -0.6)][side]
			kit.cable(stand + AU * a.x + AV * a.y + Vector3.UP * y, stand + AU * b.x + AV * b.y + Vector3.UP * y, 0.0, 0.03, ZINC_DARK, 1)
	kit.box(Transform3D(Kit.turn(0), stand + Vector3.UP * 2.85), Vector3(1.5, 0.1, 1.5), ZINC_DARK)
	kit.cylinder(Transform3D(Basis(), stand + Vector3.UP * 3.6), 0.75, 0.75, 1.4, Color("2f3a3d"), false, 12)
	kit.cylinder(Transform3D(Basis(), stand + Vector3.UP * 4.35), 0.3, 0.76, 0.12, Color("283133"), false, 12)
	# The crack, and the stain it has run down the side.
	kit.box(Transform3D(Basis(AU, Vector3.UP, AV), stand + AV * 0.74 + Vector3.UP * 3.4), Vector3(0.06, 0.7, 0.03), Color("0f1314"))
	kit.box(Transform3D(Basis(AU, Vector3.UP, AV), stand + AV * 0.75 + Vector3.UP * 3.0), Vector3(0.22, 0.6, 0.02), Color("263033"))
	# Overflow pipe out over the puddle; its open end is where the water falls.
	var out_end: Vector3 = at(source.x, source.y, 3.2)
	kit.cable(stand + AV * 0.7 + Vector3.UP * 3.2, out_end, 0.0, 0.06, Color("3c3a37"), 2)
	kit.cylinder(Transform3D(Basis(), out_end + Vector3.DOWN * 0.08), 0.08, 0.08, 0.16, Color("3c3a37"))
	return kit
