class_name ProgramBlock
extends PanelContainer

func _get_drag_data(at_position: Vector2) -> Variant:
	var preview = duplicate()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	set_drag_preview(preview)
	
	return duplicate()
	
