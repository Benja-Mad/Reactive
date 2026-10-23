extends ConditionBlock

@export_range(0, 100) var threshold_percent: float = 50.0


func evaluate(context: ProgramContext) -> bool:
	var character := context.character
	if character == null or character.maxHealth <= 0:
		return false
	return float(character.currentHealth) / float(character.maxHealth) * 100.0 > threshold_percent
