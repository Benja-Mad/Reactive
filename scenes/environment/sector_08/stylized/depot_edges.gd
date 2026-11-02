## The depot's edges and the street beyond: gate and guard booth, parked micros, signage, and the relief bus.
## Built last over the district trial; everything it adds or hides is undone by clear().
##
## Encierro y Taller, Línea 08. North (top of frame): the chainlink perimeter with the pedestrian door,
## the caseta and the rolling vehicle gate; across the street the fuente de soda, the botillería behind
## its rejas, a vulcanización, an empty animita and an old facade something took a bite out of. West:
## the taller under the apartment block, one roll-up door open. East: three micros parked nose-in
## against a zinc fence. South: the canal behind the perimeter, its railing torn where the Novia and
## the Raya came up. Behind everything, a cerro with a switchback road the relief bus comes down.
##
## Positions are written in two frames. The edge frame is screen-aligned: `a` runs along the north
## fence (screen right), `b` away from the camera (screen up); its origin is the composed framing
## target. The block frames follow the imported buildings' own piers so shopfronts sit in real bays.
extends Node3D

const FONT := preload("res://ui/kit/font.fnt")
const Relief := preload("res://scenes/environment/sector_08/stylized/depot_edges_relief.gd")

## Edge frame: local x = a (along the north fence), local -z = b (away from the camera).
const EDGE_ORIGIN := Vector3(0.0, 0.0, -2.0)
const EDGE_YAW := 35.0
## The north fence line and its openings (edge frame). The pedestrian door is the fence's original gap.
const FENCE_B := 16.5
const DOOR_A := Vector2(-0.6, 2.8)
const CASETA_A := 4.2
const GATE_A := Vector2(5.55, 12.15)
## The north block's first pier, bay width and front face (block frame: x along the facade, +z to the street).
const BLOCK_ORIGIN := Vector3(-15.2, 0.0, -15.4)
const BLOCK_YAW := 43.1
const BLOCK_BAY := 2.405
const BLOCK_FRONT := 0.38
## The west block's first pier; its facade faces the yard (+z), bays run along +x.
const TALLER_ORIGIN := Vector3(-23.4, 0.0, 7.7)
const TALLER_YAW := 100.0
const TALLER_BAY := 2.39
const TALLER_FRONT := 0.45
## Which taller bay stands open (counted from the north-east pier). Bay 4 is the one in the composed frame.
const TALLER_OPEN_BAY := 4
## Floor top.
const FLOOR_Y := 0.06

## Where DepotLighting should hang its secondaries. Every entry has a fixture built here; the matching
## Marker3D nodes (group "depot_light_markers", meta "depot_light") carry the resolved world transforms.
## kind: what the fixture is; color/energy/range are suggestions in the brief's palette.
const LIGHT_MARKERS := {
	"TallerDoor": {"kind": "fluorescent spill from the open roll-up door, aimed out across the floor", "color": "cfe6d2", "energy": 3.0, "range": 9.0},
	"CasetaWindow": {"kind": "warm tungsten window of the guard booth", "color": "d6b183", "energy": 1.2, "range": 4.0},
	"CasetaEave": {"kind": "fluorescent tube under the caseta eave, over the pedestrian door", "color": "cfe6d2", "energy": 1.0, "range": 5.0},
	"GateLamp": {"kind": "gate lamp, OFF until the relief arrives (watch gate_lamp_changed / gate_lamp_on)", "color": "e8d9a8", "energy": 4.0, "range": 8.0},
	"FuenteDeSoda": {"kind": "fluorescent glow of the fuente de soda across the street", "color": "cfe6d2", "energy": 1.5, "range": 6.0},
	"Botilleria": {"kind": "dim interior of the botillería behind its rejas", "color": "d6b183", "energy": 0.6, "range": 4.0},
	"TallerNeon": {"kind": "neon: magenta tube sign «EL CHISPA» over the taller's open bay", "color": "ff3fae", "energy": 1.8, "range": 5.0},
	"ChargerLeds": {"kind": "neon: cyan charging LEDs on the electric micros' chargers", "color": "35dcff", "energy": 1.2, "range": 3.5},
	"HoloBotilleria": {"kind": "neon holo-ad, flickering, over the botillería (meta glass is its panel)", "color": "8cefe0", "energy": 1.0, "range": 4.0},
}

signal gate_lamp_changed(on: bool)

var trial: Node3D
var arena: Node3D
var run: Node
var relief: Node3D
var gate_lamp_on: bool = false
var gate_leaf: Node3D
var gate_lamp_glass: StandardMaterial3D
var shapes: Array[CollisionShape3D] = []
var markers: Dictionary = {}
var _materials: Dictionary = {}
var _changed_from: int = 0
var _collisions_from: int = 0
var _tv_glass: StandardMaterial3D
var _tv_time: float = 0.0
## [district material, quiet copy] for the imported lit windows (see depot_edges_quiet_windows).
var _quiet_windows: Array = []
## Trial replacement colliders this pass switched off (the old tank's shells); clear() gives them back.
var _retired_replacements: Array[CollisionShape3D] = []
## The botillería's holo-ad: its panel material (published to DepotLighting as meta "glass") and text.
var _holo_glass: StandardMaterial3D
var _holo_labels: Array[Label3D] = []
var _holo_time: float = 0.0


func setup(owner_arena: Node, owner_trial: Node3D) -> void:
	arena = owner_arena as Node3D
	trial = owner_trial
	run = arena.get_parent().get_node_or_null("SurvivorRun") if arena.get_parent() != null else null
	_changed_from = trial.changed.size()
	_collisions_from = trial.collision_changes.size()
	depot_edges_retire_stock()
	depot_edges_build_north_fence()
	depot_edges_build_caseta()
	depot_edges_build_gate()
	depot_edges_build_street()
	depot_edges_build_shopfronts()
	depot_edges_build_taller()
	depot_edges_build_east()
	depot_edges_build_chargers()
	depot_edges_build_canal()
	depot_edges_build_cerro()
	relief = Relief.new()
	relief.name = "Relief"
	add_child(relief)
	relief.setup(self)
	trial.replacement_collisions.append_array(shapes)
	# The TV flicker and the relief must keep running when the shift ends (set_phase pauses the tree).
	process_mode = Node.PROCESS_MODE_ALWAYS


func clear() -> void:
	for shape: CollisionShape3D in shapes:
		trial.replacement_collisions.erase(shape)
	for i: int in range(trial.changed.size() - 1, _changed_from - 1, -1):
		var item: Dictionary = trial.changed[i]
		var mesh: GeometryInstance3D = item["node"]
		if is_instance_valid(mesh):
			mesh.material_override = item["original"]
			mesh.visible = item["visible"]
		trial.changed.remove_at(i)
	for i: int in range(trial.collision_changes.size() - 1, _collisions_from - 1, -1):
		var entry: Dictionary = trial.collision_changes[i]
		entry["node"].disabled = entry["disabled"]
		trial.collision_changes.remove_at(i)
	for shape: CollisionShape3D in _retired_replacements:
		if is_instance_valid(shape) and not trial.replacement_collisions.has(shape):
			trial.replacement_collisions.append(shape)
			shape.disabled = not trial.enabled
	_retired_replacements.clear()
	shapes.clear()
	_quiet_windows.clear()
	_holo_labels.clear()
	_holo_glass = null
	for child: Node in get_children():
		child.queue_free()


func _process(delta: float) -> void:
	if _tv_glass == null or not is_visible_in_tree():
		return
	# The quiet window copies keep the district's clock, power and blackout; only the sweeping
	# blue wave, the corruption tint and the alert wash stay off.
	for pair: Array in _quiet_windows:
		for parameter: StringName in [&"cs_effect_time", &"cs_power", &"cs_blackout", &"cs_electric_activity"]:
			var value: Variant = pair[0].get_shader_parameter(parameter)
			if value != null: pair[1].set_shader_parameter(parameter, value)
	_holo_time += delta
	depot_edges_holo_flicker()
	# A small TV in the caseta: cuts between brighter and darker shots, never a strobe.
	_tv_time += delta
	var shot: float = floorf(_tv_time / 1.7)
	var level: float = 0.45 + 0.35 * absf(sin(shot * 12.9898)) + 0.05 * sin(_tv_time * 9.0)
	_tv_glass.emission_energy_multiplier = level


## The relief has arrived: the gate lamp lights. Called by the relief.
func depot_edges_set_gate_lamp(on: bool) -> void:
	if on == gate_lamp_on:
		return
	gate_lamp_on = on
	gate_lamp_glass.emission_energy_multiplier = 2.2 if on else 0.0
	gate_lamp_glass.albedo_color = Color("e8d9a8") if on else Color("34332e")
	if markers.has("GateLamp"):
		markers["GateLamp"].set_meta("on", on)
	gate_lamp_changed.emit(on)


# --- Frames and building blocks ----------------------------------------------------------------

## World position of an edge-frame point.
static func depot_edges_ab(a: float, b: float, h: float = 0.0) -> Vector3:
	var yaw: float = deg_to_rad(EDGE_YAW)
	return EDGE_ORIGIN + Vector3(cos(yaw), 0, -sin(yaw)) * a + Vector3(-sin(yaw), 0, -cos(yaw)) * b + Vector3.UP * h


func depot_edges_frame(id: String, origin: Vector3, yaw: float, parent: Node3D = null) -> Node3D:
	var frame := Node3D.new()
	frame.name = id
	(parent if parent != null else self).add_child(frame)
	frame.position = origin
	frame.rotation.y = deg_to_rad(yaw)
	return frame


## Painted, non-emissive surfaces share the district's ink so new buildings sit with the old ones.
func depot_edges_paint(hex: String, obstacle: bool = false) -> Material:
	return trial._paint(hex, false, false, obstacle)


## A dim self-lit surface: lightboxes, LED signs, lit windows. Never above the bloom threshold.
func depot_edges_glow(hex: String, energy: float) -> StandardMaterial3D:
	var key: String = "glow" + hex + str(energy)
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(hex).darkened(0.55)
		material.roughness = 0.6
		material.metallic_specular = 0.2
		material.emission_enabled = true
		material.emission = Color(hex)
		material.emission_energy_multiplier = energy
		_materials[key] = material
	return _materials[key]


func depot_edges_glass(hex: String) -> StandardMaterial3D:
	var key: String = "glass" + hex
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(hex)
		material.roughness = 0.12
		material.metallic_specular = 0.7
		_materials[key] = material
	return _materials[key]


