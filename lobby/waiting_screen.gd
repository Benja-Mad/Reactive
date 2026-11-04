## The crew screen: each operator takes one of the two, then says they are ready. Everyone ready
## deploys the crew at once (no countdown). The two operators stand on the yard facing each other,
## name and tool beside them; plates over their heads say who took whom, and whoever is still
## choosing stands between them. On the left baseline, the ready button and the key hints.
class_name LobbyWaitingScreen
extends Control

const Kit = preload("res://scripts/ui/kit.gd")
const Frontend = preload("res://ui/frontend_backdrop.gd")
const Figure = preload("res://lobby/operator_card.gd")
## Each operator in their own voice. The name and the tool are Statics.get_role_name; what they
## do is written from the code (run.gd _flame/_animas, rules.gd heat): Brasa's flame works at
## 6 m along the ground, dries what is wet and heats what is dry, flashes puddles into steam,
## and cannot reach what flies; the Sereno's ánimas seek their machine on their own, burst into
## water that soaks the splash, and now and then leave a puddle.
const OPERATORS := {
	Statics.Role.SUPPORT: {
		"accent": "do", "flip": false,
		"frames": preload("res://materials/operators/sereno_frames.tres"),
		"about": "Suelta ánimas, espíritus de lluvia que buscan solas la máquina y revientan en agua.",
	},
	Statics.Role.DAMAGE: {
		"accent": "when", "flip": true,
		"frames": preload("res://materials/operators/brasa_frames.tres"),
		"about": "Fuego desde la palma, de cerca y sin parar; hace vapor los charcos. Lo que vuela se le escapa.",
	},
}

var _cards: Dictionary = {}
var _ready_button: Button
var _back: Button
var _status: Label
var _choosing: HBoxContainer
var _layer: Control

func _ready() -> void:
	# The inherited page layout is replaced; only its backdrop stays, dimmed evenly.
	get_node("Page").hide()
	var backdrop: Control = get_node("Backdrop")
	backdrop.set("mode", "stage")
	backdrop.queue_redraw()
	_build()
	Game.instance.players_updated.connect(_handle_players_updated)
	Game.instance.player_updated.connect(func(_id: int) -> void: _refresh())
	Game.instance.vote_updated.connect(func(_id: int) -> void: _handle_vote_updated())
	resized.connect(_layout)
	_handle_players_updated()

func _build() -> void:
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_layer)
	for role: int in [Statics.Role.SUPPORT, Statics.Role.DAMAGE]:
		var spec: Dictionary = OPERATORS[role]
		var parts: PackedStringArray = Statics.get_role_name(role).split(" · ")
		var card: Control = Figure.new()
		card.role = role
		card.accent = spec["accent"]
		card.frames = spec["frames"]
		card.flip = spec["flip"]
		card.text_left = role == Statics.Role.SUPPORT
		card.title = parts[0]
		card.line = parts[1] if parts.size() > 1 else ""
		card.about = spec["about"]
		card.chosen.connect(_update_role)
		_layer.add_child(card)
		_cards[role] = card
	_status = Label.new()
	_status.theme_type_variation = &"Muted"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_status)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_button = Button.new()
	_ready_button.name = "Ready"
	_ready_button.focus_mode = Control.FOCUS_NONE
	_ready_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ready_button.pressed.connect(_toggle_ready)
	Frontend.primary(_ready_button)
	# One row on the left baseline: the decision, then "volver" clear of it. The arrows and Enter
	# still work; nothing on screen spells them out.
	_back = %BackButton
	var back_row: HBoxContainer = $BackRow
	Frontend.back_row(back_row, _back)
	_back.pressed.connect(_handle_back_pressed)
	move_child(back_row, get_child_count() - 1)
	back_row.add_child(_ready_button)
	back_row.move_child(_ready_button, 0)
	back_row.add_child(_gap(32))
	back_row.move_child(back_row.get_child(back_row.get_child_count() - 1), 1)
	# Whoever has not picked yet stands between the two, on a dark plate.
	_choosing = HBoxContainer.new()
	_choosing.add_theme_constant_override("separation", 8)
	_choosing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_choosing)
	_layout()

