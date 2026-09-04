class_name MainScene
extends Node3D

@export var support_scene: PackedScene
@export var damage_scene: PackedScene
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D


func _ready() -> void:
	_configure_environment()
	if GameGlobal.instance.players.is_empty():
		_spawn_debug_party()
	else:
		_spawn_roster()


func _spawn_roster() -> void:
	for index: int in GameGlobal.instance.players.size():
		var player_data: Statics.PlayerData = GameGlobal.instance.players[index]
		var character: Character = _instantiate_role(player_data.role)
		if character == null:
			continue
		character.name = str(player_data.id)
		players.add_child(character)
		character.setup(player_data)
		var spawn: Marker3D = spawn_points.get_child(index % spawn_points.get_child_count()) as Marker3D
		character.global_position = spawn.global_position


func _spawn_debug_party() -> void:
	var support: Support = support_scene.instantiate() as Support
	if support == null:
		return
	support.name = "DebugSupport"
	players.add_child(support)
	support.global_position = Vector3(-2.2, 0.4, 0.0)
	support.setup_debug("Astra · Support")
	var companion: Damage = damage_scene.instantiate() as Damage
	if companion != null:
		companion.name = "DebugDamage"
		players.add_child(companion)
		companion.global_position = Vector3(2.2, 0.4, 0.0)
		companion.label_3d.text = "Rune · Damage"
		companion.programming_block.visible = false
		companion.camera_3d.current = false
		companion.input_synchronizer.set_process(false)
		# The companion demonstrates healer target selection under pressure.
		companion.get_health_component().apply_damage(90.0)


func _instantiate_role(role: Statics.Role) -> Character:
	if role == Statics.Role.DAMAGE:
		return damage_scene.instantiate() as Character
	return support_scene.instantiate() as Character


func _configure_environment() -> void:
	var environment: Environment = world_environment.environment
	if environment == null:
		environment = Environment.new()
		world_environment.environment = environment
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.018, 0.055, 0.105)
	sky_material.sky_horizon_color = Color(0.12, 0.28, 0.34)
	sky_material.ground_horizon_color = Color(0.09, 0.2, 0.22)
	sky_material.ground_bottom_color = Color(0.015, 0.025, 0.035)
	sky_material.sky_curve = 0.18
	sky_material.ground_curve = 0.12
	sky_material.sun_angle_max = 18.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.background_energy_multiplier = 0.82
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.54, 0.62)
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.08
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.11, 0.2, 0.27)
	environment.fog_density = 0.008
	environment.fog_height = -0.5
	environment.fog_height_density = 0.08
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 0.68
	directional_light.light_color = Color(1.0, 0.86, 0.7)
	directional_light.light_energy = 1.05
	directional_light.shadow_enabled = true
	directional_light.directional_shadow_max_distance = 45.0