func depot_edges_box(parent: Node3D, id: String, at: Vector3, size: Vector3, material: Material, solid: bool = false, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = id
	var shape := BoxMesh.new()
	shape.size = size
	part.mesh = shape
	part.position = at
	part.rotation_degrees = rotation_deg
	part.material_override = material
	parent.add_child(part)
	if solid:
		depot_edges_solid(part)
	return part


func depot_edges_cylinder(parent: Node3D, id: String, at: Vector3, radius: float, height: float, material: Material, segments: int = 10, rotation_deg: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = id
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = segments
	shape.rings = 1
	part.mesh = shape
	part.position = at
	part.rotation_degrees = rotation_deg
	part.material_override = material
	parent.add_child(part)
	return part


## A box collider exactly matching a box mesh, toggled with the presentation like every replacement.
func depot_edges_solid(part: MeshInstance3D) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.name = "Solid"
	part.add_child(body)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (part.mesh as BoxMesh).size
	collision.shape = box
	body.add_child(collision)
	shapes.append(collision)
	return collision


## Text in the crew's pixel font (5x7 capitals). Painted text is lit by the scene; `lit` text is a
## lightbox or LED and carries its own dim light. `height` is the capital height in metres.
func depot_edges_text(parent: Node3D, words: String, at: Vector3, height: float, hex: String, lit: bool = false, yaw_deg: float = 0.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var label := Label3D.new()
	label.name = "Text_" + words.left(12).replace(" ", "_").replace(".", "").replace("/", "")
	label.font = FONT
	label.font_size = 12
	label.text = words
	label.pixel_size = height / 7.0
	label.modulate = Color(hex)
	label.outline_size = 0
	label.shaded = not lit
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.horizontal_alignment = align
	label.position = at
	label.rotation_degrees.y = yaw_deg
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(label)
	return label


## One draw call per family of repeated parts.
func depot_edges_multimesh(parent: Node3D, id: String, mesh: Mesh, transforms: Array[Transform3D], material: Material, colors: Array[Color] = []) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = id
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if not colors.is_empty():
			multimesh.set_instance_color(i, colors[i % colors.size()])
	instance.multimesh = multimesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


## A material whose albedo comes from the MultiMesh instance colour (zinc sheets, bottles, rubble).
func depot_edges_vertex_paint(id: String, roughness: float = 0.9) -> StandardMaterial3D:
	if not _materials.has(id):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color.WHITE
		material.roughness = roughness
		material.metallic_specular = 0.25
		_materials[id] = material
	return _materials[id]


func depot_edges_unit_box() -> BoxMesh:
	if not _materials.has("unit_box"):
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		_materials["unit_box"] = box
	return _materials["unit_box"]


func depot_edges_marker(parent: Node3D, id: String, at: Vector3, aim: Vector3 = Vector3.ZERO) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = "LightMarker_" + id
	parent.add_child(marker)
	marker.position = at
	if aim != Vector3.ZERO:
		marker.look_at(parent.to_global(aim), Vector3.UP if absf((aim - at).normalized().y) < 0.98 else Vector3.FORWARD)
	var spec: Dictionary = LIGHT_MARKERS[id]
	marker.set_meta("depot_light", id)
	marker.set_meta("kind", spec["kind"])
	marker.set_meta("color", Color(spec["color"]))
	marker.set_meta("energy", spec["energy"])
	marker.set_meta("range", spec["range"])
	marker.add_to_group("depot_light_markers")
	markers[id] = marker
	return marker


# --- Retiring the stock cyberpunk dressing -----------------------------------------------------

## Hide an imported or lookdev mesh through the trial's own list; its obstacle collider goes with it.
func depot_edges_retire(mesh: GeometryInstance3D) -> void:
	if mesh == null:
		return
	trial.changed.append({"node": mesh, "original": mesh.material_override, "visible": mesh.visible, "paint": null, "hide": true})
	var collider: CollisionShape3D = arena.sector_runtime.collision.get_node_or_null("Obstacle_" + str(mesh.name))
	if collider != null:
		depot_edges_retire_collider(collider)


func depot_edges_retire_collider(collider: CollisionShape3D) -> void:
	for item: Dictionary in trial.collision_changes:
		if item["node"] == collider:
			return
	trial.collision_changes.append({"node": collider, "disabled": collider.disabled})


## Repaint through the trial's list. A mesh some earlier pass already hid stays hidden: the later
## entry wins when the trial applies its list, so it must not bring the mesh back.
func depot_edges_repaint(mesh: GeometryInstance3D, material: Material) -> void:
	if mesh == null:
		return
	for item: Dictionary in trial.changed:
		if item["node"] == mesh and item["hide"]:
			return
	trial.changed.append({"node": mesh, "original": mesh.material_override, "visible": mesh.visible, "paint": material, "hide": false})


func depot_edges_imported(title: String) -> MeshInstance3D:
	return arena.sector_runtime.imported_environment.find_child(title, true, false) as MeshInstance3D


## Every word on the old dressing was stock cyberpunk (English slogans, katakana blades, a giant
## "C/S TRANSIT" stop in the middle of the yard). The district scripts no longer build theirs; the
## imported and lookdev ones are hidden here, reversibly.
func depot_edges_retire_stock() -> void:
	var imported: Node = arena.sector_runtime.imported_environment
	for node: Node in imported.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var title: String = str(mesh.name)
		# Katakana blade signs, glyph plates and data screens.
		if title.begins_with("BladeSign") or title.begins_with("District_Plate") or title.begins_with("Sign") or "Diagnostic" in title or title.begins_with("bg_block_b_Sign"):
			if mesh.visible: depot_edges_retire(mesh)
		# Programmable status strips in the reserved cyan and machine rose: the walls go quiet.
		elif title.begins_with("StatusStrip") or title.begins_with("Transformer_Strip") or "InfraStrip" in title or title.begins_with("Corruption") or title.begins_with("AviationLight") or "JunctionLED" in title:
			var center: Vector3 = (mesh.global_transform * mesh.get_aabb()).get_center()
			var ab: Vector2 = depot_edges_to_ab(center)
			# Floor-level ducts inside the yard belong to the yard pass.
			if "JunctionLED" in title and absf(ab.x) < 22.0 and ab.y < 16.0 and ab.y > -15.0: continue
			depot_edges_repaint(mesh, depot_edges_paint("3b4447"))
		elif title.begins_with("HazardZone") and mesh.visible:
			# Stripes in the street outside the floor DepotYard repaints: faded, not signal yellow.
			if depot_edges_to_ab((mesh.global_transform * mesh.get_aabb()).get_center()).y > FENCE_B - 0.6:
				depot_edges_repaint(mesh, depot_edges_paint("6a6655"))
		elif title == "Container":
			# The red-orange box read as a WHEN-orange block: it is a zinc-grey storage container now.
			depot_edges_repaint(mesh, depot_edges_paint("6c7376", true))
		elif title.begins_with("north_block_") and mesh.visible:
			# The block across the street was painted mauve and violet-grey: plain concrete and plaster now.
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			if bounds.position.y < 5.0 and depot_edges_to_ab(bounds.get_center()).y > FENCE_B:
				var pale: bool = "Trim" in title or "Lintel" in title or "Pier" in title
				depot_edges_repaint(mesh, depot_edges_paint("8a857a" if pale else "5c5b56", true))
		elif title in ["Shrub_Canopy", "Shrub_Trunk", "Corner_Ivy"]:
			# The street corner where the relief turns in.
			depot_edges_retire(mesh)
		elif (title.begins_with("Pipe_") or title.begins_with("Tray_") or (title.begins_with("Feeder") and ("Terminal" in title or "Tie" in title))) and mesh.visible:
			# The southern overhead bundle: the trial hides its pipe runs, trays and cables where they
			# cross the court, which left their flanges, brackets, hangers and feeder ends floating 4-7 m up
			# over the south edge -- from the gameplay camera a row of black vertical drips on the floor.
			var run_box: AABB = mesh.global_transform * mesh.get_aabb()
			var run_at: Vector2 = depot_edges_to_ab(run_box.get_center())
			if run_box.position.y > 3.5 and run_at.y < -9.5 and run_at.y > -17.0: depot_edges_retire(mesh)
		elif (title.begins_with("Creeper") or title == "Gantry_Vine" or title in ["ExtractFan_002", "ExtractFan_003"]) and mesh.visible:
			# Dark foliage cards and fan discs scattered over the block facades read as black blotches.
			depot_edges_retire(mesh)
	depot_edges_quiet_windows(arena.sector_runtime)
	# The old "COOLANT" stack (repainted as a water tank in cooling_landmark.gd) stands right on the
	# street west of the north block, where the animita and the bitten facade belong. It goes, with
	# the convex shells the trial built for it; it sat outside the fence, so no floor changes.
	var tank: Node = trial.get_node_or_null("CoolingLandmark")
	if tank != null:
		for node: Node in tank.find_children("*", "MeshInstance3D", true, false):
			trial.changed.append({"node": node, "original": (node as MeshInstance3D).material_override, "visible": (node as MeshInstance3D).visible, "paint": null, "hide": true})
		for node: Node in tank.find_children("*", "CollisionShape3D", true, false):
			var shell := node as CollisionShape3D
			if trial.replacement_collisions.has(shell):
				trial.replacement_collisions.erase(shell)
				_retired_replacements.append(shell)
			shell.disabled = true
	# Transformer boxes parked on the street: one in front of the bitten facade, one by the gate.
	for node: Node in imported.find_children("Transformer*", "MeshInstance3D", true, false):
		var box := node as MeshInstance3D
		var at: Vector2 = depot_edges_to_ab((box.global_transform * box.get_aabb()).get_center())
		if at.y > FENCE_B and at.x > -16.0 and at.x < 16.0: depot_edges_retire(box)
	# The mid-yard "C/S TRANSIT 08" stop, its display and the hazard stripes under it stand on the
	# floor: DepotYard retires them (and the audit checks no solid is left where its posts stood).
	# Fence panels that the caseta and the vehicle gate replace.
	for title: String in ["ChainlinkPanel_006", "ChainlinkPanel_007", "ChainlinkPanel_008"]:
		var holder: Node = trial.get_node_or_null("Painted_" + title)
		if holder != null:
			for part: Node in holder.find_children("*", "MeshInstance3D", true, false):
				trial.changed.append({"node": part, "original": part.material_override, "visible": part.visible, "paint": null, "hide": true})
		var obstacle: CollisionShape3D = arena.sector_runtime.collision.get_node_or_null("Obstacle_" + title)
		if obstacle != null:
			depot_edges_retire_collider(obstacle)


## The district's lit windows and facade service bands sweep a saturated blue wave across every
## facade and tint rooms rose and teal with "corruption": reserved signal colours on the buildings.
## Each window or band material gets
## a quiet copy (applied through the trial's list, so F6 restores the original) with the wave,
## corruption and alert at zero; _process keeps its clock and power in step with the district.
func depot_edges_quiet_windows(imported: Node) -> void:
	var copies: Dictionary = {}
	for node: Node in imported.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.mesh.get_surface_count() != 1:
			continue
		var source := mesh.get_active_material(0) as ShaderMaterial
		if source == null or source.shader == null:
			continue
		var shader_file: String = source.shader.resource_path.get_file()
		if shader_file == "calibrated_reactive_spine.gdshader":
			# The street's "data conduit" glows cyan and rose by design: a dark cable duct now. Ducts on
			# the yard floor belong to DepotYard.
			var at: Vector2 = depot_edges_to_ab((mesh.global_transform * mesh.get_aabb()).get_center())
			if at.y > FENCE_B or absf(at.x) > 22.0 or at.y < -15.0:
				depot_edges_repaint(mesh, depot_edges_paint("2f3537"))
			continue
		if shader_file not in ["calibrated_window_interior.gdshader", "calibrated_window_glass.gdshader", "calibrated_reactive_facade.gdshader"]:
			continue
		if not copies.has(source):
			var quiet := source.duplicate() as ShaderMaterial
			quiet.set_shader_parameter(&"cs_wave_intensity", 0.0)
			quiet.set_shader_parameter(&"cs_corruption", 0.0)
			quiet.set_shader_parameter(&"cs_alert_level", 0.0)
			quiet.set_shader_parameter(&"cs_network_load", 0.0)
			copies[source] = quiet
			_quiet_windows.append([source, quiet])
		depot_edges_repaint(mesh, copies[source])


static func depot_edges_to_ab(world: Vector3) -> Vector2:
	var yaw: float = deg_to_rad(EDGE_YAW)
	var d: Vector3 = world - EDGE_ORIGIN
	return Vector2(d.x * cos(yaw) - d.z * sin(yaw), -d.x * sin(yaw) - d.z * cos(yaw))


# --- North: perimeter, caseta, gate ------------------------------------------------------------

func depot_edges_build_north_fence() -> void:
	var north := depot_edges_frame("NorthFence", EDGE_ORIGIN, EDGE_YAW)
	var steel: Material = depot_edges_paint("5d6a6a", true)
	# Pedestrian door frame in the fence's own gap. The door itself was torn off and lies in the street.
	for a: float in [DOOR_A.x, DOOR_A.y]:
		depot_edges_box(north, "DoorPost", Vector3(a, 1.2, -FENCE_B), Vector3(0.12, 2.4, 0.12), steel, true)
	depot_edges_box(north, "DoorHeader", Vector3((DOOR_A.x + DOOR_A.y) * 0.5, 2.36, -FENCE_B), Vector3(DOOR_A.y - DOOR_A.x + 0.12, 0.08, 0.08), steel)
	# One hinge still holds a twisted strip of the door frame.
	depot_edges_box(north, "TornHingeStrip", Vector3(DOOR_A.x + 0.1, 1.5, -FENCE_B - 0.12), Vector3(0.06, 0.9, 0.04), depot_edges_paint("6f7a76"), false, Vector3(0, 35, 14))
	# Zinc run closing the fence's east end; the gate leaf parks behind it when it rolls open.
	var zinc_start: float = GATE_A.y + 0.15
	var zinc_end: float = 17.6
	var sheets: Array[Transform3D] = []
	var tints: Array[Color] = []
	var a: float = zinc_start + 0.45
	var index: int = 0
	while a < zinc_end:
		var lean: float = sin(float(index) * 2.3) * 1.4
		sheets.append(Transform3D(Basis.from_euler(Vector3(deg_to_rad(lean), 0, 0)).scaled(Vector3(0.92, 2.2 + 0.08 * sin(index * 1.7), 0.04)), Vector3(a, 1.12, -FENCE_B - 0.1)))
		tints.append([Color("737773"), Color("6a6862"), Color("7c6f62"), Color("80807a")][index % 4])
		a += 0.86
		index += 1
	depot_edges_multimesh(north, "GateSideZinc", depot_edges_unit_box(), sheets, depot_edges_vertex_paint("zinc"), tints)
	var run_length: float = zinc_end - zinc_start
	var zinc_body := depot_edges_box(north, "GateSideZincCollider", Vector3(zinc_start + run_length * 0.5, 1.12, -FENCE_B - 0.1), Vector3(run_length, 2.24, 0.1), steel, true)
	zinc_body.visible = false
	for post: float in [zinc_start + 2.6, zinc_end - 0.1]:
		depot_edges_box(north, "ZincPost", Vector3(post, 1.15, -FENCE_B + 0.02), Vector3(0.1, 2.3, 0.1), steel)
	# Low rail the gate leaf runs on.
	depot_edges_box(north, "GateRail", Vector3((GATE_A.x + zinc_end) * 0.5, FLOOR_Y + 0.012, -FENCE_B - 0.28), Vector3(zinc_end - GATE_A.x + 0.4, 0.025, 0.07), depot_edges_paint("4a4e4c"))


## The sereno's booth stands in the fence line between the pedestrian door and the vehicle gate,
## its window on the yard: warm lamp, a small TV, a fluorescent tube under the eave.
func depot_edges_build_caseta() -> void:
	var caseta := depot_edges_frame("Caseta", depot_edges_ab(CASETA_A, FENCE_B - 0.2, 0.0), EDGE_YAW)
	var wall: Material = depot_edges_paint("8b8a7d", true)
	var trim: Material = depot_edges_paint("4f5b5c")
	var roof: Material = depot_edges_paint("3e4446")
	var body := depot_edges_box(caseta, "Body", Vector3(0, 1.26, 0), Vector3(2.3, 2.4, 2.2), wall, true)
	body.position.y = FLOOR_Y + 1.2
	depot_edges_box(caseta, "Plinth", Vector3(0, FLOOR_Y + 0.08, 0), Vector3(2.4, 0.16, 2.3), trim)
	depot_edges_box(caseta, "Roof", Vector3(0, FLOOR_Y + 2.5, 0.22), Vector3(2.75, 0.12, 2.75), roof)
	depot_edges_box(caseta, "RoofFascia", Vector3(0, FLOOR_Y + 2.47, 1.61), Vector3(2.75, 0.3, 0.04), depot_edges_paint("c2bca6"))
	depot_edges_text(caseta, "GUARDIA", Vector3(0, FLOOR_Y + 2.47, 1.635), 0.17, "2a3236")
	# Yard window: dim tungsten inside, a TV glow low in the right corner, a cardboard note.
	depot_edges_box(caseta, "WindowFrame", Vector3(0.2, FLOOR_Y + 1.45, 1.105), Vector3(1.5, 0.95, 0.04), trim)
	depot_edges_box(caseta, "WindowPane", Vector3(0.2, FLOOR_Y + 1.45, 1.12), Vector3(1.36, 0.82, 0.02), depot_edges_glow("d6b183", 0.32))
	_tv_glass = depot_edges_glow("b9c8cf", 0.6).duplicate()
	depot_edges_box(caseta, "TVGlow", Vector3(0.62, FLOOR_Y + 1.2, 1.132), Vector3(0.34, 0.26, 0.01), _tv_glass)
	depot_edges_box(caseta, "Cardboard", Vector3(-0.22, FLOOR_Y + 1.2, 1.134), Vector3(0.5, 0.3, 0.01), depot_edges_paint("a08d6c"))
	depot_edges_text(caseta, "VUELVO\nALTIRO", Vector3(-0.22, FLOOR_Y + 1.2, 1.141), 0.07, "2b2622")
	depot_edges_box(caseta, "Sill", Vector3(0.2, FLOOR_Y + 0.98, 1.17), Vector3(1.6, 0.06, 0.12), trim)
	# "GUARDIA" is lettered on the roof fascia (above); "TOQUE EL TIMBRE" beside the bell.
	depot_edges_box(caseta, "BellPlate", Vector3(-0.85, FLOOR_Y + 1.5, 1.11), Vector3(0.36, 0.22, 0.02), depot_edges_paint("b7b19c"))
	depot_edges_text(caseta, "TOQUE EL\nTIMBRE", Vector3(-0.85, FLOOR_Y + 1.52, 1.125), 0.035, "2a3236")
	depot_edges_box(caseta, "Bell", Vector3(-0.85, FLOOR_Y + 1.3, 1.125), Vector3(0.08, 0.1, 0.03), depot_edges_paint("3a3d3c"))
	# Door on the pedestrian side.
	depot_edges_box(caseta, "Door", Vector3(-1.16, FLOOR_Y + 1.0, 0.25), Vector3(0.03, 1.95, 0.8), depot_edges_paint("5b6662"))
	# Eave tube: the fixture for the light over the pedestrian door.
	depot_edges_box(caseta, "EaveBracket", Vector3(-0.3, FLOOR_Y + 2.38, 1.42), Vector3(1.3, 0.06, 0.1), trim)
	depot_edges_box(caseta, "EaveTube", Vector3(-0.3, FLOOR_Y + 2.33, 1.42), Vector3(1.1, 0.045, 0.045), depot_edges_glow("cfe6d2", 1.1))
	# Cable from the street pole into the roof, and a satellite dish for the TV.
	depot_edges_box(caseta, "Dish", Vector3(0.85, FLOOR_Y + 2.75, -0.7), Vector3(0.42, 0.42, 0.06), depot_edges_paint("9a9a92"), false, Vector3(-25, 20, 0))
	depot_edges_box(caseta, "DishArm", Vector3(0.85, FLOOR_Y + 2.62, -0.62), Vector3(0.04, 0.3, 0.04), trim)
	depot_edges_marker(caseta, "CasetaWindow", Vector3(0.2, FLOOR_Y + 1.6, 0.6), Vector3(0.2, 0.2, 3.5))
	depot_edges_marker(caseta, "CasetaEave", Vector3(-0.3, FLOOR_Y + 2.28, 1.42), Vector3(-1.8, 0.0, 2.2))


## The rolling vehicle gate: closed through the shift, it rolls open behind the zinc when the relief is in.
func depot_edges_build_gate() -> void:
	var north := depot_edges_frame("VehicleGate", EDGE_ORIGIN, EDGE_YAW)
	var steel: Material = depot_edges_paint("55605f", true)
	var dark: Material = depot_edges_paint("3c4443")
	var width: float = GATE_A.y - GATE_A.x
	# Plain posts, just above the leaf: nothing spans the opening, so a player in the gate lane is
	# never behind a board from the gameplay camera.
	for a: float in [GATE_A.x, GATE_A.y]:
		depot_edges_box(north, "GatePost", Vector3(a, FLOOR_Y + 1.3, -FENCE_B), Vector3(0.28, 2.6, 0.28), steel, true)
	# The depot's name board rides the zinc run east of the gate, clear of the lane.
	var board_center := Vector3(14.9, FLOOR_Y + 2.95, -FENCE_B + 0.1)
	for a: float in [12.6, 17.2]:
		depot_edges_box(north, "NameBoardStrut", Vector3(a, FLOOR_Y + 2.62, -FENCE_B + 0.06), Vector3(0.08, 0.9, 0.06), dark)
	depot_edges_box(north, "NameBoard", board_center, Vector3(5.1, 0.56, 0.06), depot_edges_paint("b9b19b"))
	depot_edges_box(north, "NameBoardRail", board_center + Vector3(0, -0.33, 0), Vector3(4.9, 0.06, 0.08), dark)
	var name_text: String = "TERMINAL LÍNEA 08 — ENCIERRO"
	depot_edges_text(north, name_text, board_center + Vector3(0, 0, 0.04), 0.2, "27313a")
	depot_edges_text(north, name_text, board_center + Vector3(0, 0, -0.04), 0.2, "27313a", false, 180.0)
	# Gate lamp on a slim mast beside the east post, its arm reaching over the opening; dark until
	# the relief pulls up.
	var lamp_at := Vector3(GATE_A.y - 0.9, FLOOR_Y + 4.25, -FENCE_B + 0.15)
	depot_edges_box(north, "LampMast", Vector3(GATE_A.y + 0.26, FLOOR_Y + 2.2, -FENCE_B), Vector3(0.1, 4.4, 0.1), dark)
	depot_edges_box(north, "LampArm", Vector3(GATE_A.y - 0.32, FLOOR_Y + 4.32, -FENCE_B + 0.05), Vector3(1.2, 0.06, 0.06), dark)
	depot_edges_box(north, "LampHousing", lamp_at, Vector3(0.42, 0.14, 0.3), dark)
	gate_lamp_glass = StandardMaterial3D.new()
	gate_lamp_glass.albedo_color = Color("34332e")
	gate_lamp_glass.roughness = 0.3
	gate_lamp_glass.emission_enabled = true
	gate_lamp_glass.emission = Color("e8d9a8")
	gate_lamp_glass.emission_energy_multiplier = 0.0
	depot_edges_box(north, "LampGlass", lamp_at + Vector3(0, -0.08, 0), Vector3(0.32, 0.03, 0.22), gate_lamp_glass)
	var lamp_marker := depot_edges_marker(north, "GateLamp", lamp_at + Vector3(0, -0.14, 0), lamp_at + Vector3(0, -4.0, 1.0))
	lamp_marker.set_meta("on", false)
	# Exit and parking plates facing the yard (drivers read them leaving).
	depot_edges_box(north, "SalidaPlate", Vector3(GATE_A.x - 0.02, FLOOR_Y + 2.15, -FENCE_B + 0.16), Vector3(0.95, 0.28, 0.03), depot_edges_paint("bdb7a3"))
	depot_edges_text(north, "SALIDA DE MICROS", Vector3(GATE_A.x - 0.02, FLOOR_Y + 2.15, -FENCE_B + 0.18), 0.075, "2a3236")
	# The leaf: one welded frame with vertical bars, rolling on four wheels.
	gate_leaf = Node3D.new()
	gate_leaf.name = "GateLeaf"
	north.add_child(gate_leaf)
	gate_leaf.position = Vector3((GATE_A.x + GATE_A.y) * 0.5, FLOOR_Y, -FENCE_B - 0.28)
	var leaf_width: float = width + 0.2
	var leaf_height: float = 2.1
	for y: float in [0.16, 1.1, leaf_height]:
		depot_edges_box(gate_leaf, "Rail", Vector3(0, y, 0), Vector3(leaf_width, 0.09, 0.08), steel)
	for x: float in [-leaf_width * 0.5, leaf_width * 0.5]:
		depot_edges_box(gate_leaf, "Stile", Vector3(x, (leaf_height + 0.16) * 0.5, 0), Vector3(0.1, leaf_height - 0.1, 0.09), steel)
	var bars: Array[Transform3D] = []
	var x: float = -leaf_width * 0.5 + 0.14
	while x < leaf_width * 0.5 - 0.1:
		bars.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.03, leaf_height - 0.2, 0.03)), Vector3(x, (leaf_height + 0.16) * 0.5, 0)))
		x += 0.14
	depot_edges_multimesh(gate_leaf, "Bars", depot_edges_unit_box(), bars, steel)
	var brace := depot_edges_box(gate_leaf, "Brace", Vector3(0, 0.63, 0.0), Vector3(0.06, sqrt(pow(leaf_width, 2) + 0.9) * 0.5, 0.06), steel)
	brace.rotation_degrees.z = rad_to_deg(atan2(leaf_width, 0.94))
	brace.scale = Vector3.ONE
	for wheel_x: float in [-leaf_width * 0.36, -leaf_width * 0.12, leaf_width * 0.12, leaf_width * 0.36]:
		depot_edges_cylinder(gate_leaf, "Wheel", Vector3(wheel_x, 0.07, 0), 0.07, 0.05, dark, 8, Vector3(90, 0, 0))
	depot_edges_box(gate_leaf, "NoEstacionarPlate", Vector3(-0.6, 1.45, 0.06), Vector3(1.1, 0.42, 0.02), depot_edges_paint("c4beaa"))
	depot_edges_box(gate_leaf, "NoEstacionarBorder", Vector3(-0.6, 1.45, 0.055), Vector3(1.18, 0.5, 0.01), depot_edges_paint("7e4d43"))
	depot_edges_text(gate_leaf, "NO\nESTACIONAR", Vector3(-0.6, 1.46, 0.075), 0.09, "3a2f2c")
	var leaf_body := depot_edges_box(gate_leaf, "LeafCollider", Vector3(0, (leaf_height + 0.12) * 0.5, 0), Vector3(leaf_width, leaf_height + 0.05, 0.1), steel, true)
	leaf_body.visible = false


