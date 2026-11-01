## A map-wide composition, not independent pools per prop. Reversible with the
## existing presentation switch; authored resources and gameplay remain intact.
extends Node3D
const SURFACE = preload("res://scenes/environment/sector_08/stylized/district_surface.gdshader")
const ARCHITECTURE_LAYER := 1 << 18
var settings: Array[Dictionary] = []
var material_cache: Dictionary = {}

func remember(target: Object, property: String, value: Variant) -> void:
	settings.append({"target":target,"property":property,"before":target.get(property),"after":value})

func set_enabled(enabled: bool) -> void:
	visible = enabled
	for setting: Dictionary in settings:
		if is_instance_valid(setting.target): setting.target.set(setting.property,setting.after if enabled else setting.before)

func _exit_tree() -> void:
	set_enabled(false)

func setup(arena: Node3D, trial: Node3D) -> void:
	remember(arena.key_light,"rotation_degrees",Vector3(-28,-60,0))
	remember(arena.key_light,"light_color",Color("dfbd95"))
	remember(arena.key_light,"light_energy",1.25)
	remember(arena.key_light,"light_angular_distance",0.45)
	remember(arena.fill_light,"rotation_degrees",Vector3(-32,145,0))
	remember(arena.fill_light,"light_color",Color("839b9a"))
	remember(arena.fill_light,"light_energy",0.23)
	var env: Environment = arena.runtime_environment.environment
	remember(env,"ambient_light_color",Color("696173"))
	remember(env,"ambient_light_energy",0.26)
	remember(env,"glow_intensity",0.5)
	remember(env,"glow_bloom",0.03)
	remember(env,"fog_light_color",Color("344e4d"))
	# Retire diffuse pools across the entire map. The architectural transit study
	# and dynamic patrol retain their directed sources; all other local light is scored below.
	for node: Node in arena.find_children("*","Light3D",true,false):
		if node is DirectionalLight3D: continue
		if str(node.name) in ["TransitSideKey","TransitRearRim"] or node.has_meta("architectural_fixture"): continue
		trial.atmosphere_changes.append({"node":node,"visible":node.visible})
	# Carry the same face/shadow language into original and newly built solid architecture.
	# Emissive signage, windows, transparent surfaces and artwork keep their own materials.
	var reserved: Dictionary = {}
	for item: Dictionary in trial.changed: reserved[item.node] = true
	var surfaces: Array[Node] = trial.find_children("*","MeshInstance3D",true,false)
	surfaces.append_array(arena.sector_runtime.imported_environment.find_children("*","MeshInstance3D",true,false))
	for geometry: Node in surfaces:
		if reserved.has(geometry): continue
		var mesh := geometry as MeshInstance3D
		if mesh.mesh == null or mesh.mesh.get_surface_count() != 1: continue
		var source := mesh.get_active_material(0) as StandardMaterial3D
		if source == null or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: continue
		var title := str(mesh.name)
		var facade: bool = "_block_" in title and ("_Mass" in title or "_Pier" in title or "_Trim" in title or "_Lintel" in title)
		if source.albedo_texture != null and not facade:
			# Preserve baked artwork while removing the PBR sparkle that blows out in crosslight.
			if source.emission_enabled and source.emission_energy_multiplier > 0.25: continue
			var matte_key := "matte_" + str(source.get_instance_id())
			if not material_cache.has(matte_key):
				var matte := source.duplicate() as StandardMaterial3D
				matte.metallic = 0.0
				matte.metallic_specular = 0.0
				matte.roughness = 1.0
				matte.normal_enabled = false
				material_cache[matte_key] = matte
			trial.changed.append({"node":mesh,"original":mesh.material_override,"visible":mesh.visible,"paint":material_cache[matte_key],"hide":false})
			continue
		var pigment: Color = source.albedo_color
		if facade: pigment = Color("545562" if "_Mass" in title else "a49580")
		if source.emission_enabled and source.emission_energy_multiplier > 0.25: continue
		var path := str(trial.get_path_to(mesh))
		var tier: float = 0.7 if "DistrictTower" in path or "TransitUpper" in path else 0.0
		var key := str(source.get_instance_id())+str(tier)+str(pigment)
		if not material_cache.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = SURFACE
			mat.set_shader_parameter("pigment",pigment)
			mat.set_shader_parameter("depth_tier",tier)
			material_cache[key] = mat
		trial.changed.append({"node":mesh,"original":mesh.material_override,"visible":mesh.visible,"paint":material_cache[key],"hide":false})
		trial.stats["surfaces"] += 1
	# The theatrical cuts must not bleach sprite colours at close range.
	# Actors still receive the common key/fill and the moving aerial light.
	for node: Node in arena.find_children("*","GeometryInstance3D",true,false):
		if node is Label3D: continue
		if node is MeshInstance3D:
			var surface := node.get_active_material(0) as StandardMaterial3D if node.mesh != null and node.mesh.get_surface_count() > 0 else null
			if surface != null and surface.emission_enabled and surface.emission_energy_multiplier > 0.25: continue
		remember(node,"layers",node.layers | ARCHITECTURE_LAYER)
	# The negative spaces between these cuts are deliberate. No source follows the camera.
	cut("NorthAmberArcade",Vector3(1,8,-4),Vector3(-9,2,-20),"ff806b",100.0,30.0,26.0,0)
	cut("WestBoneFacade",Vector3(-17,6,17),Vector3(-30,3,7),"b5b6ce",38.0,24.0,38.0,1)
	cut("EastOxideReturn",Vector3(25,7,14),Vector3(37,3,-3),"ff855d",95.0,29.0,36.0,0)
	cut("SouthMineralEdge",Vector3(-20,14,35),Vector3(-1,0,21),"829eff",110.0,42.0,30.0,3)
	# Grazing the faceted landmark produces different values on its faces, rather than a halo.
	cut("LandmarkRake",Vector3(-10,10,-3),Vector3(-22,7,-15),"65dbc8",80.0,28.0,29.0,1)

	# High urban floodlights compose broad lanes of light across the district.
	# Their projected apertures and real occluders connect the floor to architecture.
	cut("FoundryCrosslight",Vector3(-16,19,16),Vector3(-5,0,-6),"f4c48e",285.0,55.0,40.0,2)
	cut("TransitCrosslight",Vector3(30,16,-5),Vector3(15,0,15),"9fcebd",180.0,50.0,36.0,3)

