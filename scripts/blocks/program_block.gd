class_name ProgramBlock
extends PanelContainer

## true mientras el bloque vive en la paleta (CodeList).
var is_template: bool = true


func execute(_context: ProgramContext) -> void:
	pass


func on_dropped() -> void:
	pass


func _get_drag_data(at_position: Vector2) -> Variant:
	var preview := duplicate() as Control
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)

	if is_template:
		return duplicate()
	return self


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			if not is_template and get_parent() != null:
				queue_free()