## Outside the fence: the street the relief comes along, the empty animita, the torn door and the
## delivery bike, an old facade with a bite out of its corner, the paradero.
func depot_edges_build_street() -> void:
	var street := depot_edges_frame("Street", EDGE_ORIGIN, EDGE_YAW)
	var decal: Material = depot_edges_paint("3a3f40")
	# The pedestrian door, torn off and thrown into the street; a skid mark runs out through the gap.
	depot_edges_box(street, "TornDoor", Vector3(0.6, FLOOR_Y + 0.05, -18.4), Vector3(1.1, 0.05, 2.0), depot_edges_paint("5f6a66"), false, Vector3(0, 28, 4))
	for i: int in 5:
		depot_edges_box(street, "Skid", Vector3(1.0 + float(i) * 0.12, FLOOR_Y + 0.006, -17.0 - float(i) * 0.6), Vector3(0.12, 0.01, 0.62), decal, false, Vector3(0, 8 + i * 3, 0))
	# The street runs on east past the shed, where the relief comes in: asphalt, a kerb on the far side.
	var reach := Vector2(GATE_A.y, 50.0)
	depot_edges_box(street, "StreetEast", Vector3((reach.x + reach.y) * 0.5, FLOOR_Y - 0.08, -19.0), Vector3(reach.y - reach.x, 0.16, 4.6), depot_edges_paint("3c403f"))
	depot_edges_box(street, "StreetEastKerb", Vector3((reach.x + reach.y) * 0.5 + 5.0, FLOOR_Y + 0.04, -21.4), Vector3(reach.y - reach.x - 10.0, 0.2, 0.3), depot_edges_paint("6e6c64"))
	# The repartidor's delivery bike on its side, the box thrown clear.
	var bike := depot_edges_frame("DeliveryBike", depot_edges_ab(2.6, 19.2, FLOOR_Y), EDGE_YAW - 30.0)
	for wx: float in [-0.52, 0.52]:
		depot_edges_cylinder(bike, "Wheel", Vector3(wx, 0.05, 0), 0.32, 0.06, depot_edges_paint("2b2e2f"), 12)
	depot_edges_box(bike, "Frame", Vector3(0, 0.12, 0), Vector3(1.1, 0.06, 0.08), depot_edges_paint("4f5655"), false, Vector3(0, 0, 0))
	depot_edges_box(bike, "Handlebar", Vector3(0.45, 0.16, 0.2), Vector3(0.06, 0.06, 0.5), depot_edges_paint("4f5655"))
	depot_edges_box(bike, "DeliveryBox", Vector3(-1.1, 0.2, 0.55), Vector3(0.44, 0.4, 0.44), depot_edges_paint("6e6a5c"), false, Vector3(0, 32, 9))
	# Paradero 08 on its pole by the curb: the stop the relief serves.
	var stop := depot_edges_frame("Paradero", depot_edges_ab(-5.6, 18.4, FLOOR_Y), EDGE_YAW)
	depot_edges_cylinder(stop, "Pole", Vector3(0, 1.3, 0), 0.04, 2.6, depot_edges_paint("5e6866"), 8)
	depot_edges_box(stop, "Plate", Vector3(0, 2.25, 0), Vector3(0.62, 0.5, 0.03), depot_edges_paint("b8b39f"))
	for side: float in [1.0, -1.0]:
		depot_edges_text(stop, "PARADERO", Vector3(0, 2.39, 0.025 * side), 0.055, "2c343a", false, 0.0 if side > 0 else 180.0)
		depot_edges_text(stop, "08", Vector3(0, 2.2, 0.025 * side), 0.19, "2c343a", false, 0.0 if side > 0 else 180.0)
	depot_edges_build_animita()
	depot_edges_build_bitten_facade()


