class_name ConditionBlock
extends ProgramBlock


func evaluate(_context: ProgramContext) -> bool:
	return false


## Texto corto con el valor que se comparó, p. ej. "vida 25% < 50%".
func describe(_context: ProgramContext) -> String:
	return ""


static func health_percent(context: ProgramContext) -> float:
	var character := context.character
	if character == null or character.maxHealth <= 0:
		return 0.0
	return float(character.currentHealth) / float(character.maxHealth) * 100.0
