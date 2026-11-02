## The depot's light: only fixtures you can point at, in a palette that leaves the UI colours to the game.
## Built last over the district trial; everything it adds or hides is undone by clear().
##
## Hierarchy: the yard mast is the key (high-pressure sodium, ~2000 K orange; one head dead, one
## flickering); the taller's open roll-up door, the caseta/gate and the micro the night cleaner is
## working in over the bays are local secondaries; the edges' neon gets small lights of its own
## colour; the sky is a moonlit overcast that keeps the shadows a legible cool blue-grey
## (district_lighting.gd). Volumetric scattering exists only in
## the fog volumes at the mast crown and the taller door, so every beam starts at its fixture.
extends Node3D

## Where the yard's light mast stands (world, floor level). Off every keep-clear point (>= 6.9 m),
## outside the spawn ring around (0,-2) (9.6 m), off the N-S and E-W lanes through the centre,
## 5.7 m from the scrap store (3,-5). DepotYard may dress its base with scrap (keep 0.6 m round
## the plinth free so the collider stays honest).
const MAST_POSITION := Vector3(4.5, 0.06, -10.5)
## 9.5 m keeps the crown inside the gameplay frame (FOV 38 is horizontal; the vertical field is narrow).
const MAST_HEIGHT := 9.5
## The combat centre the key is aimed at.
const YARD_CENTRE := Vector3(0.0, 0.06, -2.0)
const SODIUM := Color("ff9a40")
const FLUORESCENT := Color("cfe6d2")
const TUNGSTEN := Color("d6b183")
## Mast key energies (Godot spot units at ~12 m).
const KEY_ENERGY := 110.0
const FLICKER_ENERGY := 60.0
const BAY_ENERGY := 45.0
## Where head 1 is aimed: the apron in front of the bays (yard u 16.5, v -0.5), where the
## micros back out. Clear of the lane and of the water source at (14.5, -8).
const BAY_APRON := Vector3(13.3, 0.06, -9.8)
## The parked micro whose cabin lights are on over the bays (DepotEdges' EastLot), and its tubes.
const CABIN_MICRO := "ParkedMicro2"
const CABIN_TUBE := Color("d9ecdf")

var trial: Node3D
var arena: Node3D
var mast: Node3D
var key_light: SpotLight3D
var flicker_light: SpotLight3D
var flicker_glass: StandardMaterial3D
var _materials: Dictionary = {}
var _flicker_time: float = 0.0
var gate_lamp: SpotLight3D
var _tv_light: OmniLight3D
## The caseta TV screen's material (DepotEdges'); the TV light follows its cuts.
var _tv_screen: StandardMaterial3D
## Neon that buzzes: [light, base energy, phase, glass material or null] per flickering sign.
var _neon_flicker: Array[Array] = []


func setup(owner_arena: Node, owner_trial: Node3D) -> void:
	arena = owner_arena as Node3D
	trial = owner_trial
	process_mode = Node.PROCESS_MODE_PAUSABLE
	depot_lighting_retire_unmotivated()
	depot_lighting_sweep_emissives()
	depot_lighting_build_mast()
	depot_lighting_build_secondaries()


func clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	key_light = null
	flicker_light = null
	set_process(false)


## The district already retired its fixtureless pools (district_lighting.gd). What is left of the
## old atmosphere -- broad haze volumes that lit nothing in particular -- goes too, reversibly
## through the trial's atmosphere list so F6 still swaps presentations.
func depot_lighting_retire_unmotivated() -> void:
	var listed: Dictionary = {}
	for item: Dictionary in trial.atmosphere_changes:
		listed[item["node"]] = true
	for node: Node in arena.find_children("*", "FogVolume", true, false):
		if listed.has(node) or is_ancestor_of(node): continue
		trial.atmosphere_changes.append({"node": node, "visible": node.visible})
		listed[node] = true
	# The near "lens motes" are 0.7 m out-of-focus discs 14 m in front of the lens; in a dark
	# rain frame they read as grey smudges with no cause. The finer dust layers stay.
	var dust: Node = arena.get("cinematic_dust")
	if dust != null:
		for emitter: GPUParticles3D in dust.layers:
			if emitter.name == &"LensMotes" and not listed.has(emitter):
				trial.atmosphere_changes.append({"node": emitter, "visible": emitter.visible})


