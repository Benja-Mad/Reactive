extends ProgramBlock

@onready var condition_container: ConditionContainer = $VBoxContainer/ConditionContainer
@onready var then_container: BlockContainer = $VBoxContainer/ThenContainer
@onready var else_container: BlockContainer = $VBoxContainer/ElseContainer
@onready var then_label: Label = $VBoxContainer/Label
@onready var else_label: Label = $VBoxContainer/Label3
@onready var mode: OptionButton = $VBoxContainer/Branch/Mode


func execute(context: ProgramContext) -> void:
	var any_match := mode.selected == 1
	var descriptions := PackedStringArray()
	var taken := not any_match
	for condition: ConditionBlock in condition_container.get_children():
		if condition.is_queued_for_deletion():
			continue
		var matched := condition.evaluate(context)
		descriptions.append(condition.describe(context))
		condition.flash(TRUE_COLOR if matched else FALSE_COLOR)
		if matched == any_match:
			taken = matched
			break
	if descriptions.is_empty():
		taken = false
		descriptions.append("sin condición")
	var operator := " o " if any_match else " y "
	context.trace.append("%s → %s" % [operator.join(descriptions), "then" if taken else "else"])
	if taken:
		pulse(then_label, TRUE_COLOR)
		then_container.execute(context)
	else:
		pulse(else_label, FALSE_COLOR)
		else_container.execute(context)


func on_dropped() -> void:
	mode.show()
	var box := $VBoxContainer
	box.visible = true
	for child in box.get_children():
		child.visible = true
