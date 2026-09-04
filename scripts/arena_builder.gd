class_name ArenaBuilder
extends Node3D

const RUIN_TEXTURE: Texture2D = preload("res://assets/generated/hd2d_ruin_stone_frame_0.png")
const WATER_TEXTURE: Texture2D = preload("res://assets/generated/hd2d_moon_water_frame_0.png")
const WATER_SHADER: Shader = preload("res://scenes/shaders/hd2d_water.gdshader")
const ROCK_A: PackedScene = preload("res://demo/assets/models/RockA.tscn")
const ROCK_B: PackedScene = preload("res://demo/assets/models/RockB.tscn")
const ROCK_C: PackedScene = preload("res://demo/assets/models/RockC.tscn")
const CRYSTAL_SCENE: PackedScene = preload("res://demo/assets/models/CrystalC.tscn")
const FOLIAGE_TEXTURE: Texture2D = preload("res://assets/generated/enchanted_fern_clump_frame_0.png")
const SANCTUARY_SIGIL: Texture2D = preload("res://assets/generated/sanctuary_moon_sigil_frame_0.png")
const TREE_TEXTURE: Texture2D = preload("res://assets/generated/ancient_ruin_tree_frame_0.png")

var _stone: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _moss: StandardMaterial3D
var _water: ShaderMaterial
var _wood: StandardMaterial3D
var _crystal: StandardMaterial3D
var _foliage: StandardMaterial3D
var _sanctuary: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_build_zones()


func _create_materials() -> void:
	_stone = _mat(Color(0.96, 0.98, 1.0), 0.92)
	_stone_dark = _mat(Color(0.52, 0.58, 0.64), 0.96)
	for stone_material: StandardMaterial3D in [_stone, _stone_dark]:
		stone_material.albedo_texture = RUIN_TEXTURE
		stone_material.uv1_triplanar = true
		stone_material.uv1_world_triplanar = true
		stone_material.uv1_scale = Vector3(0.75, 0.75, 0.75)
	_moss = _mat(Color(0.32, 0.5, 0.34), 0.9)
	_moss.albedo_texture = RUIN_TEXTURE
	_moss.uv1_triplanar = true
	_moss.uv1_world_triplanar = true
	_moss.uv1_scale = Vector3(0.9, 0.9, 0.9)
	_wood = _mat(Color(0.31, 0.19, 0.1), 0.85)
	_foliage = _mat(Color(0.2, 0.48, 0.25), 0.88)
	_sanctuary = _mat(Color(0.68, 0.74, 0.76), 0.58)
	_sanctuary.albedo_texture = RUIN_TEXTURE
	_sanctuary.uv1_triplanar = true
	_sanctuary.uv1_world_triplanar = true
	_sanctuary.uv1_scale = Vector3(1.15, 1.15, 1.15)
	_sanctuary.metallic = 0.12
	_water = ShaderMaterial.new()
	_water.shader = WATER_SHADER
	_water.set_shader_parameter(&"water_texture", WATER_TEXTURE)
	_crystal = AbilityVfx._material(Color(0.32, 0.76, 1.0), 4.2, true)


