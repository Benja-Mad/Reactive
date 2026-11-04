## The HUD in the crew's pixel kit, kept off the yard as much as it can: the clock to the relief
## crew big at the top, your face with your health beside it and the level on its corner, and the
## program in the corner as glyph rows, each trigger refilling as it recharges and each piece
## lighting as the world carries it out. Only the face and the program sit on a plate.
## Level-ups dock three parts above that program, each with the socket it goes in; the pause opens
## the workshop; the shift ends on a parte de turno whose centrepiece is the program you ended with.
extends Control
const Kit = preload("res://scripts/ui/kit.gd")
const Build = preload("res://scripts/survivor/build.gd")
const Attack = preload("res://scripts/survivor/attack.gd")
const NodeEditor = preload("res://scripts/survivor/node_editor.gd")
const Portraits = preload("res://ui/operator_portraits.gd")
const PX: float = Kit.PX
## A level-up offer as a row of the list, and the gap between rows.
const ROW := Vector2(300, 30) * Kit.PX
const ROW_GAP: float = 2 * Kit.PX
## The strip at the bottom of the workshop for its line of instructions and its buttons; the editor
## gets everything above it.
const BAND: float = 24 * Kit.PX
const CREW_NAME := {true: "El Sereno", false: "Brasa"}
## Health has its own colour: bone, so it is never read as water, the Sereno or a DO piece.
const HEALTH := Color("e8e4d8")
var run: Node
var _key: String = ""
var _controls: Control
var _choices: Array = []
## Level-up: the piece chosen from the offers, waiting for a destination.
var _picking: String = ""
var _hotkeys: Array[Callable] = []
## What Enter does on this sheet, if anything.
var _enter: Callable
var _editor: Control
var _faces: Dictionary = {}
var _vignette: Texture2D
var _shade: Texture2D
## The program running, per routine of yours: when each piece last acted ("lit"), or acted on
## nothing ("idle"); the wire the matter is crossing ("flow": [piece, start, duration]); the THEN
## waiting for its moment ("armed": piece, since when). Times are this machine's seconds.
var _beats: Dictionary = {}
## Two of your routines whose matter just acted on each other: [a, b, when].
var _combos: Array = []
const COMBO_HOLD := 0.9
const GLOW := 0.3
const ARMED_HOLD := 6.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	theme = Kit.theme()
	_controls = Control.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_controls)

func my_build() -> Dictionary:
	return run.builds.get(multiplayer.get_unique_id(), Build.fresh())

func _process(delta: float) -> void:
	size = get_viewport_rect().size
	if run.spellwork != null and not run.spellwork.beat.is_connected(_on_beat):
		run.spellwork.beat.connect(_on_beat)
		run.spellwork.combo.connect(_on_combo)
	_controls.size = size
	_choices = run.offers.get(multiplayer.get_unique_id(), [])
	if run.phase != "upgrade" or _picking not in _choices: _picking = ""
	var key: String = "%s|%s|%s|%s|%s" % [run.phase, _choices, my_build(), _picking, size]
	if key != _key:
		_key = key
		_rebuild()
	queue_redraw()

## A beat of one of your routines, as the host's world takes it: light the piece that acted.
func _on_beat(peer: int, index: int, stage: String, k: int, duration: float) -> void:
	if peer != multiplayer.get_unique_id() or index < 0: return
	var now: float = _now()
	if not _beats.has(index) or stage == "draw": _beats[index] = {"lit": {}, "idle": {}, "flow": [], "armed": -1, "armed_at": 0.0}
	var beat: Dictionary = _beats[index]
	var last: int = 0
	var routines: Array = my_build()["routines"]
	if index < routines.size(): last = routines[index]["steps"].size() + (1 if routines[index]["then"] != "" else 0)
	match stage:
		"draw":
			beat["lit"][0] = now
			beat["flow"] = [1, now, duration]
		"step", "idle":
			beat["lit" if stage == "step" else "idle"][1 + k] = now
			beat["flow"] = [2 + k, now, duration] if 2 + k <= last and stage == "step" else []
		"armed":
			beat["armed"] = 1 + k
			beat["armed_at"] = now
			beat["flow"] = []
		"fire":
			beat["armed"] = -1
			beat["lit"][last] = now

func _on_combo(peer: int, a: int, b: int) -> void:
	if peer != multiplayer.get_unique_id(): return
	_combos = _combos.filter(func(c: Array) -> bool: return _now() - float(c[2]) < COMBO_HOLD and not (c[0] == a and c[1] == b))
	_combos.append([a, b, _now()])

## How lit routine `index`'s number is from a combo, 1 just now to 0.
func _combo_glow(index: int) -> float:
	var best: float = 0.0
	for c: Array in _combos:
		if index == int(c[0]) or index == int(c[1]): best = maxf(best, 1.0 - (_now() - float(c[2])) / COMBO_HOLD)
	return clampf(best, 0.0, 1.0)

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## How lit piece `slot` of routine `index` still is, 1 just now to 0 gone.
func _glow(index: int, slot: int, kind: String = "lit") -> float:
	var at: float = float(_beats.get(index, {}).get(kind, {}).get(slot, -99.0))
	return clampf(1.0 - (_now() - at) / GLOW, 0.0, 1.0)

