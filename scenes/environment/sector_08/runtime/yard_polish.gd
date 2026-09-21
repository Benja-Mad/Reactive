## Scene-local art pass: all dressing is visual and leaves the authored collision intact.
extends Node3D

var relay: Node3D
var orb: MeshInstance3D
var rings: Array[MeshInstance3D] = []
var time: float = 0.0
var water_materials: Array[ShaderMaterial] = []
var rain_materials: Array[ShaderMaterial] = []
var rain_emitters: Array[GPUParticles3D] = []
var fog_volumes: Array[FogVolume] = []

func setup(arena) -> void:
	var environment: Environment = arena.runtime_environment.environment
	# Measured at 2x supersampling, screen-space reflections at 128 steps were 47.6 ms of frame
	# against 6.9 ms with them off -- about 85% of the frame, while every other part of this pass
	# (rain, the fog volumes, the probe, the wet shader) measured free. On a night yard where the
	# far field is under a heavy depth blur anyway, that is not a trade worth 128 steps.
	environment.ssr_enabled = true
	environment.ssr_max_steps = 24
	environment.ssr_depth_tolerance = 0.25
	environment.ssao_intensity = 1.8
	environment.ssao_power = 1.65
	environment.ssao_radius = 0.85
	environment.ssao_detail = 0.85
	environment.ssao_light_affect = 0.28
	# A threshold of 1.25 with almost no bloom meant nothing in the frame ever glowed, so no lamp
	# read as a source. Measured, restoring it is the only environment dial that widens the
	# image's range at all: p05-p95 0.316 -> 0.334.
	environment.glow_intensity = 0.85
	environment.glow_bloom = 0.12
	environment.glow_hdr_scale = 1.6
	environment.glow_strength = 1.05
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_hdr_threshold = 0.85
	environment.ambient_light_color = Color(0.16, 0.24, 0.34)
	environment.ambient_light_energy = 0.34
	# Separate the miniature's silhouettes while keeping the play plane in focus.
	environment.adjustment_contrast = 1.10
	environment.adjustment_saturation = 1.06
	environment.fog_density = 0.0011
	# 0.0020 was a sixth of the approved medium, which all but extinguished the light shafts the
	# fixtures are aimed through. The haze stays thin; the volume that carries the beams does not.
	environment.volumetric_fog_density = 0.0090
	arena.key_light.light_energy = 1.55
	arena.key_light.light_angular_distance = 2.5
	arena.fill_light.light_energy = 0.65
	arena.spine_cyan_light.light_specular = 0.38
	arena.industrial_amber_center.light_specular = 0.40
	arena.industrial_amber_west.light_specular = 0.22
	# The sodium had been halved -- the streetlight 38 -> 16, the central amber 12 -> 5 -- while
	# the wet floor started returning cyan across the whole yard. Measured, that left 5% of the
	# frame's chroma warm against 85% inside a single blue-cyan wedge, which is what makes the
	# picture read as generic: the two-temperature opposition this district is built on had gone.
	# Restoring it takes warm chroma to 6.5% and widens the range from 0.316 to 0.345.
	arena.industrial_amber_center.light_energy = 11.0
	arena._art_light_base_energy[arena.industrial_amber_center] = 11.0
	arena.industrial_amber_west.light_energy = 5.5
	arena._art_light_base_energy[arena.industrial_amber_west] = 5.5
	var street := arena.motivated_lights.get_node_or_null("YardStreetlight") as SpotLight3D
	if street != null:
		arena._art_light_base_energy[street] = 20.0
		# The pool clips under the lamp. Energy, specular, beam fog and pool roughness were each
		# swept and none of them clears it: at any energy that keeps the yard warm the highlight is
		# far past the clip point. Left as it is, because unlike the blown spot on the dry slabs
		# this one sits directly under a visible fixture with a visible beam, so it reads as the
		# lamp rather than as an object nobody can identify.
		street.light_specular = 0.30
		street.light_volumetric_fog_energy = 1.10
		street.light_size = 0.65
	arena._sync_art_lights(arena.controller.get_values())
	var variants: Dictionary = {}
	for node: Node in arena.sector_runtime.find_children("*", "MeshInstance3D", true, false):
		var piece := node as MeshInstance3D
		var title: String = str(piece.name)
		if piece.mesh == null:
			continue
		if title.begins_with("Yard_Slab") or title.begins_with("Ground_Patch") or title.begins_with("Apron") or title.begins_with("Puddle"):
			for surface: int in piece.mesh.get_surface_count():
				var source := piece.get_active_material(surface) as StandardMaterial3D
				var key: String = str(source.get_instance_id() if source != null else 0) + ("_pool" if title.begins_with("Puddle") else "_slab")
				if not variants.has(key):
					var wet := ShaderMaterial.new()
					wet.shader = preload("res://scenes/environment/sector_08/runtime/rain_pavement.gdshader")
					wet.set_shader_parameter("pavement", preload("res://materials/sector08/rain_pavement.png"))
					wet.set_shader_parameter("wetness", 0.96)
					wet.set_shader_parameter("standing_water", 0.96 if title.begins_with("Puddle") else 0.0)
					wet.set_shader_parameter("cyan_anchor", arena.spine_cyan_light.global_position)
					wet.set_shader_parameter("amber_anchor", street.global_position if street != null else arena.industrial_amber_center.global_position)
					wet.set_shader_parameter("magenta_anchor", arena.corruption_magenta_light.global_position)
					water_materials.append(wet)
					if source != null and source.normal_texture != null:
						wet.set_shader_parameter("authored_normal", source.normal_texture)
						wet.set_shader_parameter("has_normal", true)
					variants[key] = wet
				piece.material_override = null
				piece.set_surface_override_material(surface, variants[key])
		elif title.begins_with("Ground_Stain"):
			# Water staining is now in the scan; these opaque rectangles duplicate it.
			piece.hide()
		elif title.begins_with("Moss"):
			piece.scale *= Vector3(0.32, 1.0, 0.32)
		# Retain the imported foliage atlas and normals while adding a little backlighting.
		for surface: int in piece.mesh.get_surface_count():
			var source := piece.get_active_material(surface) as StandardMaterial3D
			if source != null and "foliage" in source.resource_name.to_lower():
				var foliage := source.duplicate() as StandardMaterial3D
				foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
				foliage.backlight_enabled = true
				foliage.backlight = Color(0.12, 0.19, 0.12)
				foliage.roughness = 0.72
				piece.set_surface_override_material(surface, foliage)
	var perimeter: Node = arena.sector_runtime.perimeter
	if perimeter != null and not water_materials.is_empty():
		var fill := perimeter.get_node_or_null("PerimeterGroundFill") as MultiMeshInstance3D
		if fill != null:
			var source := fill.material_override as StandardMaterial3D
			var wet := water_materials[0].duplicate() as ShaderMaterial
			if source != null and source.normal_texture != null:
				wet.set_shader_parameter("authored_normal", source.normal_texture)
				wet.set_shader_parameter("has_normal", true)
			fill.material_override = wet
			water_materials.append(wet)

	var probe := ReflectionProbe.new()
	probe.position = Vector3(0, 4, -5)
	probe.size = Vector3(58, 24, 54)
	probe.box_projection = true
	probe.intensity = 0.5
	probe.max_distance = 90
	add_child(probe)
	_build_relay()
	_build_rain()
	_build_service_markings(arena, street)
	# Local condensate gives the reactor service lane its own atmosphere. The warm
	# streetlight catches a separate low bank; neither volume fills the play plane.
	_condensate("ReactorCondensate", arena.spine_cyan_light.global_position + Vector3(0, -3, 1), Vector3(12, 5, 7), 0.032)
	_condensate("ReactorRearVapour", arena.spine_cyan_light.global_position + Vector3(-2, 1, -4), Vector3(10, 12, 5), 0.055)
	_condensate("FenceServiceHaze", Vector3(-6, 0.8, -19), Vector3(26, 1.5, 3), 0.016)
	if street != null:
		_condensate("SodiumDrainMist", Vector3(street.global_position.x, 0.5, street.global_position.z + 2), Vector3(5, 1.0, 3), 0.016)
	for material: ShaderMaterial in rain_materials:
		material.set_shader_parameter("cyan_anchor", arena.spine_cyan_light.global_position)
		material.set_shader_parameter("amber_anchor", street.global_position if street != null else arena.industrial_amber_center.global_position)
	arena.controller.reactive_state_changed.connect(_sync_water)
	_sync_water(arena.controller.get_values())
	# Reuse the authored world-anchored optical layers at a restrained density.
	if arena.cinematic_dust != null:
		arena.cinematic_dust.visible = true
		for emitter: GPUParticles3D in arena.cinematic_dust.layers:
			emitter.amount_ratio = 0.40 if emitter.name == &"LensMotes" else 0.75
	# The lit air motes stay: rain is falling water, the motes are suspended dust that only shows
	# inside a beam. They are different cues and the scene was tuned with both.
	if arena.sector_runtime.particles != null:
		arena.sector_runtime.particles.visible = true

