## The workshop as node chains on a dark board. The top row is the basic attack: the operator's
## own weapon with DO pieces plugged into it (attack.gd). Each routine below is one row read left
## to right: WHEN fires it, a draught is drawn, every DO step transforms it in order and THEN arms
## what is left. Under every DO chip its properties show as pixel marks; a row with a problem says
## what it is in words after its last piece. The box of loose pieces sits beside the attack row.
## Below the rows the routine under the mouse plays out on a small screen, with a few lines beside
## it, from the same table the host runs. Pieces are dragged from the box onto a slot, or clicked
## and then clicked again where they go; right click (or dragging back to the box) takes a piece
## out. The host validates every change.
extends Control
const Kit = preload("res://scripts/ui/kit.gd")
const Build = preload("res://scripts/survivor/build.gd")
const Recipe = preload("res://scripts/survivor/recipe.gd")
const Catalog = preload("res://scripts/matter/materials.gd")
const Rules = preload("res://scripts/survivor/rules.gd")
const Attack = preload("res://scripts/survivor/attack.gd")
const PX: float = Kit.PX
const ACCENT := {"when": "when", "step": "do", "then": "then", "water": "do", "weapon": "tool"}
## The attack row's address in `where`, and the weapon's glyph.
const ATTACK := Build.ATTACK
const WEAPON_ICON := {"fire": "fuego", "water": "agua"}
const WEAPON_ACCENT := {"fire": "when", "water": "do"}
const NODE_H: float = 14 * PX
const WIRE: float = 8 * PX
const ROW_H: float = 38 * PX
const SOCKET: float = 14 * PX
const ROWS_LEFT: float = 0.0
## The box of loose pieces: to the right of the attack row, which never grows that far.
const TRAY_W: float = 200 * PX
const CHIP_PITCH := Vector2(16, 15) * PX
## The read-out under the rows: the preview screen, then two columns of lines.
const SCREEN_W: float = 128 * PX
const READ_LINE: float = 14 * PX
const READOUT_MAX: float = 92 * PX
## The preview screen: dark glass, 1 px neon, machines in the hazard rose.
const GLASS := Color("070a10")
const NEON := {"water": Color("36c8e0"), "ice": Color("93f3ff"), "steam": Color("c8d0dc"), "fire": Color("ff8a3a"), "current": Color("f4e46a"), "scrap": Color("b08a6a")}
## The source node: the glyph and the word under it for where a routine draws from.
const SOURCE_ICON := {"water": "agua", "fire": "fuego", "current": "arco", "scrap": "chatarra"}
const SOURCE_ACCENT := {"water": "", "fire": "when", "current": "tool", "scrap": "mute"}
const MACHINE := Color("ff3b6b")
const OPERATOR := Color("ffad4a")
const GRAVITY := Color("7a66e8")
const REPEL_TINT := Color("b4a6ff")
const BRASS := Color("ffd27a")
const BLAST := Color("fff0c8")
const SCALD := Color("ff8a3a")
const SPARK := Color("f0ecff")
const WARN := Color("e0a040")
const LINK := Color("b4a6ff")
## A routine's problem in words: the hazard rose, softened so a sentence of it does not shout.
const ISSUE := Color("e88aa2")
## The row being read: a slightly lifted band, its number in amber; no stripe.
const SELECTED := Color(0.42, 0.55, 0.75, 0.16)
## The one plate under the rows' neighbours: the box and the preview sit on it, text never does.
const PLATE := Color(0.02, 0.03, 0.045, 0.72)
const HOT_RING := Color("ff6a24")
const LOOP: float = 5.2
const PX_PER_M: float = 4.0 * Kit.PX
signal changed(build: Dictionary)
var draft: Dictionary = {}
## The level-up piece: it starts first in the box, marked as new, until it is moved.
var incoming: String = ""
var _fresh: bool = false
var _nodes: Array[Dictionary] = []
var _targets: Array[Dictionary] = []
var _box_area := Rect2()
var _held: Dictionary = {}
var _pressed: Dictionary = {}
var _press_at := Vector2.ZERO
var _dragging: bool = false
var _mouse := Vector2.ZERO
## The routine the panel reads out: the row last under the mouse (ATTACK for the attack).
var focus: int = 0
## Whose weapon the attack row plugs into: "fire" for Brasa, "water" for the Sereno.
var weapon: String = "fire"
## Starts part-way into the preview's loop, so the screen opens on the routine already formed.
var _time: float = 2.2
var _reaction_button := Rect2()

func setup(build: Dictionary, new_piece: String = "") -> void:
	draft = build.duplicate(true)
	incoming = new_piece
	_fresh = new_piece != ""
	if _fresh: draft["box"].insert(0, new_piece)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for index: int in draft["routines"].size():
		if draft["routines"][index]["when"] != "":
			focus = index
			break
	if not draft.has("attack"): draft["attack"] = {"steps": []}
	_layout()

## Esc while a piece is in hand puts it back; returns whether there was one.
func cancel() -> bool:
	if _held.is_empty(): return false
	_held = {}
	_dragging = false
	_layout()
	return true

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

# --- Layout ---------------------------------------------------------------------------------

static func _label_of(key: String) -> String:
	return Build.PIECES[key]["name"]

func _node_width(key: String, placeholder: String) -> float:
	if key == "": return 20 * PX if placeholder != "" else SOCKET
	return Kit.width(_label_of(key)) + 22 * PX

## The rule between the rows and the read-out.
func _panel_top() -> float:
	return (draft["routines"].size() + 1) * ROW_H + 2 * PX

## Where a row's nodes sit: the attack first, then the routines in order.
static func _row_top(ri: int) -> float:
	return (0 if ri == ATTACK else ri + 1) * ROW_H + 4 * PX

## The row under a height on the board, or -1 for none.
func _row_at(y: float) -> int:
	if y < 0: return -1
	var row: int = int(y / ROW_H)
	if row == 0: return ATTACK
	return row - 1 if row - 1 < draft["routines"].size() else -1

## Recomputes every node and every drop slot. Slots exist only for the slot type in hand, and only
## where the piece would actually fit.
func _layout() -> void:
	_nodes.clear()
	_targets.clear()
	# The box takes what the attack row can never reach (weapon and three DO at most).
	var tray_w: float = roundf(clampf(size.x - 330 * PX, 120 * PX, TRAY_W) / PX) * PX
	_box_area = Rect2(size.x - tray_w, 2 * PX, tray_w, 32 * PX)
	# The box, WHEN then DO then THEN, a gap between kinds: the same chips as on the rows, with
	# their names while two lines hold them all, glyphs only once the box is that full.
	var order: Array[int] = []
	for slot: String in ["when", "step", "then"]:
		for index: int in draft["box"].size():
			if Build.PIECES[draft["box"][index]]["slot"] == slot: order.append(index)
	var named: bool = _flow_box(order, true).size() == order.size()
	var rects: Array[Rect2] = _flow_box(order, named)
	for n: int in mini(rects.size(), order.size()):
		var index: int = order[n]
		var key: String = draft["box"][index]
		_nodes.append({"rect": rects[n], "key": key, "slot": Build.PIECES[key]["slot"], "where": {"routine": -1, "index": index}, "fresh": _fresh and index == 0, "chip": true, "named": named})
	var held_slot: String = _held.get("slot", "")
	var lifted: Dictionary = Build.take(draft, _held["where"])[0] if not _held.is_empty() else draft
	if not _held.is_empty() and int(_held["where"]["routine"]) != -1:
		_targets.append({"rect": _box_area, "where": {"routine": -1}, "box": true})
	_layout_attack(held_slot, lifted)
	for ri: int in draft["routines"].size():
		var routine: Dictionary = draft["routines"][ri]
		var top: float = _row_top(ri)
		var x: float = ROWS_LEFT + 14 * PX
		var when_rect := Rect2(x, top, _node_width(routine["when"], "+"), NODE_H)
		_add_node_or_slot(when_rect, routine["when"], "when", {"routine": ri, "slot": "when"}, held_slot, lifted)
		x = when_rect.end.x + WIRE
		var water_w: float = Kit.width(Recipe.FROM[routine.get("from", "water")]) + 22 * PX
		_nodes.append({"rect": Rect2(x, top, water_w, NODE_H), "key": "", "slot": "water", "where": {"routine": ri, "slot": "water"}})
		x += water_w + WIRE
		for step: int in routine["steps"].size():
			if held_slot == "step": _try_slot(Rect2(x - WIRE * 0.5 - 4 * PX, top + NODE_H * 0.5 - 4 * PX, 8 * PX, 8 * PX), {"routine": ri, "slot": "step", "index": step}, lifted, true)
			var key: String = routine["steps"][step]
			var rect := Rect2(x, top, _node_width(key, ""), NODE_H)
			_nodes.append({"rect": rect, "key": key, "slot": "step", "where": {"routine": ri, "slot": "step", "index": step}})
			x = rect.end.x + WIRE
		if routine["steps"].size() < Build.MAX_STEPS or (held_slot == "step" and int(_held["where"].get("routine", -1)) == ri):
			var rect := Rect2(x, top, _node_width("", "+"), NODE_H)
			_nodes.append({"rect": rect, "key": "", "slot": "step", "where": {"routine": ri, "slot": "step", "index": routine["steps"].size()}, "placeholder": "+"})
			if held_slot == "step": _try_slot(rect, {"routine": ri, "slot": "step", "index": routine["steps"].size()}, lifted)
			x = rect.end.x + WIRE
		var then_rect := Rect2(x, top, _node_width(routine["then"], "+"), NODE_H)
		_add_node_or_slot(then_rect, routine["then"], "then", {"routine": ri, "slot": "then"}, held_slot, lifted)
	queue_redraw()

