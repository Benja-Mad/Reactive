## Hosting: the address your crew needs, big enough to read out across the room; your name in a
## small slot under it; and the button that opens the shift.
class_name LobbyHostScreen
extends Control

const Frontend = preload("res://ui/frontend_backdrop.gd")

@onready var player_name: LineEdit = %PlayerName
@onready var host_button: Button = %HostButton
@onready var back_button: Button = %BackButton
@onready var error_label: Label = %ErrorLabel
@onready var error_timer: Timer = $ErrorTimer
@onready var lead: Label = %Lead
@onready var address_value: Label = %AddressValue
@onready var other_addresses: Label = %OtherAddresses


func _ready() -> void:
	Frontend.primary(host_button)
	Frontend.back_row($BackRow, back_button)
	player_name.text = Frontend.player_name()
	player_name.caret_column = player_name.text.length()
	host_button.grab_focus()
	player_name.text_submitted.connect(func(_text: String) -> void: _host())
	var addresses: PackedStringArray = _lan_addresses()
	if addresses.is_empty():
		# No network: only a second window on this same computer can join.
		lead.text = "Sin red. Solo se puede unir alguien desde este PC."
		address_value.text = "127.0.0.1"
	else:
		address_value.text = addresses[0]
		other_addresses.visible = addresses.size() > 1
		other_addresses.text = "o " + " o ".join(addresses.slice(1))
	error_label.text = "El puerto %d está ocupado. ¿Ya hay un turno abierto en este PC?" % Statics.PORT
	host_button.pressed.connect(_host)
	error_timer.timeout.connect(func() -> void: error_label.hide())
	error_label.hide()
	back_button.pressed.connect(func() -> void: Lobby.instance.go_to_menu())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		Lobby.instance.go_to_menu()


## The IPv4 addresses other machines on the network can reach this one at.
static func _lan_addresses() -> PackedStringArray:
	var found := PackedStringArray()
	for ip: String in IP.get_local_addresses():
		if ip.count(".") != 3 or ip.begins_with("127.") or ip.begins_with("169.254."): continue
		found.append(ip)
	return found.slice(0, 2)


func _host() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(Statics.PORT, Statics.MAX_CLIENTS)
	if err != OK:
		error_label.show()
		error_timer.stop()
		error_timer.start()
		return
	multiplayer.multiplayer_peer = peer
	var who: String = player_name.text.strip_edges()
	if who == "": who = Frontend.player_name()
	Frontend.remember("name", who)
	Game.instance.add_player(Statics.PlayerData.new(multiplayer.get_unique_id(), who, 0))
	Debug.add_to_window_title("Server")
	Game.instance.update_player_id()
	get_tree().change_scene_to_file("res://lobby/waiting_screen.tscn")
