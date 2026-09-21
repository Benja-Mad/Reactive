extends CanvasLayer

@onready var code_block: TextEdit = $CodeBlock
@onready var code_list_btn: Button = $CodeListBtn
@onready var cast_timer: Timer = $CastTimer
@onready var add_fire_btn: Button = $CodeList/AddFireBtn
@onready var code_list: CanvasLayer = $CodeList
var ui_scale: float = 1.0
var status: Label

func _ready() -> void:
	var player = get_parent()

	if not player.is_multiplayer_authority():
		visible = false
		return
	cast_timer.timeout.connect(_execute_program)
	code_list_btn.pressed.connect(_expand_code_list)
	add_fire_btn.pressed.connect(_add_fire_to_code)
	get_viewport().size_changed.connect(_layout)
	_layout()
	code_block.placeholder_text = "heal()" if player is Support else "fire()"
	add_fire_btn.text = "Añadir " + code_block.placeholder_text
	$CodeList/Label.text = "Opciones de código\n- " + code_block.placeholder_text
	code_block.add_theme_font_size_override("font_size", 15)
	$Label.add_theme_font_size_override("font_size", 14)
	code_block.scroll_fit_content_height = false
	code_block.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	code_block.text_changed.connect(_code_changed)
	status = Label.new()
	status.name = "ProgramStatus"
	status.add_theme_font_size_override("font_size", 11)
	status.modulate = Color(0.3, 0.8, 0.85)
	add_child(status)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.015, 0.035, 0.055, 0.88)
	panel.border_color = Color(0.16, 0.52, 0.62, 0.6)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.content_margin_left = 12
	panel.content_margin_top = 8
	code_block.add_theme_stylebox_override("normal", panel)
	var focused := panel.duplicate() as StyleBoxFlat
	focused.border_color = Color(0.2, 0.85, 0.95, 0.9)
	code_block.add_theme_stylebox_override("focus", focused)
	code_list_btn.add_theme_stylebox_override("normal", panel)
	code_list_btn.add_theme_stylebox_override("hover", focused)
	add_fire_btn.add_theme_stylebox_override("normal", panel)
	add_fire_btn.add_theme_stylebox_override("hover", focused)
	add_fire_btn.add_theme_font_size_override("font_size", 12)
	var hint := Label.new()
	hint.name = "ControlsHint"
	hint.text = "WASD mover · F " + ("curar" if player is Support else "disparar · Ratón apuntar") + " · Espacio saltar"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.65, 0.8, 0.86, 0.85)
	add_child(hint)
	var objective := Label.new()
	objective.name = "YardObjective"
	objective.text = "SECTOR 08 / PATIO DE TRÁNSITO\n" + ("Mantén a tu compañero con vida · alcance 9 m" if player is Support else "Neutraliza los centinelas · usa las barreras como cobertura")
	objective.add_theme_font_size_override("font_size", 12)
	objective.add_theme_color_override("font_color", Color(0.67, 0.82, 0.87, 0.85))
	objective.add_theme_color_override("font_shadow_color", Color(0.01, 0.025, 0.045, 0.95))
	objective.add_theme_constant_override("shadow_offset_x", 1)
	objective.add_theme_constant_override("shadow_offset_y", 2)
	add_child(objective)
	_layout()

func _layout() -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if get_viewport() is Window:
		ui_scale = clampf(view_size.x / float((get_viewport() as Window).size.x), 0.5, 1.0)
	transform = Transform2D(Vector2(ui_scale, 0), Vector2(0, ui_scale), Vector2.ZERO)
	code_list.transform = transform
	var center: float = view_size.x * 0.5 / ui_scale
	code_block.position = Vector2(center - 145, 38)
	code_block.size = Vector2(245, 34)
	$Label.position = Vector2(center - 145, 13)
	code_list_btn.position = Vector2(center + 107, 38)
	code_list_btn.size = Vector2(34, 34)
	$CodeList/Label.position = Vector2(center - 145, 123)
	add_fire_btn.position = Vector2(center - 145, 170)
	add_fire_btn.size = Vector2(180, 30)
	if status != null:
		status.position = Vector2(center - 145, 102)
	if has_node("ControlsHint"):
		$ControlsHint.position = Vector2(center - 145, 80)
	if has_node("YardObjective"):
		$YardObjective.position = Vector2(24, view_size.y / ui_scale - 58)

func _code_changed() -> void:
	var code: String = code_block.text.strip_edges()
	var expected: String = "heal()" if get_parent() is Support else "fire()"
	status.text = "" if code.is_empty() else ("● Programa activo" if code == expected else "Usa " + expected)
	status.modulate = Color(0.3, 0.85, 0.8) if code == expected else Color(1, 0.65, 0.32)

func _execute_program() -> void:
	var code := code_block.text.strip_edges()
	
	if code == "fire()":
		get_parent().use_ability("fire")
	elif code == "heal()":
		get_parent().use_ability("heal")
		
		
func _expand_code_list() -> void:
	var player = get_parent()
	code_list.visible = not code_list.visible
	
func _add_fire_to_code() -> void:
	code_block.text = ""
	for letter in ("heal()" if get_parent() is Support else "fire()"):
		code_block.text = code_block.text + letter
		await get_tree().create_timer(0.05).timeout
	_code_changed()
	code_list.visible = false
	code_block.release_focus()
	
func _input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and code_block.has_focus():
		code_block.release_focus()
		_code_changed()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		code_block.release_focus()
		code_list.visible = false
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not code_block.get_global_rect().has_point(event.position / ui_scale):
				code_block.release_focus()
