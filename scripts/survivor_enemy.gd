class_name SurvivorEnemy
extends CharacterBody3D

const CHASER_TEXTURE: Texture2D = preload("res://assets/generated/enemy_chaser_sprite_frame_0.png")
const FAST_TEXTURE: Texture2D = preload("res://assets/generated/enemy_fast_sprite_frame_0.png")
const TANK_TEXTURE: Texture2D = preload("res://assets/generated/enemy_tank_sprite_frame_0.png")

enum Archetype {
	CHASER,
	FAST,
	TANK,
}

@export var archetype: Archetype = Archetype.CHASER
@export var move_speed: float = 2.1
@export var max_health: float = 35.0
@export var contact_damage: float = 8.0
@export var attack_interval: float = 1.0
var _health: HealthComponent
var _target: Character
var _attack_cooldown: float = 0.0
var _poison_remaining: float = 0.0
var _poison_tick: float = 0.0
var _poison_damage: float = 0.0


func _ready() -> void:
	add_to_group(&"enemies")
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	_health = HealthComponent.new()
	_health.max_health = max_health
	add_child(_health)
	_health.died.connect(_on_died)
	_build_visual()


func configure(type: Archetype, wave: int) -> void:
	archetype = type
	match archetype:
		Archetype.FAST:
			move_speed = 3.4 + wave * 0.04
			max_health = 18.0 + wave * 2.0
			contact_damage = 6.0
		Archetype.TANK:
			move_speed = 1.25 + wave * 0.025
			max_health = 95.0 + wave * 8.0
			contact_damage = 15.0
		_:
			move_speed = 2.1 + wave * 0.035
			max_health = 35.0 + wave * 4.0
			contact_damage = 8.0


func get_health_component() -> HealthComponent:
	return _health


func apply_status(status_name: StringName, duration: float, power: float, status_source: Character) -> void:
	if status_name != &"poison":
		return
	_poison_remaining = maxf(_poison_remaining, duration)
	_poison_damage = maxf(_poison_damage, power)
	_poison_tick = 0.15
	AbilityVfx.spawn_status(self, Color(0.42, 1.0, 0.24), duration)
	if status_source != null:
		_target = status_source


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_process_poison(delta)
	if _target == null or not is_instance_valid(_target) or not _target.get_health_component().is_alive():
		_target = _find_nearest_player()
	if _target == null:
		velocity = Vector3.ZERO
		return
	var offset: Vector3 = _target.global_position - global_position
	offset.y = 0.0
	if offset.length() > 0.85:
		velocity = offset.normalized() * move_speed
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval
			_target.get_health_component().apply_damage(contact_damage, self)


func _process_poison(delta: float) -> void:
	if _poison_remaining <= 0.0:
		return
	_poison_remaining -= delta
	_poison_tick -= delta
	if _poison_tick <= 0.0:
		_poison_tick = 1.0
		_health.apply_damage(_poison_damage, _target)


func _find_nearest_player() -> Character:
	var nearest: Character = null
	var distance_squared: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var candidate: Character = node as Character
		if candidate == null:
			continue
		var candidate_distance: float = global_position.distance_squared_to(candidate.global_position)
		if candidate_distance < distance_squared:
			distance_squared = candidate_distance
			nearest = candidate
	return nearest


func _on_died(source: Node) -> void:
	if source is Character:
		(source as Character).get_program_executor().notify_enemy_killed()
	var death: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	death.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
	death.tween_callback(queue_free)


func _build_visual() -> void:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.name = "EnemySprite"
	sprite.texture = CHASER_TEXTURE
	sprite.pixel_size = 0.022
	sprite.position.y = 0.92
	if archetype == Archetype.FAST:
		sprite.texture = FAST_TEXTURE
		sprite.pixel_size = 0.019
		sprite.position.y = 0.78
	elif archetype == Archetype.TANK:
		sprite.texture = TANK_TEXTURE
		sprite.pixel_size = 0.027
		sprite.position.y = 1.08
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(sprite)
	var bob: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(sprite, "position:y", sprite.position.y + 0.045, 0.55)
	bob.tween_property(sprite, "position:y", sprite.position.y, 0.55)