## A routine written in one line of shorthand: «near › raise · cold › relay».
static func shorthand(routine: Dictionary) -> String:
	var steps: Array = routine["steps"].map(func(key: String) -> String: return Build.PIECES[key]["name"])
	var parts: Array[String] = [Build.PIECES[routine["when"]]["name"] if routine["when"] != "" else "—", " · ".join(steps) if not steps.is_empty() else Build.Recipe.FROM[routine.get("from", "water")]]
	if routine["then"] != "": parts.append(Build.PIECES[routine["then"]]["name"])
	return "  ›  ".join(parts)

func _face(role_support: bool) -> Texture2D:
	var role: int = Statics.Role.SUPPORT if role_support else Statics.Role.DAMAGE
	if not _faces.has(role): _faces[role] = Portraits.portrait(role, true)
	return _faces[role]

## Minutes without a leading zero: «4:59».
static func clock_text(seconds: float) -> String:
	var whole: int = maxi(0, int(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]

## Any build key's name as the lists show it: pieces are lowercase keywords, and tools follow.
static func name_of(key: String) -> String:
	return String(Build.info(key)["name"]).to_lower()

# --- Playing ------------------------------------------------------------------------------------

func _draw() -> void:
	if run == null: return
	# The workshop and the parte cover the screen: nothing of the HUD shows through them.
	if run.phase in ["paused", "won", "lost"] or _picking != "":
		_draw_sheet()
		return
	var player: Character = run.local_player()
	var support: bool = player is Support
	var accent: String = "do" if support else "when"
	var health: float = player.health if player != null else 100.0
	var hurt: bool = health <= 25
	# A shade along the top so the clock reads over any part of the yard.
	draw_texture_rect(_top_shade(), Rect2(0, 0, size.x, 34 * PX), false)
	# Experience along the top edge: a thin rule that fills, ticked every twentieth.
	var fill: float = clampf(float(run.xp) / Build.threshold(run.level), 0, 1)
	draw_rect(Rect2(0, 0, size.x, 3 * PX), Color(Kit.INK, 0.85))
	draw_rect(Rect2(0, 0, roundf(size.x * fill / PX) * PX, 2 * PX), Kit.RAMPS["tool"][1])
	for i: int in range(1, 20): draw_rect(Rect2(roundf(size.x * i / 20.0 / PX) * PX, 0, PX, 2 * PX), Kit.INK)
	# You: the face on its own small plate, your health beside it, the level on its corner.
	var face_box := Rect2(Vector2(8, 8) * PX, Vector2(24, 24) * PX)
	draw_rect(face_box, Kit.INK)
	draw_rect(face_box.grow(-PX), Kit.BOARD)
	draw_rect(Rect2(face_box.position.x + PX, face_box.end.y - 2 * PX, face_box.size.x - 2 * PX, PX), Kit.ramp(accent)[1])
	# The bust at the yard's own grain: one texel a canvas unit.
	var face := _face(support) as AtlasTexture
	draw_texture_rect_region(face.atlas, Rect2(face_box.position + Vector2(PX, PX), Vector2(44, 42)), Rect2(face.region.position + Vector2(2, 0), Vector2(44, 42)))
	_health_bar(face_box.position + Vector2(29, 9) * PX, health, 5, hurt)
	# The level rides the portrait's corner on a small ink tab, the way a rank sits on a badge.
	var rank: String = "%d" % run.level
	var tab := Rect2(face_box.end - Vector2(Kit.width(rank) / PX + 4, 10) * PX + Vector2(3, 3) * PX, Vector2(Kit.width(rank) / PX + 4, 10) * PX)
	draw_rect(tab, Kit.INK)
	Kit.text(self, tab.position + Vector2(2, 0) * PX, rank, Kit.RAMPS["tool"][2])
	# The rest of the crew: their colour is their name, their bar the same bone health.
	var y: float = face_box.end.y + 6 * PX
	for other: Node in run.players():
		if other == player: continue
		var mate: Character = other
		draw_rect(Rect2(Vector2(9 * PX, y - PX), Vector2(3, 6) * PX), Kit.ramp("do" if mate is Support else "when")[1])
		_health_bar(Vector2(16 * PX, y), mate.health if not mate.eliminated else 0.0, 4, mate.health <= 25, 4)
		y += 9 * PX
	# The clock alone: time left to the relief crew, in big numerals, rose in the last half minute.
	var remaining: float = maxf(0.0, ceilf(run.DURATION - run.elapsed))
	var cx: float = roundf(size.x * 0.5 / PX) * PX
	var late: bool = remaining <= 30
	Kit.text(self, Vector2(cx, 6 * PX), clock_text(remaining), Kit.RAMPS["danger"][2] if late else Kit.TEXT, 2, HORIZONTAL_ALIGNMENT_CENTER, true)
	_draw_program()
	if player != null and player.eliminated and run.phase == "running":
		Kit.text(self, Vector2(cx, size.y * 0.38), "Fuera de servicio", Kit.RAMPS["danger"][2], 2, HORIZONTAL_ALIGNMENT_CENTER, true)
		Kit.text(self, Vector2(cx, size.y * 0.38 + 24 * PX), "la cuadrilla sigue sin ti", Kit.TEXT, 1, HORIZONTAL_ALIGNMENT_CENTER, true)
	if run.phase != "running": _draw_sheet()

## Health out of 100 as ten bone segments, rose once it is low.
func _health_bar(at: Vector2, health: float, seg_w: float, low: bool, h: float = 6.0) -> void:
	var w: float = seg_w * PX
	var hh: float = h * PX
	var lit: Color = Kit.RAMPS["danger"][1] if low else HEALTH
	draw_rect(Rect2(at - Vector2(PX, PX), Vector2(10 * (w + PX) + PX, hh + 2 * PX)), Kit.INK)
	for i: int in 10:
		var x: float = at.x + i * (w + PX)
		var amount: float = clampf(health / 10.0 - i, 0.0, 1.0)
		draw_rect(Rect2(x, at.y, w, hh), Kit.FILL)
		if amount > 0.0:
			draw_rect(Rect2(x, at.y, maxf(PX, roundf(w * amount / PX) * PX), hh), lit)
			draw_rect(Rect2(x, at.y + hh - PX, maxf(PX, roundf(w * amount / PX) * PX), PX), Color(lit.darkened(0.35)))

func _top_shade() -> Texture2D:
	if _shade == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(Kit.INK, 0.7))
		gradient.set_color(1, Color(Kit.INK, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0, 0)
		texture.fill_to = Vector2(0, 1)
		texture.width = 4
		texture.height = 34
		_shade = texture
	return _shade

const SOURCE_GLYPH := {"water": "agua", "fire": "fuego", "current": "arco", "scrap": "chatarra"}
const SOURCE_ACCENT := {"water": "do", "fire": "when", "current": "tool", "scrap": "mute"}
const STEP: float = 17 * Kit.PX
const LINE_H: float = 16 * Kit.PX

## The program's plate in the corner, sized to what it holds.
func _program_rect() -> Rect2:
	var routines: Array = my_build()["routines"]
	var widest: int = 1 + Build.attack_steps(my_build()).size()
	for routine: Dictionary in routines: widest = maxi(widest, 2 + routine["steps"].size() + (1 if routine["then"] != "" else 0))
	var w: float = 10 * PX + maxi(widest, 3) * STEP + 8 * PX
	var h: float = (routines.size() + 1) * LINE_H + 5 * PX
	return Rect2(Vector2(8 * PX, size.y - 8 * PX - h), Vector2(w, h))

## The program in the corner, on one dark plate: the weapon and its pieces (row A, as the workshop
## names it), then one row of glyphs per numbered routine. A trigger recharging shows grey with its
## colour rising from below and a track under it filling; ready, it sits in a lit socket. A routine
## the workshop marks as wrong ends on the same rose × the workshop draws beside it.
func _draw_program() -> void:
	var routines: Array = my_build()["routines"]
	var attack: Array = Build.attack_steps(my_build())
	var charge: Array = run.charges.get(multiplayer.get_unique_id(), [])
	var box := _program_rect()
	draw_rect(box, Color(Kit.BOARD, 0.82))
	draw_rect(Rect2(box.position, Vector2(box.size.x, PX)), Kit.LINE)
	var left: float = box.position.x + 4 * PX
	var first: float = box.position.y + 4 * PX
	# The weapon, with what is plugged into it.
	var support: bool = run.local_player() is Support
	Kit.text(self, Vector2(left, first - PX), "A", Kit.FAINT)
	var x: float = left + 9 * PX
	draw_texture_rect(Kit.icon("agua" if support else "fuego", "do" if support else "when"), Rect2(Vector2(x, first), Vector2(12, 12) * PX), false)
	for i: int in attack.size():
		x += STEP
		_wire(x, first, "do")
		draw_texture_rect(Kit.icon(attack[i]), Rect2(Vector2(x, first), Vector2(12, 12) * PX), false)
	for index: int in routines.size():
		var routine: Dictionary = routines[index]
		var at := Vector2(left + 9 * PX, first + (index + 1) * LINE_H)
		var joined: float = _combo_glow(index)
		Kit.text(self, Vector2(left, at.y - PX), "%d" % (index + 1), Kit.RAMPS["tool"][2] if joined > 0.0 else Kit.FAINT)
		if routine["when"] == "":
			for i: int in 3: Kit.dashed(self, Rect2(at + Vector2(i * STEP - PX, -PX), Vector2(14, 14) * PX), Kit.LINE_HI)
			continue
		var ready: float = float(charge[index]) if index < charge.size() else 0.0
		var broken: bool = Build.problem(routine, routines, index) != ""
		var pieces: Array = [routine["when"]] + routine["steps"]
		if routine["then"] != "": pieces.append(routine["then"])
		x = at.x
		var beat: Dictionary = _beats.get(index, {})
		var flow: Array = beat.get("flow", [])
		var armed: int = int(beat.get("armed", -1)) if _now() - float(beat.get("armed_at", 0.0)) < ARMED_HOLD else -1
		for i: int in pieces.size():
			var key: String = pieces[i]
			var spot := Rect2(Vector2(x, at.y), Vector2(12, 12) * PX)
			var accent: String = Kit.accent_of(key)
			if i > 0:
				# The wire in lights while the matter crosses to this piece, filling as it goes.
				var crossing: float = -1.0
				if not flow.is_empty() and int(flow[0]) == i: crossing = clampf((_now() - float(flow[1])) / maxf(0.05, float(flow[2])), 0.0, 1.0)
				_wire(x, at.y, accent, 1.0 if _glow(index, i) > 0.0 else crossing)
			var glow: float = _glow(index, i)
			var idle: float = _glow(index, i, "idle")
			if glow > 0.0 or i == armed:
				# Acting now: its own colour lit behind it, the glyph lifted a pixel while fresh. A THEN
				# waiting for its moment sits on a quiet dark plate until it goes.
				var edge: Color = Kit.ramp(accent)[2 if glow > 0.5 else 1]
				if glow <= 0.0: edge = Color(Kit.ramp(accent)[1], 0.5)
				Kit.notched(self, spot.grow(PX), Color(Kit.ramp(accent)[0], maxf(glow, 0.6)), edge)
				draw_texture_rect(Kit.icon(key), Rect2(spot.position - Vector2(0, PX if glow > 0.5 else 0.0), spot.size), false)
			elif idle > 0.0:
				# It ran and found nothing to act on: greyed, and a rose rim says so.
				Kit.notched(self, spot.grow(PX), Color(0, 0, 0, 0), Color(Kit.RAMPS["danger"][1], idle))
				Kit.notched(self, spot, Kit.BOARD, Color(0, 0, 0, 0))
				draw_texture_rect(Kit.icon(key, "mute"), spot, false)
			elif i == 0 and ready >= 1.0:
				Kit.notched(self, spot.grow(PX), Kit.FILL_HI, Kit.RAMPS["when"][1])
				draw_texture_rect(Kit.icon(key), spot, false)
			elif i == 0:
				draw_texture_rect(Kit.icon(key, "mute"), spot, false)
				var filled: float = floorf(ready * 12.0)
				var tex := Kit.icon(key)
				if filled > 0.0:
					draw_texture_rect_region(tex.atlas, Rect2(spot.position + Vector2(0, (12.0 - filled) * PX), Vector2(12, filled) * PX), Rect2(tex.region.position + Vector2(0, 12.0 - filled), Vector2(12, filled)))
				# The recharge track: dark, filling in the trigger's colour.
				draw_rect(Rect2(spot.position.x - PX, spot.end.y + PX, 14 * PX, 2 * PX), Kit.LINE)
				draw_rect(Rect2(spot.position.x - PX, spot.end.y + PX, roundf(ready * 14.0) * PX, 2 * PX), Kit.RAMPS["when"][1])
			else:
				draw_texture_rect(Kit.icon(key), spot, false)
			if i == 0 and glow > 0.0 and ready < 1.0:
				draw_rect(Rect2(spot.position.x - PX, spot.end.y + PX, 14 * PX, 2 * PX), Kit.LINE)
			x += STEP
		if broken: _cross(Vector2(x - 2 * PX, at.y + 3 * PX))
	# Combos: a bracket in the plate's left margin from one number to the other, amber, fading.
	for c: Array in _combos:
		var fade: float = 1.0 - (_now() - float(c[2])) / COMBO_HOLD
		if fade <= 0.0 or int(c[1]) >= routines.size(): continue
		var top_y: float = first + (int(c[0]) + 1) * LINE_H + 5 * PX
		var bottom_y: float = first + (int(c[1]) + 1) * LINE_H + 5 * PX
		var colour: Color = Color(Kit.RAMPS["tool"][1], fade)
		var rail: float = box.position.x + PX
		draw_rect(Rect2(rail, top_y, PX, bottom_y - top_y + PX), colour)
		draw_rect(Rect2(rail, top_y, 2 * PX, PX), colour)
		draw_rect(Rect2(rail, bottom_y, 2 * PX, PX), colour)

## The rose × the workshop puts by a routine that will not work as built; grey on the parte, where
## it is a record and no longer something to fix.
func _cross(at: Vector2, color: Color = Kit.RAMPS["danger"][1]) -> void:
	for i: int in 5:
		draw_rect(Rect2(at + Vector2(i, i) * PX, Vector2(PX, PX)), color)
		draw_rect(Rect2(at + Vector2(4 - i, i) * PX, Vector2(PX, PX)), color)

## The short wire into the glyph at `x`, in the colour of the piece it feeds; `lit` from 0 to 1
## fills it from the left in the bright tone, while matter crosses it.
func _wire(x: float, y: float, accent: String, lit: float = -1.0) -> void:
	draw_rect(Rect2(x - 4 * PX, y + 6 * PX, 3 * PX, PX), Kit.ramp(accent)[0])
	if lit > 0.0:
		draw_rect(Rect2(x - 4 * PX, y + 5 * PX, maxf(1.0, ceilf(lit * 3.0)) * PX, 3 * PX), Kit.ramp(accent)[2])

# --- Sheets: level-up, workshop, end of shift ----------------------------------------------------

## A plain scrim that darkens the yard, deeper toward the edges, so the sheet reads over it.
func _draw_scrim(amount: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Kit.INK, amount))
	if _vignette == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(Kit.INK, 0.0))
		gradient.set_offset(0, 0.45)
		gradient.set_color(1, Color(Kit.INK, 0.6))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.05, 0.5)
		texture.width = 288
		texture.height = 162
		_vignette = texture
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)

