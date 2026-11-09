extends ProgramBlock

@onready var condition_container: ConditionContainer = $VBoxContainer/ConditionContainer
@onready var then_container: BlockContainer = $VBoxContainer/ThenContainer
@onready var else_container: BlockContainer = $VBoxContainer/ElseContainer
@onready var then_label: Label = $VBoxContainer/Label
@onready var else_label: Label = $VBoxContainer/Label3


func execute(context: ProgramContext) -> void:
	var condition := condition_container.get_condition()
	var taken := condition != null and condition.evaluate(context)
	if condition == null:
		context.trace.append("if sin condición → else")
	else:
		context.trace.append("%s: %s" % [condition.describe(context), "sí → then" if taken else "no → else"])
		condition.flash(TRUE_COLOR if taken else FALSE_COLOR)
	if taken:
		pulse(then_label, TRUE_COLOR)
		then_container.execute(context)
	else:
		pulse(else_label, FALSE_COLOR)
		else_container.execute(context)


func on_dropped() -> void:
	var box := $VBoxContainer
	box.visible = true
	for child in box.get_children():
		child.visible = true
