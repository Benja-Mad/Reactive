## A map-wide composition, not independent pools per prop. Reversible with the
## existing presentation switch; authored resources and gameplay remain intact.
extends Node3D
const SURFACE = preload("res://scenes/environment/sector_08/stylized/district_surface.gdshader")
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
	# A rain night over the depot: a moonlit overcast lifts the whole yard to a legible cool
	# blue-grey (the district shaders ignore ambient, so the sky lights carry the shadow level)
	# and the yard mast's sodium pools (depot_lighting.gd) sit warm on top of it. Shadows and ambient sit in one low blue-grey, never the
	# lavender or teal that used to tint every surface, so the UI colours stay signals.
	remember(arena.key_light,"rotation_degrees",Vector3(-62,-120,0))
	remember(arena.key_light,"light_color",Color("aebcc4"))
	remember(arena.key_light,"light_energy",2.8)
	remember(arena.key_light,"light_angular_distance",3.0)
	remember(arena.key_light,"light_volumetric_fog_energy",0.0)
	remember(arena.key_light,"shadow_opacity",0.6)
	remember(arena.fill_light,"rotation_degrees",Vector3(-32,145,0))
	remember(arena.fill_light,"light_color",Color("7d8896"))
	remember(arena.fill_light,"light_energy",0.4)
	remember(arena.fill_light,"light_volumetric_fog_energy",0.0)
	var env: Environment = arena.runtime_environment.environment
	remember(env,"ambient_light_color",Color("3a4858"))
	remember(env,"ambient_light_energy",2.6)
	# Emissives glow only where they are bright enough to be a source; no bloom wash.
	remember(env,"glow_intensity",0.42)
	remember(env,"glow_bloom",0.0)
	remember(env,"glow_hdr_threshold",1.05)
	remember(env,"fog_light_color",Color("2a3644"))
	remember(env,"adjustment_saturation",1.0)
	# No district-wide volumetric haze: only the fog volumes depot_lighting.gd places at the
	# mast heads and the taller door scatter light, so a beam always starts at its fixture.
	remember(env,"volumetric_fog_density",0.0)
	remember(env,"volumetric_fog_albedo",Color("8a959c"))
	remember(env,"volumetric_fog_emission",Color(0,0,0))
	remember(env,"volumetric_fog_ambient_inject",0.0)
	# Retire every local light the district built before the depot. Most had no fixture in frame
	# and carried the reserved signal colours (rose rims, violet wall washes, cyan vistas);
	# depot_lighting.gd re-lights the place from fixtures it can point at. A light that belongs to
	# a visible depot fixture can opt out with the meta `depot_fixture`.
	for node: Node in arena.find_children("*","Light3D",true,false):
		if node is DirectionalLight3D or node.has_meta("depot_fixture"): continue
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
	# The old floodlight "cuts" (FoundryCrosslight's diagonal wedge and six projector pools)
	# had no fixture anywhere in frame, lit only geometry on a private layer and skipped actors.
	# They are gone; depot_lighting.gd builds the depot's light from fixtures you can point at.