func _condensate(id: String, origin: Vector3, extent: Vector3, density: float) -> void:
	var volume := FogVolume.new()
	volume.name = id
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	volume.size = extent
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/environment/sector_08/runtime/yard_condensate.gdshader")
	material.set_shader_parameter("density", density)
	volume.material = material
	fog_volumes.append(volume)
	add_child(volume)
	volume.global_position = origin

func _sync_water(values: Dictionary) -> void:
	var supply: float = clampf(float(values.get("power", 0.92))/0.92, 0.0, 1.1)
	supply *= 1.0 - clampf(float(values.get("blackout_amount", 0.0)), 0.0, 1.0)
	for material: ShaderMaterial in water_materials:
		material.set_shader_parameter("fixture_power", supply)
	for material: ShaderMaterial in rain_materials:
		material.set_shader_parameter("fixture_power", supply)

func _material(color: Color, energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.65
	mat.roughness = 0.28
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat

func _build_service_markings(arena, street: SpotLight3D) -> void:
	# A legible maintenance route belongs to this reactor, not a scatter of props.
	# All paint is coplanar dressing with no collision or network state.
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://scenes/environment/sector_08/runtime/yard_service_paint.gdshader")
	paint.set_shader_parameter("wear", preload("res://materials/sector08/rain_pavement.png"))
	var reactor: Vector3 = arena.spine_cyan_light.global_position
	var service := Vector3(reactor.x + 2.8, 0.045, reactor.z + 5.0)
	_floor_caption("R-08  /  PURGA", service + Vector3(0, 0.008, 0.7), 0.0065)
	_floor_caption("MANTENER LIBRE", service + Vector3(0, 0.008, 1.35), 0.0042)
	for side: float in [-1.0, 1.0]:
		_paint_strip(service + Vector3(side*2.0, 0, 0), Vector2(0.10, 2.8), paint)
		_paint_strip(service + Vector3(side*1.6, 0, -1.4), Vector2(0.9, 0.10), paint)
	# Broken line terminates at the valve approach, leaving the central combat lane open.
	for index: int in 4:
		_paint_strip(service + Vector3(-2.0, 0, 2.4 + index*0.8), Vector2(0.10, 0.38), paint)
	if street != null:
		var drain := Vector3(street.global_position.x + 2.2, 0.046, street.global_position.z + 3.5)
		_floor_caption("D-03", drain, 0.006)
		_floor_caption("DESAGÜE", drain + Vector3(0, 0.008, 0.52), 0.0038)
		_paint_strip(drain + Vector3(0, 0, -0.6), Vector2(1.15, 0.08), paint)
		# A recessed-looking iron channel gives D-03 a physical destination.
		var iron := _material(Color(0.055, 0.063, 0.065))
		iron.roughness = 0.76
		var recess := _material(Color(0.012, 0.018, 0.022))
		_box_detail(self, "D03DrainBed", drain + Vector3(0, -0.012, 1.0), Vector3(1.45, 0.018, 0.52), recess)
		for index: int in 12:
			_box_detail(self, "D03GrateBar", drain + Vector3(-0.66 + index*0.12, 0.003, 1.0), Vector3(0.035, 0.025, 0.52), iron)
		for side: float in [-1.0, 1.0]:
			_box_detail(self, "D03GrateRim", drain + Vector3(0, 0.006, 1.0 + side*0.27), Vector3(1.5, 0.03, 0.035), iron)

func _box_detail(parent: Node3D, id: String, origin: Vector3, size: Vector3, material: Material) -> void:
	var detail := MeshInstance3D.new()
	detail.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	detail.mesh = mesh
	detail.material_override = material
	parent.add_child(detail)
	detail.position = origin

func _paint_strip(origin: Vector3, size: Vector2, material: ShaderMaterial) -> void:
	var strip := MeshInstance3D.new()
	strip.name = "WornServicePaint"
	var plane := PlaneMesh.new()
	plane.size = size
	strip.mesh = plane
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)
	strip.global_position = origin

