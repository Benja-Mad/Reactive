class_name Sector08RuntimeBaselineSnapshot
extends Node3D

const GLASS_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/window_reactive_glass.gdshader"
const INTERIOR_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/window_reactive_interior.gdshader"
const FACADE_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/reactive_facade.gdshader"
const SPINE_SHADER_PATH: String = "res://scenes/environment/sector_08/runtime/reactive_spine.gdshader"
const PATTERN_TEXTURE_PATH: String = "res://scenes/environment/sector_08/slice_all_CS_Glyphs.png"

@export var enhanced_materials: bool = true
@onready var imported_environment: Node3D = $ImportedEnvironment

var mesh_instance_count: int = 0
var surface_count: int = 0
var imported_material_count: int = 0
var shader_material_count: int = 0
var overridden_mesh_count: int = 0
var metadata_node_count: int = 0
var window_mesh_count: int = 0
var interior_mesh_count: int = 0
var spine_mesh_count: int = 0
var facade_mesh_count: int = 0
var _reactive_meshes: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _glass_material: ShaderMaterial
var _interior_material: ShaderMaterial
var _facade_material: ShaderMaterial
var _spine_material: ShaderMaterial


func _ready() -> void:
	_create_shared_materials()
	_audit_and_bind()
	set_enhanced(enhanced_materials)
	print("Sector08Runtime: meshes=%d surfaces=%d imported_materials=%d reactive_overrides=%d (glass=%d interior=%d facade=%d spine=%d) shader_materials=%d metadata_nodes=%d" % [mesh_instance_count, surface_count, imported_material_count, overridden_mesh_count, window_mesh_count, interior_mesh_count, facade_mesh_count, spine_mesh_count, shader_material_count, metadata_node_count])


func get_reactive_materials() -> Array[ShaderMaterial]:
	return _materials


func set_enhanced(enabled: bool) -> void:
	enhanced_materials = enabled
	for mesh_instance: MeshInstance3D in _reactive_meshes:
		var runtime_material: Material = mesh_instance.get_meta(&"cs_runtime_material", null) as Material
		mesh_instance.material_override = runtime_material if enabled else null


func is_enhanced() -> bool:
	return enhanced_materials


func get_runtime_report() -> Dictionary:
	return {
		"mesh_instances": mesh_instance_count,
		"surfaces": surface_count,
		"imported_materials": imported_material_count,
		"shader_materials": shader_material_count,
		"overridden_meshes": overridden_mesh_count,
		"window_glass_meshes": window_mesh_count,
		"window_interior_meshes": interior_mesh_count,
		"facade_meshes": facade_mesh_count,
		"spine_meshes": spine_mesh_count,
		"metadata_nodes": metadata_node_count,
	}


func _create_shared_materials() -> void:
	_glass_material = _shader_material(GLASS_SHADER_PATH)
	_interior_material = _shader_material(INTERIOR_SHADER_PATH)
	_facade_material = _shader_material(FACADE_SHADER_PATH)
	_spine_material = _shader_material(SPINE_SHADER_PATH)
	var pattern_texture: Texture2D = load(PATTERN_TEXTURE_PATH) as Texture2D
	_interior_material.set_shader_parameter(&"pattern_mask", pattern_texture)
	_facade_material.set_shader_parameter(&"pattern_mask", pattern_texture)
	_materials = [_glass_material, _interior_material, _facade_material, _spine_material]
	shader_material_count = _materials.size()


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
			_bind_reactive_mesh(mesh_instance)
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


func _bind_reactive_mesh(mesh_instance: MeshInstance3D) -> void:
	if not mesh_instance.has_meta(&"extras"):
		return
	var extras_value: Variant = mesh_instance.get_meta(&"extras")
	if not extras_value is Dictionary:
		return
	var extras: Dictionary = extras_value as Dictionary
	var channel: String = str(extras.get("cs_channel", ""))
	var building: String = str(extras.get("cs_building", ""))
	var source_material: Material = mesh_instance.get_active_material(0) if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0 else null
	var source_name: String = source_material.resource_name if source_material != null else ""
	var runtime_material: ShaderMaterial
	if channel == "emissive_windows":
		runtime_material = _interior_material
		interior_mesh_count += 1
	elif channel == "windows" and (source_name.to_lower().contains("glass") or String(mesh_instance.name).to_lower().contains("window")):
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
	var local_coord: Vector3 = Vector3(float(extras.get("cs_local_u", 0.5)), float(extras.get("cs_local_w", 0.5)), float(extras.get("cs_local_v", 0.5)))
	var seed_value: float = float(abs(hash("%s:%s" % [building, mesh_instance.name])) % 10000) / 10000.0
	mesh_instance.set_meta(&"cs_runtime_material", runtime_material)
	mesh_instance.set_instance_shader_parameter(&"cs_local_coord", local_coord)
	mesh_instance.set_instance_shader_parameter(&"cs_building_seed", seed_value)
	mesh_instance.set_instance_shader_parameter(&"cs_route_index", float(extras.get("cs_route_index", -1.0)))
	mesh_instance.set_instance_shader_parameter(&"cs_phase_offset", float(extras.get("cs_phase_offset", _route_phase(building))))
	_reactive_meshes.append(mesh_instance)
	overridden_mesh_count += 1


func _is_emissive_source(material: Material, node_name: StringName) -> bool:
	if material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
		return true
	var lower_name: String = String(node_name).to_lower()
	return lower_name.contains("led") or lower_name.contains("trace") or lower_name.contains("strip")


func _route_phase(building: String) -> float:
	var route: Array[String] = ["SPINE", "B04", "B05", "BGCITY", "B02", "YARD", "B01", "B03"]
	var index: int = route.find(building)
	return float(maxi(index, 0)) / float(maxi(route.size() - 1, 1))