## Where the box's chips go, in `order`, on at most two lines; stops early when they do not fit.
func _flow_box(order: Array[int], named: bool) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var start := _box_area.position + Vector2(3, 2) * PX
	var at := start
	var last_slot: String = ""
	for index: int in order:
		var key: String = draft["box"][index]
		var slot: String = Build.PIECES[key]["slot"]
		if last_slot != "" and slot != last_slot: at.x += (6 if named else 5) * PX
		last_slot = slot
		var w: float = _node_width(key, "") if named else SOCKET
		if at.x + w > _box_area.end.x - 2 * PX:
			at = Vector2(start.x, at.y + CHIP_PITCH.y)
			# Named chips give up past two lines; glyphs keep wrapping (26 fit before a third line).
			if named and at.y + NODE_H > _box_area.end.y + PX: return rects
		rects.append(Rect2(at, Vector2(w, NODE_H)))
		at.x += w + (4 * PX if named else CHIP_PITCH.x - SOCKET)
	return rects

## The attack row: the weapon, then its DO pieces with slots between them, up to Attack.MAX_STEPS.
func _layout_attack(held_slot: String, lifted: Dictionary) -> void:
	var top: float = _row_top(ATTACK)
	var x: float = ROWS_LEFT + 14 * PX
	var weapon_w: float = Kit.width(Attack.WEAPON[weapon]["name"]) + 22 * PX
	_nodes.append({"rect": Rect2(x, top, weapon_w, NODE_H), "key": "", "slot": "weapon", "where": {"routine": ATTACK, "slot": "weapon"}})
	x += weapon_w + WIRE
	var steps: Array = Build.attack_steps(draft)
	for step: int in steps.size():
		if held_slot == "step": _try_slot(Rect2(x - WIRE * 0.5 - 4 * PX, top + NODE_H * 0.5 - 4 * PX, 8 * PX, 8 * PX), {"routine": ATTACK, "slot": "step", "index": step}, lifted, true)
		var rect := Rect2(x, top, _node_width(steps[step], ""), NODE_H)
		_nodes.append({"rect": rect, "key": steps[step], "slot": "step", "where": {"routine": ATTACK, "slot": "step", "index": step}})
		x = rect.end.x + WIRE
	if steps.size() < Attack.MAX_STEPS or (held_slot == "step" and int(_held["where"].get("routine", -1)) == ATTACK):
		var rect := Rect2(x, top, _node_width("", "+"), NODE_H)
		_nodes.append({"rect": rect, "key": "", "slot": "step", "where": {"routine": ATTACK, "slot": "step", "index": steps.size()}, "placeholder": "+"})
		if held_slot == "step": _try_slot(rect, {"routine": ATTACK, "slot": "step", "index": steps.size()}, lifted)

func _add_node_or_slot(rect: Rect2, key: String, slot: String, where: Dictionary, held_slot: String, lifted: Dictionary) -> void:
	var node: Dictionary = {"rect": rect, "key": key, "slot": slot, "where": where}
	if key == "": node["placeholder"] = "+"
	_nodes.append(node)
	if held_slot == slot: _try_slot(rect, where, lifted)

func _try_slot(rect: Rect2, where: Dictionary, lifted: Dictionary, between: bool = false) -> void:
	var result: Dictionary = Build.put(lifted, _held["key"], where)
	if not result.is_empty(): _targets.append({"rect": rect, "where": where, "result": result, "between": between})

func _row_node(ri: int, slot: String, index: int = -1) -> Dictionary:
	for node: Dictionary in _nodes:
		var where: Dictionary = node["where"]
		if int(where.get("routine", -2)) == ri and where.get("slot", "") == slot and (index < 0 or int(where.get("index", -1)) == index): return node
	return {}

# --- Input ----------------------------------------------------------------------------------

func _node_at(point: Vector2) -> Dictionary:
	for node: Dictionary in _nodes:
		if node["key"] != "" and (node["rect"] as Rect2).has_point(point): return node
	return {}

func _source_at(point: Vector2) -> Dictionary:
	for node: Dictionary in _nodes:
		if node["slot"] == "water" and (node["rect"] as Rect2).has_point(point): return node
	return {}

func _target_at(point: Vector2) -> Dictionary:
	# Small slots between nodes win over the box area they never overlap anyway.
	for target: Dictionary in _targets:
		if not target.get("box", false) and (target["rect"] as Rect2).grow(4).has_point(point): return target
	for target: Dictionary in _targets:
		if target.get("box", false) and (target["rect"] as Rect2).has_point(point): return target
	return {}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _mouse.x >= ROWS_LEFT and _row_at(_mouse.y) != -1 and not _box_area.has_point(_mouse): focus = _row_at(_mouse.y)
		if not _pressed.is_empty() and not _dragging and _mouse.distance_to(_press_at) > 6.0:
			_dragging = true
			_pick(_pressed)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		_mouse = button.position
		# Clicking a routine's source node cycles what it draws: water, fire, current, scrap.
		var source: Dictionary = _source_at(_mouse) if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and _held.is_empty() else {}
		if not source.is_empty():
			var next: Dictionary = draft.duplicate(true)
			var routine: Dictionary = next["routines"][int(source["where"]["routine"])]
			routine["from"] = Build.next_source(routine.get("from", "water"))
			focus = int(source["where"]["routine"])
			_commit(next)
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and _held.is_empty() and focus != ATTACK and _reaction_button.has_point(_mouse):
			var next: Dictionary = draft.duplicate(true)
			var routine: Dictionary = next["routines"][focus]
			routine["on"] = Recipe.ON[(Recipe.ON.find(routine.get("on", "contact")) + 1) % Recipe.ON.size()]
			_commit(next)
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			var node: Dictionary = _node_at(_mouse)
			if not node.is_empty() and int(node["where"]["routine"]) != -1:
				var lifted: Array = Build.take(draft, node["where"])
				_commit(Build.put(lifted[0], lifted[1], {"routine": -1}))
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				if not _held.is_empty(): _drop(_mouse)
				else:
					_pressed = _node_at(_mouse)
					_press_at = _mouse
			else:
				if _dragging: _drop(_mouse)
				elif not _pressed.is_empty(): _pick(_pressed)
				_pressed = {}
				_dragging = false
			accept_event()

func _pick(node: Dictionary) -> void:
	_held = {"key": node["key"], "slot": node["slot"], "where": node["where"]}
	_layout()

func _drop(point: Vector2) -> void:
	var target: Dictionary = _target_at(point)
	var held: Dictionary = _held
	_held = {}
	_dragging = false
	if target.is_empty():
		_layout()
		return
	var lifted: Array = Build.take(draft, held["where"])
	if int(target["where"]["routine"]) != -1: focus = int(target["where"]["routine"])
	_commit(Build.put(lifted[0], lifted[1], target["where"]), int(held["where"]["routine"]) == -1 and int(held["where"].get("index", -1)) == 0)

func _commit(next: Dictionary, moved_fresh: bool = false) -> void:
	if next.is_empty():
		_layout()
		return
	if moved_fresh: _fresh = false
	draft = next
	_layout()
	changed.emit(draft)

# --- Drawing: rows --------------------------------------------------------------------------

func _icon(key: String, at: Vector2, accent: String = "") -> void:
	draw_texture_rect(Kit.icon(key, accent), Rect2(at, Vector2(12, 12) * PX), false)

func _draw_node(node: Dictionary, idle: bool, lifted: bool) -> void:
	var rect: Rect2 = node["rect"]
	var slot: String = node["slot"]
	var accent: String = ACCENT[slot]
	if lifted:
		Kit.dashed(self, rect, Kit.ramp(accent)[0])
		return
	if slot == "weapon":
		draw_style_box(Kit.chip_box("when" if weapon == "fire" else "do"), rect)
		_icon(WEAPON_ICON[weapon], rect.position + Vector2(2, 1) * PX, WEAPON_ACCENT[weapon])
		Kit.text(self, rect.position + Vector2(16 * PX, 0), Attack.WEAPON[weapon]["name"], NEON[weapon])
		return
	if slot == "water":
		var from: String = draft["routines"][int(node["where"]["routine"])].get("from", "water")
		var hover: bool = _held.is_empty() and rect.has_point(_mouse)
		draw_style_box(Kit.chip_box("do", "" if hover else "dim"), rect)
		_icon(SOURCE_ICON[from], rect.position + Vector2(2, 1) * PX, SOURCE_ACCENT[from])
		Kit.text(self, rect.position + Vector2(16 * PX, 0), Recipe.FROM[from], NEON[from] if hover else Kit.DIM)
		return
	if node["key"] == "":
		Kit.dashed(self, rect, Kit.ramp(accent)[0])
		Kit.text(self, rect.position + Vector2(rect.size.x * 0.5, 0), node.get("placeholder", ""), Kit.ramp(accent)[0], 1, HORIZONTAL_ALIGNMENT_CENTER)
		return
	if node.get("fresh", false):
		# The level-up piece blinks an amber rim until it is moved.
		Kit.notched(self, rect.grow(PX), Color(0, 0, 0, 0), Kit.RAMPS["tool"][2] if fmod(_time, 0.8) < 0.5 else Kit.RAMPS["tool"][0])
	if node.get("chip", false) and not node.get("named", true):
		draw_style_box(Kit.chip_box(accent), rect)
		_icon(node["key"], rect.position + Vector2(PX, PX))
		return
	draw_style_box(Kit.chip_box(accent, "dim" if idle else ""), rect)
	_icon(node["key"], rect.position + Vector2(2, 1) * PX, "mute" if idle else "")
	Kit.text(self, rect.position + Vector2(16 * PX, 0), _label_of(node["key"]), Kit.DIM if idle else Kit.ramp(accent)[2])
	if idle:
		for x: float in range(int(rect.position.x), int(rect.end.x), int(3 * PX)): draw_rect(Rect2(x, rect.end.y + PX, 2 * PX, PX), WARN)