## Floor lettering is disabled: laid flat and read from a camera pitched 24 degrees, every
## caption came out smeared across the slabs and illegible, sitting right in the play lane. The
## painted strips and the drain carry the same identity without asking the frame to read text at
## a grazing angle.
func _floor_caption(_text: String, _origin: Vector3, _pixel_size: float) -> void:
	return


func _floor_caption_disabled(text: String, origin: Vector3, pixel_size: float) -> void:
	var caption := Label3D.new()
	caption.name = "ServiceStencil"
	caption.text = text
	caption.font_size = 64
	caption.pixel_size = pixel_size
	caption.outline_size = 0
	caption.modulate = Color(0.58, 0.55, 0.38, 0.65)
	caption.shaded = true
	caption.no_depth_test = false
	caption.rotation_degrees.x = -90.0
	caption.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(caption)
	caption.global_position = origin

func _build_relay() -> void:
	relay = Node3D.new()
	# Back and to the left. At (-8.1, -9) it sat in the middle of the frame competing with the
	# players it is meant to sit behind.
	relay.position = Vector3(-15.5, 0.07, -15.0)
	add_child(relay)
	var contact := MeshInstance3D.new()
	contact.name = "RelayContact"
	var footprint := QuadMesh.new()
	footprint.orientation = PlaneMesh.FACE_Y
	footprint.size = Vector2(3.8, 3.8)
	contact.mesh = footprint
	var contact_material := ShaderMaterial.new()
	contact_material.shader = preload("res://scenes/environment/sector_08/runtime/contact_shadow.gdshader")
	contact.material_override = contact_material
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	contact.position.y = -0.045
	relay.add_child(contact)
	var base := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.35
	cylinder.bottom_radius = 1.55
	cylinder.height = 0.22
	cylinder.radial_segments = 48
	base.mesh = cylinder
	base.position.y = 0.11
	base.material_override = _material(Color(0.055, 0.11, 0.14))
	relay.add_child(base)
	# Bolted service flange: the objective belongs to the yard's utility network.
	var steel := _material(Color(0.26, 0.28, 0.27))
	steel.roughness = 0.62
	for index: int in 8:
		var angle := TAU * float(index) / 8.0
		_box_detail(relay, "R08FlangeBolt", Vector3(cos(angle)*1.23, 0.245, sin(angle)*1.23), Vector3(0.10, 0.055, 0.10), steel)
	var enamel := _material(Color(0.32, 0.28, 0.16))
	enamel.roughness = 0.82
	_box_detail(relay, "R08ServicePlate", Vector3(0, 0.24, 1.13), Vector3(0.55, 0.022, 0.18), enamel)
	_floor_caption("R-08 / ENLACE", relay.position + Vector3(0, 0.008, 2.0), 0.0048)
	var energy := _material(Color(0.1, 0.85, 1.0), 1.5)
	for index: int in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.53 + index * 0.28
		torus.outer_radius = torus.inner_radius + 0.025
		torus.rings = 48
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = energy
		ring.position.y = 0.27 + index * 0.08
		relay.add_child(ring)
		rings.append(ring)
	orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.27
	sphere.height = 0.54
	orb.mesh = sphere
	orb.material_override = energy
	orb.position.y = 0.95
	relay.add_child(orb)
	var lamp := OmniLight3D.new()
	lamp.position.y = 1.15
	lamp.light_color = Color(0.13, 0.82, 1)
	lamp.light_energy = 2.8
	lamp.omni_range = 7.0
	lamp.light_specular = 0.28
	relay.add_child(lamp)