func cut(id: String, at: Vector3, target: Vector3, color: String, energy: float, reach: float, angle: float, pattern: int) -> void:
	var light := SpotLight3D.new()
	light.name = id
	add_child(light)
	light.position = at
	light.look_at(target,Vector3.UP)
	light.light_color = Color(color)
	light.light_cull_mask = ARCHITECTURE_LAYER
	light.light_energy = energy
	light.light_specular = 0.0
	light.light_volumetric_fog_energy = 0.0
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = 0.8
	light.spot_angle_attenuation = 0.3
	light.light_size = 0.1
	light.shadow_enabled = true
	var image := Image.create(64,64,false,Image.FORMAT_RGB8)
	for y: int in 64:
		for x: int in 64:
			# A single aperture with a short penumbra. Internal stripes used to
			# paint false shadows across unrelated walls and streets.
			var bounds := Vector4(5,8,59,54)
			if pattern == 2: bounds = Vector4(9,13,55,51)
			elif pattern == 3: bounds = Vector4(10,20,54,47)
			var edge: float = minf(minf(x-bounds.x,bounds.z-x),minf(y-bounds.y,bounds.w-y))
			var value: float = smoothstep(0.0,4.0,edge)
			image.set_pixel(x,y,Color(value,value,value))
	light.light_projector = ImageTexture.create_from_image(image)