func _gap(width: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.x = width
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap

func _layout() -> void:
	if _layer == null: return
	var view: Vector2 = size
	var top: float = 24.0
	var stage_h: float = view.y - 150.0
	var half: float = roundf(view.x * 0.5 / Kit.PX) * Kit.PX
	_cards[Statics.Role.SUPPORT].position = Vector2(0, top)
	_cards[Statics.Role.SUPPORT].size = Vector2(half, stage_h)
	_cards[Statics.Role.DAMAGE].position = Vector2(half, top)
	_cards[Statics.Role.DAMAGE].size = Vector2(view.x - half, stage_h)
	# The sentence of what is missing sits over the row; the ones still choosing stand between
	# the two operators, at their feet.
	_status.position = Vector2(56, view.y - 116)
	_status.size = Vector2(view.x - 112, 26)
	_choosing.reset_size()
	var feet: float = top + roundf(stage_h * 0.78 / Kit.PX) * Kit.PX
	_choosing.position = Vector2(roundf((view.x - _choosing.size.x) * 0.5 / Kit.PX) * Kit.PX, feet + 28)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"): _update_role(Statics.Role.SUPPORT)
	elif event.is_action_pressed("ui_right"): _update_role(Statics.Role.DAMAGE)
	elif event.is_action_pressed("ui_accept") and not _ready_button.disabled: _toggle_ready()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE: _handle_back_pressed()
	else: return
	get_viewport().set_input_as_handled()

func _toggle_ready() -> void:
	Game.instance.set_current_player_vote(not Game.instance.get_current_player().vote)
	_refresh()

func _update_role(role: Statics.Role) -> void:
	if not Game.instance.use_roles: return
	var me: Statics.PlayerData = Game.instance.get_current_player()
	if me.role == role: return
	# Changing operator takes back a ready already given.
	if me.vote: Game.instance.set_current_player_vote(false)
	Game.instance.set_current_player_role(role)
	_refresh()
	if _cards.has(role): _cards[role].answer()

## Figures, names, button and status from the current players.
func _refresh() -> void:
	var me: Statics.PlayerData = Game.instance.get_current_player()
	if me == null: return
	for role: int in _cards:
		var card: Control = _cards[role]
		card.selected = me.role == role
		card.is_ready = me.vote
		card.me_name = me.name
		card.crew = Game.instance.players.size() > 1
		var picks := PackedStringArray()
		for player: Statics.PlayerData in Game.instance.players:
			if player.id != me.id and player.role == role: picks.append(player.name + (" ✓" if player.vote else ""))
		card.picks = picks
		card.refresh()
	_style_ready(me.vote)
	# Once ready, the button stays live so the ready can be taken back.
	_ready_button.disabled = not _can_start_game() and not me.vote
	_ready_button.text = ("Empezar turno" if Game.instance.solo else "Listo") if not me.vote else "Listo ✓"
	for child: Node in _choosing.get_children(): child.queue_free()
	for player: Statics.PlayerData in Game.instance.players:
		if player.role != Statics.Role.NONE: continue
		var plate := Label.new()
		plate.text = (player.name + " (tú)" if player.id == me.id else player.name) + " · eligiendo"
		var box := StyleBoxFlat.new()
		box.bg_color = Kit.RAMPS["mute"][0]
		box.border_color = Kit.INK
		box.border_width_bottom = int(Kit.PX)
		box.content_margin_left = 5 * Kit.PX
		box.content_margin_right = 5 * Kit.PX
		box.content_margin_bottom = Kit.PX
		plate.add_theme_stylebox_override("normal", box)
		plate.add_theme_color_override("font_color", Kit.DIM)
		_choosing.add_child(plate)
	_layout.call_deferred()
	var reason: String = _reason(me)
	var unpicked := PackedStringArray()
	for player: Statics.PlayerData in Game.instance.players:
		if player.id != me.id and player.role == Statics.Role.NONE: unpicked.append(player.name)
	if not unpicked.is_empty():
		reason = "" if reason == "Alguien aún elige…" else reason
	_status.text = reason

func _reason(me: Statics.PlayerData) -> String:
	var required: int = 1 if Game.instance.solo else Game.instance.min_players
	if me.role == Statics.Role.NONE: return "Elige operador."
	if Game.instance.players.size() < required: return "Esperando a la cuadrilla…"
	if Game.instance.use_roles and Game.instance.unique_roles and not _are_all_roles_unique(): return "Ese operador ya está tomado."
	if Game.instance.use_roles and Game.instance.all_roles and not _are_all_roles_selected(): return "Falta el otro operador."
	if not _all_players_selected_role(): return "Alguien aún elige…"
	if me.vote: return "Esperando al resto…"
	return ""

## Ready reads as committed: the amber paint gives way to an amber outline round a check, the
## letters in amber. Pressing it (or Enter) takes the ready back.
func _style_ready(on: bool) -> void:
	Frontend.primary(_ready_button)
	if not on: return
	var tool: Array = Kit.RAMPS["tool"]
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Kit.INK, 0.7)
	box.border_color = tool[1]
	box.set_border_width_all(int(Kit.PX))
	box.content_margin_left = 8 * Kit.PX
	box.content_margin_right = 8 * Kit.PX
	box.content_margin_top = 2 * Kit.PX
	box.content_margin_bottom = 3 * Kit.PX
	var hover: StyleBoxFlat = box.duplicate()
	hover.border_color = tool[2]
	for state: String in ["normal", "focus"]: _ready_button.add_theme_stylebox_override(state, box)
	for state: String in ["hover", "pressed", "hover_pressed"]: _ready_button.add_theme_stylebox_override(state, hover)
	for color: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		_ready_button.add_theme_color_override(color, tool[2])

