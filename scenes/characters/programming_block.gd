class_name ProgrammingBlock
extends CanvasLayer

@onready var text_edit: TextEdit = $TextEdit
@onready var label: Label = $Label
var _character: Character
var _apply_button: Button
var _status_label: Label


func _ready() -> void:
	add_to_group(&"program_editors")
	_build_editor()


func setup_for_character(character: Character) -> void:
	_character = character
	visible = character.is_multiplayer_authority()
	if visible and text_edit.text.strip_edges().is_empty():
		text_edit.text = _default_program_for(character)


func _build_editor() -> void:
	label.text = "ABILITY PROGRAM — safe-time editor"
	label.offset_left = 22.0
	label.offset_top = 18.0
	label.offset_right = 430.0
	label.offset_bottom = 44.0
	text_edit.offset_left = 22.0
	text_edit.offset_top = 48.0
	text_edit.offset_right = 590.0
	text_edit.offset_bottom = 158.0
	text_edit.placeholder_text = "Every(4s) -> LowestHPAlly -> IfHPBelow(70%) -> Heal(18)"
	_apply_button = Button.new()
	_apply_button.text = "COMPILE & APPLY"
	_apply_button.position = Vector2(22.0, 166.0)
	_apply_button.size = Vector2(180.0, 34.0)
	_apply_button.pressed.connect(_compile_program)
	add_child(_apply_button)
	_status_label = Label.new()
	_status_label.text = "Runtime ready"
	_status_label.position = Vector2(214.0, 172.0)
	_status_label.modulate = Color(0.55, 1.0, 0.76)
	add_child(_status_label)
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.025, 0.045, 0.065, 0.88)
	panel.position = Vector2(10.0, 8.0)
	panel.size = Vector2(595.0, 204.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	move_child(panel, 0)


func _compile_program() -> void:
	if _character == null:
		_status_label.text = "Waiting for character setup"
		return
	var compiled: Array[ProgramInstruction] = []
	var errors: Array[String] = []
	for raw_line: String in text_edit.text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var instruction: ProgramInstruction = _parse_line(line)
		if instruction == null:
			errors.append(line)
		else:
			compiled.append(instruction)
	if compiled.is_empty():
		_status_label.text = "No valid instructions"
		_status_label.modulate = Color(1.0, 0.42, 0.35)
		return
	_character.get_program_executor().set_instructions(compiled)
	_status_label.text = "%d blocks active%s" % [compiled.size(), " · %d ignored" % errors.size() if not errors.is_empty() else ""]
	_status_label.modulate = Color(0.55, 1.0, 0.76)
	visible = false


func _parse_line(line: String) -> ProgramInstruction:
	var lower: String = line.to_lower()
	var numbers: Array[float] = _extract_numbers(line)
	if "healingarea" in lower or "healing_area" in lower:
		var area: ProgramInstruction = ProgramInstruction.new()
		area.label = line
		area.interval = numbers[0] if numbers.size() > 0 else 8.0
		area.target_selector = ProgramInstruction.TargetSelector.SELF
		area.action = ProgramInstruction.Action.HEALING_AREA
		area.radius = numbers[1] if numbers.size() > 1 else 3.5
		area.duration = numbers[2] if numbers.size() > 2 else 6.0
		area.power = numbers[3] if numbers.size() > 3 else 5.0
		return area
	if "chain" in lower and "heal" in lower:
		var chain: ProgramInstruction = ProgramInstruction.every_heal(numbers[0] if numbers.size() > 0 else 6.0, numbers[1] if numbers.size() > 1 else 14.0, 1.0)
		chain.label = line
		chain.action = ProgramInstruction.Action.CHAIN_HEAL
		chain.chain_count = int(numbers[2]) if numbers.size() > 2 else 2
		chain.condition = ProgramInstruction.Condition.ALWAYS
		return chain
	if "shield" in lower:
		var shield: ProgramInstruction = ProgramInstruction.every_heal(numbers[0] if numbers.size() > 0 else 6.0, numbers[2] if numbers.size() > 2 else 24.0, (numbers[1] / 100.0) if numbers.size() > 1 else 0.3)
		shield.label = line
		shield.action = ProgramInstruction.Action.SHIELD
		shield.duration = 4.0
		return shield
	if "status" in lower or "poison" in lower:
		var status: ProgramInstruction = ProgramInstruction.new()
		status.label = line
		status.trigger = ProgramInstruction.Trigger.ON_ENEMY_KILLED
		status.target_selector = ProgramInstruction.TargetSelector.NEAREST_ENEMY
		status.action = ProgramInstruction.Action.APPLY_STATUS
		status.status_name = &"poison"
		status.duration = numbers[0] if numbers.size() > 0 else 4.0
		status.power = numbers[1] if numbers.size() > 1 else 4.0
		return status
	if "projectile" in lower or "damage" in lower:
		return ProgramInstruction.every_projectile(numbers[0] if numbers.size() > 0 else 2.0, numbers[1] if numbers.size() > 1 else 12.0)
	if "heal" in lower:
		var threshold: float = (numbers[1] / 100.0) if numbers.size() > 1 else 0.7
		return ProgramInstruction.every_heal(numbers[0] if numbers.size() > 0 else 4.0, numbers[2] if numbers.size() > 2 else 18.0, threshold)
	return null


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_P:
		visible = not visible
		get_viewport().set_input_as_handled()


func is_editor_open() -> bool:
	return visible and _character != null and _character.is_multiplayer_authority()


func _extract_numbers(source: String) -> Array[float]:
	var result: Array[float] = []
	var regex: RegEx = RegEx.new()
	regex.compile("[0-9]+(?:\\.[0-9]+)?")
	for match_result: RegExMatch in regex.search_all(source):
		result.append(match_result.get_string().to_float())
	return result


func _default_program_for(character: Character) -> String:
	if character is Support:
		return "Every(4s) -> LowestHPAlly -> IfHPBelow(70%) -> Heal(18)\nEvery(8s) -> Self -> HealingArea(3.5, 6, 5)\nEvery(6s) -> LowestHPAlly -> IfHPBelow(30%) -> Shield(24)\nEvery(7s) -> LowestHPAlly -> ChainHeal(14, 2)"
	return "Every(2s) -> NearestEnemy -> Projectile -> Damage(12)\nOnEnemyKilled -> NearestEnemy -> ApplyStatus(Poison, 4, 4)"
