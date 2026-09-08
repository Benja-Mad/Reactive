extends Node

const SECTOR_SCENE: String = "res://scenes/environment/sector_08/Sector08LookDev.tscn"
const SOURCE_GLB: String = "res://scenes/environment/sector_08/slice_all.glb"
const SHADERS: Array[String] = [
	"res://scenes/environment/sector_08/runtime/window_reactive_glass.gdshader",
	"res://scenes/environment/sector_08/runtime/window_reactive_interior.gdshader",
	"res://scenes/environment/sector_08/runtime/reactive_facade.gdshader",
	"res://scenes/environment/sector_08/runtime/reactive_spine.gdshader",
]


func test_sector_lookdev_resources_load() -> void:
	assert(load(SECTOR_SCENE) is PackedScene)
	assert(load(SOURCE_GLB) is PackedScene)
	for shader_path: String in SHADERS:
		var shader: Shader = load(shader_path) as Shader
		assert(shader != null)


func test_imported_extras_and_vertex_channels_are_auditable() -> void:
	var packed: PackedScene = load(SOURCE_GLB) as PackedScene
	var source: Node = packed.instantiate()
	var reactive: Node = source.get_node("CS_REACTIVE")
	var owner_b04: Node = reactive.get_node("OWNER_B04")
	assert(owner_b04.has_meta(&"extras"))
	var extras: Dictionary = owner_b04.get_meta(&"extras") as Dictionary
	assert(int(extras.get("cs_route_index", -1)) == 1)
	assert(extras.get("cs_pattern_grid", []).size() == 2)
	var first_mesh: MeshInstance3D = _find_first_mesh(source)
	assert(first_mesh != null)
	var arrays: Array = first_mesh.mesh.surface_get_arrays(0)
	assert(arrays[Mesh.ARRAY_VERTEX] != null)
	assert(arrays[Mesh.ARRAY_TEX_UV] != null)
	source.free()


func _find_first_mesh(root: Node) -> MeshInstance3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			return node as MeshInstance3D
		for child: Node in node.get_children():
			stack.append(child)
	return null
