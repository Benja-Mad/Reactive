extends CanvasLayer

@onready var code_block: TextEdit = $CodeBlock
@onready var code_list_btn: Button = $CodeListBtn
@onready var cast_timer: Timer = $CastTimer
@onready var add_fire_btn: Button = $CodeList/AddFireBtn
@onready var code_list: CanvasLayer = $CodeList

func _ready() -> void:
	var player = get_parent()

	if not player.is_multiplayer_authority():
		visible = false
		return
	cast_timer.timeout.connect(_execute_program)
	code_list_btn.pressed.connect(_expand_code_list)
	add_fire_btn.pressed.connect(_add_fire_to_code)

func _execute_program() -> void:
	var code := code_block.text
	
	if code == "fire()":
		get_parent().use_ability("fire")
		
		
func _expand_code_list() -> void:
	var player = get_parent()
	code_list.visible = not code_list.visible
	
func _add_fire_to_code() -> void:
	code_block.text = ""
	for letter in "fire()":
		code_block.text = code_block.text + letter
		await get_tree().create_timer(0.05).timeout
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not code_block.get_global_rect().has_point(event.position):
				code_block.release_focus()
