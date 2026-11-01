## Joining: one big field for the address your crew read out to you, your name in a small slot,
## and the connection's state said in place of the buttons while it lasts.
class_name LobbyJoinScreen
extends Control

const Kit = preload("res://scripts/ui/kit.gd")
const Frontend = preload("res://ui/frontend_backdrop.gd")

@onready var player_name: LineEdit = %PlayerName
@onready var ip: LineEdit = %IP
@onready var join_button: Button = %JoinButton
@onready var back_button: Button = %BackButton
@onready var error_label: Label = %ErrorLabel
@onready var error_timer: Timer = $ErrorTimer
@onready var actions: Control = $Page/Actions
@onready var status: Control = %Status
@onready var status_label: Label = %StatusLabel
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	Frontend.primary(join_button)
	Frontend.back_row($BackRow, back_button)
	Frontend.link(cancel_button, Kit.DIM)
	player_name.text = Frontend.player_name()
	# The last address that worked is usually the one you want again.
	ip.text = Frontend.recall("address")
	ip.caret_column = ip.text.length()
	ip.grab_focus()
	ip.text_submitted.connect(func(_text: String) -> void: _join())
	join_button.pressed.connect(_join)
	error_timer.timeout.connect(func() -> void: error_label.hide())
	error_label.hide()
	back_button.pressed.connect(_back)
	multiplayer.connected_to_server.connect(_handle_connected_to_server)
	multiplayer.connection_failed.connect(_handle_connection_failed)
	cancel_button.pressed.connect(_handle_cancel_pressed)
	_show_connecting(false)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE): return
	get_viewport().set_input_as_handled()
	_back()


## Esc (or the word next to it): while connecting it cancels, otherwise back to the menu.
func _back() -> void:
	if status.visible: _handle_cancel_pressed()
	else: Lobby.instance.go_to_menu()


func _address() -> String:
	return ip.text if ip.text else "localhost"


## While connecting the form holds still and the buttons give way to what is happening.
func _show_connecting(on: bool) -> void:
	status.visible = on
	actions.visible = not on
	# Mid-connection the same spot says "[Esc] cancelar": leaving goes through cancel, never
	# straight to a paused menu.
	back_button.text = "cancelar" if on else "volver"
	cancel_button.hide()
	player_name.editable = not on
	ip.editable = not on
	if on:
		status_label.text = "Conectando con %s…" % (ip.text if ip.text else "este PC")
		error_label.hide()
		ip.release_focus()


func _join() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(_address(), Statics.PORT)
	if err != OK:
		error_label.text = "Esa dirección no es válida."
		error_label.show()
		error_timer.stop()
		error_timer.start()
		return

	multiplayer.multiplayer_peer = peer

	get_tree().paused = true
	_show_connecting(true)


func _handle_connected_to_server() -> void:
	get_tree().paused = false
	var who: String = player_name.text.strip_edges()
	if who == "": who = Frontend.player_name()
	Frontend.remember("name", who)
	Frontend.remember("address", ip.text)
	Game.instance.add_player(Statics.PlayerData.new(multiplayer.get_unique_id(), who))
	get_tree().change_scene_to_file("res://lobby/waiting_screen.tscn")


func _handle_connection_failed() -> void:
	get_tree().paused = false
	_show_connecting(false)
	error_label.text = "Sin respuesta de %s. Revisa la dirección y que el turno esté abierto." % (ip.text if ip.text else "este PC")
	error_label.show()
	error_timer.stop()
	join_button.grab_focus()


func _handle_cancel_pressed() -> void:
	get_tree().paused = false
	_show_connecting(false)
	Lobby.instance.reset()
	join_button.grab_focus()
