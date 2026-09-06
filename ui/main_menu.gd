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
	credits.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/credits.tscn"))
	
	solo.grab_focus()


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
