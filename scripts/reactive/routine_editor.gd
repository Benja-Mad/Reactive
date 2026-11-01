## The routine editor: the program laid out as the pipe it is -- source, up to four steps, then
## the one-shot reaction -- with every card answering click (next), right click (previous) and
## the wheel. It reads the routine back to the player before it runs: the step that will stop
## it is marked, and a sentence says what will happen. Combat continues while it is open.
extends Control

const Style = preload("res://scripts/reactive/console_style.gd")
const Model = preload("res://scripts/reactive/routine_model.gd")
const Catalog = preload("res://scripts/matter/materials.gd")
const STEP_CYCLE := ["", "raise", "wall", "freeze", "heat", "coat", "impact", "push", "drop"]
const PANEL := Vector2(1080, 318)
const CARD := Vector2(112, 104)

var console: Node
var _regions: Array[Dictionary] = []
var _hover: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	size = PANEL

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func place(view: Vector2) -> void:
	size = PANEL
	# Top of the screen: the diorama camera keeps the player in the lower half, and combat goes on
	# while the editor is open. Clear of the status plate on the left.
	position = Vector2(maxf((view.x - PANEL.x) * 0.5, 444.0), 24.0)

func _region(rect: Rect2, kind: String, index: int = 0) -> bool:
	_regions.append({"rect": rect, "kind": kind, "index": index})
	return _hover == _regions.size() - 1