func _handle_players_updated() -> void:
	if multiplayer.is_server():
		Game.instance.reset_votes()
	_refresh()

func _handle_back_pressed() -> void:
	if Game.instance.solo:
		Lobby.instance.go_to_menu()
	elif multiplayer.is_server():
		Lobby.instance.go_to_host()
	else:
		Lobby.instance.go_to_join()

func _handle_vote_updated() -> void:
	_refresh()
	if multiplayer and multiplayer.is_server():
		var all_voted: bool = true
		for player: Statics.PlayerData in Game.instance.players:
			all_voted = all_voted and player.vote
		# Everyone ready deploys the crew at once: no countdown.
		if all_voted and _can_start_game():
			_start_game.rpc()

@rpc("reliable", "call_local")
func _start_game() -> void:
	Game.instance.set_current_player_vote(false)
	get_tree().change_scene_to_packed(Game.instance.main_scene)

func _can_start_game() -> bool:
	var required: int = 1 if Game.instance.solo else Game.instance.min_players
	var quantity: bool = Game.instance.players.size() >= required
	var completion: bool = not Game.instance.use_roles or not Game.instance.all_roles or _are_all_roles_selected()
	var uniqueness: bool = not Game.instance.use_roles or not Game.instance.unique_roles or _are_all_roles_unique()
	var fullness: bool = not Game.instance.use_roles or _all_players_selected_role()
	return quantity and completion and uniqueness and fullness

func _are_all_roles_selected() -> bool:
	var roles: Array = Statics.Role.values()
	roles.pop_front()
	for player: Statics.PlayerData in Game.instance.players:
		roles.erase(player.role)
	return roles.is_empty()

func _are_all_roles_unique() -> bool:
	var roles: Array = Statics.Role.values()
	roles.pop_front()
	for player: Statics.PlayerData in Game.instance.players:
		if roles.has(player.role):
			roles.erase(player.role)
		else:
			return false
	return true

func _all_players_selected_role() -> bool:
	for player: Statics.PlayerData in Game.instance.players:
		if player.role == Statics.Role.NONE:
			return false
	return true
