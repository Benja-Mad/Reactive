## The always-on instrument: who you are and how intact, which routine is loaded and whether it
## is charged, what you have selected, and the last thing the matter told you. Drawn, not built
## from stock controls, so it shares one language with the yard's own signage.
extends Control

const Style = preload("res://scripts/reactive/console_style.gd")
const Model = preload("res://scripts/reactive/routine_model.gd")
const WORDS := {"water": "AGUA", "ice": "HIELO", "steam": "VAPOR"}

var console: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if console == null: return
	var view: Vector2 = size
	_draw_status()
	_draw_toast()
	_draw_strip(view)
	_draw_keys(view)
	if console.aiming: _draw_aim_verdict(view)

func _draw_status() -> void:
	var rect := Rect2(28, 24, 392, 124)
	Style.plate(self, rect, Style.PLATE, Style.BRASS_DIM, 12.0)
	Style.clamps(self, rect)
	var player: Node = console.local_player()
	var health: float = player.health if player != null else 0.0
	var data: Variant = Game.instance.get_player(multiplayer.get_unique_id())
	var name: String = (data.name if data != null else "—").to_upper()
	Style.text(self, Vector2(44, 50), "OPERADOR", 13, Style.TEXT_DIM)
	Style.text(self, Vector2(44 + Style.text_width("OPERADOR  ", 13), 50), name, 15, Style.TEXT)
	Style.text(self, Vector2(rect.end.x - 64, 50), "%03d" % int(health), 15, Style.TEXT, Style.mono(), HORIZONTAL_ALIGNMENT_RIGHT, 48)
	# Integrity as twelve cells, the last few turning to fault.
	var cells: int = 12
	var lit: int = ceili(health / 100.0 * float(cells))
	for i: int in cells:
		var cell := Rect2(44 + i * 30, 58, 26, 7)
		var color: Color = (Style.SPINE if health > 35.0 else Style.FAULT) if i < lit else Color(1, 1, 1, 0.07)
		draw_rect(cell, color)
	# Loaded routine: three numbered slots, its name, and the deploy charge.
	for i: int in console.slots.size():
		var tab := Rect2(44 + i * 34, 76, 28, 20)
		var active: bool = i == console.current_slot
		draw_rect(tab, Style.BRASS if active else Style.INK)
		draw_rect(tab, Style.BRASS if active else Style.BRASS_DIM, false, 1.0)
		Style.text(self, Vector2(tab.position.x, tab.position.y + 15), "%02d" % (i + 1), 12, Style.INK if active else Style.TEXT_DIM, Style.mono(), HORIZONTAL_ALIGNMENT_CENTER, tab.size.x)
	var draft: Dictionary = console.current_draft()
	Style.text(self, Vector2(154, 92), Model.name_of(draft), 19, Style.SODIUM)
	var charge: float = console.charge()
	var ring_centre := Vector2(rect.end.x - 26, 86)
	draw_arc(ring_centre, 11, 0, TAU, 28, Color(1, 1, 1, 0.08), 3.0, true)
	draw_arc(ring_centre, 11, -PI * 0.5, -PI * 0.5 + TAU * charge, 28, Style.SODIUM if charge >= 1.0 else Style.BRASS_DIM, 3.0, true)
	if charge >= 1.0: draw_circle(ring_centre, 4, Style.SODIUM)
	# The selected reference, read off the replicated record.
	var record: Dictionary = console.selected_record()
	draw_line(Vector2(44, 106), Vector2(rect.end.x - 16, 106), Color(1, 1, 1, 0.06), 1.0)
	if record.is_empty():
		Style.text(self, Vector2(44, 130), "SIN REFERENCIA  ·  C SELECCIONA LA MÁS CERCANA AL CURSOR", 12, Style.TEXT_DIM)
		return
	var label: String = "#%d  %s" % [record["id"], WORDS.get(record["material"], record["material"].to_upper())]
	Style.text(self, Vector2(44, 131), label, 16, Style.TEXT)
	var x: float = 44 + Style.text_width(label, 16) + 12
	var integrity: float = clampf(float(record["integrity"]) / 20.0, 0.0, 1.0)
	draw_rect(Rect2(x, 121, 54, 6), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(x, 121, 54 * integrity, 6), Style.SPINE if integrity > 0.4 else Style.FAULT)
	x += 66
	if record["attachments"].has("nanites"):
		Style.glyph(self, "coat", Vector2(x + 8, 124), 9, Style.BRASS, 1.5)
		x += 24
	if record.has("link"):
		Style.glyph(self, "chain", Vector2(x + 8, 124), 9, Style.BRASS, 1.5)
		x += 24
	var reaction: Dictionary = record.get("reaction", {})
	if not reaction.is_empty():
		Style.glyph(self, reaction["trigger"], Vector2(x + 8, 124), 9, Style.SODIUM, 1.5)
		Style.text(self, Vector2(x + 20, 131), "▸", 13, Style.SODIUM)
		Style.glyph(self, reaction["action"], Vector2(x + 40, 124), 9, Style.SODIUM, 1.5)

