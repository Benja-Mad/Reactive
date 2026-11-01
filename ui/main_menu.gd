## The title screen: the name lettered like the yard's own signs, and under it one list of what
## you can do from here, all one size: the shift first, the network pair after a breath, the rest
## receding in dim text. Focus is amber and the pointer, nothing else moves.
class_name MainMenu
extends Control

const Kit = preload("res://scripts/ui/kit.gd")
const Frontend = preload("res://ui/frontend_backdrop.gd")
## Canvas units per letter cell: three UI pixels.
const LETTER_CELL: float = 3.0 * Kit.PX

@onready var solo: Button = %Solo
@onready var host: Button = %Host
@onready var join: Button = %Join
@onready var credits: Button = %Credits
@onready var quit: Button = %Quit

var _marker: Control


func _ready() -> void:
	var wordmark := $Column/Wordmark as TextureRect
	wordmark.texture = Frontend.signword("REACTIVE")
	wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wordmark.stretch_mode = TextureRect.STRETCH_SCALE
	wordmark.custom_minimum_size = wordmark.texture.get_size() * LETTER_CELL
	if Game.instance.multiplayer_test:
		get_tree().change_scene_to_file.call_deferred("res://lobby/lobby_test.tscn")
		return

	Frontend.link(solo)
	Frontend.link(host)
	Frontend.link(join)
	Frontend.link(credits, Kit.DIM)
	Frontend.link(quit, Kit.DIM)
	for button: Button in [solo, host, join, credits, quit]:
		# The pointer follows the mouse too, so there is only ever one item marked.
		button.mouse_entered.connect(button.grab_focus)
	_marker = Control.new()
	_marker.name = "Marker"
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.draw.connect(_draw_marker)
	add_child(_marker)

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


func _process(_delta: float) -> void:
	if _marker != null: _marker.queue_redraw()


## A small amber pointer left of the focused item, at the height of its letters.
func _draw_marker() -> void:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused == null or focused.get_parent() != $Column: return
	var px: float = Kit.PX
	var rect: Rect2 = focused.get_global_rect()
	var cell: float = px
	var mid: float = roundf((rect.position.y + rect.size.y * 0.5) / px) * px
	var x: float = rect.position.x - cell * 7.0
	var color: Color = Kit.RAMPS["tool"][2]
	for i: int in 3:
		var h: float = cell * (5 - i * 2)
		_marker.draw_rect(Rect2(x + i * cell, mid - h * 0.5, cell, h), color)


# Single player: no server, no peers. We keep the OfflineMultiplayerPeer that
# Lobby.reset() leaves in place, register the one local player and reuse the
# lobby screen so the role can still be picked.
func _start_solo() -> void:
	Game.instance.solo = true
	Game.instance.players.clear()
	var player_name: String = Frontend.player_name()
	Game.instance.add_player(Statics.PlayerData.new(
		multiplayer.get_unique_id(), player_name, 0, Statics.Role.DAMAGE))
	get_tree().change_scene_to_file("res://lobby/waiting_screen.tscn")