func _build_zones() -> void:
	# An irregular flat ribbon avoids the previous transparent blue-box look.
	_add_river()
	for bank_z: float in [-14.0, -5.5, 5.5, 14.0]:
		var center_x: float = _river_center_x(bank_z)
		var bank_width: float = _river_half_width(bank_z) + 0.35
		_add_rock(Vector3(center_x - bank_width, 0.0, bank_z), randf_range(0.32, 0.46), false)
		_add_rock(Vector3(center_x + bank_width, 0.0, bank_z + randf_range(-0.7, 0.7)), randf_range(0.3, 0.44), false)
	for fern_z: float in [-15.5, -12.0, -3.8, 3.8, 12.0, 15.5]:
		var fern_center: float = _river_center_x(fern_z)
		var fern_width: float = _river_half_width(fern_z) + 0.22
		_add_fern(Vector3(fern_center - fern_width, 0.0, fern_z), randf_range(0.65, 0.95))
		_add_fern(Vector3(fern_center + fern_width, 0.0, fern_z + 0.35), randf_range(0.6, 0.9))
	_add_bridge(Vector3(0.0, 0.03, -8.5), 5.4, 3.2)
	_add_bridge(Vector3(0.0, 0.03, 8.5), 5.4, 3.2)
	# Central sanctuary: broken paver ring, textured center and asymmetric crystals.
	_add_sanctuary_floor()
	_add_sanctuary_decal()
	var shrine_angles: PackedFloat32Array = PackedFloat32Array([0.42, 2.48, 4.82])
	for index: int in shrine_angles.size():
		var angle: float = shrine_angles[index]
		_add_crystal(Vector3(cos(angle) * 3.45, 0.1, sin(angle) * 3.45), 0.44 + float(index) * 0.06)
	# Western ruins form readable funnels.
	_add_arch(Vector3(-10.5, 0.0, -5.0), 0.0)
	_add_arch(Vector3(-10.5, 0.0, 5.0), 0.0)
	_add_wall_segment(Vector3(-13.0, 0.0, 0.0), Vector3(1.2, 2.2, 7.0))
	_add_wall_segment(Vector3(-7.8, 0.0, -9.0), Vector3(6.0, 1.5, 1.0))
	_add_stairs(Vector3(-9.0, 0.0, 0.0), Vector3.RIGHT)
	# Eastern crystal garden is mostly open, with small kiting obstacles.
	for point: Vector3 in [Vector3(10.0, 0.0, -7.0), Vector3(13.0, 0.0, -2.0), Vector3(9.0, 0.0, 5.0), Vector3(14.0, 0.0, 8.0)]:
		_add_crystal(point, randf_range(0.7, 1.25))
		_add_rock(point + Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2)), randf_range(0.55, 1.0), true)
	# Southern broken colonnade creates a risky narrow route.
	for x: int in range(-12, 13, 4):
		_add_pillar(Vector3(float(x), 0.0, 13.0), 0.52, 2.4 if x % 8 == 0 else 1.45)
	# Perimeter silhouette and soft collision boundary.
	for index: int in 24:
		var angle: float = TAU * float(index) / 24.0 + randf_range(-0.08, 0.08)
		var radius_x: float = 20.5 + randf_range(-1.4, 1.4)
		var radius_z: float = 17.0 + randf_range(-1.0, 1.0)
		var perimeter_point: Vector3 = Vector3(cos(angle) * radius_x, 0.0, sin(angle) * radius_z)
		_add_rock(perimeter_point, randf_range(0.7, 1.35), index % 2 == 0)
	_add_background_trees()
	_add_boundary_walls()
	_add_vegetation_clusters()


func _add_river() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 24
	for index: int in segments:
		var t0: float = float(index) / float(segments)
		var t1: float = float(index + 1) / float(segments)
		var z0: float = lerpf(-17.45, 17.45, t0)
		var z1: float = lerpf(-17.45, 17.45, t1)
		var center0: float = _river_center_x(z0)
		var center1: float = _river_center_x(z1)
		var width0: float = _river_half_width(z0)
		var width1: float = _river_half_width(z1)
		var left0: Vector3 = Vector3(center0 - width0, 0.028, z0)
		var right0: Vector3 = Vector3(center0 + width0, 0.028, z0)
		var left1: Vector3 = Vector3(center1 - width1, 0.028, z1)
		var right1: Vector3 = Vector3(center1 + width1, 0.028, z1)
		_add_river_vertex(surface, left0, Vector2(0.0, t0))
		_add_river_vertex(surface, left1, Vector2(0.0, t1))
		_add_river_vertex(surface, right0, Vector2(1.0, t0))
		_add_river_vertex(surface, right0, Vector2(1.0, t0))
		_add_river_vertex(surface, left1, Vector2(0.0, t1))
		_add_river_vertex(surface, right1, Vector2(1.0, t1))
	var river_mesh: ArrayMesh = surface.commit() as ArrayMesh
	if river_mesh == null:
		return
	river_mesh.surface_set_material(0, _water)
	var river: MeshInstance3D = MeshInstance3D.new()
	river.name = "MoonRiver"
	river.mesh = river_mesh
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river)