## The corner animita stands empty: glass door open, LED candles dark, wax trailing toward the yard.
func depot_edges_build_animita() -> void:
	var shrine := depot_edges_frame("Animita", depot_edges_ab(-11.0, 17.75, FLOOR_Y), EDGE_YAW + 8.0)
	var lime: Material = depot_edges_paint("a59f8f", true)
	var pedestal := depot_edges_box(shrine, "Pedestal", Vector3(0, 0.32, 0), Vector3(0.78, 0.64, 0.62), lime, true)
	pedestal.name = "Pedestal"
	depot_edges_box(shrine, "House", Vector3(0, 0.9, 0), Vector3(0.62, 0.52, 0.5), depot_edges_paint("c1b9a7"))
	for side: float in [-1.0, 1.0]:
		depot_edges_box(shrine, "RoofSlope", Vector3(side * 0.18, 1.24, 0), Vector3(0.44, 0.05, 0.6), depot_edges_paint("6c5f55"), false, Vector3(0, 0, -side * 32))
	depot_edges_box(shrine, "Cross", Vector3(0, 1.48, 0), Vector3(0.03, 0.2, 0.03), depot_edges_paint("4a4542"))
	depot_edges_box(shrine, "CrossBar", Vector3(0, 1.52, 0), Vector3(0.12, 0.03, 0.03), depot_edges_paint("4a4542"))
	depot_edges_box(shrine, "Niche", Vector3(0, 0.88, 0.2), Vector3(0.44, 0.38, 0.12), depot_edges_paint("1e2224"))
	# The little glass door hangs open on its hinge.
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	shrine.add_child(hinge)
	hinge.position = Vector3(-0.23, 0.88, 0.27)
	hinge.rotation_degrees.y = -118.0
	depot_edges_box(hinge, "GlassDoor", Vector3(0.22, 0, 0), Vector3(0.44, 0.38, 0.015), depot_edges_glass("6f7d80"))
	# Dark LED candles, a bottle of plastic flowers, the thank-you plaques.
	for cx: float in [-0.12, 0.0, 0.12]:
		depot_edges_cylinder(shrine, "LedCandle", Vector3(cx, 0.75, 0.2), 0.025, 0.08, depot_edges_paint("bdb6a4"), 6)
	depot_edges_cylinder(shrine, "FlowerBottle", Vector3(0.29, 0.7, 0.36), 0.04, 0.14, depot_edges_glass("5a6a5c"), 6)
	depot_edges_box(shrine, "Flowers", Vector3(0.29, 0.82, 0.36), Vector3(0.12, 0.1, 0.1), depot_edges_paint("8f6f6a"))
	for i: int in 4:
		depot_edges_box(shrine, "Plaque", Vector3(-0.27 + float(i) * 0.18, 0.4 - float(i % 2) * 0.12, 0.315), Vector3(0.13, 0.08, 0.01), depot_edges_paint("bcb6a2"))
	var plaque := depot_edges_text(shrine, "GRACIAS POR EL\nFAVOR CONCEDIDO", Vector3(-0.27, 0.4, 0.322), 0.009, "3a3632")
	plaque.name = "Plaque_Gracias"
	# Wax dripped in a trail from the shrine to the torn door: the ánima went into the yard.
	var drops: Array[Transform3D] = []
	for i: int in 16:
		var t: float = float(i) / 15.0
		var at: Vector3 = depot_edges_ab(lerpf(-10.5, 0.4, t), lerpf(17.45, 16.8, t) + sin(t * 9.0) * 0.25, FLOOR_Y + 0.004)
		var size: float = 0.07 + 0.05 * absf(sin(float(i) * 3.1))
		drops.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, 0.008, size * 1.3)), at))
	depot_edges_multimesh(self, "WaxTrail", depot_edges_unit_box(), drops, depot_edges_paint("c9bfa4"))


## An old two-storey facade across the street: something took a bite out of its top corner.
func depot_edges_build_bitten_facade() -> void:
	var facade := depot_edges_frame("BittenFacade", depot_edges_ab(-9.6, 20.9, FLOOR_Y), EDGE_YAW)
	var plaster: Material = depot_edges_paint("857c6d", true)
	var brick: Material = depot_edges_paint("6e5547")
	var dark: Material = depot_edges_paint("23282a")
	var trim: Material = depot_edges_paint("5f6260")
	# The wall up to the first floor is whole; the upper storey is built in steps so the bite has edges.
	depot_edges_box(facade, "GroundStorey", Vector3(0, 1.7, 0), Vector3(7.0, 3.4, 0.5), plaster, true)
	depot_edges_box(facade, "UpperLeft", Vector3(-1.75, 4.9, 0), Vector3(3.5, 3.0, 0.5), plaster)
	depot_edges_box(facade, "UpperMid", Vector3(0.9, 4.45, 0), Vector3(1.8, 2.1, 0.5), plaster)
	depot_edges_box(facade, "UpperBiteStep", Vector3(2.35, 3.8, 0), Vector3(1.1, 0.8, 0.5), plaster)
	# Exposed brick and torn rebar inside the bite.
	depot_edges_box(facade, "BiteBrick", Vector3(1.9, 4.6, -0.1), Vector3(1.4, 1.6, 0.32), brick)
	for i: int in 3:
		depot_edges_box(facade, "Rebar", Vector3(1.6 + float(i) * 0.35, 5.4 + float(i % 2) * 0.2, 0.1), Vector3(0.03, 0.7, 0.03), depot_edges_paint("4d3f38"), false, Vector3(0, 0, -20 + i * 18))
	depot_edges_box(facade, "Cornice", Vector3(-1.75, 6.45, 0.12), Vector3(3.6, 0.14, 0.4), trim)
	# Door with rejas, a shuttered window, two upper windows (one boarded with the For Rent board).
	depot_edges_box(facade, "Door", Vector3(-2.3, 1.15, 0.26), Vector3(1.0, 2.2, 0.03), dark)
	depot_edges_box(facade, "ShopShutter", Vector3(1.2, 1.4, 0.26), Vector3(2.6, 2.1, 0.03), depot_edges_paint("5c6461"))
	var slats: Array[Transform3D] = []
	for i: int in 12:
		slats.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.55, 0.025, 0.02)), Vector3(1.2, 0.45 + float(i) * 0.17, 0.28)))
	depot_edges_multimesh(facade, "ShutterSlats", depot_edges_unit_box(), slats, depot_edges_paint("4a5250"))
	depot_edges_box(facade, "UpperWindow", Vector3(-2.4, 4.8, 0.26), Vector3(1.0, 1.3, 0.03), dark)
	depot_edges_box(facade, "UpperWindowGlow", Vector3(-2.4, 4.6, 0.27), Vector3(0.9, 0.5, 0.01), depot_edges_glow("b89a70", 0.18))
	depot_edges_box(facade, "BoardedWindow", Vector3(-0.6, 4.75, 0.26), Vector3(1.2, 1.25, 0.03), depot_edges_paint("8a7a62"))
	depot_edges_text(facade, "SE\nARRIENDA", Vector3(-0.6, 4.78, 0.28), 0.17, "d9d2bf")
	# Rubble on the sidewalk below the bite: low, flat, walk-over.
	var rubble: Array[Transform3D] = []
	var tints: Array[Color] = []
	for i: int in 16:
		var s: float = 0.12 + 0.16 * absf(sin(float(i) * 1.93))
		var x: float = 1.2 + sin(float(i) * 2.71) * 1.3
		var z: float = 0.9 + absf(cos(float(i) * 1.37)) * 1.3
		rubble.append(Transform3D(Basis.from_euler(Vector3(0.4 * sin(i), float(i), 0.3 * cos(i))).scaled(Vector3(s, s * 0.55, s * 0.8)), Vector3(x, s * 0.22, z)))
		tints.append([Color("857c6d"), Color("6e5547"), Color("77705f")][i % 3])
	depot_edges_multimesh(facade, "Rubble", depot_edges_unit_box(), rubble, depot_edges_vertex_paint("rubble"), tints)


# --- Across the street: the north block's ground-floor bays --------------------------------------