func _draw() -> void:
	if console == null: return
	_regions.clear()
	var draft: Dictionary = console.current_draft()
	var simulation: Dictionary = Model.simulate(draft)
	var frame := Rect2(Vector2.ZERO, PANEL)
	Style.plate(self, frame, Color(0.04, 0.045, 0.048, 0.96), Style.BRASS_DIM, 14.0)
	Style.clamps(self, frame.grow(-4))
	# Header: which routine, what it is called, the three slots.
	Style.text(self, Vector2(28, 38), "RUTINA %02d" % (console.current_slot + 1), 14, Style.TEXT_DIM, Style.mono())
	Style.text(self, Vector2(128, 39), Model.name_of(draft), 24, Style.SODIUM)
	for i: int in console.slots.size():
		var tab := Rect2(PANEL.x - 150 + i * 40, 20, 32, 24)
		var active: bool = i == console.current_slot
		var hot: bool = _region(tab, "slot", i)
		draw_rect(tab, Style.BRASS if active else (Style.PLATE_HI if hot else Style.INK))
		draw_rect(tab, Style.BRASS if active or hot else Style.BRASS_DIM, false, 1.0)
		Style.text(self, Vector2(tab.position.x, tab.position.y + 17), "%02d" % (i + 1), 13, Style.INK if active else Style.TEXT, Style.mono(), HORIZONTAL_ALIGNMENT_CENTER, tab.size.x)
	draw_line(Vector2(24, 54), Vector2(PANEL.x - 24, 54), Color(1, 1, 1, 0.06), 1.0)
	# The pipe.
	var steps: Array = draft["steps"]
	var x: float = 28.0
	var y: float = 72.0
	_card(Rect2(x, y, CARD.x, CARD.y), "water", "AGUA", "ORIGEN", Style.SPINE, false, false, "")
	x += CARD.x + 22
	for i: int in 4:
		var rect := Rect2(x, y, CARD.x, CARD.y)
		var exists: bool = i < steps.size()
		var addable: bool = i == steps.size()
		if exists or addable:
			var hot: bool = _region(rect, "step", i)
			var failing: bool = i == simulation["failed"]
			var after_fail: bool = simulation["failed"] >= 0 and i > simulation["failed"]
			if exists:
				_card(rect, steps[i], Model.STEP_NAMES[steps[i]], "PASO %d" % (i + 1), Style.FAULT if failing else (Style.TEXT_DIM if after_fail else Style.TEXT), hot, failing, "")
			else:
				_card(rect, "empty", "AÑADIR", "PASO %d" % (i + 1), Style.BRASS_DIM, hot, false, "dashed")
		else:
			_card(rect, "", "", "", Style.TEXT_DIM, false, false, "void")
		_connector(Vector2(x - 22, y + CARD.y * 0.5), Vector2(x, y + CARD.y * 0.5), exists or addable)
		x += CARD.x + 22
	# Separator between what is built and what is armed.
	draw_line(Vector2(x - 8, y - 6), Vector2(x - 8, y + CARD.y + 6), Style.BRASS_DIM, 1.0)
	draw_line(Vector2(x - 4, y - 6), Vector2(x - 4, y + CARD.y + 6), Style.BRASS_DIM, 1.0)
	x += 10
	var wide := Vector2(150, CARD.y)
	var reaction_bad: bool = simulation["reaction_problem"] != ""
	var trigger_rect := Rect2(x, y, wide.x, wide.y)
	_card(trigger_rect, draft["trigger"], Model.TRIGGER_NAMES[draft["trigger"]], "CUANDO", Style.SODIUM, _region(trigger_rect, "trigger"), false, "")
	_connector(Vector2(trigger_rect.end.x, y + CARD.y * 0.5), Vector2(trigger_rect.end.x + 22, y + CARD.y * 0.5), true)
	var action_rect := Rect2(trigger_rect.end.x + 22, y, wide.x, wide.y)
	_card(action_rect, draft["action"], Model.ACTION_NAMES[draft["action"]], "ENTONCES · UNA VEZ", Style.FAULT if reaction_bad else Style.SODIUM, _region(action_rect, "action"), reaction_bad, "")
	# The program read back as a sentence, then whatever will stop it.
	var line_y: float = y + CARD.y + 34
	Style.text(self, Vector2(28, line_y), Model.describe(draft), 16, Style.TEXT, null, HORIZONTAL_ALIGNMENT_LEFT, PANEL.x - 56)
	var warning: String = ""
	if simulation["failed"] >= 0: warning = "SE DETENDRÁ EN EL PASO %d · %s" % [simulation["failed"] + 1, simulation["reason"].to_upper()]
	elif reaction_bad: warning = "LA REACCIÓN NO TENDRÁ EFECTO · " + simulation["reaction_problem"].to_upper()
	if warning != "":
		draw_rect(Rect2(28, line_y + 12, 3, 18), Style.FAULT)
		Style.text(self, Vector2(40, line_y + 27), warning, 14, Style.FAULT)
	else:
		Style.text(self, Vector2(28, line_y + 27), "LOS PASOS SE RESUELVEN CADA 0,18 s · LA MATERIA YA CREADA PERMANECE SI ALGO FALLA", 12, Style.TEXT_DIM)
	# Controls along the foot.
	var foot_y: float = PANEL.y - 54
	var chain_rect := Rect2(28, foot_y, 250, 34)
	_button(chain_rect, "chain", "ENCADENAR CON LA ANTERIOR", draft.get("chain", false), _region(chain_rect, "chain"))
	var bind_rect := Rect2(292, foot_y, 330, 34)
	var can_bind: bool = not console.selected_record().is_empty()
	_button(bind_rect, draft["trigger"], "ARMAR ESTA REACCIÓN EN LA SELECCIÓN" if can_bind else "SIN REFERENCIA PARA ARMAR", false, _region(bind_rect, "bind") and can_bind, not can_bind)
	var save_rect := Rect2(PANEL.x - 232, foot_y, 204, 34)
	_button(save_rect, "", "GUARDAR Y VOLVER  [E]", true, _region(save_rect, "save"))