func _add_river_vertex(surface: SurfaceTool, vertex: Vector3, uv: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(vertex)


func _river_center_x(z_value: float) -> float:
	return sin(z_value * 0.27) * 0.48 + sin(z_value * 0.11 + 0.8) * 0.28


func _river_half_width(z_value: float) -> float:
	return 1.85 + sin(z_value * 0.39 + 1.1) * 0.22 + sin(z_value * 0.17) * 0.12


func _add_sanctuary_floor() -> void:
	var center_mesh: CylinderMesh = CylinderMesh.new()
	center_mesh.top_radius = 2.62
	center_mesh.bottom_radius = 2.68
	center_mesh.height = 0.035
	center_mesh.radial_segments = 12
	center_mesh.material = _sanctuary
	var center: MeshInstance3D = MeshInstance3D.new()
	center.name = "SanctuaryCenter"
	center.mesh = center_mesh
	center.position.y = 0.018
	add_child(center)
	for index: int in 12:
		var angle: float = TAU * float(index) / 12.0
		var paver_mesh: BoxMesh = BoxMesh.new()
		paver_mesh.size = Vector3(1.42, 0.045, 0.72)
		paver_mesh.material = _stone
		var paver: MeshInstance3D = MeshInstance3D.new()
		paver.name = "SanctuaryRingStone"
		paver.mesh = paver_mesh
		paver.position = Vector3(cos(angle) * 3.36, 0.023, sin(angle) * 3.36)
		paver.rotation.y = -angle + PI * 0.5
		paver.scale = Vector3(randf_range(0.9, 1.06), 1.0, randf_range(0.9, 1.04))
		add_child(paver)


func _add_sanctuary_decal() -> void:
	var decal: Decal = Decal.new()
	decal.name = "SanctuaryMoonSigil"
	decal.texture_albedo = SANCTUARY_SIGIL
	decal.texture_emission = SANCTUARY_SIGIL
	decal.emission_energy = 0.82
	decal.modulate = Color(0.5, 0.72, 0.8, 0.72)
	decal.albedo_mix = 0.52
	decal.size = Vector3(5.0, 1.1, 5.0)
	decal.position = Vector3(0.0, 0.28, 0.0)
	add_child(decal)


func _add_bridge(world_position: Vector3, width: float, depth: float) -> void:
	# Walkable bridge deck remains almost coplanar with the global floor.
	# Only the clearly visible side rails block movement.
	_add_box("BridgeDeck", Vector3(width, 0.06, depth), world_position, _stone, false)
	for x: float in [-width * 0.42, width * 0.42]:
		_add_box("BridgeRail", Vector3(0.22, 0.45, depth), world_position + Vector3(x, 0.23, 0.0), _stone_dark, true)


func _add_arch(world_position: Vector3, rotation_y: float) -> void:
	var root: Node3D = Node3D.new()
	root.position = world_position
	root.rotation.y = rotation_y
	add_child(root)
	_add_box_to(root, "ArchLeft", Vector3(0.75, 3.0, 0.9), Vector3(-1.45, 1.5, 0.0), _stone, true)
	_add_box_to(root, "ArchRight", Vector3(0.75, 3.0, 0.9), Vector3(1.45, 1.5, 0.0), _stone, true)
	_add_box_to(root, "ArchLintel", Vector3(3.65, 0.75, 0.9), Vector3(0.0, 3.0, 0.0), _stone_dark, true)


func _add_wall_segment(world_position: Vector3, size: Vector3) -> void:
	var runs_along_z: bool = size.z > size.x
	var height_factors: PackedFloat32Array = PackedFloat32Array([0.72, 1.0, 0.58])
	for piece: int in 3:
		var offset_ratio: float = float(piece - 1)
		var piece_height: float = size.y * height_factors[piece]
		var piece_size: Vector3
		var piece_position: Vector3
		if runs_along_z:
			piece_size = Vector3(size.x, piece_height, size.z * 0.26)
			piece_position = world_position + Vector3(0.0, piece_height * 0.5, offset_ratio * size.z * 0.32)
		else:
			piece_size = Vector3(size.x * 0.26, piece_height, size.z)
			piece_position = world_position + Vector3(offset_ratio * size.x * 0.32, piece_height * 0.5, 0.0)
		_add_box("BrokenWallPiece", piece_size, piece_position, _stone, true)
		_add_box("MossCap", Vector3(piece_size.x * 1.04, 0.08, piece_size.z * 1.04), piece_position + Vector3.UP * (piece_height * 0.5 + 0.04), _moss, false)


func _add_stairs(origin: Vector3, direction: Vector3) -> void:
	# Uneven, coplanar paving suggests a ruined path without creating step collisions.
	for step: int in 4:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(randf_range(1.0, 1.35), 0.035, randf_range(1.55, 2.15))
		mesh.material = _stone
		var paver: MeshInstance3D = MeshInstance3D.new()
		paver.name = "RuinPaver"
		paver.mesh = mesh
		paver.position = origin + direction * float(step) * 1.48 + Vector3(0.0, 0.018, randf_range(-0.28, 0.28))
		paver.rotation.y = randf_range(-0.11, 0.11)
		add_child(paver)


func _add_pillar(world_position: Vector3, radius: float, height: float) -> void:
	_add_cylinder("Pillar", radius, height, world_position + Vector3.UP * height * 0.5, _stone, true)
	_add_cylinder("PillarCap", radius * 1.25, 0.18, world_position + Vector3.UP * height, _stone_dark, false)


func _add_crystal(world_position: Vector3, scale_factor: float) -> void:
	var crystal: Node3D = CRYSTAL_SCENE.instantiate() as Node3D
	if crystal == null:
		return
	crystal.name = "CrystalLandmark"
	crystal.position = world_position + Vector3.UP * 0.72 * scale_factor
	crystal.scale = Vector3.ONE * 0.22 * scale_factor
	crystal.rotation.y = randf_range(0.0, TAU)
	add_child(crystal)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.25, 0.7, 1.0)
	light.light_energy = 2.1 * scale_factor
	light.omni_range = 4.5 * scale_factor
	light.shadow_enabled = false
	light.position = world_position + Vector3.UP * 1.0
	add_child(light)


