class_name Sector08Runtime
extends Node3D

const GLASS_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/window_reactive_glass.gdshader"
const INTERIOR_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/window_reactive_interior.gdshader"
const FACADE_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/reactive_facade.gdshader"
const SPINE_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/reactive_spine.gdshader"
const CAL_GLASS_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/calibrated_window_glass.gdshader"
const CAL_INTERIOR_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/calibrated_window_interior.gdshader"
const CAL_FACADE_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/calibrated_reactive_facade.gdshader"
const CAL_SPINE_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/calibrated_reactive_spine.gdshader"
const CAL_SURFACE_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/calibrated_surface.gdshader"
const CAL_FOLIAGE_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/calibrated_foliage.gdshader"
const PATTERN_TEXTURE_PATH: String = "res://scenes/environment/sector_08/slice_all_CS_Glyphs.png"

@export var enhanced_materials: bool = true
@export var calibrated_look: bool = true
## Redistributes inert ground decoration away from the gameplay core. Lives here rather than in
## the lookdev harness so a gameplay scene that instances only Sector08Runtime gets it too.
@export var ground_dressing_enabled: bool = true
## Static collision for the yard, built from the imported bounds. The authored GLB ships none.
@export var collision_enabled: bool = true
## Lit airborne motes, so the yard is not a still photograph.
@export var particles_enabled: bool = true
## Facade-scale screen closing the lower edge of the frame. Needs the framing camera, so it is
## built in the same deferred pass as the ground dressing.
@export var billboard_enabled: bool = true
## Fills the lateral edges, where the collision floor reaches further than the authored slabs.
@export var perimeter_enabled: bool = true
@onready var imported_environment: Node3D = $ImportedEnvironment

## Framing the ground composition is judged from. The owner sets this during its own _ready();
## the redistribution itself is deferred to the first frame so the owner's camera setup has run.
var composition_camera: Camera3D
var ground_dressing: Node
var collision: StaticBody3D
var particles: Node3D
var billboard: Node3D
var perimeter: Node3D

var mesh_instance_count: int = 0
var surface_count: int = 0
var imported_material_count: int = 0
var shader_material_count: int = 0
var overridden_mesh_count: int = 0
var calibrated_override_count: int = 0
var authored_pbr_mesh_count: int = 0
var metadata_node_count: int = 0
var window_mesh_count: int = 0
var interior_mesh_count: int = 0
var spine_mesh_count: int = 0
var facade_mesh_count: int = 0
var _override_meshes: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _glass_material: ShaderMaterial
var _interior_material: ShaderMaterial
var _facade_material: ShaderMaterial
var _spine_material: ShaderMaterial
var _cal_glass_material: ShaderMaterial
var _cal_interior_material: ShaderMaterial
var _cal_facade_material: ShaderMaterial
var _cal_spine_material: ShaderMaterial
var _cal_surface_material: ShaderMaterial
var _cal_foliage_material: ShaderMaterial
var _upper_center_repair_enabled: bool = true


func _ready() -> void:
	_create_shared_materials()
	_audit_and_bind()
	set_enhanced(enhanced_materials)
	if collision_enabled:
		collision = preload("res://scenes/environment/sector_08/runtime/sector_08_collision.gd").new()
		collision.name = "YardCollision"
		add_child(collision)
		collision.build(imported_environment)
	if particles_enabled:
		particles = preload("res://scenes/environment/sector_08/runtime/sector_08_particles.gd").new()
		particles.name = "AirMotes"
		add_child(particles)
		particles.setup()
	if ground_dressing_enabled:
		ground_dressing = preload("res://scenes/environment/sector_08/runtime/sector_08_ground_dressing.gd").new()
		ground_dressing.name = "GroundDressing"
		add_child(ground_dressing)
	# Ground dressing, the perimeter and the billboard all need the framing camera, which the
	# owner sets during its own _ready(), so they are built on the first frame instead.
	call_deferred("_apply_framing_dependent_pass")
	print("Sector08Runtime: meshes=%d surfaces=%d imported_materials=%d baseline_overrides=%d calibrated_overrides=%d shared_shaders=%d metadata_nodes=%d" % [mesh_instance_count, surface_count, imported_material_count, overridden_mesh_count, calibrated_override_count, shader_material_count, metadata_node_count])


