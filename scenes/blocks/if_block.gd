extends ProgramBlock

@onready var condition_container: ConditionContainer = $VBoxContainer/ConditionContainer
@onready var then_container: BlockContainer = $VBoxContainer/ThenContainer
@onready var else_container: BlockContainer = $VBoxContainer/ElseContainer


func execute(context: ProgramContext) -> void:
	var condition := condition_container.get_condition()
	if condition != null and condition.evaluate(context):
		then_container.execute(context)
	else:
		else_container.execute(context)


func on_dropped() -> void:
	var box := $VBoxContainer
	box.visible = true
	for child in box.get_children():
		child.visible = true