func _build_rain() -> void:
	_rain_layer("ServiceLaneRain", Vector3(0, 17, -22), Vector3(27, 2, 5), 650, 0.018, 0.42, 0.26)
	_rain_layer("YardRain", Vector3(0, 15, -4), Vector3(28, 2, 18), 1500, 0.022, 0.50, 0.30)
	_rain_layer("ForegroundRain", Vector3(0, 12, 17), Vector3(27, 1, 6), 110, 0.065, 0.85, 0.13)

## Releases what this pass allocated, the way the other two particle systems here already do.
##
## It does not silence the "1 shaders of type ParticlesShaderRD were never freed" line at exit:
## freeing all three particle systems thirty frames before quitting leaves that message, and the
## seven leaked texture RIDs, exactly as they were. They are the rendering server's own shutdown
## accounting, not this project's. Kept anyway because deterministic release is right regardless
## of what the exit prints.
func _exit_tree() -> void:
	for emitter: GPUParticles3D in rain_emitters:
		emitter.emitting = false
		emitter.process_material = null
		emitter.draw_pass_1 = null
	rain_emitters.clear()
	for material: ShaderMaterial in water_materials:
		material.shader = null
	for material: ShaderMaterial in rain_materials:
		material.shader = null
	water_materials.clear()
	rain_materials.clear()
	for volume: FogVolume in fog_volumes:
		volume.material = null
	fog_volumes.clear()