func _wire(from: Vector2, to: Vector2, live: bool, accent: String, pulse: bool) -> void:
	var color: Color = Kit.ramp(accent)[0] if live else Kit.LINE
	draw_rect(Rect2(from.x, from.y - PX * 0.5, to.x - from.x, PX), color)
	if pulse:
		var p: float = from.x + fposmod(_time * 40.0 * PX, maxf(PX, to.x - from.x))
		draw_rect(Rect2(roundf(p / PX) * PX, from.y - PX * 0.5, PX * 2, PX), Kit.ramp(accent)[3])

## A conduit between rows, routed through the gap under the source row, marked with its glyph.
## A `broken` one stops short of the row it feeds, with the break marked where it fails.
func _cable(from: Rect2, to: Rect2, key: String, down: bool, broken: bool = false) -> void:
	var start := Vector2(from.get_center().x if key == "cadena" else from.end.x - 6 * PX, from.end.y if down else from.position.y)
	var finish := Vector2(to.get_center().x, to.position.y if down else to.end.y)
	var lane: float = (from.position.y + ROW_H - 9 * PX) if down else (from.position.y - 3 * PX)
	var points: Array[Vector2] = [start, Vector2(start.x, lane), Vector2(finish.x, lane), finish]
	for i: int in 3:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a).normalized() if length > 0 else Vector2.ZERO
		var t: float = 0.0
		var stop: float = length - 7 * PX if broken and i == 2 else length
		while t < stop:
			draw_rect(Rect2((a + dir * t).snapped(Vector2(PX, PX)), Vector2(PX, PX)), LINK)
			t += 3 * PX
		if broken and i == 2: _break_mark(b - dir * 4 * PX)
	var mid := Vector2(minf(start.x, finish.x) + absf(finish.x - start.x) * 0.5 - 6 * PX, lane - 4 * PX)
	Kit.notched(self, Rect2(mid - Vector2(PX, PX), Vector2(14, 14) * PX), Kit.FILL, LINK.darkened(0.5))
	_icon(key, mid)

## The drawn mark for something that does not work: a small cross in the hazard rose on a dark
## backing, centred on `at`.
func _break_mark(at: Vector2) -> void:
	var c: Vector2 = (at - Vector2(2, 2) * PX).snapped(Vector2(PX, PX))
	draw_rect(Rect2(c - Vector2(PX, PX), Vector2(7, 7) * PX), Kit.INK)
	for i: int in 5:
		draw_rect(Rect2(c + Vector2(i, i) * PX, Vector2(PX, PX)), Kit.RAMPS["danger"][1])
		draw_rect(Rect2(c + Vector2(4 - i, i) * PX, Vector2(PX, PX)), Kit.RAMPS["danger"][1])

func _draw() -> void:
	# The rows sit straight on the workshop's own plate: no board of their own.
	var board := Rect2(ROWS_LEFT, 0, size.x - ROWS_LEFT, _panel_top())
	var held_where: Dictionary = _held.get("where", {})
	var rows: Array = draft["routines"]
	_draw_tray()
	_draw_attack_row(board, held_where)
	for ri: int in rows.size():
		var routine: Dictionary = rows[ri]
		var top: float = _row_top(ri)
		if ri == focus:
			draw_rect(Rect2(ROWS_LEFT, top - 4 * PX, board.size.x, ROW_H), SELECTED)
		Kit.text(self, Vector2(ROWS_LEFT + 5 * PX, top), "%d" % (ri + 1), Kit.RAMPS["tool"][2] if ri == focus else Kit.FAINT)
		var result: Dictionary = Recipe.simulate(routine["steps"], routine.get("from", "water"))
		var chain: Array[Dictionary] = []
		for node: Dictionary in _nodes:
			if int(node["where"].get("routine", -2)) == ri: chain.append(node)
		var live: bool = routine["when"] != ""
		for i: int in chain.size():
			var node: Dictionary = chain[i]
			var rect: Rect2 = node["rect"]
			var is_step: bool = node["slot"] == "step" and node["key"] != ""
			var step_index: int = int(node["where"].get("index", -1)) if is_step else -1
			var idle: bool = is_step and step_index in result["idle"]
			if i > 0:
				var before: Rect2 = chain[i - 1]["rect"]
				_wire(Vector2(before.end.x, top + NODE_H * 0.5), Vector2(rect.position.x, top + NODE_H * 0.5), live, ACCENT[node["slot"]], live and ri == focus)
			_draw_node(node, idle, node["where"] == held_where and not held_where.is_empty())
			# What comes out of this node, as marks; the word only on the row being read.
			var after: Dictionary = {}
			var tag: String = ""
			if node["slot"] == "water":
				after = Recipe.source(routine.get("from", "water"))
				tag = "manos"
			elif is_step:
				after = result["trace"][step_index]["state"]
				tag = result["trace"][step_index]["tag"]
			if not after.is_empty() and not idle:
				var px_end: float = _props(Vector2(rect.position.x + PX, rect.end.y + 3 * PX), after)
				# Glyphs under every row; the word after them, a space clear, on the row being read.
				if ri == focus and Kit.width(tag) <= rect.end.x + WIRE * 0.5 - px_end - _space(): Kit.text(self, Vector2(px_end + _space(), rect.end.y), tag, Kit.DIM)
		if routine["when"] == "eco" and ri == 0 and not chain.is_empty(): _break_mark((chain[0]["rect"] as Rect2).position + Vector2(3, 0) * PX)
		var issue: String = Build.problem(routine, rows, ri)
		if issue != "" and routine["when"] != "" and not chain.is_empty():
			_draw_row_issue((chain[-1]["rect"] as Rect2).end.x + 6 * PX, top)
	_draw_cables(rows)
	draw_rect(Rect2(0, _panel_top(), size.x, PX), Kit.LINE)
	for node: Dictionary in _nodes:
		if int(node["where"].get("routine", 0)) == -1: _draw_node(node, false, node["where"] == held_where)
	# Slots that accept the piece in hand.
	var hovered: Dictionary = _target_at(_mouse) if not _held.is_empty() else {}
	for target: Dictionary in _targets:
		var rect: Rect2 = target["rect"]
		var hot: bool = target == hovered
		var amber: Array = Kit.RAMPS["tool"]
		if target.get("box", false):
			if hot: Kit.dashed(self, rect.grow(-PX), amber[1])
			continue
		if target.get("between", false):
			var c: Vector2 = rect.get_center().snapped(Vector2(PX, PX))
			var r: float = (4 if hot else 3) * PX
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), amber[2] if hot else amber[0])
		else:
			if hot: Kit.notched(self, rect.grow(PX), Color(amber[0], 0.6), Color(0, 0, 0, 0))
			Kit.dashed(self, rect.grow(PX), amber[2] if hot else amber[1])
	var shown: Dictionary = draft
	var index: int = focus if focus == ATTACK else clampi(focus, 0, rows.size() - 1)
	if hovered.has("result"):
		shown = hovered["result"]
		index = int(hovered["where"]["routine"])
	_draw_panel(shown, index, hovered.has("result"))
	if not _held.is_empty():
		var key: String = _held["key"]
		# Carried below-right of the pointer, so the slot under it stays visible.
		var rect := Rect2((_mouse + Vector2(7, 6) * PX).snapped(Vector2(PX, PX)), Vector2(_node_width(key, ""), NODE_H))
		_draw_node({"rect": rect, "key": key, "slot": _held["slot"], "where": {}}, false, false)
	else:
		_draw_tooltip()

## The attack row: the weapon and its pieces on one wire, always live; pieces that add nothing are
## marked like an idle DO step.
func _draw_attack_row(board: Rect2, held_where: Dictionary) -> void:
	var top: float = _row_top(ATTACK)
	if focus == ATTACK:
		draw_rect(Rect2(ROWS_LEFT, top - 4 * PX, _tray_left() - ROWS_LEFT, ROW_H - 4 * PX), SELECTED)
	Kit.text(self, Vector2(ROWS_LEFT + 5 * PX, top), "A", Kit.RAMPS["tool"][2] if focus == ATTACK else Kit.FAINT)
	# A rule under the attack row: the routines below run on their own, the attack is the weapon.
	draw_rect(Rect2(ROWS_LEFT, top + ROW_H - 6 * PX, board.size.x, PX), Kit.LINE)
	var hit: Dictionary = Attack.profile(Build.attack_steps(draft), weapon)
	var chain: Array[Dictionary] = []
	for node: Dictionary in _nodes:
		if int(node["where"].get("routine", -9)) == ATTACK: chain.append(node)
	for i: int in chain.size():
		var node: Dictionary = chain[i]
		var rect: Rect2 = node["rect"]
		var is_step: bool = node["slot"] == "step" and node["key"] != ""
		var idle: bool = is_step and hit["trace"][int(node["where"]["index"])]["idle"]
		if i > 0:
			var before: Rect2 = chain[i - 1]["rect"]
			_wire(Vector2(before.end.x, top + NODE_H * 0.5), Vector2(rect.position.x, top + NODE_H * 0.5), true, ACCENT[node["slot"]] if node["slot"] != "weapon" else "do", focus == ATTACK)
		_draw_node(node, idle, node["where"] == held_where and not held_where.is_empty())

