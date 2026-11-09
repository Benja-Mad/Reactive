class_name ProgramBlock
extends PanelContainer

const ACTIVE_COLOR := Color(1.7, 1.5, 0.8)
const TRUE_COLOR := Color(0.7, 1.7, 0.8)
const FALSE_COLOR := Color(1.7, 0.7, 0.7)
const SKIPPED_COLOR := Color(0.45, 0.45, 0.45)

## true mientras el bloque vive en la paleta (CodeList).
var is_template: bool = true


func execute(_context: ProgramContext) -> void:
	pass


func on_dropped() -> void:
	pass


## Ilumina el bloque un momento para que se vea qué se ejecutó.
func flash(color: Color = ACTIVE_COLOR) -> void:
	pulse(self, color)


static func pulse(item: CanvasItem, color: Color) -> void:
	if item == null or not item.is_inside_tree():
		return
	item.modulate = color
	item.create_tween().tween_property(item, "modulate", Color.WHITE, 0.6)


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