func depot_edges_build_shopfronts() -> void:
	var block := depot_edges_frame("NorthShopfronts", BLOCK_ORIGIN, BLOCK_YAW)
	# Bays 0-1: a shuttered shop for rent.
	depot_edges_shutter(block, "RentShutter", BLOCK_BAY * 0.5, 1.0, "SE ARRIENDA")
	depot_edges_shutter(block, "SideShutter", BLOCK_BAY * 1.5, 0.92, "")
	# Bays 2-4 hold the old arcade (CyberpunkDepth's street vista): it is the fuente de soda now.
	var soda_x: float = 8.1
	depot_edges_box(block, "SodaFascia", Vector3(soda_x, 3.85, BLOCK_FRONT + 0.32), Vector3(7.6, 0.62, 0.06), depot_edges_paint("c9c4b2"))
	depot_edges_box(block, "SodaFasciaTrim", Vector3(soda_x, 3.5, BLOCK_FRONT + 0.34), Vector3(7.6, 0.06, 0.06), depot_edges_paint("3e5a4c"))
	depot_edges_text(block, "FUENTE DE SODA  LA PARADA", Vector3(soda_x, 3.86, BLOCK_FRONT + 0.36), 0.3, "2f4a3e")
	depot_edges_marker(block, "FuenteDeSoda", Vector3(soda_x - 0.8, 2.9, BLOCK_FRONT - 0.6), Vector3(soda_x - 0.8, 0.0, BLOCK_FRONT + 3.0))
	# Bays 5-6: the botillería behind its rejas.
	var bot_x: float = BLOCK_BAY * 6.0
	depot_edges_box(block, "BotilleriaBack", Vector3(bot_x, 1.75, BLOCK_FRONT - 0.9), Vector3(4.5, 3.3, 0.06), depot_edges_glow("8c7b5e", 0.18))
	var bottles: Array[Transform3D] = []
	var bottle_tints: Array[Color] = []
	for shelf: int in 3:
		var y: float = 0.9 + float(shelf) * 0.62
		depot_edges_box(block, "Shelf", Vector3(bot_x, y, BLOCK_FRONT - 0.78), Vector3(4.2, 0.04, 0.22), depot_edges_paint("4b4136"))
		for i: int in 26:
			var bx: float = bot_x - 2.0 + float(i) * 0.16
			var bh: float = 0.22 + 0.08 * absf(sin(float(i * 7 + shelf)))
			bottles.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.07, bh, 0.07)), Vector3(bx, y + 0.02 + bh * 0.5, BLOCK_FRONT - 0.76)))
			bottle_tints.append([Color("4f5a3c"), Color("6b4f34"), Color("3e4a44"), Color("7a6a48"), Color("5c3f36")][(i + shelf) % 5])
	depot_edges_multimesh(block, "Bottles", depot_edges_unit_box(), bottles, depot_edges_vertex_paint("bottles", 0.35), bottle_tints)
	depot_edges_box(block, "Counter", Vector3(bot_x + 0.9, 0.55, BLOCK_FRONT - 0.2), Vector3(1.6, 1.0, 0.5), depot_edges_paint("4d453b"))
	var rejas: Array[Transform3D] = []
	var rx: float = bot_x - 2.3
	while rx <= bot_x + 2.3:
		rejas.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.035, 3.2, 0.035)), Vector3(rx, 1.7, BLOCK_FRONT + 0.1)))
		rx += 0.13
	depot_edges_multimesh(block, "Rejas", depot_edges_unit_box(), rejas, depot_edges_paint("3f4644"))
	for y: float in [0.35, 1.7, 3.25]:
		depot_edges_box(block, "RejaFlat", Vector3(bot_x, y, BLOCK_FRONT + 0.12), Vector3(4.7, 0.05, 0.04), depot_edges_paint("3f4644"))
	depot_edges_box(block, "BotilleriaFascia", Vector3(bot_x, 3.75, BLOCK_FRONT + 0.3), Vector3(4.6, 0.56, 0.06), depot_edges_paint("33404a"))
	depot_edges_text(block, "BOTILLERÍA", Vector3(bot_x, 3.76, BLOCK_FRONT + 0.34), 0.3, "d4cbb2")
	# "ABIERTO 24 HRS": a lightbox hung inside the rejas, half its tubes dead.
	var box_at := Vector3(bot_x - 1.0, 2.62, BLOCK_FRONT - 0.05)
	depot_edges_box(block, "OpenBox", box_at, Vector3(1.55, 0.3, 0.08), depot_edges_paint("2a2d2c"))
	depot_edges_text(block, "ABIER", box_at + Vector3(-0.33, 0, 0.05), 0.12, "e3dcc0", true, 0.0, HORIZONTAL_ALIGNMENT_RIGHT)
	depot_edges_text(block, "TO", box_at + Vector3(-0.2, 0, 0.05), 0.12, "57544a", true, 0.0, HORIZONTAL_ALIGNMENT_CENTER)
	depot_edges_text(block, "24 HRS", box_at + Vector3(0.08, 0, 0.05), 0.12, "e3dcc0", true, 0.0, HORIZONTAL_ALIGNMENT_LEFT)
	depot_edges_marker(block, "Botilleria", Vector3(bot_x, 2.4, BLOCK_FRONT - 0.4), Vector3(bot_x, 0.0, BLOCK_FRONT + 2.5))
	depot_edges_build_holo_ad(block, bot_x)
	# Bays 7-8: vulcanización, its shutter half down, tyres stacked on the sidewalk.
	var vul_x: float = BLOCK_BAY * 8.0
	depot_edges_box(block, "VulcanizacionDark", Vector3(vul_x, 1.0, BLOCK_FRONT - 0.5), Vector3(4.4, 2.0, 0.06), depot_edges_paint("1d2123"))
	depot_edges_shutter(block, "VulcaShutter", vul_x, 2.0, "", 1.8)
	depot_edges_box(block, "VulcaFascia", Vector3(vul_x, 3.78, BLOCK_FRONT + 0.3), Vector3(4.6, 0.5, 0.06), depot_edges_paint("8b8466"))
	depot_edges_text(block, "VULCANIZACIÓN", Vector3(vul_x, 3.79, BLOCK_FRONT + 0.34), 0.24, "2b2b26")
	for i: int in 5:
		depot_edges_cylinder(block, "Tyre", Vector3(vul_x - 1.4 + float(i / 3) * 0.75, 0.13 + float(i % 3) * 0.24, BLOCK_FRONT + 0.8), 0.36, 0.22, depot_edges_paint("232526"), 12)


## Over the botillería: a cheap holo-ad off a projector puck on the fascia, a translucent panel
## that buzzes and drops out (depot_edges_holo_flicker). Its panel material goes to DepotLighting
## as the marker's "glass", so the light it hangs follows the same flicker.
func depot_edges_build_holo_ad(block: Node3D, x: float) -> void:
	var holo := depot_edges_frame("HoloAd", Vector3(x + 0.2, 0, BLOCK_FRONT), 0.0, block)
	var dark: Material = depot_edges_paint("2a2f30")
	depot_edges_box(holo, "Projector", Vector3(0, 4.12, 0.42), Vector3(0.5, 0.14, 0.26), dark)
	depot_edges_box(holo, "ProjectorLens", Vector3(0, 4.2, 0.46), Vector3(0.22, 0.03, 0.1), depot_edges_glow("8cefe0", 2.0))
	_holo_glass = StandardMaterial3D.new()
	_holo_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_holo_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_holo_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_holo_glass.albedo_color = Color(0.35, 0.8, 0.74, 0.07)
	_holo_glass.emission_enabled = true
	_holo_glass.emission = Color(0.03, 0.07, 0.065)
	_holo_glass.emission_energy_multiplier = 1.0
	var panel := depot_edges_box(holo, "HoloPanel", Vector3(0, 4.85, 0.6), Vector3(3.1, 1.15, 0.005), _holo_glass)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Corner ticks and two scan bands, in the same light.
	var tick: StandardMaterial3D = depot_edges_glow("8cefe0", 1.6)
	for cx: float in [-1.5, 1.5]:
		for cy: float in [4.3, 5.4]:
			depot_edges_box(holo, "HoloTickH", Vector3(cx - signf(cx) * 0.12, cy, 0.61), Vector3(0.26, 0.025, 0.004), tick)
			depot_edges_box(holo, "HoloTickV", Vector3(cx, cy - signf(cy - 4.85) * 0.1, 0.61), Vector3(0.025, 0.22, 0.004), tick)
	for band_y: float in [4.55, 5.12]:
		var band := depot_edges_box(holo, "HoloScan", Vector3(0, band_y, 0.605), Vector3(3.0, 0.012, 0.003), _holo_glass)
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A bottle, drawn in light, and the offer.
	for part: Array in [[Vector3(-1.12, 4.7, 0.612), Vector3(0.2, 0.5, 0.004)], [Vector3(-1.12, 5.04, 0.612), Vector3(0.08, 0.2, 0.004)], [Vector3(-1.12, 4.7, 0.613), Vector3(0.2, 0.08, 0.004)]]:
		depot_edges_box(holo, "HoloBottle", part[0], part[1], tick if part[1].y < 0.1 else _holo_glass)
	_holo_labels.append(depot_edges_text(holo, "CERVEZA", Vector3(0.18, 4.98, 0.615), 0.3, "b8fff2", true))
	_holo_labels.append(depot_edges_text(holo, "BIEN HELADA", Vector3(0.18, 4.6, 0.615), 0.16, "b8fff2", true))
	for label: Label3D in _holo_labels:
		label.modulate = Color(1.3, 1.9, 1.75)
	var marker := depot_edges_marker(holo, "HoloBotilleria", Vector3(0, 4.85, 0.7), Vector3(0, 1.0, 4.0))
	marker.set_meta("glass", _holo_glass)


## Mostly on with a soft buzz; every few seconds a short dropout or a double stutter.
func depot_edges_holo_flicker() -> void:
	if _holo_glass == null:
		return
	var t: float = _holo_time
	var slot: float = floorf(t * 7.0)
	var noise: float = fposmod(sin(slot * 12.9898 + 4.1) * 43758.5453, 1.0)
	var level: float = 0.92 + 0.08 * sin(t * 37.0)
	if noise > 0.93: level = 0.12
	elif noise > 0.86: level = 0.55
	_holo_glass.emission_energy_multiplier = level
	_holo_glass.albedo_color.a = 0.07 * level
	for label: Label3D in _holo_labels:
		label.modulate = Color(1.3, 1.9, 1.75, clampf(level * 1.05, 0.0, 1.0))


## A painted roll shutter in one bay, optionally lettered. `drop` is how far down it is pulled (0-1 of the opening).
func depot_edges_shutter(parent: Node3D, id: String, x: float, drop: float, words: String, width: float = 1.95) -> void:
	var top: float = 3.75
	var height: float = 3.45 * drop
	depot_edges_box(parent, id, Vector3(x, top - height * 0.5, BLOCK_FRONT + 0.05), Vector3(width, height, 0.04), depot_edges_paint("5d6663"))
	var slats: Array[Transform3D] = []
	var y: float = top - 0.12
	while y > top - height:
		slats.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width - 0.05, 0.022, 0.02)), Vector3(x, y, BLOCK_FRONT + 0.075)))
		y -= 0.16
	depot_edges_multimesh(parent, id + "Slats", depot_edges_unit_box(), slats, depot_edges_paint("4b5351"))
	depot_edges_box(parent, id + "Box", Vector3(x, top + 0.1, BLOCK_FRONT + 0.12), Vector3(width + 0.1, 0.24, 0.24), depot_edges_paint("464d4c"))
	if words != "":
		depot_edges_text(parent, words, Vector3(x, top - height * 0.45, BLOCK_FRONT + 0.09), 0.13, "d8d0bb")


# --- West: the taller under the apartment block ---------------------------------------------------

func depot_edges_build_taller() -> void:
	var taller := depot_edges_frame("Taller", TALLER_ORIGIN, TALLER_YAW)
	var paint_band: Material = depot_edges_paint("b0a68c")
	var lettering: String = "2c3438"
	# Painted band over the bays: the workshop's name, read once the camera comes west.
	var band_x: float = TALLER_BAY * 3.5
	depot_edges_box(taller, "Band", Vector3(band_x, 4.62, TALLER_FRONT + 0.05), Vector3(TALLER_BAY * 4.0 + 0.4, 0.72, 0.04), paint_band)
	depot_edges_text(taller, "TALLER  ·  MECÁNICA EN GENERAL", Vector3(band_x, 4.62, TALLER_FRONT + 0.08), 0.3, lettering)
	# A projecting board at door height, readable in the composed frame.
	var blade := depot_edges_frame("TallerBlade", Vector3(TALLER_BAY * 4.0 + 0.0, 0, TALLER_FRONT), 0.0, taller)
	depot_edges_box(blade, "BladeArm", Vector3(0, 3.3, 0.55), Vector3(0.06, 0.06, 1.1), depot_edges_paint("3e4446"))
	depot_edges_box(blade, "BladeBoard", Vector3(0, 2.92, 0.62), Vector3(0.05, 0.62, 1.05), paint_band)
	depot_edges_text(blade, "TALLER", Vector3(0.035, 2.92, 0.62), 0.2, lettering, false, 90.0)
	depot_edges_text(blade, "TALLER", Vector3(-0.035, 2.92, 0.62), 0.2, lettering, false, -90.0)
	for bay: int in range(2, 7):
		var x: float = TALLER_BAY * (float(bay) + 0.5)
		if bay == 6:
			# The staff door: plain, with its plate.
			depot_edges_box(taller, "StaffDoor", Vector3(x, 1.05, TALLER_FRONT - 0.3), Vector3(0.95, 2.1, 0.04), depot_edges_paint("4f5856"))
			depot_edges_box(taller, "StaffPlate", Vector3(x, 2.4, TALLER_FRONT - 0.27), Vector3(0.8, 0.22, 0.02), depot_edges_paint("c2bca6"))
			depot_edges_text(taller, "SOLO PERSONAL\nAUTORIZADO", Vector3(x, 2.4, TALLER_FRONT - 0.255), 0.04, "2a3236")
		else:
			depot_edges_rollup(taller, "Rollup%d" % bay, x, 1.0 if bay != 5 else 0.93)
	# No-smoking plate beside the open door.
	var plate_x: float = TALLER_BAY * (float(TALLER_OPEN_BAY) + 1.0)
	depot_edges_box(taller, "FumarPlate", Vector3(plate_x, 1.8, TALLER_FRONT + 0.32), Vector3(0.42, 0.3, 0.02), depot_edges_paint("c7c1ad"))
	depot_edges_text(taller, "PROHIBIDO\nFUMAR", Vector3(plate_x, 1.8, TALLER_FRONT + 0.335), 0.045, "6a3d36")
	# The municipal street plate on the corner pier.
	depot_edges_box(taller, "SectorPlate", Vector3(TALLER_BAY * 7.0, 2.7, TALLER_FRONT + 0.33), Vector3(0.62, 0.24, 0.02), depot_edges_paint("3c5060"))
	depot_edges_text(taller, "SECTOR 08", Vector3(TALLER_BAY * 7.0, 2.7, TALLER_FRONT + 0.345), 0.07, "d6d2c4")
	depot_edges_build_taller_south()


