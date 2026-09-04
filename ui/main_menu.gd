class_name MainMenu
extends Control


@onready var host: Button = %Host
@onready var join: Button = %Join
@onready var credits: Button = %Credits
@onready var quit: Button = %Quit
@onready var menu_buttons: VBoxContainer = $MarginContainer/VBoxContainer2
var vertical_slice: Button


func _ready() -> void:
	if GameGlobal.instance.multiplayer_test:
		get_tree().change_scene_to_file("res://lobby/lobby_test.tscn")
		return
	
	vertical_slice = Button.new()
	vertical_slice.text = "PLAY VERTICAL SLICE"
	vertical_slice.tooltip_text = "Offline arena showcase: programming, healer VFX and enemy waves"
	menu_buttons.add_child(vertical_slice)
	menu_buttons.move_child(vertical_slice, 0)
	vertical_slice.pressed.connect(_play_vertical_slice)
	quit.pressed.connect(func() -> void: get_tree().quit())
	host.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://lobby/host_screen.tscn"))
	join.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://lobby/join_screen.tscn"))
	credits.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/credits.tscn"))
	
	vertical_slice.grab_focus()


func _play_vertical_slice() -> void:
	GameGlobal.instance.players.clear()
	get_tree().change_scene_to_file("res://scenes/main_scene.tscn")
