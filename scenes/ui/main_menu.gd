class_name MainMenu
extends Control


@onready var solo: Button = %Solo
@onready var host: Button = %Host
@onready var join: Button = %Join
@onready var credits: Button = %Credits
@onready var quit: Button = %Quit


func _ready() -> void:
	if Game.instance.multiplayer_test:
		get_tree().change_scene_to_file("res://lobby/lobby_test.tscn")
		return
	
	quit.pressed.connect(func() -> void: get_tree().quit())
	solo.pressed.connect(_start_solo)
	host.pressed.connect(func() -> void:
		Game.instance.solo = false
		get_tree().change_scene_to_file("res://lobby/host_screen.tscn"))
	join.pressed.connect(func() -> void:
		Game.instance.solo = false
		get_tree().change_scene_to_file("res://lobby/join_screen.tscn"))
	credits.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/credits.tscn"))
	
	resized.connect(_fit_chart)
	_fit_chart()
	var reader: PathFollow2D = $Sheet/Signal/Reader
	var sweep := create_tween().set_loops()
	sweep.tween_property(reader, "progress_ratio", 1.0, 1.6).from(0.0)
	sweep.tween_interval(0.4)
	solo.grab_focus()


func _fit_chart() -> void:
	var sheet: Control = $Sheet
	var factor := minf(size.x / sheet.size.x, size.y / sheet.size.y)
	sheet.scale = Vector2.ONE * factor
	sheet.position = (size - sheet.size * factor) * 0.5


# Single player: no server, no peers. We keep the OfflineMultiplayerPeer that
# Lobby.reset() leaves in place, register the one local player and reuse the
# lobby screen so the role can still be picked.
func _start_solo() -> void:
	Game.instance.solo = true
	Game.instance.players.clear()
	var player_name: String = OS.get_environment("USERNAME")
	if player_name.is_empty():
		player_name = OS.get_environment("USER")
	if player_name.is_empty():
		player_name = "Player"
	Game.instance.add_player(Statics.PlayerData.new(
		multiplayer.get_unique_id(), player_name, 0))
	get_tree().change_scene_to_file("res://lobby/waiting_screen.tscn")