func _draw_cables(rows: Array) -> void:
	for ri: int in rows.size():
		var routine: Dictionary = rows[ri]
		if routine["then"] == "cadena":
			var target: int = Build.relay_target(rows, ri)
			var from: Dictionary = _row_node(ri, "then")
			var to: Dictionary = _row_node(target, "water") if target >= 0 else {}
			var deaf: bool = target >= 0 and (rows[target]["then"] == "" or rows[target].get("on", "contact") != "pulse")
			if not from.is_empty() and not to.is_empty(): _cable(from["rect"], to["rect"], "cadena", target > ri, deaf)
		if routine["when"] == "eco" and ri > 0:
			var from: Dictionary = _row_node(ri - 1, "water")
			var to: Dictionary = _row_node(ri, "when")
			if not from.is_empty() and not to.is_empty(): _cable(from["rect"], to["rect"], "eco", true)

## The piece under the mouse: its name and a few words, on a small plate by the pointer.
func _draw_tooltip() -> void:
	if _reaction_button.has_point(_mouse):
		var at: Vector2 = _reaction_button.position - Vector2(0, 17 * PX)
		var message: String = "Clic: contacto / rotura / 2 s / pulso"
		at.x = minf(at.x, size.x - Kit.width(message) - 10 * PX)
		Kit.notched(self, Rect2(at, Vector2(Kit.width(message) + 10 * PX, 14 * PX)), Kit.FILL_HI, Kit.ramp("then")[1])
		Kit.text(self, at + Vector2(5 * PX, 0), message, Kit.TEXT)
		return
	var node: Dictionary = _node_at(_mouse)
	if node.is_empty(): return
	var key: String = node["key"]
	var accent: String = ACCENT[node["slot"]]
	var name: String = _label_of(key)
	var short: String = Build.SHORT.get(key, "")
	var where: Dictionary = node["where"]
	if where.get("slot", "") == "step" and int(where.get("routine", -1)) == ATTACK:
		short = Attack.profile(Build.attack_steps(draft), weapon)["trace"][where["index"]]["text"]
	elif where.get("slot", "") == "step" and int(where.get("routine", -1)) >= 0:
		var trace: Array = Recipe.simulate(draft["routines"][where["routine"]]["steps"], draft["routines"][where["routine"]].get("from", "water"))["trace"]
		short = trace[where["index"]]["text"]
	var w: float = maxf(Kit.width(name) + 18 * PX, Kit.width(short) + 10 * PX)
	var at := (_mouse + Vector2(8, 10) * PX).snapped(Vector2(PX, PX))
	at.x = minf(at.x, size.x - w)
	var rect := Rect2(at, Vector2(w, 26 * PX))
	Kit.notched(self, rect, Kit.FILL_HI, Kit.ramp(accent)[1])
	_icon(key, at + Vector2(3, 1) * PX)
	Kit.text(self, at + Vector2(16 * PX, 0), name, Kit.ramp(accent)[2])
	Kit.text(self, at + Vector2(5 * PX, 12 * PX), short, Kit.TEXT)

# --- Drawing: the box and the problems ------------------------------------------------------

## The box: a dark tray right of the attack row with its word in front, the loose pieces in it.
## While a placed piece is in hand it says where to put it back; a new piece is told apart by its
## amber edge alone.
func _draw_tray() -> void:
	var tray: Rect2 = _box_area
	draw_rect(tray, PLATE)
	Kit.text(self, Vector2(tray.position.x - 6 * PX, tray.position.y + 2 * PX), "caja", Kit.DIM, 1, HORIZONTAL_ALIGNMENT_RIGHT)
	var note: String = ""
	var color: Color = Kit.FAINT
	if not _held.is_empty() and int(_held["where"]["routine"]) != -1:
		note = "suéltala aquí para guardarla"
		color = Kit.RAMPS["tool"][2]
	elif draft["box"].is_empty():
		note = "vacía"
	if note == "": return
	# After the last chip on its line, or on the next line when it does not fit there.
	var at := tray.position + Vector2(4, 2) * PX
	for node: Dictionary in _nodes:
		if node.get("chip", false):
			var rect: Rect2 = node["rect"]
			at = Vector2(rect.end.x + 5 * PX, rect.position.y + PX)
	if at.x + Kit.width(note) > tray.end.x - 3 * PX: at = Vector2(tray.position.x + 4 * PX, at.y + CHIP_PITCH.y)
	if at.y + 12 * PX <= tray.end.y + 2 * PX: Kit.text(self, at - Vector2(0, PX), note, color)

## Where the attack row's highlight stops, short of the box's word.
func _tray_left() -> float:
	return _box_area.position.x - Kit.width("caja") - 14 * PX

## Splits `value` into lines no wider than `room`.
static func _wrap(value: String, room: float) -> Array[String]:
	var lines: Array[String] = []
	var current: String = ""
	for word: String in value.split(" ", false):
		var next: String = word if current == "" else current + " " + word
		if current != "" and Kit.width(next) > room:
			lines.append(current)
			current = word
		else: current = next
	if current != "": lines.append(current)
	return lines

## Like _wrap, but never leaves one word alone on the last line when a narrower measure with
## the same number of lines avoids it.
static func _wrap_even(value: String, room: float) -> Array[String]:
	var lines: Array[String] = _wrap(value, room)
	if lines.size() < 2 or lines[-1].contains(" "): return lines
	var narrower: float = room
	while narrower > room * 0.6:
		narrower -= 6 * PX
		var tried: Array[String] = _wrap(value, narrower)
		if tried.size() > lines.size(): break
		if tried[-1].contains(" "): return tried
	return lines

## Draws `value` at (x, y) wrapped to `room`, whole or not at all: never cut short. Returns the
## y of the next entry, which is `y` itself when it did not fit in `max_lines` above `bottom`.
func _say(x: float, y: float, value: String, room: float, colour: Color, bottom: float, max_lines: int = 2) -> float:
	var lines: Array[String] = _wrap_even(value, room)
	if lines.is_empty() or lines.size() > max_lines or y + (lines.size() - 1) * 12 * PX + 12 * PX > bottom: return y
	for i: int in lines.size(): Kit.text(self, Vector2(x, y - PX + i * 12 * PX), lines[i], colour)
	return y + (lines.size() - 1) * 12 * PX + READ_LINE

## What a matter does on touch, as the read-out says it: the first clause, no «label:» in front,
## and the mass rule in words.
static func _plain_touch(touch: String) -> String:
	if touch.begins_with("golpea según masa"): return "golpea más fuerte cuanto más pesa y más rápido va"
	# The yard's hazards: the first one is enough to say the matter sets them off.
	if touch.begins_with("en el patio: "): return touch.get_slice(", ", 0)
	var clause: String = touch.get_slice(";", 0)
	var colon: int = clause.find(": ")
	if colon > 0 and clause.left(colon).split(" ").size() <= 2: clause = clause.substr(colon + 2)
	return clause

## The width of a space in the UI font: the gap between a row of state glyphs and their word.
static func _space() -> float:
	return Kit.width("a b") - Kit.width("ab")

## A row's problem is only its break mark after the last piece; the read-out says what it is
## when the row is the one being read.
func _draw_row_issue(x: float, top: float) -> void:
	_break_mark(Vector2(x + 3 * PX, top + 7 * PX))

# --- Drawing: the read-out ------------------------------------------------------------------