func _rain_layer(id: String, origin: Vector3, extent: Vector3, count: int, width: float, length: float, opacity: float) -> void:
	var rain := GPUParticles3D.new()
	rain.name = id
	rain.position = origin
	rain.amount = count
	rain.lifetime = 1.45
	rain.preprocess = 1.45
	rain.local_coords = false
	rain.use_fixed_seed = true
	rain.seed = 808 + rain_materials.size() * 37
	rain.visibility_aabb = AABB(Vector3(-32, -20, -30), Vector3(64, 26, 60))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extent
	process.direction = Vector3(-0.12, -1, 0.04)
	process.spread = 2.0
	process.initial_velocity_min = 13.0
	process.initial_velocity_max = 16.0
	process.gravity = Vector3(0, -2, 0)
	rain.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(width, length)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scenes/environment/sector_08/runtime/stylized_rain.gdshader")
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("softness", 0.8 if id == "ForegroundRain" else 0.0)
	rain_materials.append(mat)
	drop.material = mat
	rain.draw_pass_1 = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_emitters.append(rain)
	add_child(rain)

func _process(delta: float) -> void:
	if orb == null:
		return
	time += delta
	orb.position.y = 0.95 + sin(time * 2.0) * 0.09
	for index: int in rings.size():
		rings[index].rotation.x = sin(time * 0.8 + index) * 0.18
		rings[index].rotation.z = cos(time * 0.6 + index) * 0.18