func _apply_framing_dependent_pass() -> void:
	var camera: Camera3D = composition_camera
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if perimeter_enabled:
		perimeter = preload("res://scenes/environment/sector_08/runtime/sector_08_perimeter.gd").new()
		perimeter.name = "PerimeterFill"
		add_child(perimeter)
		perimeter.build(imported_environment, camera)
	if ground_dressing != null:
		ground_dressing.setup(imported_environment, camera)
	if billboard_enabled and camera != null:
		billboard = preload("res://scenes/environment/sector_08/runtime/sector_08_billboard.gd").new()
		billboard.name = "FacadeBillboard"
		add_child(billboard)
		billboard.setup(camera)


func get_reactive_materials() -> Array[ShaderMaterial]:
	return _materials


func set_enhanced(enabled: bool) -> void:
	enhanced_materials = enabled
	for mesh_instance: MeshInstance3D in _override_meshes:
		var runtime_material: Material
		if enabled:
			var key: StringName = &"cs_calibrated_material" if calibrated_look else &"cs_runtime_material"
			if mesh_instance.has_meta(key):
				runtime_material = mesh_instance.get_meta(key) as Material
		mesh_instance.material_override = runtime_material


func set_calibrated(enabled: bool) -> void:
	calibrated_look = enabled
	set_enhanced(enhanced_materials)


func is_calibrated() -> bool:
	return calibrated_look


func is_enhanced() -> bool:
	return enhanced_materials


func set_upper_center_repair_enabled(enabled: bool) -> void:
	_upper_center_repair_enabled = enabled
	for target_name: String in ["Skyline_Block_019", "Skyline_Block_037"]:
		var mesh_instance: MeshInstance3D = imported_environment.find_child(target_name, true, false) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
			continue
		var source_material: Material = mesh_instance.mesh.surface_get_material(0)
		var source_name: String = source_material.resource_name if source_material != null else ""
		var extras: Dictionary = mesh_instance.get_meta("extras", {}) as Dictionary
		_set_surface_instance_parameters(mesh_instance, source_name, extras)


func is_upper_center_repair_enabled() -> bool:
	return _upper_center_repair_enabled


func get_runtime_report() -> Dictionary:
	return {"mesh_instances": mesh_instance_count, "surfaces": surface_count, "imported_materials": imported_material_count, "shader_materials": shader_material_count, "baseline_overrides": overridden_mesh_count, "calibrated_overrides": calibrated_override_count, "authored_pbr_meshes": authored_pbr_mesh_count, "window_glass_meshes": window_mesh_count, "window_interior_meshes": interior_mesh_count, "facade_meshes": facade_mesh_count, "spine_meshes": spine_mesh_count, "metadata_nodes": metadata_node_count, "collision_shapes": int(collision.stats.get("total_shapes", 0)) if collision != null else 0}


func _create_shared_materials() -> void:
	_glass_material = _shader_material(GLASS_SHADER_PATH)
	_interior_material = _shader_material(INTERIOR_SHADER_PATH)
	_facade_material = _shader_material(FACADE_SHADER_PATH)
	_spine_material = _shader_material(SPINE_SHADER_PATH)
	_cal_glass_material = _shader_material(CAL_GLASS_SHADER_PATH)
	_cal_interior_material = _shader_material(CAL_INTERIOR_SHADER_PATH)
	_cal_facade_material = _shader_material(CAL_FACADE_SHADER_PATH)
	_cal_spine_material = _shader_material(CAL_SPINE_SHADER_PATH)
	_cal_surface_material = _shader_material(CAL_SURFACE_SHADER_PATH)
	_cal_foliage_material = _shader_material(CAL_FOLIAGE_SHADER_PATH)
	var pattern_texture: Texture2D = load(PATTERN_TEXTURE_PATH) as Texture2D
	for material: ShaderMaterial in [_interior_material, _facade_material, _cal_interior_material, _cal_facade_material]:
		material.set_shader_parameter(&"pattern_mask", pattern_texture)
	_materials = [_glass_material, _interior_material, _facade_material, _spine_material, _cal_glass_material, _cal_interior_material, _cal_facade_material, _cal_spine_material]
	shader_material_count = 10