func _draw_sheet() -> void:
	if run.phase in ["won", "lost"]:
		_draw_scrim(0.88)
		_draw_report()
	elif run.phase == "upgrade" and _choices.is_empty():
		_draw_scrim(0.45)
		Kit.text(self, size * 0.5, "esperando a la cuadrilla…", Kit.TEXT, 1, HORIZONTAL_ALIGNMENT_CENTER, true)
	elif run.phase == "upgrade" and _picking == "":
		# The offers come in docked above the program they will go into, which stays lit.
		_draw_scrim(0.5)
		_draw_program()
		var list := _offers_rect()
		draw_rect(Rect2(list.position - Vector2(0, 2 * PX), list.size + Vector2(0, 4 * PX)), Color(Kit.BOARD, 0.92))
		Kit.text(self, Vector2(list.position.x + 3 * PX, list.position.y - 30 * PX), "Nivel %d" % run.level, Kit.TEXT, 2, HORIZONTAL_ALIGNMENT_LEFT, true)
	elif run.phase == "paused" or _picking != "":
		_draw_scrim(0.82)
		var area := _workshop_rect()
		# A guest is told why the yard stopped; the host paused it and knows.
		if _picking == "" and not multiplayer.is_server():
			Kit.text(self, Vector2(area.position.x, area.end.y - 15 * PX), "El anfitrión pausó el turno", Kit.DIM)

