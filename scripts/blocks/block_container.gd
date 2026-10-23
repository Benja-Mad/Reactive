class_name BlockContainer
extends VBoxContainer


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is ProgramBlock:
		return false
	if not _accepts_block(data as ProgramBlock):
		return false
	return _is_ability_allowed(data as AbilityBlock)


func _accepts_block(block: ProgramBlock) -> bool:
	if block is ConditionBlock:
		return false
	return true


func execute(context: ProgramContext) -> void:
	for child in get_children():
		if child is ProgramBlock:
			(child as ProgramBlock).execute(context)


func _is_ability_allowed(block: AbilityBlock) -> bool:
	if block == null:
		return true
	var character := _find_character()
	if character == null:
		return true
	var player: Statics.PlayerData = Game.instance.get_player(character.get_multiplayer_authority())
	if player == null or player.role == Statics.Role.NONE:
		return true
	return Statics.get_ability_role(block.get_ability()) == player.role


func _find_character() -> Character:
	var node: Node = get_parent()
	while node != null:
		if node is Character:
			return node as Character
		node = node.get_parent()
	return null


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var block := data as ProgramBlock
	if block == null:
		return

	var target := _index_at(at_position)
	var old_parent := block.get_parent()

	# Plantilla de la paleta -> se copia; bloque del programa -> se mueve.
	if block.is_template:
		if old_parent != null:
			block = block.duplicate() as ProgramBlock
		block.is_template = false
		add_child(block)
		move_child(block, target)
		block.on_dropped()
		return

	if old_parent == self and target > block.get_index():
		target -= 1

	if old_parent != null:
		old_parent.remove_child(block)

	add_child(block)
	move_child(block, target)
	block.on_dropped()


func _index_at(at_position: Vector2) -> int:
	var count := get_child_count()
	for i in count:
		var child := get_child(i) as Control
		if child == null:
			continue
		if at_position.y < child.position.y + child.size.y * 0.5:
			return i
	return count
