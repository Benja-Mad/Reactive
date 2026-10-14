class_name BlockContainer
extends VBoxContainer

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is ProgramBlock

func _drop_data(at_position: Vector2, data: Variant) -> void:
	add_child(data)
