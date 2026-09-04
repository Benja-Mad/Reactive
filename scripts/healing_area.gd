class_name HealingArea
extends Node3D

const RUNE_TEXTURE: Texture2D = preload("res://assets/generated/healer_rune_circle_frame_0.png")
const ORB_SCENE: PackedScene = preload("res://scenes/effects/healer_orb_sprite.tscn")

@export var radius: float = 3.5
@export var duration: float = 6.0
@export var heal_per_pulse: float = 5.0
@export var pulse_interval: float = 1.0
var source: Character
var _remaining: float = 0.0
var _pulse_remaining: float = 0.0


func _ready() -> void:
	_remaining = duration
	_pulse_remaining = 0.1
	_build_visuals()


func setup_area(caster: Character, area_radius: float, area_duration: float, heal_amount: float) -> void:
	source = caster
	radius = area_radius
	duration = area_duration
	heal_per_pulse = heal_amount


func _process(delta: float) -> void:
	_remaining -= delta
	_pulse_remaining -= delta
	if _pulse_remaining <= 0.0:
		_pulse_remaining = pulse_interval
		_pulse_heal()
	if _remaining <= 0.0:
		queue_free()


func _pulse_heal() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var ally: Character = node as Character
		if ally == null or global_position.distance_to(ally.global_position) > radius:
			continue
		ally.get_health_component().heal(heal_per_pulse, source)
		AbilityVfx.spawn_heal(self, ally)


func _build_visuals() -> void:
	var rune_decal: Decal = Decal.new()
	rune_decal.texture_albedo = RUNE_TEXTURE
	rune_decal.texture_emission = RUNE_TEXTURE
	rune_decal.emission_energy = 0.75
	rune_decal.modulate = Color(0.36, 0.82, 0.58, 0.55)
	rune_decal.albedo_mix = 0.3
	rune_decal.size = Vector3(radius * 1.55, 1.4, radius * 1.55)
	rune_decal.position.y = 0.55
	add_child(rune_decal)
	var boundary: MeshInstance3D = _create_ring(radius, 0.055, Color(0.35, 1.0, 0.7, 0.34), 2.1)
	boundary.position.y = 0.08
	add_child(boundary)
	var orbit_root: Node3D = Node3D.new()
	orbit_root.name = "OrbitingHealMotes"
	add_child(orbit_root)
	for index: int in 8:
		var angle: float = TAU * float(index) / 8.0
		var orb: AnimatedSprite3D = ORB_SCENE.instantiate() as AnimatedSprite3D
		if orb == null:
			continue
		orb.position = Vector3(cos(angle) * radius * 0.84, 0.22 + 0.08 * float(index % 2), sin(angle) * radius * 0.84)
		orb.scale = Vector3.ONE * 0.28
		orbit_root.add_child(orb)
	var orbit: Tween = create_tween().set_loops()
	orbit.tween_property(orbit_root, "rotation:y", TAU, 5.5).from(0.0)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = AbilityVfx.HEAL_COLOR
	light.light_energy = 0.62
	light.omni_range = radius * 1.1
	light.shadow_enabled = false
	light.position.y = 0.35
	add_child(light)
	var pulse: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(boundary, "scale", Vector3(1.025, 1.025, 1.025), 0.85)
	pulse.tween_property(boundary, "scale", Vector3(0.985, 0.985, 0.985), 0.85)


func _create_ring(ring_radius: float, thickness: float, color: Color, energy: float) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = maxf(ring_radius - thickness, 0.05)
	mesh.outer_radius = ring_radius
	mesh.rings = 48
	mesh.ring_segments = 8
	mesh.material = AbilityVfx._material(color, energy, true)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _create_disc(disc_radius: float, height: float, color: Color, energy: float) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = disc_radius
	mesh.bottom_radius = disc_radius
	mesh.height = height
	mesh.radial_segments = 48
	mesh.material = AbilityVfx._material(color, energy, true)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