# --- The parte de turno -------------------------------------------------------------------------

const REPORT_LEFT: float = 28 * Kit.PX
const REPORT_TOP: float = 24 * Kit.PX
const CHIP_ROW: float = 20 * Kit.PX
const GLYPH_ROW: float = 16 * Kit.PX

## The operators on the parte, you first.
func _crew() -> Array:
	var crew: Array = run.players().duplicate()
	var me: Node = run.local_player()
	if me in crew:
		crew.erase(me)
		crew.push_front(me)
	return crew

## The end of the shift on a sheet over the yard, left-aligned: what ended it, one line of time and
## machines, then the program it ended with. Alone, that is your program chip by chip as the
## workshop draws it; with a crew, one column per operator with their name, whether they are still
## standing and their program as the HUD's glyph rows.
func _draw_report() -> void:
	var won: bool = run.phase == "won"
	var x: float = REPORT_LEFT
	var y: float = REPORT_TOP
	Kit.text(self, Vector2(x, y), "Turno cumplido" if won else "Turno perdido", Kit.TEXT, 2)
	y += 27 * PX
	var downed: String = "%d %s" % [run.kills, "máquina derribada" if run.kills == 1 else "máquinas derribadas"]
	var crew: Array = _crew()
	var line: String = "%s en el patio · %s" % [clock_text(run.elapsed), downed]
	if not won: line = "%s a los %s · %s" % ["Caíste" if crew.size() <= 1 else "La cuadrilla cayó", clock_text(run.elapsed), downed]
	Kit.text(self, Vector2(x, y), line, Kit.RAMPS["danger"][2] if not won else Kit.TEXT)
	y += 26 * PX
	if crew.size() <= 1:
		_draw_chips(Vector2(x, y), my_build(), run.local_player() is Support)
	else:
		var column: float = minf(200 * PX, roundf((size.x - 2 * x) / crew.size() / PX) * PX)
		for i: int in crew.size():
			var mate: Character = crew[i]
			var support: bool = mate is Support
			var at := Vector2(x + i * column, y)
			Kit.text(self, at, CREW_NAME[support], Kit.ramp("do" if support else "when")[2])
			Kit.text(self, at + Vector2(0, 12 * PX), "fuera de servicio" if mate.eliminated else "en pie", Kit.DIM if mate.eliminated else Kit.TEXT)
			_glyph_rows(at + Vector2(0, 30 * PX), run.builds.get(mate.get_multiplayer_authority(), Build.fresh()), support)
	if not multiplayer.is_server(): Kit.text(self, Vector2(x + primary_width("Menú") + 12 * PX, _report_buttons_y() + PX), "esperando al anfitrión", Kit.DIM)

