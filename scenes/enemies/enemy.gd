class_name Enemy
extends CharacterBody3D

const SPEED: float = 2.5
const ATTACK_RANGE: float = 1.5
const ATTACK_DAMAGE: int = 75
const ATTACK_COOLDOWN: float = 1.0

@export var maxHealth: int = 30
var currentHealth: int
var attack_timer: float = 0.0

#@onready var health_bar: ProgressBar = get_node_or_null("HealthBar/SubViewport/ProgressBar")


func _ready() -> void:
	add_to_group("enemies")
	currentHealth = maxHealth
	#_update_health_bar()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var target := _nearest_player()
	if target != null:
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()
		if distance > ATTACK_RANGE:
			var dir := to_target.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = ATTACK_COOLDOWN
				target.take_damage(ATTACK_DAMAGE)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


func _nearest_player() -> Character:
	var nearest: Character = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Character
		if player == null or player.is_dead:
			continue
		var dist := global_position.distance_squared_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player
	return nearest


func take_damage(amount: int) -> void:
	apply_damage.rpc(amount)


@rpc("any_peer", "call_local", "reliable")
func apply_damage(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	currentHealth = maxi(0, currentHealth - amount)
	#broadcast_enemy_hp.rpc(currentHealth)
	if currentHealth <= 0:
		queue_free()


#@rpc("call_local")
#func broadcast_enemy_hp(new_health: int) -> void:
#	currentHealth = new_health
#	_update_health_bar()


#func _update_health_bar() -> void:
#	if health_bar == null:
#		return
#	health_bar.max_value = maxHealth
#	health_bar.value = currentHealth
