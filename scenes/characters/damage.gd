class_name Damage
extends Character

const FireAttackType = preload("res://scripts/fire_attack.gd")

@export var fire_attack_scene: PackedScene
@onready var marker_3d: Marker3D = $Marker3D
var facing_dir: Vector3 = Vector3.FORWARD


func _ready() -> void:
	super._ready()
	var defaults: Array[ProgramInstruction] = [ProgramInstruction.every_projectile(2.0, 12.0)]
	var poison_on_kill: ProgramInstruction = ProgramInstruction.new()
	poison_on_kill.label = "OnEnemyKilled → NearestEnemy → ApplyStatus(Poison)"
	poison_on_kill.trigger = ProgramInstruction.Trigger.ON_ENEMY_KILLED
	poison_on_kill.target_selector = ProgramInstruction.TargetSelector.NEAREST_ENEMY
	poison_on_kill.action = ProgramInstruction.Action.APPLY_STATUS
	poison_on_kill.status_name = &"poison"
	poison_on_kill.duration = 4.0
	poison_on_kill.power = 4.0
	defaults.append(poison_on_kill)
	get_program_executor().set_instructions(defaults)


func execute_program_instruction(instruction: ProgramInstruction, target: Node3D) -> void:
	if target == null:
		return
	if instruction.action == ProgramInstruction.Action.PROJECTILE_DAMAGE:
		_fire_at(target, instruction.power)
	elif instruction.action == ProgramInstruction.Action.APPLY_STATUS and target.has_method("apply_status"):
		target.call("apply_status", instruction.status_name, instruction.duration, instruction.power, self)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction.length() > 0.0:
		facing_dir = direction
	if Input.is_action_just_pressed(&"Fire"):
		_fire_direction(facing_dir, 12.0)


func _fire_at(target: Node3D, power: float) -> void:
	var direction: Vector3 = (target.global_position - marker_3d.global_position).normalized()
	var projectile: FireAttackType = _spawn_projectile(power)
	if projectile == null:
		return
	projectile.setup_projectile(self, direction, target, power)


func _fire_direction(direction: Vector3, power: float) -> void:
	var projectile: FireAttackType = _spawn_projectile(power)
	if projectile == null:
		return
	projectile.setup_projectile(self, direction.normalized(), null, power)


func _spawn_projectile(power: float) -> FireAttackType:
	var projectile: FireAttackType = fire_attack_scene.instantiate() as FireAttackType
	if projectile == null:
		return null
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = marker_3d.global_position
	projectile.damage = power
	return projectile
