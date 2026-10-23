extends Node3D

@export var support_scene: PackedScene
@export var damage_scene: PackedScene
@export var enemy_scene: PackedScene
@export var enemy_spawn_interval: float = 5.0
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
@onready var death_ui: CanvasLayer = get_node_or_null("DeathUI")
@onready var wait_panel: Control = get_node_or_null("DeathUI/WaitPanel")
@onready var game_over_panel: Control = get_node_or_null("DeathUI/GameOverPanel")
@onready var lobby_button: Button = get_node_or_null("DeathUI/GameOverPanel/VBoxContainer/LobbyButton")

var enemy_count: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	if enemy_spawner != null:
		enemy_spawner.spawn_function = _spawn_enemy
	if wait_panel != null:
		wait_panel.hide()
	if game_over_panel != null:
		game_over_panel.hide()
	if lobby_button != null:
		lobby_button.pressed.connect(_on_lobby_button_pressed)
	if not multiplayer.is_server():
		return
	else:
		await get_tree().create_timer(0.2).timeout
	
	for player_data: Statics.PlayerData in Game.instance.players:
		player_spawner.spawn(player_data.to_dict())

	var enemy_timer := Timer.new()
	enemy_timer.wait_time = enemy_spawn_interval
	enemy_timer.autostart = true
	enemy_timer.timeout.connect(_on_enemy_spawn_timeout)
	add_child(enemy_timer)
		

func _spawn_player(data: Dictionary) -> Node:
	var player_data : Statics.PlayerData = Statics.PlayerData.from_dict(data)
	
	var player_inst
	
	if player_data.role == Statics.Role.DAMAGE:
		player_inst = damage_scene.instantiate()
	else:
		player_inst = support_scene.instantiate()
		
	player_inst.set_multiplayer_authority(player_data.id)
	player_inst.name = str(player_data.id)
	player_inst.hp_changed.connect(_check_alive_players)

	player_inst.position = spawn_points.get_child(player_data.index).global_position
	return player_inst


func _on_lobby_button_pressed() -> void:
	Lobby.instance.go_to_lobby()


func _check_alive_players() -> void:
	if wait_panel == null or game_over_panel == null:
		return
	var total: int = 0
	var alive: int = 0
	for node: Node in players.get_children():
		var player := node as Character
		if player == null:
			continue
		total += 1
		if not player.is_dead:
			alive += 1
	if total == 0:
		return
	if alive == 0:
		wait_panel.hide()
		if death_ui != null:
			death_ui.show()
		game_over_panel.show()
		return
	var me := _my_character()
	if me != null and me.is_dead:
		if death_ui != null:
			death_ui.show()
		wait_panel.show()
	else:
		wait_panel.hide()
		if death_ui != null:
			death_ui.hide()


func _my_character() -> Character:
	for node: Node in players.get_children():
		var player := node as Character
		if player != null and player.is_multiplayer_authority():
			return player
	return null


func _on_enemy_spawn_timeout() -> void:
	if enemy_scene == null or enemy_spawner == null:
		return
	enemy_spawner.spawn({})


func _spawn_enemy(_data: Dictionary) -> Node:
	var enemy_inst: Node3D = enemy_scene.instantiate()
	enemy_count += 1
	var angle := float(enemy_count) * 0.7
	var dist := randf_range(8.0, 12.0)
	enemy_inst.position = Vector3(cos(angle) * dist, 2.0, sin(angle) * dist)
	return enemy_inst
