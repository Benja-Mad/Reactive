extends ConditionBlock

@export_range(0, 100) var threshold_percent: float = 50.0


func evaluate(context: ProgramContext) -> bool:
	if context.character == null or context.character.maxHealth <= 0:
		return false
	return health_percent(context) < threshold_percent


func describe(context: ProgramContext) -> String:
	return "vida %d%% < %d%%" % [roundi(health_percent(context)), roundi(threshold_percent)]
