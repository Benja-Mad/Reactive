class_name ConditionContainer
extends BlockContainer


func _accepts_block(block: ProgramBlock) -> bool:
	return block is ConditionBlock