## The routine read out under the rows: its preview on a small screen, then what it is (WHEN,
## what is left, what that does to what it touches) and what it ends in (THEN, where a pulse
## goes, what is wrong). While a piece hovers over a slot it reads the routine as it would be.
func _draw_panel(build: Dictionary, index: int, proposed: bool) -> void:
	_reaction_button = Rect2()
	var top: float = _panel_top() + 6 * PX
	var height: float = roundf(clampf(size.y - top, 4 * READ_LINE, READOUT_MAX) / PX) * PX
	var screen := Rect2(Vector2(ROWS_LEFT, top), Vector2(roundf(minf(SCREEN_W, size.x * 0.32) / PX) * PX, height))
	var x: float = screen.end.x + 10 * PX
	var bottom: float = top + height
	if index == ATTACK:
		_draw_attack_panel(build, screen, x, bottom, proposed)
		return
	_draw_screen(screen, build, index)
	var routine: Dictionary = build["routines"][index]
	var col_w: float = floorf((size.x - x) * 0.58 / PX) * PX
	var x2: float = x + col_w
	var room: float = col_w - 10 * PX
	var y: float = top + PX
	var cx: float = x
	if proposed:
		Kit.text(self, Vector2(x, y - PX), "Así quedaría la rutina %d" % (index + 1), Kit.TEXT)
		y += READ_LINE
	if routine["when"] == "":
		_break_mark(Vector2(cx + 3 * PX, y + 6 * PX))
		Kit.text(self, Vector2(cx + 9 * PX, y - PX), Build.problem(routine), ISSUE)
		y += READ_LINE
		Kit.text(self, Vector2(x, y - PX), "arrastra uno desde la caja a su primer hueco", Kit.DIM)
		return
	var result: Dictionary = Recipe.simulate(routine["steps"], routine.get("from", "water"))
	var state: Dictionary = result["state"]
	# WHEN and how often.
	_icon(routine["when"], Vector2(cx, y))
	Kit.text(self, Vector2(cx + 15 * PX, y - PX), _label_of(routine["when"]), Kit.RAMPS["when"][2])
	cx += 15 * PX + Kit.width(_label_of(routine["when"])) + 8 * PX
	var cadence: String = "recarga %s s" % Recipe._num(snappedf(Build.cooldown(build, index), 0.1))
	if routine["when"] == "eco": cadence = ("justo después de la rutina %d" % index) if index > 0 else "sin rutina arriba"
	Kit.text(self, Vector2(cx, y - PX), cadence, Kit.DIM)
	y += READ_LINE
	# What is left: marks and the matter's two words.
	var end: float = _props(Vector2(x + PX, y + 3 * PX), state)
	var left_x: float = maxf(end + _space(), x + 15 * PX)
	var after: float = _say(left_x, y, Recipe.matter_text(state), x + room - left_x, Kit.TEXT, bottom)
	y = after if after != y else y + READ_LINE
	# What it does to what it touches, first clause of each.
	# Each whole, on up to two lines; one that does not fit is left out, never cut.
	for touch: String in Rules.touch(state):
		var line: String = _plain_touch(touch)
		var next_y: float = _say(x + 15 * PX, y, line, room - 15 * PX, Kit.DIM, bottom)
		if next_y == y: next_y = _say(x + 15 * PX, y, line.get_slice(",", 0), room - 15 * PX, Kit.DIM, bottom, 1)
		if next_y == y: continue
		_icon("arco" if state["charge"] > 0 else "frio" if state["temp"] < 0 else "fuego", Vector2(x, y), "mute")
		y = next_y
	# The second column: the THEN and its moment (a click changes the moment), then the rest.
	y = top + PX
	var room2: float = size.x - x2 - 4 * PX
	if routine["then"] != "":
		var moment: String = Recipe.moment(state, routine["then"], routine.get("on", "contact")).get_slice(" (", 0)
		# The moment is a plain-text control: «cambiar» after it, dim, amber under the mouse.
		var label: String = "%s %s" % [_label_of(routine["then"]), moment]
		var verb_x: float = x2 + 15 * PX + Kit.width(label) + 8 * PX
		_reaction_button = Rect2(x2, y - 2 * PX, verb_x + Kit.width("cambiar") + 2 * PX - x2, READ_LINE)
		var hot: bool = _held.is_empty() and _reaction_button.has_point(_mouse)
		_icon(routine["then"], Vector2(x2, y))
		Kit.text(self, Vector2(x2 + 15 * PX, y - PX), label, Kit.RAMPS["then"][2])
		Kit.text(self, Vector2(verb_x, y - PX), "cambiar", Kit.RAMPS["tool"][2] if hot else Kit.DIM)
		if hot: draw_rect(Rect2(verb_x, y + 11 * PX, Kit.width("cambiar"), PX), Kit.RAMPS["tool"][1])
		y += READ_LINE
		if routine["then"] != "cadena" and state["shape"] != "gone":
			y = _say(x2 + 15 * PX, y, Recipe.effect(state, routine["then"]), room2 - 15 * PX, Kit.DIM, bottom)
	if routine["then"] == "cadena":
		var target: int = Build.relay_target(build["routines"], index)
		_icon("cadena", Vector2(x2, y), "mute")
		Kit.text(self, Vector2(x2 + 15 * PX, y - PX), ("pulso a la rutina %d" % (target + 1)) if target >= 0 else "el pulso no llega a nada", Kit.DIM)
		y += READ_LINE
	if index + 1 < build["routines"].size() and build["routines"][index + 1]["when"] == "eco":
		_icon("eco", Vector2(x2, y), "mute")
		y = _say(x2 + 15 * PX, y, "al activarse dispara la rutina %d" % (index + 2), room2 - 15 * PX, Kit.DIM, bottom)
	# The problem: the row only marks it.
	var issue: String = Build.problem(routine, build["routines"], index)
	if issue != "":
		# The narrow column takes the short way of saying the relay one.
		issue = issue.replace("no hace nada con el pulso", "no reacciona")
		if _say(x2 + 15 * PX, y, issue, room2 - 15 * PX, ISSUE, bottom, 3) != y: _break_mark(Vector2(x2 + 5 * PX, y + 6 * PX))

## The attack read out: what one hit does on a loop on the screen, its numbers and each piece's
## line beside it, from attack.gd -- the same profile the host strikes with.
func _draw_attack_panel(build: Dictionary, screen: Rect2, x: float, bottom: float, proposed: bool) -> void:
	var steps: Array = Build.attack_steps(build)
	var hit: Dictionary = Attack.profile(steps, weapon)
	_draw_attack_screen(screen, hit)
	var y: float = screen.position.y + PX
	var room: float = size.x - x - 4 * PX
	var cx: float = x
	if proposed:
		Kit.text(self, Vector2(x, y - PX), "Así quedaría el ataque", Kit.TEXT)
		y += READ_LINE
	else:
		Kit.text(self, Vector2(x, y - PX), "Ataque", Kit.TEXT)
		cx = x + Kit.width("Ataque") + 8 * PX
	var tools: Dictionary = build.get("tools", {})
	var stats: Dictionary = Attack.WEAPON[weapon]
	var damage: float = float(stats["damage"]) + int(tools.get("power", 0)) * float(stats["power"])
	var every: float = float(stats["every"]) * pow(0.82, int(tools.get("cadence", 0)))
	_icon(WEAPON_ICON[weapon], Vector2(cx, y), WEAPON_ACCENT[weapon])
	Kit.text(self, Vector2(cx + 15 * PX, y - PX), "%s · %s de daño cada %s s" % [stats["name"], Recipe._num(snappedf(damage, 0.1)), ("%.2f" % every).replace(".", ",")], NEON[weapon])
	y += READ_LINE
	y = _say(x + 15 * PX, y, stats["text"], room - 15 * PX, Kit.DIM, bottom)
	if steps.is_empty():
		_say(x + 15 * PX, y, "sin DO, cada golpe es solo %s; caben %d en la fila A" % [stats["name"], Attack.MAX_STEPS], room - 15 * PX, Kit.DIM, bottom)
		return
	for entry: Dictionary in hit["trace"]:
		var next_y: float = _say(x + 15 * PX, y, entry["text"], room - 15 * PX, Kit.DIM if entry["idle"] else Kit.TEXT, bottom)
		if next_y == y: break
		_icon(entry["key"], Vector2(x, y), "mute" if entry["idle"] else "")
		y = next_y
	_say(x + 15 * PX, y, "lo extra cae en cada máquina una vez cada 0,5 s", room - 15 * PX, Kit.FAINT, bottom, 1)

## The preview's ground: the same flat dark plate as the box, no rim.
func _glass(rect: Rect2) -> void:
	draw_rect(rect, PLATE)

