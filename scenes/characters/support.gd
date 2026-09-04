class_name Support
extends Character

const HEALING_AREA_SCENE: PackedScene = preload("res://scenes/effects/healing_area.tscn")


func _ready() -> void:
	super._ready()
	var defaults: Array[ProgramInstruction] = []
	defaults.append(ProgramInstruction.every_heal(4.0, 18.0, 0.7))
	var area: ProgramInstruction = ProgramInstruction.new()
	area.label = "Every 8s → CreateHealingArea(Self.Position)"
	area.interval = 8.0
	area.target_selector = ProgramInstruction.TargetSelector.SELF
	area.action = ProgramInstruction.Action.HEALING_AREA
	area.radius = 3.5
	area.duration = 6.0
	area.power = 5.0
	defaults.append(area)
	var shield: ProgramInstruction = ProgramInstruction.every_heal(6.0, 24.0, 0.3)
	shield.label = "Every 6s → LowestHPAlly → HP < 30% → Shield"
	shield.action = ProgramInstruction.Action.SHIELD
	shield.duration = 4.0
	defaults.append(shield)
	var chain: ProgramInstruction = ProgramInstruction.every_heal(7.0, 14.0, 1.0)
	chain.label = "Every 7s → LowestHPAlly → Heal → Chain(2)"
	chain.action = ProgramInstruction.Action.CHAIN_HEAL
	chain.condition = ProgramInstruction.Condition.ALWAYS
	chain.chain_count = 2
	defaults.append(chain)
	get_program_executor().set_instructions(defaults)


func execute_program_instruction(instruction: ProgramInstruction, target: Node3D) -> void:
	match instruction.action:
		ProgramInstruction.Action.HEAL:
			_heal_target(target as Character, instruction.power)
		ProgramInstruction.Action.HEALING_AREA:
			_create_healing_area(instruction)
		ProgramInstruction.Action.SHIELD:
			_shield_target(target as Character, instruction.power, instruction.duration)
		ProgramInstruction.Action.CHAIN_HEAL:
			_chain_heal(target as Character, instruction.power, instruction.chain_count)


func _heal_target(target: Character, amount: float) -> void:
	if target == null:
		return
	animated_sprite_3d.play(&"Heal")
	target.get_health_component().heal(amount, self)
	AbilityVfx.spawn_heal(self, target)


func _create_healing_area(instruction: ProgramInstruction) -> void:
	var area: HealingArea = HEALING_AREA_SCENE.instantiate() as HealingArea
	if area == null:
		return
	area.setup_area(self, instruction.radius, instruction.duration, instruction.power)
	get_tree().current_scene.add_child(area)
	area.global_position = global_position
	animated_sprite_3d.play(&"Heal")


func _shield_target(target: Character, amount: float, duration: float) -> void:
	if target == null:
		return
	target.get_health_component().add_shield(amount)
	AbilityVfx.spawn_shield(target, duration)
	animated_sprite_3d.play(&"Heal")


func _chain_heal(first_target: Character, amount: float, chain_count: int) -> void:
	if first_target == null:
		return
	var healed_targets: Array[Character] = [first_target]
	_heal_target(first_target, amount)
	var current: Character = first_target
	for _index: int in chain_count:
		var next_target: Character = _nearest_unhealed_ally(current, healed_targets)
		if next_target == null:
			break
		_heal_target(next_target, amount * 0.75)
		healed_targets.append(next_target)
		current = next_target


func _nearest_unhealed_ally(origin: Character, excluded: Array[Character]) -> Character:
	var nearest: Character = null
	var nearest_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var candidate: Character = node as Character
		if candidate == null or candidate in excluded:
			continue
		var distance: float = origin.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance and distance <= 49.0:
			nearest_distance = distance
			nearest = candidate
	return nearest


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