func _shader_material(path: String) -> ShaderMaterial:
	var shader_resource: Shader = load(path) as Shader
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader_resource
	return material


func _audit_and_bind() -> void:
	var imported_material_ids: Dictionary = {}
	var stack: Array[Node] = [imported_environment]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		_map_extras_to_metadata(node)
		if node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			mesh_instance_count += 1
			if mesh_instance.mesh != null:
				surface_count += mesh_instance.mesh.get_surface_count()
				for surface_index: int in mesh_instance.mesh.get_surface_count():
					var imported_material: Material = mesh_instance.get_active_material(surface_index)
					if imported_material != null:
						imported_material_ids[imported_material.get_instance_id()] = true
			_bind_baseline_reactive_mesh(mesh_instance)
			_bind_calibrated_mesh(mesh_instance)
			if mesh_instance.has_meta(&"cs_runtime_material") or mesh_instance.has_meta(&"cs_calibrated_material"):
				_override_meshes.append(mesh_instance)
		for child: Node in node.get_children():
			stack.append(child)
	imported_material_count = imported_material_ids.size()


func _map_extras_to_metadata(node: Node) -> void:
	if not node.has_meta(&"extras"):
		return
	var extras_value: Variant = node.get_meta(&"extras")
	if not extras_value is Dictionary:
		return
	var extras: Dictionary = extras_value as Dictionary
	if extras.is_empty():
		return
	metadata_node_count += 1
	for key_value: Variant in extras.keys():
		var key: StringName = StringName(str(key_value))
		if not node.has_meta(key):
			node.set_meta(key, extras[key_value])


func _bind_baseline_reactive_mesh(mesh_instance: MeshInstance3D) -> void:
	# Authored structural window modules retain their PBR surface.
	if _is_authored_pbr(_source_material(mesh_instance)):
		return
	var extras: Dictionary = _extras(mesh_instance)
	if extras.is_empty():
		return
	var channel: String = str(extras.get("cs_channel", ""))
	var building: String = str(extras.get("cs_building", ""))
	var source_material: Material = _source_material(mesh_instance)
	var source_name: String = source_material.resource_name if source_material != null else ""
	var runtime_material: ShaderMaterial
	if channel == "emissive_windows":
		runtime_material = _interior_material
		interior_mesh_count += 1
	elif channel == "windows" and (source_name.to_lower().contains("glass") ):
		runtime_material = _glass_material
		window_mesh_count += 1
	elif channel == "facade_panels" and building in ["B04", "B05"]:
		runtime_material = _facade_material
		facade_mesh_count += 1
	elif building == "SPINE" and channel in ["data_conduit", "execution_traces", "rings", "status_nodes", "screens"] and _is_emissive_source(source_material, mesh_instance.name):
		runtime_material = _spine_material
		spine_mesh_count += 1
	else:
		return
	_set_reactive_instance_parameters(mesh_instance, extras)
	mesh_instance.set_meta(&"cs_runtime_material", runtime_material)
	overridden_mesh_count += 1


func _bind_calibrated_mesh(mesh_instance: MeshInstance3D) -> void:
	var source_material: Material = _source_material(mesh_instance)
	# Versioned export marker + real texture: do not reconstruct baked surfaces.
	if _is_authored_pbr(source_material):
		authored_pbr_mesh_count += 1
		return
	if source_material == null:
		return
	var source_name: String = source_material.resource_name
	var lower: String = source_name.to_lower()
	var extras: Dictionary = _extras(mesh_instance)
	var channel: String = str(extras.get("cs_channel", ""))
	var building: String = str(extras.get("cs_building", ""))
	var calibrated_material: ShaderMaterial
	if lower.contains("img_"):
		return
	elif building == "SPINE" and _is_emissive_source(source_material, mesh_instance.name):
		calibrated_material = _cal_spine_material
	elif channel == "emissive_windows" or lower.contains("winbank") or lower.contains("emit_interior"):
		calibrated_material = _cal_interior_material
	elif channel == "windows" and lower.contains("glass"):
		calibrated_material = _cal_glass_material
	elif channel == "facade_panels" and building in ["B04", "B05"]:
		calibrated_material = _cal_facade_material
	elif _is_surface_family(lower):
		calibrated_material = _cal_foliage_material if lower.contains("foliage") else _cal_surface_material
	else:
		return
	_set_reactive_instance_parameters(mesh_instance, extras)
	_set_surface_instance_parameters(mesh_instance, source_name, extras)
	mesh_instance.set_meta(&"cs_calibrated_material", calibrated_material)
	calibrated_override_count += 1