## One hit after another on a small pack walking in: the weapon's own matter, and what each piece
## adds -- heat or frost rings, a shove, the pack drawn in or thrown wide, a jump of charge,
## nanites, a patch left behind, a blow from above on the one that flies.
func _draw_attack_screen(rect: Rect2, hit: Dictionary) -> void:
	_glass(rect)
	# Closer in than a routine's screen: a weapon's reach is a few metres, and each hit has to read.
	var m := func(meters: float) -> float: return meters * 3.0 * PX * (2.4 if weapon == "fire" else 1.5)
	var mid: float = rect.position.y + rect.size.y * 0.56
	var me := Vector2(rect.position.x + 14 * PX, mid)
	var t: float = fmod(_time, LOOP)
	var fire: bool = weapon == "fire"
	var reach: float = m.call(float(Attack.WEAPON[weapon]["reach"]) + (3.0 if hit["aloft"] and not fire else 0.0))
	var colour: Color = NEON[weapon]
	if hit["temp"] >= 2: colour = SCALD if not fire else NEON["fire"].lightened(0.3)
	elif hit["temp"] < 0: colour = NEON["ice"]
	# The pack walks in; from when the first is in reach, the weapon fires every beat.
	var start: float = rect.end.x - 6 * PX - m.call(2.0)
	var lead_x: float = maxf(me.x + reach * 0.75, lerpf(start, me.x + reach * 0.75, clampf(t / 1.0, 0, 1)))
	var offsets: Array[Vector2] = [Vector2(0, 0), Vector2(m.call(1.6), -m.call(1.8)), Vector2(m.call(2.0), m.call(1.6))]
	var firing: bool = t > 1.0 and t < LOOP - 0.5
	var shots: int = int((t - 1.0) / 0.5) + 1 if firing else 0
	var kick: float = 0.0
	var spread: float = 1.0
	if firing:
		kick = minf(shots, 4) * hit["knock"] * 3.0 + (minf(shots, 4) * 4.0 if hit["scatter"] else 0.0)
		if hit["gather"]: spread = maxf(0.35, 1.0 - shots * 0.18)
		if hit["scatter"]: spread = minf(2.2, 1.0 + shots * 0.3)
	var lead := Vector2(lead_x + kick, mid)
	var pack: Array[Vector2] = []
	for offset: Vector2 in offsets: pack.append(lead + offset * spread)
	# A flyer overhead: only a raised weapon reaches it; a ball dropped on it brings it down.
	var flyer := Vector2(lead_x + 4, mid - 26)
	var downed: bool = hit["slam"] and firing and t - 1.0 >= Attack.FALL_TIME
	if downed: flyer.y = mid - 4
	var shot_t: float = fmod(t - 1.0, 0.5) if firing else 1.0
	var hot: bool = shot_t < 0.18
	if firing and hot:
		var aim: Vector2 = pack[0]
		if fire:
			for i: int in 5:
				var fan: float = (i - 2) * 0.12
				var tip: Vector2 = me + Vector2.from_angle(fan) * minf(reach, aim.distance_to(me) + 6)
				draw_line(me, tip, colour, PX)
			if hit["aloft"]: draw_line(me, flyer, colour, PX)
		else:
			var p: Vector2 = me.lerp(aim, clampf(shot_t / 0.18, 0, 1))
			draw_circle(p, 2 * PX, colour)
			if hit["aloft"]: draw_circle(me.lerp(flyer, clampf(shot_t / 0.18, 0, 1)), 2 * PX, colour)
	if firing and not hot and not fire and shot_t < 0.4:
		draw_arc(pack[0], m.call(2.0) * clampf((shot_t - 0.18) / 0.2, 0, 1), 0, TAU, 24, colour, PX)
	# Wall: what the weapon leaves on the floor where it struck.
	if hit["trail"] and shots >= 2:
		_matter(Vector2(lead_x + 2, mid), {"material": weapon if weapon == "water" else "fire", "shape": "patch", "scald": false, "hard": false, "coat": 0, "charge": 0, "well": false, "repel": false}, t)
	# The machines, with what the hits left on them.
	var struck: bool = firing and shots >= 1
	for i: int in pack.size():
		var body: Vector2 = pack[i]
		_machine(body, firing and hot and i == 0)
		if not struck: continue
		if hit["temp"] != 0: draw_arc(body, 6 * PX * 0.5 + 2, 0, TAU, 12, HOT_RING if hit["temp"] > 0 else NEON["ice"], PX)
		if weapon == "water" and hit["temp"] <= 0: draw_rect(Rect2(body + Vector2(-3, 6), Vector2(6, PX)), NEON["water"])
		if hit["coat"] > 0:
			for k: int in 3 * hit["coat"]:
				var angle: float = k * TAU / (3 * hit["coat"]) + t * 2.0
				draw_rect(Rect2((body + Vector2(cos(angle), sin(angle)) * 8.0).snapped(Vector2(PX, PX)), Vector2(PX, PX)), BRASS)
	if struck and hit["charge"] > 0 and hot:
		for i: int in mini(hit["charge"], pack.size() - 1): _zap(pack[i], pack[i + 1], t)
	# Drop: a ball goes up from the operator and comes down on the lead, its shadow under it and
	# its reach dashed on the floor, then the ring where it hit.
	if hit["slam"] and firing:
		var phase: float = fmod(t - 1.0, Attack.FALL_EVERY)
		var spot := Vector2(lead_x + 2, mid)
		var top: Vector2 = spot - Vector2(0, minf(m.call(Attack.FALL_HEIGHT), spot.y - rect.position.y - 6 * PX))
		var reach_px: float = m.call(Attack.FALL_RADIUS)
		if phase < Attack.FALL_TIME:
			var k: float = phase / Attack.FALL_TIME
			var ball: Vector2 = me.lerp(top, k * 3.0) if k < 1.0 / 3.0 else top.lerp(spot, pow((k - 1.0 / 3.0) * 1.5, 2.0))
			if k < 1.0 / 3.0: draw_line(me, top, Color(colour, 0.5), PX)
			for i: int in 12: draw_arc(spot, reach_px, i * TAU / 12, i * TAU / 12 + TAU / 24, 3, colour, PX)
			draw_circle(spot, (2.0 + k * 2.0) * PX, Color(0, 0, 0, 0.3 + 0.3 * k))
			draw_circle(ball.snapped(Vector2(PX, PX)), 3 * PX, colour)
		elif phase < Attack.FALL_TIME + 0.25:
			draw_arc(spot, reach_px * (phase - Attack.FALL_TIME) / 0.25, 0, TAU, 24, colour, PX)
	if not downed: draw_circle(flyer + Vector2(0, 26), 3, Color(0, 0, 0, 0.6))
	_machine(flyer, firing and hot and hit["aloft"])
	_operator(me)
	var title: String = Attack.WEAPON[weapon]["name"]
	if not hit["trace"].is_empty() and firing:
		var live: Array = hit["trace"].filter(func(entry: Dictionary) -> bool: return not entry["idle"])
		if not live.is_empty():
			var entry: Dictionary = live[shots % live.size()]
			_icon(entry["key"], rect.position + Vector2(3, 3) * PX)
			title = _label_of(entry["key"])
	Kit.text(self, rect.position + Vector2(18 if firing and not hit["trace"].is_empty() else 4, 2) * PX, title, BLAST)

## The screen: the operator on the left, a machine coming in from the right, and the routine
## happening between them on a loop. Distances are to scale (4 UI pixels a metre); the WHEN's reach is a ring on the floor.
func _draw_screen(rect: Rect2, build: Dictionary, index: int) -> void:
	_glass(rect)
	var routine: Dictionary = build["routines"][index]
	var mid: float = rect.position.y + rect.size.y * 0.5
	var me := Vector2(rect.position.x + 40 * PX, mid)
	var t: float = fmod(_time, LOOP)
	var me_fired: Vector2 = me
	if routine["when"] == "rastro":
		# Walking: the matter is left behind where the operator was when it fired.
		me_fired.x += 1.2 * 18.0
		me.x += minf(t, 1.2) * 18.0
	var title: String = ""
	if routine["when"] == "":
		_operator(me)
		return
	var from: String = routine.get("from", "water")
	var result: Dictionary = Recipe.simulate(routine["steps"], from)
	var trace: Array = result["trace"]
	var when: String = routine["when"]
	var m := func(meters: float) -> float: return meters * PX_PER_M
	# Where the machine stands when the routine fires, and where the matter lands.
	var trigger_at := Vector2(me.x + m.call(9.0), mid)
	var place := Vector2(me.x + m.call(3.1), mid)
	var ghost := Vector2.INF
	match when:
		"cada":
			trigger_at = Vector2(me.x + m.call(12.0), mid)
			place = trigger_at
		"rastro":
			place = Vector2(me_fired.x - m.call(1.6), mid)
			trigger_at = Vector2(me.x + m.call(14.0), mid)
		"grupo":
			trigger_at = Vector2(me.x + m.call(11.0), mid)
			place = trigger_at
		"herido":
			trigger_at = Vector2(me.x + m.call(0.9), mid)
			place = Vector2(me.x + m.call(1.8), mid)
		"eco":
			ghost = Vector2(me.x + m.call(3.1), mid)
			place = ghost + Vector2(m.call(2.5), 0)
		"derribo":
			trigger_at = Vector2(me.x + m.call(14.0), mid)
			place = Vector2(me.x + m.call(7.0), mid)
		"charco":
			trigger_at = Vector2(me.x + m.call(8.0), mid)
			place = trigger_at
		"mano":
			trigger_at = Vector2(me.x + m.call(8.0), mid)
			place = trigger_at
	var start_x: float = rect.end.x - 10
	# Phase times: approach, build (one beat per step), then the reaction.
	var fired: float = 1.2
	var beat: float = 0.42
	var built: float = fired + 0.35 + trace.size() * beat
	var state: Dictionary = Recipe.source(from)
	var shown_step: int = -1
	if t >= fired + 0.35:
		shown_step = mini(int((t - fired - 0.35) / beat), trace.size() - 1)
		state = trace[shown_step]["state"] if shown_step >= 0 else state
	var final: Dictionary = result["state"]
	# The machine: approaching, then reacting to what the matter does to it.
	var machine := Vector2(lerpf(start_x, trigger_at.x, clampf(t / fired, 0, 1)), mid)
	var blocked_x: float = INF
	if t > fired:
		var walk: float = (t - fired) * m.call(1.9)
		machine.x = trigger_at.x - walk
		if final["shape"] == "wall" and final["material"] in ["ice", "scrap"] and t > built and machine.x < place.x + 7:
			machine.x = place.x + 7
			blocked_x = machine.x
		machine.x = maxf(machine.x, me.x + 8)
		# A whirl takes the machine round its ring, then lets it fly off along it; the preview's loop
		# is shorter than the well's five seconds, so the letting go is shown near its end.
		if state["well"] and t > built and machine.distance_to(place) < m.call(Recipe.WELL_RADIUS):
			var on_ring: Callable = func(angle: float) -> Vector2: return place + Vector2(cos(angle), sin(angle) * 0.5) * m.call(Catalog.VORTEX_RING)
			var start_angle: float = (machine - place).angle()
			var turn_rate: float = Catalog.ORBIT_SPEED / Catalog.VORTEX_RING
			var let_go: float = LOOP - 0.9
			if t < let_go: machine = machine.lerp(on_ring.call(start_angle - (t - built) * turn_rate), clampf((t - built) / 0.4, 0.0, 1.0))
			else:
				var angle: float = start_angle - (let_go - built) * turn_rate
				var along := Vector2(sin(angle), -cos(angle) * 0.5).normalized()
				machine = on_ring.call(angle) + along * (t - let_go) * m.call(9.0)
		# A wave throws it out past the bubble, and it stays outside.
		if state["repel"] and t > built and absf(machine.x - place.x) < m.call(Recipe.REPEL_RADIUS):
			machine.x = maxf(machine.x, place.x + m.call(Catalog.BUBBLE) + m.call(Recipe.REPEL_RADIUS - Catalog.BUBBLE) * clampf((t - built) / 0.6, 0.0, 1.0))
	# The matter's moment and its THEN.
	var then: String = routine["then"]
	var moment_at: float = built + (Recipe.REACTION_DELAY if routine.get("on", "contact") == "timer" else 0.5)
	if routine.get("on", "contact") == "pulse": moment_at = LOOP + 1.0
	if routine.get("on", "contact") == "broken" and final["material"] not in ["ice", "scrap"]: moment_at = LOOP + 1.0
	var crowd: Array[Vector2] = [machine]
	if when == "grupo":
		# A well draws the group in tight; a repulsor throws it wide.
		var spread: float = 1.6
		if t > built and state["repel"]: spread = minf(3.2, 1.6 + (t - built) * 2.6)
		crowd = [machine + Vector2(-6, -9) * spread, machine + Vector2(7, 2) * spread, machine + Vector2(-3, 10) * spread]
	# Where the matter comes from: a puddle (drum, transformer, heap) near the operator that runs to
	# the spot when the routine fires and shrinks by what it gave; for «on wade» with water, the
	# puddle the machine walks into.
	var wade: bool = when == "charco" and from == "water"
	var pool: Vector2 = place if wade else Vector2(me_fired.x + m.call(1.2), mid + m.call(4.0))
	var drawn: float = clampf((t - fired) / 0.35, 0.0, 1.0)
	if not wade or t < fired: _pool(pool, 1.0 - drawn * 0.45 if not wade else 1.0, from)
	if not wade and t >= fired and t < fired + 0.35:
		draw_line(pool.lerp(place, maxf(0.0, drawn * 1.6 - 0.6)), pool.lerp(place, minf(1.0, drawn * 1.6)), NEON[from], 2 * PX)
	# WHEN cue.
	# The trigger's reach as a ring on the ground, at the camera's pitch.
	if when in ["cerca", "derribo"]: _ground_ring(me_fired, m.call(9.0 if when == "cerca" else 10.0), Color(Kit.RAMPS["when"][1], 0.7 if t < fired else 0.35))
	if when == "derribo" and t < fired:
		_cross(place, MACHINE)
	# On cue: the aim comes down where the player points, a beat before the matter.
	if when == "mano" and t > fired - 0.45 and t < fired + 0.2: _reticle(place)
	if when == "herido" and t > fired - 0.1 and t < fired + 0.25: draw_circle(me, 9, Color(MACHINE, 0.5))
	if ghost != Vector2.INF:
		draw_rect(Rect2(ghost - Vector2(3, 18), Vector2(6, 36)), Color(BLAST, 0.25), false, PX)
	# The matter, once the routine has fired.
	var gone: bool = false
	var effect_t: float = t - moment_at
	if t >= fired:
		var center: Vector2 = place
		if state["moving"] and shown_step >= 0:
			center.x += minf(t - (fired + 0.35 + trace.size() * beat - beat), 1.4) * m.call(2.2) * (1.0 if when != "rastro" else -1.0)
		if then != "" and effect_t > 0.0 and final["shape"] != "gone":
			gone = then in ["estallar", "colapso"] and final["material"] not in ["ice", "scrap"] and effect_t > 0.6 or then == "fragmentos" and final["material"] in ["water", "fire", "current"] and effect_t > 0.2
		if not gone:
			var drop_step: bool = shown_step >= 0 and trace[shown_step]["key"] == "drop" and t - (fired + 0.35 + shown_step * beat) < beat * 0.7
			var lift: float = 13.0 if state.get("suspended", false) else 0.0
			if state.get("suspended", false): draw_circle(center, 7, Color(0, 0, 0, 0.7))
			if drop_step: lift = (1.0 - (t - (fired + 0.35 + shown_step * beat)) / (beat * 0.7)) * 26.0
			var shard_state: Dictionary = state
			if then != "" and effect_t > 0.0 and final["material"] in ["ice", "scrap"] and then in ["fragmentos", "estallar", "colapso"]:
				shard_state = state.duplicate()
				shard_state["shape"] = "fragments"
			if then == "detonar" and effect_t > 0.0:
				shard_state = shard_state.duplicate()
				shard_state["coat"] = 0
			_matter(center - Vector2(0, lift), shard_state, t)
			# Conduction: a charged matter discharges into the machine that comes within reach.
			var reach: float = m.call(2.4 + (2.8 if final["material"] in ["water", "scrap"] else 0.0) + (5.0 if final["material"] == "current" else 0.0))
			if final["charge"] > 0 and t > built and machine.distance_to(center) < reach and fmod(t, 0.5) < 0.22: _zap(center, machine, t)
			# Ice waits to be broken: the machine hammers it just before the moment.
			if then != "" and routine.get("on", "contact") == "broken" and final["material"] in ["ice", "scrap"] and final["shape"] != "fragments" and effect_t > -0.5 and effect_t < 0.0 and fmod(t, 0.16) < 0.08:
				for i: int in 3: draw_line(center + Vector2(4, -6 + i * 6), center + Vector2(9, -8 + i * 6), BLAST, PX)
			if drop_step: draw_circle(center, 5, Color(0, 0, 0, 0.6))
			if then != "" and t > built: _armed(center, t)
		if then != "" and effect_t > 0.0 and final["shape"] != "gone":
			_effect(then, final, center, machine, rect, effect_t, build, index)
	# The machines, drawn last: hazard rose.
	for body: Vector2 in crowd:
		var flash: bool = then != "" and effect_t > 0.1 and effect_t < 0.45 and body.distance_to(place) < m.call(4.5)
		_machine(body, flash)
	if blocked_x != INF: draw_rect(Rect2(Vector2(blocked_x + 6, mid - 12), Vector2(PX, 24)), MACHINE)
	_operator(me)
	# What is happening, as the piece's glyph and name.
	var key: String = ""
	if t < fired: key = when
	elif t < built and shown_step >= 0: key = trace[shown_step]["key"]
	elif then != "" and effect_t > -0.5: key = then
	if key != "":
		_icon(key, rect.position + Vector2(3, 3) * PX, "mute" if t < built and shown_step >= 0 and trace[shown_step]["op"] == "" else "")
		title = _label_of(key)
	elif t < built: title = Recipe.FROM[from]
	else: title = Recipe.matter_text(final)
	Kit.text(self, rect.position + Vector2(18 if key != "" else 4, 2) * PX, title, BLAST)