## A build as chip rows: A for the weapon and its pieces, then each numbered routine as WHEN, where
## it draws from, its DO steps and its THEN, wired in order.
func _draw_chips(at: Vector2, build: Dictionary, support: bool) -> void:
	var weapon: String = "water" if support else "fire"
	var y: float = at.y
	Kit.text(self, Vector2(at.x, y + PX), "A", Kit.FAINT)
	var x: float = at.x + 10 * PX
	x = _chip(Vector2(x, y), "agua" if support else "fuego", Attack.WEAPON[weapon]["name"], "do" if support else "when")
	for key: String in Build.attack_steps(build):
		x = _chip(Vector2(x + 5 * PX, y), key, name_of(key), "do", true)
	var routines: Array = build["routines"]
	for index: int in routines.size():
		y += CHIP_ROW
		var routine: Dictionary = routines[index]
		Kit.text(self, Vector2(at.x, y + PX), "%d" % (index + 1), Kit.FAINT)
		x = at.x + 10 * PX
		if routine["when"] == "":
			Kit.text(self, Vector2(x, y + PX), "vacía", Kit.FAINT)
			continue
		x = _chip(Vector2(x, y), routine["when"], name_of(routine["when"]), "when")
		var from: String = routine.get("from", "water")
		x = _chip(Vector2(x + 5 * PX, y), SOURCE_GLYPH[from], Build.Recipe.FROM[from], SOURCE_ACCENT[from], true)
		for key: String in routine["steps"]:
			x = _chip(Vector2(x + 5 * PX, y), key, name_of(key), "do", true)
		if routine["then"] != "":
			x = _chip(Vector2(x + 5 * PX, y), routine["then"], name_of(routine["then"]), "then", true)

