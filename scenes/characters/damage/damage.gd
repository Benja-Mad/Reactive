class_name Damage
extends Character

@export var fire_attack_scene : PackedScene
@onready var marker_3d: Marker3D = $Marker3D
@onready var fire_attack_spawner: MultiplayerSpawner = $FireAttackSpawner

const FLAME_WAVE_RADIUS: float = 3.0
const FLAME_WAVE_DAMAGE: int = 40

var facing_dir: Vector3 = Vector3.RIGHT

func _ready() -> void:
	super._ready()
	fire_attack_spawner.spawn_function = _spawn_fire_attack


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
	if direction.length() > 0:
		facing_dir = direction
			
func use_ability(ability: Statics.Ability) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
		
	match ability:
		Statics.Ability.FIRE:
			_fire()
		Statics.Ability.FLAME_WAVE:
			_flame_wave()


## Daña a todos los enemigos alrededor; el impacto lo procesa el caster, como los proyectiles.
func _flame_wave() -> void:
	show_flame_wave.rpc()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy != null and enemy.global_position.distance_to(global_position) <= FLAME_WAVE_RADIUS:
			enemy.take_damage(FLAME_WAVE_DAMAGE)


@rpc("call_local")
func show_flame_wave() -> void:
	var ring := Sprite3D.new()
	ring.texture = preload("res://materials/combat/wave.png")
	ring.hframes = ring.texture.get_width() / ring.texture.get_height()
	ring.axis = Vector3.AXIS_Y
	ring.pixel_size = FLAME_WAVE_RADIUS * 2.0 / ring.texture.get_height()
	ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(ring)
	ring.global_position = $Footprint.global_position + Vector3.UP * 0.05
	ring.scale = Vector3.ONE * 0.22
	CombatFeedback.sound(self, preload("res://materials/combat/ignition.wav"), -7.5)
	var spread := ring.create_tween().set_parallel(true)
	spread.tween_property(ring, "scale", Vector3.ONE, 0.23).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	spread.tween_property(ring, "modulate:a", 0.0, 0.19).set_delay(0.17)
	CombatFeedback.play_frames(ring, 0.36)


func _fire() -> void:
	cast_animation(&"Fire", 0.24)
	fire_attack_spawner.spawn({
		"pos": global_position + facing_dir * marker_3d.position.x + Vector3.UP * marker_3d.position.y,
		"facing_dir": facing_dir
	})
	
func _spawn_fire_attack(data: Dictionary) -> Node:
	if not fire_attack_scene:
		return null
	var fire_inst: Node3D = fire_attack_scene.instantiate()
	fire_inst.direction = data.facing_dir
	fire_inst.position = data.pos
	fire_inst.set_multiplayer_authority(get_multiplayer_authority())
	return fire_inst