## A corrugated roll-up door filling one bay. A dented one stops short of the ground.
func depot_edges_rollup(parent: Node3D, id: String, x: float, drop: float, width: float = 1.82) -> void:
	var top: float = 3.8
	var height: float = (top - FLOOR_Y) * drop
	depot_edges_box(parent, id, Vector3(x, top - height * 0.5, TALLER_FRONT - 0.35), Vector3(width, height, 0.04), depot_edges_paint("66706c"))
	var slats: Array[Transform3D] = []
	var y: float = top - 0.1
	while y > top - height + 0.05:
		slats.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width - 0.04, 0.024, 0.02)), Vector3(x, y, TALLER_FRONT - 0.32)))
		y -= 0.13
	depot_edges_multimesh(parent, id + "Slats", depot_edges_unit_box(), slats, depot_edges_paint("535c59"))
	depot_edges_box(parent, id + "Handle", Vector3(x, top - height + 0.2, TALLER_FRONT - 0.31), Vector3(0.3, 0.05, 0.04), depot_edges_paint("2f3433"))


## The block's south face, square to the camera (the bays above face east and read edge-on). The
## mass ends flush at local z = 0 of a frame on the south-east pier; nothing here stands proud of
## it by more than 0.28 m, so the walkable strip in front keeps its width without new colliders.
func depot_edges_build_taller_south() -> void:
	var face := depot_edges_frame("TallerSouth", TALLER_ORIGIN, TALLER_YAW - 90.0)
	var pale: Material = depot_edges_paint("8a857a")
	var course: Material = depot_edges_paint("6d6a62")
	var lettering: String = "2c3438"
	var bays: Array[float] = [-10.65, -7.75, -4.85, -1.87]
	depot_edges_box(face, "Plinth", Vector3(-6.33, FLOOR_Y + 0.15, 0.05), Vector3(11.95, 0.3, 0.1), depot_edges_paint("4a4a45"))
	for px: float in [-12.1, -9.2, -6.3, -3.4]:
		depot_edges_box(face, "Pier", Vector3(px, FLOOR_Y + 2.15, 0.12), Vector3(0.4, 4.3, 0.24), pale)
	# The workshop's band over the ground storey.
	depot_edges_box(face, "Band", Vector3(-6.35, FLOOR_Y + 4.6, 0.14), Vector3(11.9, 0.7, 0.06), depot_edges_paint("b0a68c"))
	depot_edges_text(face, "TALLER  ·  MECÁNICA EN GENERAL", Vector3(-6.35, FLOOR_Y + 4.6, 0.18), 0.3, lettering)
	depot_edges_rollup(face, "SouthRollupA", bays[0], 1.0, 2.4)
	depot_edges_rollup(face, "SouthRollupB", bays[1], 0.9, 2.4)
	depot_edges_south_open_bay(face, bays[2])
	# Staff door and a barred window in the corner bay.
	var door_x: float = bays[3] + 0.7
	depot_edges_box(face, "StaffDoor", Vector3(door_x, FLOOR_Y + 1.05, 0.03), Vector3(0.95, 2.1, 0.04), depot_edges_paint("4f5856"))
	depot_edges_box(face, "StaffPlate", Vector3(door_x, FLOOR_Y + 2.4, 0.04), Vector3(0.8, 0.22, 0.02), depot_edges_paint("c2bca6"))
	depot_edges_text(face, "SOLO PERSONAL\nAUTORIZADO", Vector3(door_x, FLOOR_Y + 2.4, 0.055), 0.04, "2a3236")
	var win_x: float = bays[3] - 0.75
	depot_edges_box(face, "OfficeWindow", Vector3(win_x, FLOOR_Y + 1.75, 0.02), Vector3(1.1, 1.0, 0.03), depot_edges_glow("d6b183", 0.22))
	var bars: Array[Transform3D] = []
	for k: int in 7:
		bars.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.025, 1.04, 0.025)), Vector3(win_x - 0.48 + float(k) * 0.16, FLOOR_Y + 1.75, 0.06)))
	depot_edges_multimesh(face, "OfficeBars", depot_edges_unit_box(), bars, depot_edges_paint("3f4644"))
	depot_edges_box(face, "FumarPlate", Vector3(bays[2] + 1.55, FLOOR_Y + 1.8, 0.25), Vector3(0.42, 0.3, 0.02), depot_edges_paint("c7c1ad"))
	depot_edges_text(face, "PROHIBIDO\nFUMAR", Vector3(bays[2] + 1.55, FLOOR_Y + 1.8, 0.265), 0.045, "6a3d36")
	# Upper storeys: cornice, string courses, windows with sills, a few lit.
	depot_edges_box(face, "Cornice", Vector3(-6.33, FLOOR_Y + 5.02, 0.12), Vector3(12.0, 0.16, 0.24), course)
	for cy: float in [8.35, 11.15, 13.6]:
		depot_edges_box(face, "StringCourse", Vector3(-6.33, cy, 0.09), Vector3(12.0, 0.14, 0.18), course)
	var lit: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 3), Vector2i(2, 0)]
	var glass: Material = depot_edges_glass("1d2326")
	var lamp: Material = depot_edges_glow("d6b183", 0.28)
	var reveal: Material = depot_edges_paint("3e3d39")
	for storey: int in 3:
		var wy: float = 6.95 + float(storey) * 2.8
		for k: int in bays.size():
			var wx: float = bays[k]
			depot_edges_box(face, "WindowReveal", Vector3(wx, wy, 0.01), Vector3(1.56, 1.66, 0.02), reveal)
			depot_edges_box(face, "Window", Vector3(wx, wy, 0.025), Vector3(1.4, 1.5, 0.02), lamp if Vector2i(storey, k) in lit else glass)
			depot_edges_box(face, "Mullion", Vector3(wx, wy, 0.04), Vector3(0.05, 1.5, 0.02), reveal)
			depot_edges_box(face, "Sill", Vector3(wx, wy - 0.8, 0.08), Vector3(1.6, 0.08, 0.16), pale)
	depot_edges_box(face, "AirCon", Vector3(-6.95, 7.95, 0.2), Vector3(0.8, 0.55, 0.35), depot_edges_paint("8d8f88"))
	depot_edges_box(face, "AirCon", Vector3(-2.6, 10.75, 0.2), Vector3(0.8, 0.55, 0.35), depot_edges_paint("8d8f88"))
	depot_edges_cylinder(face, "Downpipe", Vector3(-0.62, 6.9, 0.12), 0.06, 13.6, depot_edges_paint("4a4f4f"), 8)
	# The neon over the open bay: the taller's name in magenta tube on a black raceway.
	depot_edges_neon_sign(face, "EL CHISPA", Vector3(bays[2], FLOOR_Y + 5.55, 0.0), "ff3fae")
	depot_edges_marker(face, "TallerNeon", Vector3(bays[2], FLOOR_Y + 5.55, 0.45), Vector3(bays[2], 1.0, 5.0))


## A neon sign on a dark raceway: tube lettering in the pixel font, a bolt, a tube border, and the
## warm-dark backing that keeps it from reading as a screen.
func depot_edges_neon_sign(parent: Node3D, words: String, at: Vector3, hex: String) -> void:
	var height: float = 0.42
	var width: float = float(words.length()) * height * 6.0 / 7.0 + 1.0
	depot_edges_box(parent, "NeonRaceway", at + Vector3(0, 0, 0.05), Vector3(width + 0.3, 0.74, 0.08), depot_edges_paint("1f2324"))
	var tube: StandardMaterial3D = depot_edges_glow(hex, 3.2)
	for sy: float in [-0.3, 0.3]:
		depot_edges_box(parent, "NeonBorder", at + Vector3(0, sy, 0.11), Vector3(width + 0.1, 0.03, 0.03), tube)
	for sx: float in [-0.5, 0.5]:
		depot_edges_box(parent, "NeonBorder", at + Vector3(sx * (width + 0.1), 0, 0.11), Vector3(0.03, 0.63, 0.03), tube)
	var text := depot_edges_text(parent, words, at + Vector3(0.35, 0, 0.12), height, hex, true)
	var c := Color(hex)
	text.modulate = Color(c.r * 2.4, c.g * 2.4, c.b * 2.4)
	# The bolt: three tube strokes left of the name.
	var bolt_x: float = at.x - width * 0.5 + 0.38
	for stroke: Array in [[Vector3(0.06, 0.12, 0), -28.0], [Vector3(-0.02, 0.0, 0), 62.0], [Vector3(-0.08, -0.12, 0), -28.0]]:
		depot_edges_box(parent, "NeonBolt", Vector3(bolt_x, at.y, at.z + 0.12) + stroke[0], Vector3(0.035, 0.22, 0.03), tube, false, Vector3(0, 0, stroke[1]))


## The open bay on the south face: the roll-up wound into its box, the shop lit white-green behind,
## its bench, hoist and tool wall in silhouette. Shallow by necessity (the mass is solid behind the
## facade) -- the reveals and the lit back carry the depth.
func depot_edges_south_open_bay(face: Node3D, x: float) -> void:
	var y0: float = FLOOR_Y
	depot_edges_box(face, "BayBackWall", Vector3(x, y0 + 1.8, 0.01), Vector3(2.4, 3.6, 0.02), depot_edges_glow("8fa89a", 0.2))
	for side: float in [-1.0, 1.0]:
		depot_edges_box(face, "BayReveal", Vector3(x + side * 1.24, y0 + 1.8, 0.14), Vector3(0.08, 3.6, 0.28), depot_edges_paint("8a948c"))
	depot_edges_cylinder(face, "RolledShutter", Vector3(x, y0 + 3.75, 0.18), 0.18, 2.4, depot_edges_paint("535c59"), 10, Vector3(0, 0, 90))
	var ink: Material = depot_edges_paint("22272a")
	# Tool wall: spanners and a saw hung on the pegboard.
	for k: int in 6:
		depot_edges_box(face, "Tool", Vector3(x - 0.9 + float(k) * 0.17, y0 + 2.45 - 0.05 * float(k % 2), 0.026), Vector3(0.05, 0.34 + 0.05 * float(k % 3), 0.006), ink)
	depot_edges_box(face, "Shelf", Vector3(x + 0.55, y0 + 2.25, 0.04), Vector3(0.9, 0.05, 0.05), ink)
	depot_edges_box(face, "Parts", Vector3(x + 0.55, y0 + 2.4, 0.04), Vector3(0.7, 0.25, 0.04), ink)
	# Chain hoist hanging over an engine on its stand, the bench in front.
	depot_edges_box(face, "HoistChain", Vector3(x - 0.4, y0 + 2.6, 0.08), Vector3(0.025, 1.3, 0.025), ink)
	depot_edges_box(face, "Engine", Vector3(x - 0.4, y0 + 1.15, 0.08), Vector3(0.7, 0.55, 0.1), depot_edges_paint("3b3f3d"))
	depot_edges_box(face, "EngineStand", Vector3(x - 0.4, y0 + 0.45, 0.08), Vector3(0.1, 0.9, 0.06), ink)
	depot_edges_box(face, "Bench", Vector3(x + 0.5, y0 + 0.88, 0.16), Vector3(1.1, 0.07, 0.22), depot_edges_paint("3d4442"))
	for lx: float in [-0.48, 0.48]:
		depot_edges_box(face, "BenchLeg", Vector3(x + 0.5 + lx, y0 + 0.43, 0.16), Vector3(0.05, 0.86, 0.05), ink)
	depot_edges_box(face, "HangingTube", Vector3(x, y0 + 3.35, 0.2), Vector3(1.2, 0.05, 0.05), depot_edges_glow("cfe6d2", 1.4))
	depot_edges_box(face, "TubeHousing", Vector3(x, y0 + 3.4, 0.2), Vector3(1.3, 0.04, 0.12), depot_edges_paint("3a3f3e"))
	depot_edges_marker(face, "TallerDoor", Vector3(x, y0 + 3.0, 0.3), Vector3(x, 0.0, 4.5))


# --- East: micros parked nose-in against the zinc ----------------------------------------------------

