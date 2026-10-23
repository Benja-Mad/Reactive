class_name ConditionContainer
extends BlockContainer


func get_condition() -> ConditionBlock:
	for child in get_children():
		if child is ConditionBlock:
			return child as ConditionBlock
	return null


func _accepts_block(block: ProgramBlock) -> bool:
	return block is ConditionBlock


func _drop_data(at_position: Vector2, data: Variant) -> void:
	for child in get_children():
		if child is ConditionBlock and child != data:
			(child as ConditionBlock).queue_free()
	super._drop_data(at_position, data)