## The player's aim on the floor: four corners round the spot, in the WHEN colour.
func _reticle(at: Vector2) -> void:
	var c: Color = Kit.RAMPS["when"][2]
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := at + Vector2(sx * 9, sy * 6)
			draw_rect(Rect2(corner - Vector2(maxf(0, sx) * 3, maxf(0, sy) * PX), Vector2(3, PX)), c)
			draw_rect(Rect2(corner - Vector2(maxf(0, sx) * PX, maxf(0, sy) * 3), Vector2(PX, 3)), c)

## A puddle seen from above: a flat dark ellipse with its neon rim, `amount` of a full draught.
func _pool(at: Vector2, amount: float, from: String = "water") -> void:
	var half := Vector2(9, 5) * sqrt(maxf(amount, 0.2))
	var points := PackedVector2Array()
	for i: int in 17: points.append(at + Vector2(cos(i * TAU / 16) * half.x, sin(i * TAU / 16) * half.y))
	draw_colored_polygon(points, Color(NEON[from].darkened(0.78), 0.9))
	draw_polyline(points, NEON[from], PX)
	# A drum's flames, a transformer's terminals, a heap's jagged top over the pool they stand in.
	match from:
		"fire":
			for i: int in 3: draw_line(at + Vector2(-4 + i * 4, -2), at + Vector2(-4 + i * 4 + sin(_time * 9.0 + i) * 2.0, -9 - (i % 2) * 3), NEON["fire"], PX)
		"current":
			draw_rect(Rect2(at - Vector2(4, 9), Vector2(8, 8)), GLASS)
			draw_rect(Rect2(at - Vector2(4, 9), Vector2(8, 8)), NEON["current"], false, PX)
			if fmod(_time, 0.6) < 0.2: draw_line(at + Vector2(-3, -10), at + Vector2(3, -13), SPARK, PX)
		"scrap":
			draw_polyline(PackedVector2Array([at + Vector2(-8, 0), at + Vector2(-4, -6), at + Vector2(0, -3), at + Vector2(3, -8), at + Vector2(8, 0)]), NEON["scrap"], PX)

## The operator on the preview, with the one word that says which dot is you.
func _operator(at: Vector2) -> void:
	var colour: Color = Kit.RAMPS["do"][2] if weapon == "water" else OPERATOR
	_dot(at, colour, 4)
	Kit.text(self, at + Vector2(-Kit.width("tú") - 4 * PX, -6 * PX), "tú", colour)

## A dashed circle on the yard floor seen at the game camera's 38° pitch.
func _ground_ring(center: Vector2, radius: float, colour: Color) -> void:
	var squash: float = sin(deg_to_rad(38.0))
	var dashes: int = maxi(12, int(radius * TAU / (6 * PX)))
	for i: int in dashes:
		var a: float = i * TAU / dashes
		var p := center + Vector2(cos(a) * radius, sin(a) * radius * squash)
		draw_rect(Rect2(p.snapped(Vector2(PX, PX)), Vector2(2 * PX, PX)), colour)

func _dot(at: Vector2, color: Color, radius: float) -> void:
	draw_circle(at, radius + 1, GLASS)
	draw_circle(at, radius, color)

func _cross(at: Vector2, color: Color) -> void:
	draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), color, PX)
	draw_line(at + Vector2(-4, 4), at + Vector2(4, -4), color, PX)

func _machine(at: Vector2, flash: bool) -> void:
	var body := Rect2((at - Vector2(5, 5)).snapped(Vector2(PX, PX)), Vector2(10, 10))
	draw_rect(body, GLASS)
	draw_rect(body, BLAST if flash else MACHINE, false, PX)
	draw_rect(Rect2(body.get_center() - Vector2(1, 1), Vector2(2, 2)), MACHINE)

