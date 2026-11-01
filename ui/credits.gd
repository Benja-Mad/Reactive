## Who made what, role on the left and name on the right, and at the foot the engine's notice in
## small dim type.
class_name Credits
extends Control

const Kit = preload("res://scripts/ui/kit.gd")
const Frontend = preload("res://ui/frontend_backdrop.gd")
## [role, name] in the order they roll. Only what is known; the owner fills in the rest.
const ROLL: Array = [
	["Lobby", "Elías Zelada"],
]
## Godot's own copyright lines, which its MIT licence asks every game to carry.
const ENGINE_NOTICE := "Hecho con Godot Engine.\nCopyright 2014-presente Godot Engine contributors.\nCopyright 2007-2014 Juan Linietsky, Ariel Manzur."

@onready var back_button: Button = %BackButton
@onready var roll: GridContainer = %Roll

func _ready() -> void:
	Frontend.back_row($BackRow, back_button)
	for line: Array in ROLL:
		var role := Label.new()
		role.text = line[0]
		role.theme_type_variation = &"Muted"
		role.custom_minimum_size.x = 80
		roll.add_child(role)
		var who := Label.new()
		who.text = line[1]
		roll.add_child(who)
	var notice: Label = %Notice
	# The pixel font has no ©; with it, the lines read "Copyright ©" as the licence writes them.
	notice.text = ENGINE_NOTICE if not Kit.font().has_char(0xA9) else ENGINE_NOTICE.replace("Copyright ", "Copyright © ")
	back_button.pressed.connect(_back)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
