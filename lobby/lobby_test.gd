extends Node


var player_index: int = 1

@onready var start_game_timer: Timer = $StartGameTimer

func _ready() -> void:
	for i: int in GameGlobal.instance.test_players.size():
		var test_player: PlayerDataResource = GameGlobal.instance.test_players[i]
		var player: Statics.PlayerData = Statics.PlayerData.new(
			0,
			test_player.name,
			i,
			test_player.role
		)
		GameGlobal.instance.players.push_back(player)
	
	if GameGlobal.instance.players.size() > 0:
		GameGlobal.instance.players[0].id = 1
	
	if is_multiplayer_authority():
		multiplayer.peer_connected.connect(_on_peer_connected)
	
	if not _try_host():
		_try_join()
	
	# disable in order to be able to reach main menu again
	GameGlobal.instance.multiplayer_test = false


func _try_host() -> bool:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(Statics.PORT, Statics.MAX_CLIENTS)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		Debug.add_to_window_title("Server")
		GameGlobal.instance.update_player_id()
		_update_window_placement(0)
		start_game_timer.timeout.connect(_on_start_game_timeout)
	return err == OK


func _try_join() -> bool:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client("localhost", Statics.PORT)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err == OK


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		GameGlobal.instance.players[player_index].id = id
		for i: int in GameGlobal.instance.players.size():
			_send_player_data_id.rpc(i, GameGlobal.instance.players[i].id)
		player_index += 1
		start_game_timer.start()


@rpc("reliable")
func _send_player_data_id(index: int, id: int) -> void:
	if multiplayer.get_unique_id() == id and not GameGlobal.instance.players[index].id:
		Debug.add_to_window_title("Client %d" % index)
		Debug.index = index
		_update_window_placement(index)
	GameGlobal.instance.players[index].id = id


func _on_start_game_timeout() -> void:
	_start_game.rpc()


@rpc("reliable", "call_local")
func _start_game() -> void:
	get_tree().change_scene_to_packed(GameGlobal.instance.main_scene)


func _update_window_placement(index: int) -> void:
	if not GameGlobal.instance.fill_screen:
		return
	var columns: int = ceil(sqrt(GameGlobal.instance.players.size()))
	var rows: int = ceil(1.0 * GameGlobal.instance.players.size() / columns)
	var x: int = index % columns
	@warning_ignore("integer_division")
	var y: int = index / columns
	
	var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect()
	@warning_ignore("integer_division")
	var window_size: Vector2i = screen_rect.size / Vector2i(columns, rows)
	var title_size: Vector2i = DisplayServer.window_get_title_size(get_window().title)
	var title_size_offset: Vector2i = Vector2i(0, title_size.y)
	
	get_window().position = Vector2i(x, y) * window_size + title_size_offset + screen_rect.position
	get_window().size = window_size - title_size_offset