func _set_reactive_instance_parameters(mesh_instance: MeshInstance3D, extras: Dictionary) -> void:
	var building: String = str(extras.get("cs_building", ""))
	var local_coord: Vector3 = Vector3(float(extras.get("cs_local_u", 0.5)), float(extras.get("cs_local_w", 0.5)), float(extras.get("cs_local_v", 0.5)))
	var seed_value: float = float(abs(hash("%s:%s" % [building, mesh_instance.name])) % 10000) / 10000.0
	mesh_instance.set_instance_shader_parameter(&"cs_local_coord", local_coord)
	mesh_instance.set_instance_shader_parameter(&"cs_building_seed", seed_value)
	mesh_instance.set_instance_shader_parameter(&"cs_route_index", float(extras.get("cs_route_index", -1.0)))
	mesh_instance.set_instance_shader_parameter(&"cs_phase_offset", float(extras.get("cs_phase_offset", _route_phase(building))))


func _set_surface_instance_parameters(mesh_instance: MeshInstance3D, source_name: String, extras: Dictionary) -> void:
	var settings: Dictionary = _surface_settings(source_name)
	var band: String = str(extras.get("cs_band", "PLAY"))
	var building: String = str(extras.get("cs_building", ""))
	var facade_role: String = str(extras.get("cs_facade_role", ""))
	var is_mid_architecture: bool = band == "BG_NEAR" or (building in ["B01", "B02", "B03", "B04", "B05"] and facade_role in ["residential", "commercial", "industrial", "megablock"])
	# These two imported backdrop blocks are the audited P30 metadata exception: they close the visible midground gap.
	var is_upper_center_backdrop: bool = _upper_center_repair_enabled and mesh_instance.name in [&"Skyline_Block_019", &"Skyline_Block_037"]
	var depth_fade: float = 0.42 if is_upper_center_backdrop else (0.72 if band == "BG_FAR" else (0.24 if band == "BG_NEAR" else (0.1 if is_mid_architecture else 0.0)))
	var architecture_fill: float = 0.22 if is_upper_center_backdrop else (0.035 if band == "BG_FAR" else (0.052 if band == "BG_NEAR" else (0.055 if is_mid_architecture else 0.0)))
	var local_contrast: float = 0.9 if is_upper_center_backdrop else (0.14 if band == "BG_FAR" else (0.55 if is_mid_architecture else 0.0))
	var seed_value: float = float(abs(hash(mesh_instance.name)) % 10000) / 10000.0
	var surface_color: Color = settings["color"]
	if is_upper_center_backdrop:
		surface_color = Color(0.31, 0.335, 0.36) if mesh_instance.name == &"Skyline_Block_019" else Color(0.22, 0.245, 0.275)
	elif band == "PLAY" and not is_mid_architecture and (source_name.to_lower().contains("concrete") or source_name.to_lower().contains("asphalt")):
		surface_color = surface_color.lerp(Color(0.38, 0.375, 0.36), 0.74)
	elif is_mid_architecture:
		var architecture_lift: float = 1.34
		surface_color = Color(surface_color.r * architecture_lift, surface_color.g * architecture_lift, surface_color.b * architecture_lift, 1.0)
	mesh_instance.set_instance_shader_parameter(&"cs_surface_color", surface_color)
	var roughness_factor: float = 0.7 if is_upper_center_backdrop else (0.91 if is_mid_architecture else 1.0)
	mesh_instance.set_instance_shader_parameter(&"cs_surface_roughness", float(settings["roughness"]) * roughness_factor)
	mesh_instance.set_instance_shader_parameter(&"cs_surface_metallic", settings["metallic"])
	mesh_instance.set_instance_shader_parameter(&"cs_surface_kind", settings["kind"])
	mesh_instance.set_instance_shader_parameter(&"cs_surface_wetness", settings["wetness"])
	mesh_instance.set_instance_shader_parameter(&"cs_surface_seed", seed_value)
	mesh_instance.set_instance_shader_parameter(&"cs_depth_fade", depth_fade)
	mesh_instance.set_instance_shader_parameter(&"cs_architecture_fill", architecture_fill)
	mesh_instance.set_instance_shader_parameter(&"cs_local_contrast", local_contrast)