## A build as the HUD's glyph rows, for a crew member's column on the parte.
func _glyph_rows(at: Vector2, build: Dictionary, support: bool) -> void:
	Kit.text(self, Vector2(at.x, at.y - PX), "A", Kit.FAINT)
	var x: float = at.x + 9 * PX
	draw_texture_rect(Kit.icon("agua" if support else "fuego", "do" if support else "when"), Rect2(Vector2(x, at.y), Vector2(12, 12) * PX), false)
	for key: String in Build.attack_steps(build):
		x += STEP
		_wire(x, at.y, "do")
		draw_texture_rect(Kit.icon(key), Rect2(Vector2(x, at.y), Vector2(12, 12) * PX), false)
	var routines: Array = build["routines"]
	for index: int in routines.size():
		var routine: Dictionary = routines[index]
		var y: float = at.y + (index + 1) * GLYPH_ROW
		Kit.text(self, Vector2(at.x, y - PX), "%d" % (index + 1), Kit.FAINT)
		x = at.x + 9 * PX
		if routine["when"] == "":
			Kit.text(self, Vector2(x, y - PX), "vacía", Kit.FAINT)
			continue
		var pieces: Array = [routine["when"]] + routine["steps"]
		if routine["then"] != "": pieces.append(routine["then"])
		for i: int in pieces.size():
			if i > 0: _wire(x, y, Kit.accent_of(pieces[i]))
			draw_texture_rect(Kit.icon(pieces[i]), Rect2(Vector2(x, y), Vector2(12, 12) * PX), false)
			x += STEP
		if Build.problem(routine, routines, index) != "": _cross(Vector2(x - 2 * PX, y + 3 * PX), Kit.FAINT)

## One chip: glyph and name on a dark notched plate edged in its category; returns its right edge.
func _chip(at: Vector2, glyph: String, label: String, accent: String, wired: bool = false) -> float:
	var r: Array = Kit.ramp(accent)
	var w: float = 17 * PX + Kit.width(label) + 5 * PX
	if wired: draw_rect(Rect2(at.x - 5 * PX, at.y + 7 * PX, 5 * PX, PX), r[0])
	Kit.notched(self, Rect2(at, Vector2(w, 14 * PX)), Kit.FILL_HI, r[0])
	draw_texture_rect(Kit.icon(glyph, accent), Rect2(at + Vector2(2, 1) * PX, Vector2(12, 12) * PX), false)
	Kit.text(self, at + Vector2(16 * PX, 0), label, r[2])
	return at.x + w

## Where the parte's actions go: under the tallest program on it.
func _report_buttons_y() -> float:
	var crew: Array = _crew()
	var y: float = REPORT_TOP + 27 * PX + 26 * PX
	if crew.size() <= 1: return y + (my_build()["routines"].size() + 1) * CHIP_ROW + 10 * PX
	var rows: int = 1
	for mate: Node in crew: rows = maxi(rows, run.builds.get(mate.get_multiplayer_authority(), Build.fresh())["routines"].size() + 1)
	return y + 30 * PX + rows * GLYPH_ROW + 12 * PX