func _card(rect: Rect2, glyph: String, title: String, caption: String, color: Color, hot: bool, fault: bool, style: String) -> void:
	if style == "void":
		Style.dashed(self, rect.position + Vector2(0, rect.size.y * 0.5), rect.position + Vector2(rect.size.x, rect.size.y * 0.5), Color(1, 1, 1, 0.06))
		return
	var fill: Color = Style.PLATE_HI if hot else Style.PLATE
	if style == "dashed":
		draw_rect(rect, Color(fill, 0.5))
		for edge: Array in [[rect.position, rect.position + Vector2(rect.size.x, 0)], [rect.position + Vector2(0, rect.size.y), rect.end],
				[rect.position, rect.position + Vector2(0, rect.size.y)], [rect.position + Vector2(rect.size.x, 0), rect.end]]:
			Style.dashed(self, edge[0], edge[1], Style.BRASS if hot else Style.BRASS_DIM, 4.0)
	else:
		Style.plate(self, rect, fill, Style.FAULT if fault else (Style.BRASS if hot else Style.BRASS_DIM), 8.0, 2.0 if hot or fault else 1.0)
	Style.text(self, rect.position + Vector2(10, 18), caption, 10, Style.TEXT_DIM, Style.mono())
	Style.glyph(self, glyph, rect.position + Vector2(rect.size.x * 0.5, 50), 17, color, 2.2)
	Style.text(self, Vector2(rect.position.x, rect.end.y - 12), title, 15, color, null, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)

func _connector(from: Vector2, to: Vector2, live: bool) -> void:
	var color: Color = Style.BRASS if live else Color(1, 1, 1, 0.06)
	draw_line(from, to, color, 1.5)
	if live:
		draw_colored_polygon(PackedVector2Array([to, to + Vector2(-6, -4), to + Vector2(-6, 4)]), color)

func _button(rect: Rect2, glyph: String, label: String, active: bool, hot: bool, disabled: bool = false) -> void:
	var edge: Color = Style.BRASS if (active or hot) and not disabled else Style.BRASS_DIM
	Style.plate(self, rect, Style.PLATE_HI if hot else Style.INK, edge, 7.0)
	var x: float = rect.position.x + 14
	if glyph != "":
		Style.glyph(self, glyph, Vector2(x + 8, rect.position.y + rect.size.y * 0.5), 9, Style.SODIUM if active else Style.TEXT_DIM, 1.6)
		x += 26
	Style.text(self, Vector2(x, rect.position.y + 23), label, 14, Style.TEXT_DIM if disabled else (Style.SODIUM if active else Style.TEXT))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var found: int = _hit(event.position)
		if found != _hover:
			_hover = found
			queue_redraw()
		return
	if not event is InputEventMouseButton or not event.pressed: return
	var step: int = 0
	match event.button_index:
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_WHEEL_DOWN: step = 1
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP: step = -1
	if step == 0: return
	var index: int = _hit(event.position)
	accept_event()
	if index < 0: return
	var region: Dictionary = _regions[index]
	var wheel: bool = event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	var draft: Dictionary = console.current_draft()
	match region["kind"]:
		"step": _cycle_step(draft, region["index"], step)
		"trigger": draft["trigger"] = _cycle(Catalog.TRIGGERS, draft["trigger"], step)
		"action": draft["action"] = _cycle(Catalog.REACTIONS, draft["action"], step)
		"chain": if not wheel: draft["chain"] = not draft.get("chain", false)
		"slot": if not wheel: console.select_slot(region["index"])
		"bind": if not wheel and step > 0: console.bind_reaction()
		"save": if not wheel and step > 0: console.close_editor()
	queue_redraw()

func _hit(point: Vector2) -> int:
	for i: int in _regions.size():
		if _regions[i]["rect"].has_point(point): return i
	return -1

func _cycle(options: Array, current: String, step: int) -> String:
	var at: int = maxi(options.find(current), 0)
	return options[(at + step + options.size()) % options.size()]

func _cycle_step(draft: Dictionary, index: int, step: int) -> void:
	var steps: Array = draft["steps"]
	var current: String = steps[index] if index < steps.size() else ""
	var next: String = _cycle(STEP_CYCLE, current, step)
	if index < steps.size():
		if next == "": steps.remove_at(index)
		else: steps[index] = next
	elif next != "":
		steps.append(next)
