class_name ProgramExecutor
extends Node

signal instruction_executed(instruction: ProgramInstruction, target: Node3D)

var owner_character: Character
var instructions: Array[ProgramInstruction] = []
var _elapsed: Array[float] = []


func setup(character: Character) -> void:
	owner_character = character


func set_instructions(value: Array[ProgramInstruction]) -> void:
	instructions = value.duplicate()
	_elapsed.clear()
	for _instruction: ProgramInstruction in instructions:
		_elapsed.append(0.0)


func add_instruction(instruction: ProgramInstruction) -> void:
	instructions.append(instruction)
	_elapsed.append(0.0)


func _process(delta: float) -> void:
	if owner_character == null or not is_instance_valid(owner_character):
		return
	for index: int in instructions.size():
		var instruction: ProgramInstruction = instructions[index]
		if instruction.trigger != ProgramInstruction.Trigger.EVERY:
			continue
		_elapsed[index] += delta
		if _elapsed[index] < instruction.interval:
			continue
		_elapsed[index] = 0.0
		_execute(instruction)


func notify_enemy_killed() -> void:
	for instruction: ProgramInstruction in instructions:
		if instruction.trigger == ProgramInstruction.Trigger.ON_ENEMY_KILLED:
			_execute(instruction)


func _execute(instruction: ProgramInstruction) -> void:
	var target: Node3D = _select_target(instruction.target_selector)
	if target == null or not _passes_condition(instruction, target):
		return
	owner_character.execute_program_instruction(instruction, target)
	instruction_executed.emit(instruction, target)


func _select_target(selector: ProgramInstruction.TargetSelector) -> Node3D:
	match selector:
		ProgramInstruction.TargetSelector.SELF:
			return owner_character
		ProgramInstruction.TargetSelector.NEAREST_ENEMY:
			return _nearest_from_group(&"enemies")
		ProgramInstruction.TargetSelector.LOWEST_HP_ALLY:
			return _lowest_health_ally()
	return null


func _nearest_from_group(group_name: StringName) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = INF
	for candidate_node: Node in get_tree().get_nodes_in_group(group_name):
		var candidate: Node3D = candidate_node as Node3D
		if candidate == null:
			continue
		var health: HealthComponent = _get_health(candidate)
		if health != null and not health.is_alive():
			continue
		var distance: float = owner_character.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func _lowest_health_ally() -> Node3D:
	var selected: Character = owner_character
	var lowest_ratio: float = owner_character.get_health_component().get_health_ratio()
	for candidate_node: Node in get_tree().get_nodes_in_group(&"players"):
		var candidate: Character = candidate_node as Character
		if candidate == null:
			continue
		var health: HealthComponent = candidate.get_health_component()
		if health.is_alive() and health.get_health_ratio() < lowest_ratio:
			lowest_ratio = health.get_health_ratio()
			selected = candidate
	return selected


func _passes_condition(instruction: ProgramInstruction, target: Node3D) -> bool:
	if instruction.condition == ProgramInstruction.Condition.ALWAYS:
		return true
	if instruction.condition == ProgramInstruction.Condition.TARGET_HP_BELOW:
		var health: HealthComponent = _get_health(target)
		return health != null and health.get_health_ratio() < instruction.hp_threshold
	return false


func _get_health(target: Node) -> HealthComponent:
	if target is Character:
		return (target as Character).get_health_component()
	if target.has_method("get_health_component"):
		return target.call("get_health_component") as HealthComponent
	return null