## A dark mass with a 1 px neon edge, shaped by the state.
func _matter(at: Vector2, state: Dictionary, t: float) -> void:
	if state["shape"] == "gone": return
	var edge: Color = NEON[state["material"]]
	if state["scald"]: edge = SCALD
	var fill: Color = Color(edge.darkened(0.78), 0.92)
	match state["shape"]:
		"orb":
			draw_circle(at, 9, fill)
			draw_arc(at, 9, 0, TAU, 12 if state["material"] == "ice" else 32, edge, PX)
			if state["material"] == "water": draw_arc(at + Vector2(-1, -1), 6, t, t + PI, 16, edge, PX)
			else: draw_rect(Rect2((at + Vector2(-4, -4)).snapped(Vector2(PX, PX)), Vector2(2, 2) * PX), edge)  # a glint
		"patch":
			var points := _ellipse(at, Vector2(16, 11))
			draw_colored_polygon(points, fill)
			draw_polyline(points, edge, PX)
			if state["hard"]: draw_polyline(_ellipse(at, Vector2(12, 7)), edge, PX)
		"wall":
			var bar := Rect2(at - Vector2(3, 20), Vector2(6, 40))
			draw_rect(bar, fill)
			draw_rect(bar, edge, false, PX)
			if state["hard"]: draw_rect(bar.grow(2), edge, false, PX)
		"cloud":
			for offset: Vector2 in [Vector2(-7, 2), Vector2(6, 3), Vector2(0, -5)]:
				draw_circle(at + offset, 10, fill)
			for offset: Vector2 in [Vector2(-7, 2), Vector2(6, 3), Vector2(0, -5)]:
				draw_arc(at + offset, 10, 0, TAU, 20, edge, PX)
		"fragments":
			for i: int in 7:
				var angle: float = i * 0.9
				var p: Vector2 = at + Vector2(cos(angle), sin(angle)) * (5.0 + (i % 3) * 4.0)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 2), p + Vector2(-3, 2)]), edge)
	if state["coat"] > 0:
		for i: int in 4 * state["coat"]:
			var angle: float = i * TAU / (4 * state["coat"]) + t * 0.7
			draw_rect(Rect2((at + Vector2(cos(angle), sin(angle)) * 14.0).snapped(Vector2(PX, PX)), Vector2(PX, PX)), BRASS)
	if state["charge"] > 0 and fmod(t, 0.4) < 0.25:
		for i: int in state["charge"] + 1:
			var angle: float = i * 2.3 + floorf(t * 6.0)
			var p: Vector2 = (at + Vector2(cos(angle) * 15.0, sin(angle) * 9.0)).snapped(Vector2(PX, PX))
			draw_polyline(PackedVector2Array([p, p + Vector2(2, 3), p + Vector2(-1, 4), p + Vector2(1, 7)]), SPARK, PX)
	if state["well"] or state["repel"]: _gravity(at, state, t)

## A node's properties as 7x7 marks, left to right: temperature, charge, gravity, steam. Returns
## where they end.
func _props(at: Vector2, state: Dictionary) -> float:
	if state.is_empty() or state["shape"] == "gone": return at.x
	var marks: Array[String] = []
	if state["material"] == "water" or state["material"] == "ice": marks.append("mojado")
	if state["material"] == "steam": marks.append("vapor")
	if state["material"] == "fire" and state.get("fierce", false): marks.append("caliente")
	var temp: int = state["temp"]
	for i: int in absi(temp): marks.append("caliente" if temp > 0 else "frio")
	for i: int in int(state["charge"]): marks.append("carga")
	if state["grav"] > 0: marks.append("pozo")
	elif state["grav"] < 0: marks.append("repele")
	var x: float = at.x
	for mark: String in marks:
		draw_texture_rect(Kit.prop(mark), Rect2(Vector2(x, at.y), Vector2(7, 7) * PX), false)
		x += 6 * PX
	return x

## A 1 px arc from `from` to `to`, jittering.
func _zap(from: Vector2, to: Vector2, t: float) -> void:
	var points := PackedVector2Array([from])
	for i: int in range(1, 5):
		var along: Vector2 = from.lerp(to, i / 5.0)
		points.append(along + Vector2(0, sin(t * 53.0 + i * 2.1) * 4.0))
	points.append(to)
	draw_polyline(points, SPARK, PX)

func _ellipse(at: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in 21: points.append(at + Vector2(cos(i * TAU / 20) * radius.x, sin(i * TAU / 20) * radius.y))
	return points

## The yard's gravity at the preview's scale, on the same squashed floor as the matter: a well's
## arms winding in and the ring of its matter going round; a repulsor's front and bubble.
func _gravity(at: Vector2, state: Dictionary, t: float) -> void:
	var floor_ellipse := func(radius: float, from: float, to: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i: int in 13: points.append(at + Vector2(cos(lerpf(from, to, i / 12.0)), sin(lerpf(from, to, i / 12.0)) * 0.5) * radius)
		return points
	if state["well"]:
		var ring: float = Catalog.VORTEX_RING * PX_PER_M
		var turn: float = -t * Catalog.ORBIT_SPEED / Catalog.VORTEX_RING
		for arm: int in 3:
			var points := PackedVector2Array()
			for i: int in 9:
				var r: float = lerpf(Catalog.VORTEX_REACH * PX_PER_M, ring * 0.6, i / 8.0)
				var angle: float = turn * 0.5 + arm * TAU / 3.0 + i * 0.32
				points.append(at + Vector2(cos(angle), sin(angle) * 0.5) * r)
			draw_polyline(points, Color(GRAVITY, 0.55), PX)
		var tint: Color = NEON.get(state["material"], NEON["water"])
		for i: int in 6:
			var from: float = turn + i * TAU / 6.0
			draw_polyline(floor_ellipse.call(ring, from, from + 0.55), tint, PX * 2.0)
	if state["repel"]:
		var reach: float = Catalog.BLAST_REACH * PX_PER_M
		var front: float = fmod(t, 1.6) / 0.6
		if front < 1.0: draw_polyline(floor_ellipse.call(reach * front, 0.0, TAU), REPEL_TINT, PX * 2.0)
		for i: int in 12:
			var from: float = i * TAU / 12.0 + t * 0.4
			draw_polyline(floor_ellipse.call(Catalog.BUBBLE * PX_PER_M, from, from + 0.3), Color(REPEL_TINT, 0.8), PX)

## The armed mark: a small blinking tick over matter waiting for its THEN.
func _armed(at: Vector2, t: float) -> void:
	if fmod(t, 0.5) < 0.3: draw_rect(Rect2((at + Vector2(-2, -26)).snapped(Vector2(PX, PX)), Vector2(2, 2) * PX), Kit.RAMPS["then"][2])

## The THEN playing out from `at`, `elapsed` seconds after its moment.
func _effect(then: String, state: Dictionary, at: Vector2, machine: Vector2, rect: Rect2, elapsed: float, build: Dictionary, index: int) -> void:
	var grow: float = clampf(elapsed / 0.5, 0, 1)
	var fade: Color = Color(1, 1, 1, 1.0 - clampf((elapsed - 0.5) / 0.6, 0, 1))
	if state["coat"] > 0 and then == "detonar": draw_arc(at, Recipe.BURST_RADIUS * PX_PER_M * (1.2 + 0.3 * (state["coat"] - 1)) * grow, 0, TAU, 32, BRASS * fade, PX)
	match then:
		"fragmentos":
			match state["material"]:
				"ice":
					for i: int in 5:
						var spread: Vector2 = Vector2(0, (i - 2) * 3.0)
						var p: Vector2 = at.lerp(machine + spread, grow)
						draw_colored_polygon(PackedVector2Array([p + Vector2(3, 0), p + Vector2(-2, -2), p + Vector2(-2, 2)]), NEON["ice"] * fade)
				"scrap":
					for i: int in 5:
						var spread: Vector2 = Vector2(0, (i - 2) * 3.0)
						var p: Vector2 = at.lerp(machine + spread, grow)
						draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 2)), NEON["scrap"] * fade)
				"current": if grow < 1.0: _zap(at, machine, elapsed)
				"fire":
					for i: int in 10:
						var p: Vector2 = at + Vector2.from_angle(i * TAU / 10 + 0.3) * Recipe.SPLASH_RADIUS * PX_PER_M * grow
						draw_rect(Rect2(p, Vector2(PX, PX)), NEON["fire"] * fade)
				"water": draw_arc(at, Recipe.SPLASH_RADIUS * PX_PER_M * grow, 0, TAU, 32, NEON["water"] * fade, PX)
				"steam": draw_arc(at, Recipe.SPLASH_RADIUS * PX_PER_M * grow, 0, TAU, 32, SCALD * fade, PX)
		"estallar":
			draw_arc(at, Recipe.BURST_RADIUS * PX_PER_M * grow, 0, TAU, 32, NEON[state["material"]] * fade, PX)
		"detonar":
			if state["coat"] > 0: draw_arc(at, Recipe.BURST_RADIUS * PX_PER_M * grow, 0, TAU, 32, BRASS * fade, PX)
		"colapso":
			if elapsed < 0.6:
				for i: int in 8:
					var dir := Vector2.from_angle(i * TAU / 8)
					var r: float = Recipe.WELL_RADIUS * PX_PER_M * (1.0 - elapsed / 0.6)
					draw_line(at + dir * r, at + dir * maxf(r - 8, 0), GRAVITY, PX)
			else:
				draw_arc(at, Recipe.BURST_RADIUS * PX_PER_M * clampf((elapsed - 0.6) / 0.4, 0, 1), 0, TAU, 32, BLAST * fade, PX)
		"cadena":
			var target: int = Build.relay_target(build["routines"], index)
			var box := Rect2(rect.end - Vector2(34, 16) * PX, Vector2(30, 13) * PX)
			Kit.notched(self, box, GLASS, LINK)
			Kit.text(self, box.position + Vector2(4, 0) * PX, ("→ %d" % (target + 1)) if target >= 0 else "→ ·", LINK)
			if target >= 0:
				var p: Vector2 = at.lerp(box.get_center(), clampf(elapsed / 0.7, 0, 1))
				draw_line(at, p, Color(LINK, 0.6), PX)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), BLAST)