func depot_edges_build_east() -> void:
	var east := depot_edges_frame("EastLot", EDGE_ORIGIN, EDGE_YAW)
	# Sawtooth: each micro nose-in toward the zinc at a slight angle; the dark gaps are where the quiltros come in.
	var micros: Array[Dictionary] = [
		{"a": 23.6, "b": 2.6, "yaw": -5.0, "body": "b9b7aa", "band": "4f5a66", "sign": "FUERA DE SERVICIO", "lit": [-3.8]},
		{"a": 24.9, "b": -2.0, "yaw": -7.0, "body": "a49d89", "band": "56604e", "sign": "08 CENTRO", "lit": []},
		{"a": 25.6, "b": -6.6, "yaw": -9.0, "body": "8e9291", "band": "4d5458", "sign": "", "lit": [1.5]},
	]
	for i: int in micros.size():
		var spec: Dictionary = micros[i]
		var bus := depot_edges_frame("ParkedMicro%d" % (i + 1), Vector3(spec["a"], 0, -float(spec["b"])), float(spec["yaw"]), east)
		depot_edges_build_micro(bus, spec["body"], spec["band"], spec["sign"], i == 2, true, spec["lit"])
	depot_edges_build_zinc(east)


## A micro, long axis on local x with the nose at +x (10.4 x 2.5 m, the size DepotLighting's cabin
## overlays assume). Both flanks are dressed: the camera sees a parked micro's +z flank and rear, the
## relief's -z flank and nose. The body box stops above the wheels so the tyres and hubs show under
## the livery; a narrower chassis box between the wheels keeps the footprint solid.
## `lit_windows`: local x of window bays whose cabin tube is on (a driver resting, a cleaner).
func depot_edges_build_micro(bus: Node3D, body_hex: String, band_hex: String, sign_words: String, dark_signs: bool, solid: bool = true, lit_windows: Array = []) -> void:
	var length: float = 10.4
	var width: float = 2.5
	var half_l: float = length * 0.5
	var half_w: float = width * 0.5
	var y0: float = FLOOR_Y
	var body_paint: Material = depot_edges_paint(body_hex, true)
	var dark: Material = depot_edges_paint("2b2e2e")
	var body := depot_edges_box(bus, "Body", Vector3(0, y0 + 2.0, 0), Vector3(length, 2.2, width), body_paint, solid)
	body.name = "Body"
	depot_edges_box(bus, "Chassis", Vector3(0, y0 + 0.6, 0), Vector3(length - 0.3, 0.8, width - 0.62), dark, solid)
	depot_edges_box(bus, "Roof", Vector3(-0.4, y0 + 3.16, 0), Vector3(length - 1.6, 0.14, width - 0.3), depot_edges_paint("8c8b82"))
	depot_edges_box(bus, "RoofPod", Vector3(1.6, y0 + 3.33, 0), Vector3(2.4, 0.22, 1.6), depot_edges_paint("7a7b74"))
	depot_edges_box(bus, "RoofHatch", Vector3(-2.6, y0 + 3.25, 0), Vector3(0.8, 0.06, 0.7), depot_edges_paint("6c6d67"))
	var livery: Material = depot_edges_paint(band_hex)
	var accent: Material = depot_edges_paint("b88a3c")
	var tyre: Material = depot_edges_paint("1b1d1e")
	var hub: Material = depot_edges_paint("8d8f8a")
	var pillar_paint: Material = depot_edges_paint(body_hex)
	var cabin: Material = depot_edges_glow("cfe6d2", 0.3)
	for side: float in [-1.0, 1.0]:
		var face: float = side * half_w
		depot_edges_box(bus, "WindowStrip", Vector3(-0.3, y0 + 2.25, face + side * 0.005), Vector3(length - 2.0, 0.92, 0.02), depot_edges_glass("252c30"))
		# Window pillars, just outside any cabin overlay so they frame the lit glass.
		var px: float = -4.4
		while px <= 3.9:
			depot_edges_box(bus, "Pillar", Vector3(px, y0 + 2.25, face + side * 0.035), Vector3(0.09, 0.96, 0.02), pillar_paint)
			px += 1.17
		for lx: Variant in lit_windows:
			depot_edges_box(bus, "CabinLit", Vector3(float(lx), y0 + 2.25, face + side * 0.014), Vector3(1.05, 0.84, 0.006), cabin)
		# Livery: the lower panel in the line's colour, an amber stripe under the windows.
		depot_edges_box(bus, "Livery", Vector3(0, y0 + 1.18, face + side * 0.006), Vector3(length - 0.04, 0.56, 0.02), livery)
		depot_edges_box(bus, "Stripe", Vector3(0, y0 + 1.56, face + side * 0.008), Vector3(length - 0.04, 0.07, 0.02), accent)
		depot_edges_box(bus, "Gutter", Vector3(-0.3, y0 + 2.78, face + side * 0.01), Vector3(length - 1.0, 0.05, 0.03), dark)
		# Skirts between the wheel openings, wheels with hubs, arches over them.
		for span: Vector2 in [Vector2(-5.15, -3.75), Vector2(-2.45, 2.55), Vector2(3.85, 5.15)]:
			depot_edges_box(bus, "Skirt", Vector3((span.x + span.y) * 0.5, y0 + 0.67, face - side * 0.02), Vector3(span.y - span.x, 0.5, 0.04), livery)
		for wx: float in [-3.1, 3.2]:
			depot_edges_cylinder(bus, "Wheel", Vector3(wx, y0 + 0.48, side * (half_w - 0.16)), 0.48, 0.3, tyre, 14, Vector3(90, 0, 0))
			depot_edges_cylinder(bus, "Hub", Vector3(wx, y0 + 0.48, side * (half_w + 0.005)), 0.2, 0.03, hub, 10, Vector3(90, 0, 0))
			depot_edges_box(bus, "Arch", Vector3(wx, y0 + 0.97, face + side * 0.012), Vector3(1.36, 0.1, 0.04), dark)
		# Mirrors on forward arms, the bunny ears every micro wears.
		depot_edges_box(bus, "MirrorArm", Vector3(half_l + 0.15, y0 + 2.7, face + side * 0.08), Vector3(0.5, 0.04, 0.04), dark)
		depot_edges_box(bus, "Mirror", Vector3(half_l + 0.4, y0 + 2.45, face + side * 0.12), Vector3(0.06, 0.45, 0.22), dark)
		# Rear lamps at the corners.
		depot_edges_box(bus, "RearLamp", Vector3(-half_l - 0.01, y0 + 1.1, side * 0.98), Vector3(0.02, 0.32, 0.22), depot_edges_paint("6b3a33"))
		depot_edges_box(bus, "Headlamp", Vector3(half_l + 0.02, y0 + 1.0, side * 0.85), Vector3(0.03, 0.18, 0.32), depot_edges_paint("9c977f"))
	# Nose and tail: windscreen under the route board, rear window, bumpers, plate.
	depot_edges_box(bus, "Windscreen", Vector3(half_l + 0.005, y0 + 2.05, 0), Vector3(0.02, 1.4, width - 0.3), depot_edges_glass("2a3236"))
	depot_edges_box(bus, "RearWindow", Vector3(-half_l - 0.005, y0 + 2.35, 0), Vector3(0.02, 0.75, width - 0.6), depot_edges_glass("2a3236"))
	for end: float in [-1.0, 1.0]:
		depot_edges_box(bus, "Bumper", Vector3(end * (half_l + 0.07), y0 + 0.62, 0), Vector3(0.16, 0.3, width + 0.04), depot_edges_paint("2d3031"))
	depot_edges_box(bus, "Plate", Vector3(-half_l - 0.16, y0 + 0.62, 0), Vector3(0.02, 0.15, 0.42), depot_edges_paint("c9c4b0"))
	# LED boards: front over the windscreen, rear, and the side board by the front door. Dim amber-white.
	var board: Material = depot_edges_paint("1c1f20")
	depot_edges_box(bus, "FrontSignBox", Vector3(half_l + 0.02, y0 + 2.93, 0), Vector3(0.03, 0.26, 1.8), board)
	depot_edges_box(bus, "RearSignBox", Vector3(-half_l - 0.02, y0 + 2.92, 0), Vector3(0.03, 0.26, 1.1), board)
	depot_edges_box(bus, "SideSignBox", Vector3(3.0, y0 + 2.85, half_w + 0.02), Vector3(2.0, 0.26, 0.03), board)
	if not dark_signs:
		depot_edges_text(bus, sign_words, Vector3(half_l + 0.04, y0 + 2.93, 0), 0.12, "d9c9a0", true, 90.0)
		depot_edges_text(bus, sign_words, Vector3(3.0, y0 + 2.85, half_w + 0.04), 0.12, "d9c9a0", true)
		depot_edges_text(bus, "08", Vector3(-half_l - 0.04, y0 + 2.92, 0), 0.15, "d9c9a0", true, -90.0)
	else:
		# Dead LED matrix: the grid is visible, nothing lit.
		depot_edges_box(bus, "SideSignDead", Vector3(3.0, y0 + 2.85, half_w + 0.035), Vector3(1.9, 0.18, 0.005), depot_edges_glow("d9c9a0", 0.0))
	depot_edges_box(bus, "FrontDoor", Vector3(3.9, y0 + 1.5, half_w + 0.012), Vector3(1.0, 2.2, 0.02), depot_edges_glass("2b3236"))


## The electric micros' chargers (ServiceArchitecture's "MemoryCoolingBank") carry their own cyan
## LEDs; this only hangs the neon marker in front of them so DepotLighting gives the LEDs a light.
func depot_edges_build_chargers() -> void:
	var chargers := trial.find_child("MemoryCoolingBank", true, false) as Node3D
	if chargers == null:
		return
	var holder := Node3D.new()
	holder.name = "ChargerNeon"
	add_child(holder)
	holder.global_transform = chargers.global_transform
	depot_edges_marker(holder, "ChargerLeds", Vector3(0.0, 1.9, 1.0), Vector3(0.0, 0.4, 4.0))


## Corrugated zinc closing the lot behind the micros: one painted mural panel, the scrap buyer's
## lettering, a sheet lifted where the dogs dug under.
func depot_edges_build_zinc(east: Node3D) -> void:
	var line_a: float = 32.4
	var from_b: float = -11.0
	var to_b: float = 5.4
	var sheets: Array[Transform3D] = []
	var tints: Array[Color] = []
	var b: float = from_b + 0.45
	var i: int = 0
	while b < to_b:
		var lean: float = sin(float(i) * 1.7) * 1.6
		var lift: float = 0.22 if absf(b - (-4.4)) < 0.5 else 0.0
		var height: float = 2.25 + 0.1 * sin(float(i) * 2.9) - lift
		sheets.append(Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(lean))).scaled(Vector3(0.04, height, 0.9)), Vector3(line_a, FLOOR_Y + lift + height * 0.5, -b)))
		tints.append([Color("6f7270"), Color("7b6c5d"), Color("676560"), Color("84837c"), Color("725f52")][(i * 3) % 5])
		b += 0.86
		i += 1
	depot_edges_multimesh(east, "ZincSheets", depot_edges_unit_box(), sheets, depot_edges_vertex_paint("zinc"), tints)
	var fence := depot_edges_box(east, "ZincCollider", Vector3(line_a, FLOOR_Y + 1.12, -(from_b + to_b) * 0.5), Vector3(0.12, 2.25, to_b - from_b), depot_edges_paint("6f7270"), true)
	fence.visible = false
	var post_b: float = from_b
	while post_b <= to_b:
		depot_edges_box(east, "ZincPost", Vector3(line_a - 0.08, FLOOR_Y + 1.2, -post_b), Vector3(0.1, 2.4, 0.1), depot_edges_paint("4f5655"))
		post_b += 2.75
	# The dug hole under the lifted sheet.
	depot_edges_box(east, "DugHole", Vector3(line_a - 0.35, FLOOR_Y + 0.004, 4.4), Vector3(0.9, 0.01, 0.8), depot_edges_paint("1c1a18"))
	# Mural: three sheets painted by the neighbourhood: a cerro at dusk, houses, a dog. No words.
	var face: float = line_a - 0.05
	var mural := depot_edges_frame("Mural", Vector3(face, FLOOR_Y, 1.4), -90.0, east)
	depot_edges_box(mural, "Sky", Vector3(0, 1.4, 0), Vector3(2.6, 1.5, 0.01), depot_edges_paint("6a6f78"))
	depot_edges_box(mural, "Dusk", Vector3(0, 1.85, 0.003), Vector3(2.6, 0.5, 0.01), depot_edges_paint("8a7466"))
	depot_edges_box(mural, "Sun", Vector3(0.6, 1.75, 0.006), Vector3(0.42, 0.42, 0.01), depot_edges_paint("b29a6a"))
	depot_edges_box(mural, "CerroLeft", Vector3(-0.6, 1.0, 0.009), Vector3(1.6, 0.9, 0.01), depot_edges_paint("4c5a4d"), false, Vector3(0, 0, 18))
	depot_edges_box(mural, "CerroRight", Vector3(0.7, 0.9, 0.012), Vector3(1.4, 0.7, 0.01), depot_edges_paint("55604f"), false, Vector3(0, 0, -14))
	for h: int in 6:
		depot_edges_box(mural, "House", Vector3(-1.0 + float(h) * 0.38, 0.95 + float(h % 3) * 0.14, 0.015), Vector3(0.16, 0.13, 0.01), depot_edges_paint(["a8907a", "8f8f84", "9b7f6c"][h % 3]))
	depot_edges_box(mural, "Dog", Vector3(-0.5, 0.42, 0.018), Vector3(0.36, 0.16, 0.01), depot_edges_paint("3d3530"))
	depot_edges_box(mural, "DogHead", Vector3(-0.3, 0.52, 0.018), Vector3(0.12, 0.12, 0.01), depot_edges_paint("3d3530"))
	depot_edges_text(mural, "J.R.", Vector3(1.05, 0.35, 0.02), 0.06, "c9c1ad")
	# The scrap buyer's lettering, brushed straight on the zinc.
	var buyer := depot_edges_frame("CompoChatarra", Vector3(face - 0.01, FLOOR_Y, -1.6), -90.0, east)
	depot_edges_text(buyer, "COMPRO\nCHATARRA", Vector3(0, 1.45, 0), 0.32, "d6d0bf")
	depot_edges_text(buyer, "- FIERRO  COBRE  BATERÍAS -", Vector3(0, 0.75, 0), 0.08, "cfc8b4")
	var wood := depot_edges_frame("LenaSign", Vector3(face - 0.01, FLOOR_Y, 8.6), -90.0, east)
	depot_edges_text(wood, "SE VENDE LEÑA", Vector3(0, 1.3, 0), 0.16, "cbc4b0")