## The workshop takes the whole screen but a margin; its bottom BAND holds the instructions and the
## buttons, and the editor everything above.
func _workshop_rect() -> Rect2:
	return Rect2(Vector2(8, 6) * PX, size - Vector2(16, 12) * PX)

## The level-up list: docked on the program's left edge, just above it.
func _offers_rect() -> Rect2:
	var h: float = ROW.y * _choices.size() + ROW_GAP * maxi(0, _choices.size() - 1)
	var program := _program_rect()
	return Rect2(Vector2(program.position.x, program.position.y - 8 * PX - h), Vector2(_row_width(), h))

## The list as wide as its longest line, so each part's sockets sit right by its name.
func _row_width() -> float:
	var widest: float = 120 * PX
	for key: String in _choices:
		widest = maxf(widest, Kit.width(Build.SHORT.get(key, "")))
		widest = maxf(widest, Kit.width(name_of(key)) + 8 * PX + 39 * PX)
	return roundf((51 * PX + widest + 10 * PX) / PX) * PX

# --- Controls -----------------------------------------------------------------------------------

func _rebuild() -> void:
	_hotkeys.clear()
	_enter = Callable()
	_editor = null
	for child: Node in _controls.get_children():
		_controls.remove_child(child)
		child.queue_free()
	match run.phase:
		"upgrade":
			if _choices.is_empty(): pass
			elif _picking == "": _build_offers()
			else: _build_placement()
		"paused":
			_build_workshop()
		"won", "lost":
			var at := Vector2(REPORT_LEFT, _report_buttons_y())
			if multiplayer.is_server():
				var again := _primary(at, "Otro turno")
				_enter = func() -> void: run.restart.rpc_id(1)
				again.pressed.connect(_enter)
				_link(Vector2(at.x + primary_width("Otro turno") + 24 * PX, at.y), "menú").pressed.connect(_to_menu)
				again.grab_focus()
			else:
				var leave := _primary(at, "Menú")
				_enter = _to_menu
				leave.pressed.connect(_to_menu)
				leave.grab_focus()

## The one decisive action of a sheet: amber paint, ink letters, a darker lip; focus goes lighter.
## Enter presses it; no keycap says so.
func _primary(at: Vector2, label: String) -> Button:
	var tool: Array = Kit.RAMPS["tool"]
	var button := Button.new()
	button.text = label
	button.position = at
	button.size = Vector2(primary_width(label), 15 * PX)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state: Array in [["normal", tool[1], tool[0]], ["hover", tool[2], tool[1]], ["focus", tool[2], tool[1]], ["pressed", tool[0], tool[0]], ["hover_pressed", tool[0], tool[0]]]:
		var box := StyleBoxFlat.new()
		box.bg_color = state[1]
		box.border_color = state[2]
		box.border_width_bottom = int(PX)
		box.content_margin_left = 8 * PX
		box.content_margin_right = 8 * PX
		box.content_margin_top = 2 * PX
		box.content_margin_bottom = 3 * PX
		button.add_theme_stylebox_override(state[0], box)
	for state: String in ["font_color", "font_hover_color", "font_focus_color"]: button.add_theme_color_override(state, Kit.INK)
	button.add_theme_color_override("font_pressed_color", tool[3])
	button.add_theme_color_override("font_hover_pressed_color", tool[3])
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_controls.add_child(button)
	return button

static func primary_width(label: String) -> float:
	return Kit.width(label) + 17 * PX