func _add_rock(world_position: Vector3, scale_factor: float, collidable: bool) -> void:
	var rock_scene: PackedScene = ROCK_A
	var variant: int = randi() % 3
	if variant == 1:
		rock_scene = ROCK_B
	elif variant == 2:
		rock_scene = ROCK_C
	var rock: StaticBody3D = rock_scene.instantiate() as StaticBody3D
	if rock == null:
		return
	rock.name = "WeatheredRock"
	rock.position = world_position + Vector3.UP * 0.36 * scale_factor
	rock.scale = Vector3(0.22, 0.18, 0.24) * scale_factor * Vector3(randf_range(0.85, 1.2), randf_range(0.8, 1.15), randf_range(0.85, 1.2))
	rock.rotation = Vector3(randf_range(-0.16, 0.16), randf_range(0.0, TAU), randf_range(-0.14, 0.14))
	if not collidable:
		rock.collision_layer = 0
		rock.collision_mask = 0
	add_child(rock)


func _add_background_trees() -> void:
	for index: int in 14:
		var angle: float = TAU * float(index) / 14.0 + randf_range(-0.12, 0.12)
		var tree_position: Vector3 = Vector3(cos(angle) * randf_range(21.5, 24.0), 0.0, sin(angle) * randf_range(18.0, 20.5))
		var tree: Sprite3D = Sprite3D.new()
		tree.name = "AncientTree"
		tree.texture = TREE_TEXTURE
		tree.pixel_size = 0.025
		tree.position = tree_position + Vector3.UP * 2.35
		tree.scale = Vector3.ONE * randf_range(0.86, 1.34)
		tree.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tree.shaded = false
		tree.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		tree.render_priority = -1
		add_child(tree)


func _add_boundary_walls() -> void:
	_add_collision_box("NorthBoundary", Vector3(42.0, 3.0, 0.8), Vector3(0.0, 1.5, -17.5))
	_add_collision_box("SouthBoundary", Vector3(42.0, 3.0, 0.8), Vector3(0.0, 1.5, 17.5))
	_add_collision_box("WestBoundary", Vector3(0.8, 3.0, 35.0), Vector3(-21.0, 1.5, 0.0))
	_add_collision_box("EastBoundary", Vector3(0.8, 3.0, 35.0), Vector3(21.0, 1.5, 0.0))


func _add_vegetation_clusters() -> void:
	for index: int in 28:
		var angle: float = randf_range(0.0, TAU)
		var distance: float = randf_range(9.5, 18.5)
		var plant_position: Vector3 = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance * 0.78)
		_add_fern(plant_position, randf_range(0.72, 1.18))


func _add_fern(world_position: Vector3, scale_factor: float) -> void:
	var plant: Sprite3D = Sprite3D.new()
	plant.name = "FernClump"
	plant.texture = FOLIAGE_TEXTURE
	plant.pixel_size = 0.012
	plant.position = world_position + Vector3.UP * 0.42
	plant.scale = Vector3.ONE * scale_factor
	plant.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plant.shaded = false
	plant.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(plant)


func _add_collision_box(name_value: String, size: Vector3, world_position: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_value
	body.position = world_position
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)


func _add_box(name_value: String, size: Vector3, world_position: Vector3, material: Material, collision: bool) -> void:
	_add_box_to(self, name_value, size, world_position, material, collision)


func _add_box_to(parent: Node3D, name_value: String, size: Vector3, local_position: Vector3, material: Material, collision: bool) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.position = local_position
	parent.add_child(instance)
	if collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.position = local_position
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		parent.add_child(body)


func _add_cylinder(name_value: String, radius: float, height: float, world_position: Vector3, material: Material, collision: bool) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.position = world_position
	add_child(instance)
	if collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.position = world_position
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		body.add_child(shape_node)
		add_child(body)


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
