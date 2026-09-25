## A disposable projection of server state. Never resolves gameplay locally.
extends StaticBody3D
var system: Node
var construct_id: int
var visual: MeshInstance3D
var fragments: MultiMeshInstance3D
var collider: CollisionShape3D
var material: ShaderMaterial
var last_shape: String = ""
var last_visual_key: String = ""

func _ready() -> void:
	add_to_group("matter_constructs")
	visual = MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	visual.mesh.subdivide_width = 18
	visual.mesh.subdivide_height = 6
	visual.mesh.subdivide_depth = 4
	add_child(visual)
	collider = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	add_child(collider)
	fragments = MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var shard := PrismMesh.new()
	shard.size = Vector3(0.24, 0.5, 0.16)
	multi.mesh = shard
	multi.instance_count = 8
	fragments.multimesh = multi
	add_child(fragments)
	material = ShaderMaterial.new()
	material.shader = preload("res://scripts/matter/surface.gdshader")
	visual.material_override = material
	fragments.material_override = material

func apply(record: Dictionary) -> void:
	global_position = record["position"]
	rotation.y = record["yaw"]
	var key: String = str([record["material"],record["shape"],record["size"],record["attachments"],record.get("reaction",{}),record["integrity"]])
	if key == last_visual_key: return
	last_visual_key = key
	var size: Vector3 = record["size"]
	visual.mesh.size = size
	visual.position.y = size.y * 0.5
	collider.shape.size = size
	collider.position.y = size.y * 0.5
	var debris: bool = record["shape"] == "fragments"
	collision_layer = 1 if preload("res://scripts/matter/materials.gd").has_property(record,"solid") and not debris else 0
	collision_mask = 1
	visual.visible = not debris
	fragments.visible = debris
	material.set_shader_parameter("matter_color", preload("res://scripts/matter/materials.gd").MATERIALS[record["material"]]["color"])
	material.set_shader_parameter("extent",size)
	material.set_shader_parameter("wall",record["shape"] == "wall")
	material.set_shader_parameter("armed",not record.get("reaction",{}).is_empty())
	material.set_shader_parameter("damage",clampf(1.0-float(record["integrity"])/20.0,0.0,1.0))
	material.set_shader_parameter("frozen", "frozen" in record["states"])
	material.set_shader_parameter("coated", record["attachments"].has("nanites"))
	if last_shape != record["shape"]:
		for i in 8:
			var position := Vector3((float(i % 4) - 1.5) * size.x * 0.23, 0.3 + float(i % 3)*0.18, (float(i / 4) - 0.5)*0.8)
			fragments.multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(i*0.5,i*1.3,0.4)), position))
		last_shape = record["shape"]

func take_damage(amount: float) -> void:
	if multiplayer.is_server():
		system.damage_construct(construct_id, amount)
