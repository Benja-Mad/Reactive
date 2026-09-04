class_name ProgramInstruction
extends Resource

enum Trigger {
	EVERY,
	ON_ENEMY_KILLED,
}

enum TargetSelector {
	SELF,
	NEAREST_ENEMY,
	LOWEST_HP_ALLY,
}

enum Condition {
	ALWAYS,
	TARGET_HP_BELOW,
}

enum Action {
	HEAL,
	PROJECTILE_DAMAGE,
	HEALING_AREA,
	SHIELD,
	CHAIN_HEAL,
	APPLY_STATUS,
}

@export var label: String = "Instruction"
@export var trigger: Trigger = Trigger.EVERY
@export_range(0.25, 60.0, 0.25) var interval: float = 4.0
@export var target_selector: TargetSelector = TargetSelector.SELF
@export var condition: Condition = Condition.ALWAYS
@export_range(0.0, 1.0, 0.05) var hp_threshold: float = 0.7
@export var action: Action = Action.HEAL
@export_range(0.0, 500.0, 1.0) var power: float = 20.0
@export_range(0.5, 20.0, 0.5) var radius: float = 4.0
@export_range(0.25, 30.0, 0.25) var duration: float = 5.0
@export_range(0, 8, 1) var chain_count: int = 0
@export var status_name: StringName = &""


static func every_heal(seconds: float, amount: float, threshold: float = 0.7) -> ProgramInstruction:
	var instruction: ProgramInstruction = ProgramInstruction.new()
	instruction.label = "Every %.1fs → LowestHPAlly → HP < %d%% → Heal" % [seconds, int(threshold * 100.0)]
	instruction.interval = seconds
	instruction.target_selector = TargetSelector.LOWEST_HP_ALLY
	instruction.condition = Condition.TARGET_HP_BELOW
	instruction.hp_threshold = threshold
	instruction.action = Action.HEAL
	instruction.power = amount
	return instruction


static func every_projectile(seconds: float, amount: float) -> ProgramInstruction:
	var instruction: ProgramInstruction = ProgramInstruction.new()
	instruction.label = "Every %.1fs → NearestEnemy → Projectile → Damage" % seconds
	instruction.interval = seconds
	instruction.target_selector = TargetSelector.NEAREST_ENEMY
	instruction.action = Action.PROJECTILE_DAMAGE
	instruction.power = amount
	return instruction
