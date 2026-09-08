extends Node


func test_health_heal_and_shield() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 100.0
	health.current_health = 100.0
	health.add_shield(20.0)
	var applied: float = health.apply_damage(30.0)
	assert(is_equal_approx(applied, 10.0))
	assert(is_equal_approx(health.current_health, 90.0))
	assert(is_equal_approx(health.shield, 0.0))
	var healed: float = health.heal(25.0)
	assert(is_equal_approx(healed, 10.0))
	assert(is_equal_approx(health.current_health, 100.0))


func test_program_instruction_factories() -> void:
	var heal: ProgramInstruction = ProgramInstruction.every_heal(4.0, 18.0, 0.7)
	assert(heal.trigger == ProgramInstruction.Trigger.EVERY)
	assert(heal.target_selector == ProgramInstruction.TargetSelector.LOWEST_HP_ALLY)
	assert(heal.condition == ProgramInstruction.Condition.TARGET_HP_BELOW)
	assert(heal.action == ProgramInstruction.Action.HEAL)
	var projectile: ProgramInstruction = ProgramInstruction.every_projectile(2.0, 12.0)
	assert(projectile.target_selector == ProgramInstruction.TargetSelector.NEAREST_ENEMY)
	assert(projectile.action == ProgramInstruction.Action.PROJECTILE_DAMAGE)
