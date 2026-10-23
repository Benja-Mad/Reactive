class_name AbilityBlock
extends ProgramBlock


func get_ability() -> Statics.Ability:
	return Statics.Ability.NONE


func execute(context: ProgramContext) -> void:
	var ability := get_ability()
	if ability != Statics.Ability.NONE:
		context.character.use_ability(ability)