# --- South: the canal behind the perimeter ----------------------------------------------------------

## The canal runs just outside the south perimeter (z = 28): low railing, the channel, the far bank.
## The perimeter collider already stops everyone at the railing; the torn section is bent, not open.
func depot_edges_build_canal() -> void:
	var canal := depot_edges_frame("Canal", Vector3.ZERO, 0.0)
	var concrete: Material = depot_edges_paint("6e6c64")
	var edge_z: float = 28.25
	var width: float = 3.2
	var x_from: float = -34.0
	var x_to: float = 34.0
	var length: float = x_to - x_from
	var mid_x: float = (x_from + x_to) * 0.5
	# Coping on both banks, inner walls, dark water well below the yard.
	depot_edges_box(canal, "NearCoping", Vector3(mid_x, FLOOR_Y - 0.04, edge_z + 0.25), Vector3(length, 0.16, 0.5), concrete)
	depot_edges_box(canal, "FarCoping", Vector3(mid_x, FLOOR_Y - 0.04, edge_z + width + 0.75), Vector3(length, 0.16, 0.5), concrete)
	depot_edges_box(canal, "NearWall", Vector3(mid_x, -0.9, edge_z + 0.48), Vector3(length, 1.85, 0.06), depot_edges_paint("4e4d47"))
	depot_edges_box(canal, "FarWall", Vector3(mid_x, -0.9, edge_z + width + 0.52), Vector3(length, 1.85, 0.06), depot_edges_paint("55544d"))
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("161d20")
	water.roughness = 0.08
	water.metallic_specular = 0.8
	depot_edges_box(canal, "Water", Vector3(mid_x, -1.25, edge_z + 0.5 + width * 0.5), Vector3(length, 0.02, width), water)
	depot_edges_box(canal, "FarBank", Vector3(mid_x, -0.4, edge_z + width + 4.0), Vector3(length, 0.8, 6.0), depot_edges_paint("3a3d39"))
	# Low railing on the yard side: posts and two rails, bent outward at the torn section.
	var torn := Vector2(2.0, 6.4)
	var posts: Array[Transform3D] = []
	var x: float = x_from + 0.5
	while x < x_to:
		var in_tear: bool = x > torn.x and x < torn.y
		var basis := Basis.IDENTITY
		if in_tear:
			basis = Basis.from_euler(Vector3(deg_to_rad(28.0 + 10.0 * sin(x * 3.0)), 0, deg_to_rad(8.0 * cos(x * 2.0))))
		posts.append(Transform3D(basis.scaled(Vector3(0.06, 0.85, 0.06)), Vector3(x, FLOOR_Y + 0.42, edge_z + 0.12 + (0.18 if in_tear else 0.0))))
		x += 2.0
	depot_edges_multimesh(canal, "RailPosts", depot_edges_unit_box(), posts, depot_edges_paint("5b6563"))
	for y: float in [0.45, 0.85]:
		depot_edges_box(canal, "RailWest", Vector3((x_from + torn.x) * 0.5, FLOOR_Y + y, edge_z + 0.12), Vector3(torn.x - x_from, 0.045, 0.045), depot_edges_paint("5b6563"))
		depot_edges_box(canal, "RailEast", Vector3((torn.y + x_to) * 0.5, FLOOR_Y + y, edge_z + 0.12), Vector3(x_to - torn.y, 0.045, 0.045), depot_edges_paint("5b6563"))
	# The torn rails hang into the channel.
	depot_edges_box(canal, "TornRailA", Vector3(torn.x + 1.0, FLOOR_Y + 0.25, edge_z + 0.55), Vector3(2.1, 0.045, 0.045), depot_edges_paint("5b6563"), false, Vector3(35, -8, -12))
	depot_edges_box(canal, "TornRailB", Vector3(torn.y - 1.1, FLOOR_Y + 0.1, edge_z + 0.7), Vector3(2.0, 0.045, 0.045), depot_edges_paint("5b6563"), false, Vector3(48, 10, 16))
	# Culvert in the channel's yard-side wall under the tear (its face looks south, at the camera),
	# grate pried open: where the drowned came up.
	var culvert := depot_edges_frame("Culvert", Vector3((torn.x + torn.y) * 0.5, 0, edge_z + 0.52), 0.0, canal)
	depot_edges_box(culvert, "Mouth", Vector3(0, -0.85, 0.02), Vector3(1.5, 1.0, 0.04), depot_edges_paint("101415"))
	var grate: Array[Transform3D] = []
	for i: int in 9:
		grate.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.04, 1.0, 0.04)), Vector3(-0.64 + float(i) * 0.16, -0.85, 0.06)))
	var hinge := Node3D.new()
	hinge.name = "GrateHinge"
	culvert.add_child(hinge)
	hinge.position = Vector3(0, -0.35, 0.05)
	hinge.rotation_degrees.x = -62.0
	for t: Transform3D in grate:
		t.origin.y += 0.5
		t.origin.z -= 0.05
	depot_edges_multimesh(hinge, "Grate", depot_edges_unit_box(), grate, depot_edges_paint("3c4442"))
	# Canal plates wired to the railing, lettered on the side the camera sees.
	var signs := [{"x": -10.0, "text": "PROHIBIDO BOTAR\nBASURA"}, {"x": 12.0, "text": "PELIGRO —\nNO BAÑARSE"}]
	for spec: Dictionary in signs:
		var plate_at := Vector3(spec["x"], FLOOR_Y + 0.62, edge_z + 0.16)
		depot_edges_box(canal, "CanalPlate", plate_at, Vector3(0.9, 0.42, 0.02), depot_edges_paint("c4beaa"))
		var label := depot_edges_text(canal, spec["text"], plate_at + Vector3(0, 0, 0.015), 0.06, "3a3532")
		label.name = "CanalPlateText"


# --- Background: the cerro ---------------------------------------------------------------------------

## A cerro across the low district, beyond the north buildings: dark slopes, scattered dim windows of
## the población, a switchback road. Seen in the wide views; the relief comes down its road.
var cerro_road: PackedVector3Array = PackedVector3Array()

func depot_edges_build_cerro() -> void:
	var cerro := depot_edges_frame("Cerro", EDGE_ORIGIN, EDGE_YAW)
	# Height field in the edge frame: a ridge rising from the low district.
	var columns: int = 28
	var rows: int = 12
	var a_span := Vector2(-150.0, 150.0)
	var b_span := Vector2(70.0, 190.0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights: Array[PackedFloat32Array] = []
	for r: int in rows + 1:
		var row := PackedFloat32Array()
		for c: int in columns + 1:
			var a: float = lerpf(a_span.x, a_span.y, float(c) / columns)
			var b: float = lerpf(b_span.x, b_span.y, float(r) / rows)
			row.append(depot_edges_cerro_height(a, b))
		heights.append(row)
	for r: int in rows:
		for c: int in columns:
			var quad: Array[Vector3] = []
			for corner: Vector2i in [Vector2i(c, r), Vector2i(c + 1, r), Vector2i(c + 1, r + 1), Vector2i(c, r + 1)]:
				var a: float = lerpf(a_span.x, a_span.y, float(corner.x) / columns)
				var b: float = lerpf(b_span.x, b_span.y, float(corner.y) / rows)
				quad.append(Vector3(a, heights[corner.y][corner.x], -b))
			for index: int in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(quad[index])
	surface.generate_normals()
	var hill := MeshInstance3D.new()
	hill.name = "CerroSlopes"
	hill.mesh = surface.commit()
	hill.material_override = depot_edges_paint("232c2a")
	hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cerro.add_child(hill)
	# Switchback road: five legs across the face, each a little lower and nearer.
	var legs: Array[Vector2] = [Vector2(-40, 178), Vector2(30, 165), Vector2(-25, 148), Vector2(35, 132), Vector2(-15, 116), Vector2(42, 100), Vector2(20, 86), Vector2(30, 72)]
	cerro_road = PackedVector3Array()
	for leg: Vector2 in legs:
		cerro_road.append(Vector3(leg.x, depot_edges_cerro_height(leg.x, leg.y) + 0.4, -leg.y))
	var road_parts: Array[Transform3D] = []
	for i: int in cerro_road.size() - 1:
		var p: Vector3 = cerro_road[i]
		var q: Vector3 = cerro_road[i + 1]
		var steps: int = int(p.distance_to(q) / 6.0) + 1
		for s: int in steps:
			var u: Vector3 = p.lerp(q, (float(s) + 0.5) / steps)
			u.y = depot_edges_cerro_height(u.x, -u.z) + 0.25
			var dir: Vector3 = (q - p).normalized()
			var basis := Basis.looking_at(dir, Vector3.UP).scaled(Vector3(3.2, 0.2, p.distance_to(q) / steps + 0.4))
			road_parts.append(Transform3D(basis, u))
	var road := depot_edges_multimesh(cerro, "SwitchbackRoad", depot_edges_unit_box(), road_parts, depot_edges_paint("4b4c46"))
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Street lamps along the road, every other one dead.
	var lamps: Array[Transform3D] = []
	for i: int in cerro_road.size() - 1:
		var p: Vector3 = cerro_road[i]
		var q: Vector3 = cerro_road[i + 1]
		for s: int in 3:
			var u: Vector3 = p.lerp(q, (float(s) + 0.5) / 3.0)
			if (i + s) % 2 == 0:
				lamps.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.6, 0.6, 0.6)), u + Vector3(0, 3.2, 0)))
	var lamp_glow := depot_edges_multimesh(cerro, "RoadLamps", depot_edges_unit_box(), lamps, depot_edges_glow("d8c46a", 0.7))
	lamp_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The población: scattered dim windows, warm and fluorescent, thinning toward the ridge.
	var windows: Array[Transform3D] = []
	var tints: Array[Color] = []
	var seed_value: int = 20261031
	for i: int in 340:
		seed_value = (seed_value * 1103515245 + 12345) % 2147483648
		var a: float = lerpf(-140.0, 140.0, float(seed_value % 10000) / 10000.0)
		seed_value = (seed_value * 1103515245 + 12345) % 2147483648
		var b: float = lerpf(74.0, 175.0, pow(float(seed_value % 10000) / 10000.0, 1.4))
		if absf(a - 10.0) < 4.0: continue
		var h: float = depot_edges_cerro_height(a, b)
		windows.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.1, 0.8, 0.3)), Vector3(a, h + 1.2, -b)))
		tints.append([Color("d6b183"), Color("c9a76f"), Color("bfcdbf"), Color("d0b48a")][i % 4])
	var lit := depot_edges_multimesh(cerro, "PoblacionWindows", depot_edges_unit_box(), windows, depot_edges_window_glow(), tints)
	lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func depot_edges_window_glow() -> StandardMaterial3D:
	if not _materials.has("window_glow"):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(0.25, 0.25, 0.25)
		material.emission_enabled = true
		material.emission = Color(0.85, 0.75, 0.6)
		material.emission_energy_multiplier = 0.55
		material.roughness = 0.8
		_materials["window_glow"] = material
	return _materials["window_glow"]


## The cerro rises from the low district (about 34 m below the yard) toward a ridge far behind.
static func depot_edges_cerro_height(a: float, b: float) -> float:
	var rise: float = clampf((b - 70.0) / 120.0, 0.0, 1.0)
	var ridge: float = -34.0 + 62.0 * pow(rise, 0.8)
	var shoulders: float = 6.0 * sin(a * 0.025 + 0.6) + 3.0 * sin(a * 0.07 + b * 0.03)
	var flank: float = -10.0 * pow(clampf(absf(a) / 150.0, 0.0, 1.0), 2.0)
	return ridge + shoulders * rise + flank