## Legacy environment emissives (not the depot's own geometry, not gameplay) are pulled into the
## environment's three light roles: cyan/teal tubes become fluorescent white-green, violet and
## rose become dim tungsten, saturated orange becomes tungsten. Reversible: the material's own
## emission is remembered on the district switch, so F6 restores it.
func depot_lighting_sweep_emissives() -> void:
	var skip: Array[Node] = []
	for id: String in ["DepotYard", "DepotEdges"]:
		var node: Node = trial.get_node_or_null(id)
		if node != null: skip.append(node)
	var done: Dictionary = {}
	for node: Node in arena.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or is_ancestor_of(mesh): continue
		var excluded: bool = false
		for root: Node in skip:
			if root.is_ancestor_of(mesh): excluded = true
		if excluded: continue
		var materials: Array[Material] = []
		if mesh.material_override != null: materials.append(mesh.material_override)
		else:
			for surface: int in mesh.mesh.get_surface_count():
				var found: Material = mesh.get_active_material(surface)
				if found != null: materials.append(found)
		for material: Material in materials:
			var lit := material as StandardMaterial3D
			if lit == null or done.has(lit) or not lit.emission_enabled or lit.emission_texture != null: continue
			done[lit] = true
			var role: Variant = depot_lighting_role(lit.emission)
			if role == null: continue
			var energy: float = lit.emission_energy_multiplier * (0.8 if role == FLUORESCENT else 0.6)
			trial.district_lighting.remember(lit, "emission", role)
			trial.district_lighting.remember(lit, "emission_energy_multiplier", energy)


## The environment role for a reserved signal hue, or null when the colour is already in band.
func depot_lighting_role(color: Color) -> Variant:
	if color.s < 0.3 or color.v < 0.05: return null
	var hue: float = color.h * 360.0
	if hue >= 150.0 and hue <= 225.0: return FLUORESCENT
	if hue > 225.0 or hue < 12.0: return TUNGSTEN.darkened(0.25)
	if hue >= 12.0 and hue < 42.0 and color.s > 0.45: return TUNGSTEN
	return null


