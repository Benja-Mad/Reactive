extends CanvasLayer

@onready var code_list_btn: Button = $CodeListBtn
@onready var cast_timer: Timer = $CastTimer
@onready var code_list: Control = $CodeList
@onready var program_container: ProgramContainer = $PanelContainer/ScrollContainer/ProgramContainer
@onready var status_label: Label = $Status

var last_trace: String = "todavía no se ejecuta"


func _ready() -> void:
	var player: Node = get_parent()

	if not player.is_multiplayer_authority():
		visible = false
		set_process(false)
		return

	cast_timer.timeout.connect(_execute_program)
	code_list_btn.pressed.connect(_expand_code_list)
	_apply_role_filter()


func _apply_role_filter() -> void:
	var player: Statics.PlayerData = Game.instance.get_player(get_parent().get_multiplayer_authority())
	if player == null or player.role == Statics.Role.NONE:
		return
	_filter_node(code_list, player.role)


func _filter_node(node: Node, role: Statics.Role) -> void:
	for child in node.get_children():
		if child is AbilityBlock:
			var block := child as AbilityBlock
			block.visible = Statics.get_ability_role(block.get_ability()) == role
		else:
			_filter_node(child, role)


func _process(_delta: float) -> void:
	status_label.text = "Próximo ciclo en %.1f s\nÚltimo: %s" % [cast_timer.time_left, last_trace]


func _execute_program() -> void:
	var character := get_parent() as Character
	if character == null or character.is_dead:
		return

	var context := ProgramContext.new(character)
	program_container.execute(context)
	last_trace = " · ".join(context.trace) if not context.trace.is_empty() else "programa vacío"


func _expand_code_list() -> void:
	code_list.visible = not code_list.visible