func _draw_toast() -> void:
	var age: float = console.message_age()
	if age > 4.5 or console.message == "": return
	var alpha: float = clampf((4.5 - age) / 0.8, 0.0, 1.0) * clampf(age / 0.08, 0.0, 1.0)
	var color: Color = (Style.TEXT if console.message_ok else Style.FAULT)
	var width: float = Style.text_width(console.message, 15) + 40
	var rect := Rect2(28, 158, maxf(width, 160), 30)
	Style.plate(self, rect, Color(Style.INK, Style.INK.a * alpha), Color(color, 0.6 * alpha), 8.0)
	draw_rect(Rect2(rect.position.x, rect.position.y + 8, 3, rect.size.y - 16), Color(color, alpha))
	Style.text(self, rect.position + Vector2(16, 21), console.message, 15, Color(color, alpha))

## The loaded routine as a line of glyphs, so it can be read mid-fight without opening anything.
func _draw_strip(view: Vector2) -> void:
	var draft: Dictionary = console.current_draft()
	var simulation: Dictionary = Model.simulate(draft)
	var steps: Array = draft["steps"]
	var glyphs: Array = ["water"] + steps
	var width: float = 40.0 * glyphs.size() + 130.0 + (30.0 if draft.get("chain", false) else 0.0)
	var keys_width: float = 330.0
	var rect := Rect2((view.x - width - keys_width) * 0.5, view.y - 96, width + keys_width, 42)
	Style.plate(self, rect, Style.PLATE, Style.BRASS_DIM, 9.0)
	var x: float = rect.position.x + 26
	var y: float = rect.position.y + 21
	for i: int in glyphs.size():
		var failing: bool = i > 0 and i - 1 == simulation["failed"]
		var faded: bool = simulation["failed"] >= 0 and i - 1 > simulation["failed"]
		var color: Color = Style.FAULT if failing else (Style.TEXT_DIM if faded else (Style.SPINE if i == 0 else Style.TEXT))
		Style.glyph(self, glyphs[i], Vector2(x, y), 10, color, 1.6)
		if i < glyphs.size() - 1: draw_line(Vector2(x + 14, y), Vector2(x + 26, y), Style.BRASS_DIM, 1.0)
		x += 40
	draw_line(Vector2(x - 12, rect.position.y + 9), Vector2(x - 12, rect.end.y - 9), Style.BRASS_DIM, 1.0)
	Style.glyph(self, draft["trigger"], Vector2(x + 10, y), 10, Style.SODIUM, 1.6)
	Style.text(self, Vector2(x + 26, y + 6), "▸", 15, Style.SODIUM)
	Style.glyph(self, draft["action"], Vector2(x + 52, y), 10, Style.SODIUM, 1.6)
	x += 76
	if draft.get("chain", false):
		Style.glyph(self, "chain", Vector2(x + 6, y), 10, Style.BRASS, 1.6)
		x += 30
	x += 14
	draw_line(Vector2(x - 12, rect.position.y + 9), Vector2(x - 12, rect.end.y - 9), Style.BRASS_DIM, 1.0)
	x += Style.keycap(self, Vector2(x, y + 6), "Q", "DESPLEGAR", 14)
	x += Style.keycap(self, Vector2(x, y + 6), "E", "EDITAR", 14)
	Style.keycap(self, Vector2(x, y + 6), "TAB", "RUTINA", 14)

func _draw_keys(view: Vector2) -> void:
	var entries := [["C", "SELECCIONAR"], ["L", "CONECTAR"], ["R", "GOLPEAR"], ["T", "DETONAR"], ["⌫", "RETIRAR"], ["1-4", "MANUAL"], ["P", "AUTO " + ("SÍ" if console.periodic else "NO")]]
	var y: float = view.y - 20
	var total: float = 0.0
	for entry: Array in entries: total += maxf(Style.text_width(entry[0], 11, Style.mono()) + 10.0, 20.0) + 6 + Style.text_width(entry[1], 12) + 18
	var x: float = (view.x - total) * 0.5
	for entry: Array in entries:
		x += Style.keycap(self, Vector2(x, y - 4), entry[0], entry[1], 12)

func _draw_aim_verdict(view: Vector2) -> void:
	var verdict: Dictionary = console.verdict
	var ok: bool = verdict.get("ok", false)
	var message: String = "SUELO COMPATIBLE · SUELTA Q PARA DESPLEGAR" if ok else ("NO SE PUEDE CREAR · " + console.translate(verdict.get("reason", "")).to_upper())
	if ok and console.charge() < 1.0: message = "RECARGANDO · %.1f s" % ((1.0 - console.charge()) * 6.0)
	var width: float = Style.text_width(message, 15) + 36
	var rect := Rect2((view.x - width) * 0.5, view.y - 138, width, 30)
	Style.plate(self, rect, Style.INK, Style.SODIUM if ok else Style.FAULT, 8.0)
	Style.text(self, rect.position + Vector2(18, 21), message, 15, Style.SODIUM if ok else Style.FAULT)