## A secondary action: a lowercase verb in plain dim text, amber on hover or focus.
func _link(at: Vector2, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.position = Vector2(at.x, at.y + PX)
	button.size = Vector2(Kit.width(label) + 4 * PX, 15 * PX)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = PX
		empty.content_margin_right = PX
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_color_override("font_color", Kit.DIM)
	for state: String in ["font_hover_color", "font_focus_color"]: button.add_theme_color_override(state, Kit.RAMPS["tool"][2])
	button.add_theme_color_override("font_pressed_color", Kit.RAMPS["tool"][1])
	button.add_theme_color_override("font_hover_pressed_color", Kit.RAMPS["tool"][1])
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_controls.add_child(button)
	return button

static func link_width(label: String) -> float:
	return Kit.width(label) + 4 * PX

func _to_menu() -> void:
	get_tree().paused = false
	Lobby.instance.go_to_menu()

func _build_offers() -> void:
	var list := _offers_rect()
	for i: int in _choices.size():
		var key: String = _choices[i]
		var row := OfferRow.new()
		row.key = key
		row.level = int(my_build()["tools"].get(key, 0)) if Build.is_tool_key(key) else 0
		row.position = list.position + Vector2(0, i * (ROW.y + ROW_GAP))
		row.size = Vector2(_row_width(), ROW.y)
		var choose := func() -> void:
			if Build.is_tool_key(key): run.choose_upgrade.rpc_id(1, key, -1)
			else: _picking = key
		row.pressed.connect(choose)
		_hotkeys.append(choose)
		_controls.add_child(row)
		if i == 0: row.grab_focus()

func _open_editor(new_piece: String = "") -> Control:
	var area := _workshop_rect()
	var editor: Control = NodeEditor.new()
	editor.position = area.position
	editor.size = area.size - Vector2(0, BAND)
	_controls.add_child(editor)
	editor.weapon = "water" if run.local_player() is Support else "fire"
	editor.setup(my_build(), new_piece)
	_editor = editor
	return editor

## The workshop band's controls, right-aligned: the secondary action, a clear gap, then the
## primary at the edge.
func _band(primary: String, secondary: String, gap: float) -> Array:
	var area := _workshop_rect()
	var y: float = area.end.y - 16 * PX
	var right: float = area.end.x
	var main: Button = null
	if primary != "":
		right -= primary_width(primary)
		main = _primary(Vector2(right, y), primary)
		right -= gap
	var other := _link(Vector2(right - link_width(secondary), y), secondary)
	return [main, other]

## Level-up: the chosen piece arrives in the box; the player may rearrange anything around it.
## Nothing reaches the host until «listo» (Enter); Esc, or «elegir otra», goes back to the offers.
func _build_placement() -> void:
	var editor: Control = _open_editor(_picking)
	var buttons: Array = _band("Listo", "elegir otra", 24 * PX)
	_enter = func() -> void: run.choose_upgrade.rpc_id(1, _picking, -1, editor.draft)
	buttons[0].pressed.connect(_enter)
	buttons[1].pressed.connect(func() -> void: _picking = "")
	buttons[0].grab_focus()

## The workshop in the pause: every change goes to the host at once, which checks it against the
## pieces owned. Esc resumes; the menu is a plain link kept well apart.
func _build_workshop() -> void:
	var editor: Control = _open_editor()
	editor.changed.connect(func(build: Dictionary) -> void: run.submit_build.rpc_id(1, build))
	if multiplayer.is_server():
		var buttons: Array = _band("Reanudar", "menú", 28 * PX)
		buttons[0].pressed.connect(func() -> void: run.toggle_pause.rpc_id(1))
		buttons[1].pressed.connect(_to_menu)
		buttons[0].grab_focus()
	else:
		_band("", "menú", 0.0)[1].pressed.connect(_to_menu)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if _editor != null and _editor.cancel(): pass
		elif _picking != "": _picking = ""
		else: run.toggle_pause.rpc_id(1)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and _enter.is_valid():
		_enter.call()
		get_viewport().set_input_as_handled()
	elif run.phase in ["upgrade", "paused"] and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var index: int = event.keycode - KEY_1
		if index < _hotkeys.size(): _hotkeys[index].call()
		get_viewport().set_input_as_handled()

## A level-up offer as one line of a parts list: its glyph, its name and what it does (1–9 still
## pick it, unlabelled);
## on the right, where it goes, drawn as a routine's three sockets with its own lit (WHEN opens a
## routine, DO is a step in the middle, THEN closes it), or for a tool the level it brings. The
## focused row is the lighter one, with the amber marker.
class OfferRow extends Button:
	var key: String = ""
	var level: int = 0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		# The pointer moves the focus, so only one row is ever the selected one.
		mouse_entered.connect(grab_focus)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _draw() -> void:
		var px: float = Kit.PX
		var accent: String = Kit.accent_of(key)
		var r: Array = Kit.ramp(accent)
		var amber: Array = Kit.RAMPS["tool"]
		var hot: bool = has_focus()
		if hot:
			draw_rect(Rect2(Vector2.ZERO, size), Kit.FILL_HI)
			var tip := Vector2(4, 12) * px
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(3, 3) * px, tip + Vector2(0, 6) * px]), amber[1])
		draw_texture_rect(Kit.icon(key, accent), Rect2(Vector2(13, 3) * px, Vector2(24, 24) * px), false)
		var label: String = String(Build.info(key)["name"]).to_lower()
		Kit.text(self, Vector2(44 * px, 3 * px), label, r[2])
		Kit.text(self, Vector2(44 * px, 15 * px), Build.SHORT.get(key, ""), Kit.TEXT if hot else Kit.DIM)
		var left: float = 44 * px + Kit.width(label) + 8 * px
		if Build.is_tool_key(key):
			var most: int = int(Build.TOOLS[key]["max"])
			for pip: int in most:
				var spot := Rect2(Vector2(left + pip * 7 * px + px, 4 * px), Vector2(5, 10) * px)
				draw_rect(spot.grow(px), Kit.INK)
				draw_rect(spot, r[1] if pip < level else r[2] if pip == level else Kit.FILL)
		else:
			var lit: int = ["when", "step", "then"].find(Build.slot_of(key))
			for i: int in 3:
				var spot := Rect2(Vector2(left + i * 13 * px, 4 * px), Vector2(10, 10) * px)
				if i > 0: draw_rect(Rect2(spot.position.x - 3 * px, spot.position.y + 5 * px, 3 * px, px), Kit.LINE_HI)
				if i == lit: Kit.notched(self, spot, r[1], r[2], 1)
				else: Kit.dashed(self, spot, Kit.LINE_HI)