func depot_lighting_material(id: String, color: Color, emission: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	if _materials.has(id):
		return _materials[id]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.25
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[id] = material
	return material


func depot_lighting_box(parent: Node3D, id: String, at: Vector3, size: Vector3, material: Material, shadows: bool = true) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = id
	var shape := BoxMesh.new()
	shape.size = size
	part.mesh = shape
	part.position = at
	part.material_override = material
	if not shadows:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


func depot_lighting_cylinder(parent: Node3D, id: String, at: Vector3, radius_bottom: float, radius_top: float, height: float, material: Material, segments: int = 10) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = id
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius_bottom
	shape.top_radius = radius_top
	shape.height = height
	shape.radial_segments = segments
	shape.rings = 1
	part.mesh = shape
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part


## A tall thin galvanised mast on a concrete plinth, a square crown and four cobra heads. Head 0
## faces the combat centre and carries the key; head 1 is steady and only glows; head 2 (facing
## the back fence) is dead; head 3 (toward the west current store) flickers and carries a second,
## smaller shadowed pool. Two shadowed spots replace seven shadowed floodlight cuts.
func depot_lighting_build_mast() -> void:
	mast = Node3D.new()
	mast.name = "YardLightMast"
	add_child(mast)
	mast.global_position = MAST_POSITION
	var steel: Material = trial._paint("707a7c", false, false, true)
	var concrete: Material = trial._paint("7f7b72", false, false, true)
	var housing: Material = trial._paint("3c4346")
	var conduit: Material = trial._paint("2f3436")
	# Plinth and pole.
	depot_lighting_box(mast, "Plinth", Vector3(0, 0.22, 0), Vector3(0.9, 0.44, 0.9), concrete)
	depot_lighting_box(mast, "BasePlate", Vector3(0, 0.47, 0), Vector3(0.56, 0.06, 0.56), steel)
	depot_lighting_cylinder(mast, "Pole", Vector3(0, 0.5 + (MAST_HEIGHT - 0.5) * 0.5, 0), 0.19, 0.1, MAST_HEIGHT - 0.5, steel)
	# Service hatch with the depot's seal: a pale paper strip across a cabinet bolted to the pole.
	var toward_centre: Vector3 = (YARD_CENTRE - MAST_POSITION) * Vector3(1, 0, 1)
	toward_centre = toward_centre.normalized()
	var hatch := Node3D.new()
	hatch.name = "ServiceHatch"
	mast.add_child(hatch)
	hatch.look_at_from_position(Vector3(0, 1.35, 0), Vector3(0, 1.35, 0) + toward_centre, Vector3.UP)
	depot_lighting_box(hatch, "Cabinet", Vector3(0, 0, -0.27), Vector3(0.34, 0.52, 0.16), housing)
	depot_lighting_box(hatch, "Seal", Vector3(0.0, 0.04, -0.356), Vector3(0.08, 0.36, 0.012), depot_lighting_material("seal_paper", Color("b9b09a")))
	# Cable conduit running up the shadow side of the pole into the crown.
	depot_lighting_cylinder(mast, "Conduit", Vector3(-toward_centre.x * 0.2, 6.0, -toward_centre.z * 0.2), 0.045, 0.045, 10.6, conduit, 6)
	# Crown: a square frame on four short arms.
	var crown := Node3D.new()
	crown.name = "Crown"
	mast.add_child(crown)
	crown.position = Vector3(0, MAST_HEIGHT, 0)
	crown.rotation.y = atan2(toward_centre.x, toward_centre.z)
	depot_lighting_box(crown, "RingNS", Vector3(0, 0, 0), Vector3(0.12, 0.1, 1.9), steel)
	depot_lighting_box(crown, "RingEW", Vector3(0, 0, 0), Vector3(1.9, 0.1, 0.12), steel)
	depot_lighting_cylinder(crown, "Cap", Vector3(0, 0.12, 0), 0.16, 0.12, 0.24, housing, 8)
	var sodium_glass := depot_lighting_material("sodium_glass", SODIUM, 5.0, 0.4)
	var dead_glass := depot_lighting_material("dead_glass", Color("38362e"), 0.0, 0.35)
	flicker_glass = depot_lighting_material("flicker_glass", SODIUM, 5.0, 0.4).duplicate()
	for index: int in 4:
		var head := Node3D.new()
		head.name = "Head%d" % index
		crown.add_child(head)
		# Local +Z of the crown points at the yard centre; heads go round in 90 degree steps.
		var yaw: float = float(index) * PI * 0.5
		head.position = Vector3(sin(yaw), 0, cos(yaw)) * 0.98
		head.rotation = Vector3(0, yaw, 0)
		var tilt := Node3D.new()
		tilt.name = "Tilt"
		head.add_child(tilt)
		tilt.rotation.x = deg_to_rad(18.0)
		depot_lighting_box(tilt, "Housing", Vector3(0, 0, 0.24), Vector3(0.42, 0.16, 0.66), housing)
		var glass: Material = sodium_glass
		if index == 2: glass = dead_glass
		elif index == 3: glass = flicker_glass
		# The refractor bowl hangs below the housing so its sides glow toward the camera.
		depot_lighting_box(tilt, "Refractor", Vector3(0, -0.13, 0.27), Vector3(0.32, 0.12, 0.5), glass, false)
	# Key: head 0, steady, aimed a little inside the yard so one broad soft pool holds the centre.
	key_light = depot_lighting_spot("MastKeyCentre", crown.global_transform * Vector3(0, -0.25, 1.2), MAST_POSITION + toward_centre * 10.0, SODIUM, KEY_ENERGY, 40.0, 30.0)
	# Second pool: head 3, flickering, toward the west current store and the gate approach.
	var west: Vector3 = toward_centre.rotated(Vector3.UP, -PI * 0.5)
	flicker_light = depot_lighting_spot("MastKeyFlicker", crown.global_transform * Vector3(-1.2, -0.25, 0), MAST_POSITION + west * 5.0 + toward_centre * 2.5, SODIUM.lerp(Color("f08a3a"), 0.4), FLICKER_ENERGY, 36.0, 26.0)
	# Third pool: head 1 faces the bays. Unshadowed: from 9.5 m the micros' shadows would fall
	# under their own noses anyway, and the yard keeps its two shadowed lights.
	var bay_light := depot_lighting_spot("MastKeyBays", crown.global_transform * Vector3(1.2, -0.25, 0), BAY_APRON, SODIUM, BAY_ENERGY, 38.0, 26.0)
	bay_light.shadow_enabled = false
	# Volumetric scattering only at the crown: the heads read as sources in the rain.
	var haze := FogVolume.new()
	haze.name = "MastHeadRain"
	haze.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	haze.size = Vector3(4.2, 2.4, 4.2)
	var fog := FogMaterial.new()
	fog.density = 0.07
	fog.albedo = Color("c8c2ba")
	fog.height_falloff = 0.0
	fog.edge_fade = 0.6
	haze.material = fog
	mast.add_child(haze)
	haze.position = Vector3(0, MAST_HEIGHT - 1.0, 0)
	# Solid plinth and pole, toggled with the presentation like every other replacement collider.
	var body := StaticBody3D.new()
	body.name = "MastCollision"
	mast.add_child(body)
	var plinth_shape := CollisionShape3D.new()
	var plinth_box := BoxShape3D.new()
	plinth_box.size = Vector3(0.9, 0.44, 0.9)
	plinth_shape.shape = plinth_box
	plinth_shape.position = Vector3(0, 0.22, 0)
	body.add_child(plinth_shape)
	var pole_shape := CollisionShape3D.new()
	var pole_cylinder := CylinderShape3D.new()
	pole_cylinder.radius = 0.19
	pole_cylinder.height = MAST_HEIGHT - 0.5
	pole_shape.shape = pole_cylinder
	pole_shape.position = Vector3(0, 0.5 + (MAST_HEIGHT - 0.5) * 0.5, 0)
	body.add_child(pole_shape)
	trial.replacement_collisions.append(plinth_shape)
	trial.replacement_collisions.append(pole_shape)


## A downward sodium head: broad soft cone, shadowed, lights every layer (actors included).
func depot_lighting_spot(id: String, at: Vector3, target: Vector3, color: Color, energy: float, angle: float, reach: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = id
	add_child(light)
	light.global_position = at
	light.look_at(target, Vector3.FORWARD if absf((target - at).normalized().y) > 0.99 else Vector3.UP)
	light.light_color = color
	light.light_energy = energy
	light.light_specular = 0.35
	light.light_volumetric_fog_energy = 1.0
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = 0.9
	light.spot_angle_attenuation = 0.55
	light.light_size = 0.12
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.2
	return light


## Small, local, unshadowed secondaries, hung on the fixtures DepotEdges built. It publishes a
## Marker3D per fixture (group "depot_light_markers", meta "depot_light"); -Z of each marker points
## where the light goes. A fixture that is missing simply gets no light: nothing here glows
## without something to point at.
func depot_lighting_build_secondaries() -> void:
	var edges: Node = trial.get_node_or_null("DepotEdges")
	if edges == null:
		return
	var found: Dictionary = {}
	for node: Node in edges.find_children("LightMarker_*", "Marker3D", true, false):
		if node.has_meta("depot_light"): found[str(node.get_meta("depot_light"))] = node
	if found.has("TallerDoor"): depot_lighting_door_spill(found["TallerDoor"])
	if found.has("CasetaWindow") and found.has("CasetaEave"):
		depot_lighting_caseta(found["CasetaWindow"], found["CasetaEave"])
		_tv_screen = edges.get("_tv_glass") as StandardMaterial3D
	if found.has("GateLamp"): depot_lighting_gate(found["GateLamp"], edges)
	if found.has("FuenteDeSoda"):
		# Across the street: the soda fountain's tubes wash the sidewalk under its fascia.
		var soda := depot_lighting_local_spot("FuenteDeSodaSpill", found["FuenteDeSoda"], FLUORESCENT, 2.2, 7.0, 55.0)
		soda.spot_angle_attenuation = 0.7
	if found.has("Botilleria"):
		var shop := OmniLight3D.new()
		shop.name = "BotilleriaInterior"
		add_child(shop)
		shop.global_position = found["Botilleria"].global_position
		shop.light_color = TUNGSTEN
		shop.light_energy = 0.7
		shop.omni_range = 3.6
		shop.light_specular = 0.1
	var known: Array[String] = ["TallerDoor", "CasetaWindow", "CasetaEave", "GateLamp", "FuenteDeSoda", "Botilleria"]
	for id: String in found:
		if id in known: continue
		if "neon" in str(found[id].get_meta("kind", "")).to_lower(): depot_lighting_neon(id, found[id])
	depot_lighting_cabin(edges)


## A neon fixture DepotEdges hung (meta kind contains "neon"): a small unshadowed light in the tube's
## own colour, just in front of the tubes so it washes the wall and floor they face. A sign whose id
## or kind says holo/flicker buzzes; if DepotEdges publishes the sign's material (meta "glass"), the
## light follows its emission instead of keeping a rhythm of its own.
func depot_lighting_neon(id: String, marker: Node3D) -> void:
	var tube := OmniLight3D.new()
	tube.name = "Neon" + id
	add_child(tube)
	tube.global_position = marker.global_position - marker.global_basis.z * 0.25
	tube.light_color = Color(marker.get_meta("color", FLUORESCENT))
	tube.light_energy = minf(float(marker.get_meta("energy", 1.0)), 2.5)
	tube.omni_range = clampf(float(marker.get_meta("range", 3.0)), 1.0, 5.0)
	tube.omni_attenuation = 1.3
	tube.light_specular = 0.25
	tube.shadow_enabled = false
	var words: String = (id + " " + str(marker.get_meta("kind", ""))).to_lower()
	if "holo" in words or "flicker" in words:
		var glass: Variant = marker.get_meta("glass") if marker.has_meta("glass") else null
		_neon_flicker.append([tube, tube.light_energy, float(_neon_flicker.size()) * 1.37, glass if glass is BaseMaterial3D else null])


## Over the bays: the night cleaner is working through the micro DepotEdges parked in the middle of
## the row, so its cabin tubes are on. The windows glow (thin overlays outside DepotEdges' glass, so their
## shared material is untouched) and the rear window throws its trapezoid back across the apron
## toward the yard; a softer wash leaves the flank the camera sees. No micro, no light.
func depot_lighting_cabin(edges: Node) -> void:
	var micro := edges.find_child(CABIN_MICRO, true, false) as Node3D
	if micro == null:
		return
	var cabin := Node3D.new()
	cabin.name = "CabinLights"
	add_child(cabin)
	cabin.global_transform = micro.global_transform
	var lit := depot_lighting_material("cabin_window", CABIN_TUBE.darkened(0.25), 0.45, 0.3)
	for side: float in [-1.0, 1.0]:
		depot_lighting_box(cabin, "WindowGlow", Vector3(-0.3, 0.06 + 2.25, side * 1.273), Vector3(8.3, 0.84, 0.004), lit, false)
	depot_lighting_box(cabin, "RearGlow", Vector3(-5.223, 0.06 + 2.35, 0), Vector3(0.004, 0.68, 1.8), lit, false)
	depot_lighting_box(cabin, "DoorGlow", Vector3(3.9, 0.06 + 1.62, 1.273), Vector3(0.9, 1.9, 0.004), depot_lighting_material("cabin_door", CABIN_TUBE.darkened(0.35), 0.3, 0.3), false)
	# Unshadowed on purpose: the body would block a shadowed source sitting inside it.
	var rear := SpotLight3D.new()
	rear.name = "CabinRearSpill"
	cabin.add_child(rear)
	rear.position = Vector3(-5.0, 2.4, 0)
	var rear_aim: Vector3 = cabin.global_transform * Vector3(-12.0, 0.0, 0.0)
	rear.look_at(rear_aim, Vector3.UP)
	rear.light_color = CABIN_TUBE
	rear.light_energy = 30.0
	rear.spot_range = 14.0
	rear.spot_angle = 52.0
	rear.spot_attenuation = 1.0
	rear.spot_angle_attenuation = 0.5
	rear.light_specular = 0.3
	rear.light_volumetric_fog_energy = 0.0
	rear.shadow_enabled = false
	var flank := SpotLight3D.new()
	flank.name = "CabinFlankSpill"
	cabin.add_child(flank)
	flank.position = Vector3(0.0, 2.3, 1.0)
	flank.look_at(cabin.global_transform * Vector3(-1.0, 0.0, 6.0), Vector3.UP)
	flank.light_color = CABIN_TUBE
	flank.light_energy = 3.5
	flank.spot_range = 9.0
	flank.spot_angle = 60.0
	flank.spot_attenuation = 1.1
	flank.spot_angle_attenuation = 0.6
	flank.light_specular = 0.2
	flank.light_volumetric_fog_energy = 0.0
	flank.shadow_enabled = false


func depot_lighting_local_spot(id: String, marker: Node3D, color: Color, energy: float, reach: float, angle: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = id
	add_child(light)
	light.global_transform = marker.global_transform
	light.light_color = color
	light.light_energy = energy
	light.light_specular = 0.3
	light.light_volumetric_fog_energy = 0.0
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = 1.1
	light.spot_angle_attenuation = 0.6
	light.shadow_enabled = false
	return light


## The taller's open roll-up door: the tube hanging inside the bay is the fixture; this throws its
## hard-edged white-green trapezoid out across the wet floor. Unshadowed: the spill only leaves the
## opening (the facade's front faces away from it), so no shadow map is needed.
func depot_lighting_door_spill(marker: Node3D) -> void:
	var spill := depot_lighting_local_spot("TallerDoorSpill", marker, FLUORESCENT, 16.0, 12.0, 46.0)
	spill.light_volumetric_fog_energy = 1.0
	spill.spot_angle_attenuation = 0.35
	# The opening is the aperture: a rectangle with a short penumbra (wider than tall, since the
	# lintel cuts the top of the cone and the floor takes the bottom).
	var aperture := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y: int in 64:
		for x: int in 64:
			var edge: float = minf(minf(x - 6.0, 58.0 - x), minf(y - 14.0, 62.0 - y))
			var value: float = smoothstep(0.0, 3.0, edge)
			aperture.set_pixel(x, y, Color(value, value, value))
	spill.light_projector = ImageTexture.create_from_image(aperture)
	# Rain hangs in the light at the door, and only there: a volume that fills the opening and
	# barely leaves it, so it is hidden whenever the bay is (no glowing haze on a blank wall).
	var haze := FogVolume.new()
	haze.name = "TallerDoorRain"
	haze.size = Vector3(1.9, 3.3, 1.8)
	var fog := FogMaterial.new()
	fog.density = 0.06
	fog.albedo = Color("c6d2c8")
	fog.edge_fade = 0.5
	haze.material = fog
	add_child(haze)
	var out: Vector3 = -marker.global_basis.z
	out.y = 0.0
	haze.global_position = Vector3(marker.global_position.x, 1.75, marker.global_position.z) + out.normalized() * 0.9
	haze.global_basis = Basis.looking_at(out.normalized(), Vector3.UP)


## The caseta: a dim tungsten pool just outside its window with the TV's cold cuts in it, and the
## fluorescent tube under the eave over the pedestrian door. Tiny omni lights, unshadowed.
func depot_lighting_caseta(window: Node3D, eave: Node3D) -> void:
	var room := OmniLight3D.new()
	room.name = "CasetaWindowLight"
	add_child(room)
	room.global_position = window.global_transform * Vector3(0, -0.2, -0.75)
	room.light_color = TUNGSTEN
	room.light_energy = 1.1
	room.omni_range = 3.4
	room.omni_attenuation = 1.4
	room.light_specular = 0.2
	_tv_light = OmniLight3D.new()
	_tv_light.name = "CasetaTelevision"
	add_child(_tv_light)
	_tv_light.global_position = window.global_transform * Vector3(0.4, -0.4, -0.7)
	_tv_light.light_color = Color("aab8c4")
	_tv_light.light_energy = 0.3
	_tv_light.omni_range = 2.2
	_tv_light.light_specular = 0.0
	var tube := depot_lighting_local_spot("CasetaEaveTube", eave, FLUORESCENT, 3.0, 6.0, 70.0)
	tube.spot_angle_attenuation = 0.5


## The gate lamp is the relief's light: dark through the shift, it comes on when DepotEdges says
## the bus has pulled up (signal gate_lamp_changed), with a short warm-up like a real discharge lamp.
func depot_lighting_gate(marker: Node3D, edges: Node) -> void:
	gate_lamp = depot_lighting_local_spot("GateLamp", marker, Color(marker.get_meta("color", Color("e8d9a8"))), 0.0, 10.0, 52.0)
	gate_lamp.visible = false
	gate_lamp.set_meta("on", false)
	if edges.has_signal("gate_lamp_changed"):
		edges.connect("gate_lamp_changed", depot_lighting_on_gate_lamp)
	if bool(marker.get_meta("on", false)): depot_lighting_on_gate_lamp(true)


func depot_lighting_on_gate_lamp(on: bool) -> void:
	if gate_lamp == null: return
	gate_lamp.set_meta("on", on)
	var tween := create_tween()
	# The relief arrives as the shift ends, when the run pauses the tree.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if on:
		gate_lamp.visible = true
		tween.tween_property(gate_lamp, "light_energy", 1.5, 0.15)
		tween.tween_property(gate_lamp, "light_energy", 0.6, 0.25)
		tween.tween_property(gate_lamp, "light_energy", 5.0, 1.6)
	else:
		tween.tween_property(gate_lamp, "light_energy", 0.0, 0.4)
		tween.tween_callback(gate_lamp.hide)


## Head 3's ballast is failing: long steady stretches, then a short stutter. Subtle on the floor.
func _process(delta: float) -> void:
	if flicker_light == null or not is_visible_in_tree():
		return
	_flicker_time += delta
	for entry: Array in _neon_flicker:
		var tube := entry[0] as OmniLight3D
		var glass := entry[3] as BaseMaterial3D
		if glass != null:
			tube.light_energy = float(entry[1]) * clampf(glass.emission_energy_multiplier, 0.0, 2.0)
			continue
		# A cheap holo ballast: mostly on, dropping out in short glitches.
		var t: float = _flicker_time + float(entry[2])
		var glitch: float = 1.0 if fposmod(sin(floorf(t * 9.0) * 12.9898) * 43758.5453, 1.0) > 0.82 else 0.0
		tube.light_energy = float(entry[1]) * (1.0 - 0.75 * glitch) * (0.9 + 0.1 * sin(t * 31.0))
	if _tv_light != null:
		# The TV's cuts: follow the screen DepotEdges flickers, or keep a slow rhythm of our own.
		if _tv_screen != null: _tv_light.light_energy = 0.4 * _tv_screen.emission_energy_multiplier
		else: _tv_light.light_energy = 0.18 + 0.3 * float((int(_flicker_time / 1.7) * 7919) % 11) / 10.0
	var cycle: float = fmod(_flicker_time, 7.3)
	var level: float = 1.0
	if cycle > 6.2:
		var stutter: float = (cycle - 6.2) / 1.1
		level = 0.62 + 0.38 * absf(sin(stutter * 23.0)) * (0.6 + 0.4 * sin(stutter * 61.0))
	elif cycle > 3.0 and cycle < 3.12:
		level = 0.7
	flicker_light.light_energy = FLICKER_ENERGY * level
	flicker_glass.emission_energy_multiplier = 5.0 * level * level