func _surface_settings(source_name: String) -> Dictionary:
	var lower: String = source_name.to_lower()
	var color: Color = Color(0.2, 0.21, 0.22)
	var roughness: float = 0.7
	var metallic: float = 0.0
	var kind: float = 0.0
	var wetness: float = 0.0
	if lower.contains("silhouette"):
		color = Color(0.2, 0.215, 0.23) if lower.contains("bg_near") else Color(0.095, 0.11, 0.13)
		roughness = 0.92
	elif lower.contains("asphalt"):
		color = Color(0.4, 0.39, 0.365)
		roughness = 0.82
		kind = 1.0
		if lower.contains("wet"):
			color = Color(0.33, 0.35, 0.37)
			roughness = 0.5
			wetness = 0.72
	elif lower.contains("concrete"):
		color = Color(0.48, 0.46, 0.42)
		roughness = 0.8
		if lower.contains("dark"):
			color = Color(0.4, 0.42, 0.44)
		elif lower.contains("pale"):
			color = Color(0.6, 0.57, 0.5)
	elif lower.contains("steel"):
		color = Color(0.27, 0.3, 0.34)
		roughness = 0.58
		metallic = 0.7
		kind = 3.0
	elif lower.contains("galv"):
		color = Color(0.52, 0.54, 0.55)
		roughness = 0.5
		metallic = 0.72
		kind = 3.0
	elif lower.contains("rust"):
		color = Color(0.46, 0.2, 0.075)
		roughness = 0.76
		metallic = 0.2
		kind = 4.0
	elif lower.contains("paint_red"):
		color = Color(0.34, 0.055, 0.045)
		roughness = 0.62
		metallic = 0.22
		kind = 4.0
	elif lower.contains("paint_yellow"):
		color = Color(0.48, 0.29, 0.055)
		roughness = 0.66
		metallic = 0.16
		kind = 4.0
	elif lower.contains("foliage"):
		color = Color(0.055, 0.095, 0.06)
		if lower.contains("dry"):
			color = Color(0.16, 0.13, 0.07)
		roughness = 0.88
		kind = 5.0
	elif lower.contains("bark"):
		color = Color(0.13, 0.065, 0.035)
		roughness = 0.84
		kind = 6.0
	elif lower.contains("plastic"):
		color = Color(0.14, 0.15, 0.16)
		roughness = 0.64
		kind = 7.0
	return {"color": color, "roughness": roughness, "metallic": metallic, "kind": kind, "wetness": wetness}


func _extras(node: Node) -> Dictionary:
	if not node.has_meta(&"extras"):
		return {}
	var value: Variant = node.get_meta(&"extras")
	return value as Dictionary if value is Dictionary else {}


func _source_material(mesh_instance: MeshInstance3D) -> Material:
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return null
	return mesh_instance.get_active_material(0)


func _is_surface_family(lower_name: String) -> bool:
	for family: String in ["asphalt", "concrete", "steel", "galv", "rust", "paint_", "foliage", "bark", "plastic", "silhouette"]:
		if lower_name.contains(family):
			return true
	return false


func _is_emissive_source(material: Material, node_name: StringName) -> bool:
	if material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
		return true
	var lower_name: String = String(node_name).to_lower()
	return lower_name.contains("led") or lower_name.contains("trace") or lower_name.contains("strip")


func _route_phase(building: String) -> float:
	var route: Array[String] = ["SPINE", "B04", "B05", "BGCITY", "B02", "YARD", "B01", "B03"]
	var index: int = route.find(building)
	return float(maxi(index, 0)) / float(maxi(route.size() - 1, 1))


func _is_authored_pbr(material: Material) -> bool:
	if not material is StandardMaterial3D:
		return false
	var standard: StandardMaterial3D = material as StandardMaterial3D
	return standard.resource_name.ends_with("_PBR_BAKED_v1") and standard.albedo_texture != null and standard.roughness_texture != null and standard.normal_texture != null
