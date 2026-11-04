## One operator on the crew screen, standing on the yard: the figure itself, big, their name and
## tool beside them on a soft patch of dark, and over their head a plate with the name of whoever
## took them. No frame. The one you picked stands in a yard light, breathing, and says what they
## do; the other waits in the dark, still, until you point at them.
## Click anywhere on the figure or its words to take them.
extends Control
signal chosen(role: int)
const Kit = preload("res://scripts/ui/kit.gd")
## Crop of the 128 px frame that holds the whole figure, arm out included.
const FIGURE := Rect2(30, 36, 70, 90)
## Canvas units per texel: two UI pixels.
const ZOOM: float = 4.0
## How far the figure's middle stands from the inner edge of this half.
const INSET: float = 150.0
## Texel row of the top of the head inside FIGURE.
const HEAD: float = 8.0

var role: int = 0
var accent: String = "tool"
var frames: SpriteFrames
## "El Sereno"; the tool under it ("sellos y ánimas"); then what they do, in their own words.
var title: String = ""
var line: String = ""
var about: String = ""
## Text on the left of the figure (the left half), or on the right.
var text_left: bool = false
## The figure turned to face the middle of the screen.
var flip: bool = false
var selected: bool = false
var is_ready: bool = false
## Your name, shown over the head when you took this one, and whether there are others to tell
## you apart from.
var me_name: String = ""
var crew: bool = false
## Names of the other operators who took this one (with " ✓" when ready).
var picks: PackedStringArray = []

var _hover: bool = false
var _time: float = 0.0
## Seconds into the answer the figure gives when picked (its attack), or < 0 when idle.
var _answer: float = -1.0
var _name: Label
var _line: Label
var _about: Label

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)
	_name = _label("Heading")
	_line = _label("")
	_about = _label("Muted")
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(_layout)
	_layout()

func _label(variation: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

## The figure's middle, and the line its feet stand on.
func figure_x() -> float:
	return roundf((size.x - INSET if text_left else INSET) / Kit.PX) * Kit.PX

func floor_y() -> float:
	return roundf(size.y * 0.78 / Kit.PX) * Kit.PX

func _layout() -> void:
	if _name == null: return
	_name.text = title
	_line.text = line
	_about.text = about
	# Both blocks read left to right; the left one ends a little short of its figure.
	var width: float = 300.0
	var x: float = maxf(56.0, figure_x() - 100.0 - width) if text_left else figure_x() + 100.0
	width = minf(width, (figure_x() - 100.0 - x) if text_left else size.x - x - 40.0)
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
	var y: float = floor_y() - FIGURE.size.y * ZOOM * 0.62
	for label: Label in [_name, _line, _about]:
		label.horizontal_alignment = align
		label.position = Vector2(x, y)
		label.size = Vector2(width, 0)
		label.custom_minimum_size.x = width
	_line.position.y = y + 56
	_about.position.y = y + 92
	_style()

## Picked: lit and in the operator's colour. Not picked: receding, unless the mouse is over it.
## Name and tool always readable; what they do only for the one you picked or point at. Taken
## by a teammate: half lit, so the crew reads as two people.
func _style() -> void:
	var lit: bool = selected or _hover
	var r: Array = Kit.ramp(accent)
	_name.add_theme_color_override("font_color", Kit.TEXT if lit else Kit.TEXT.lerp(Kit.DIM, 0.55))
	_line.add_theme_color_override("font_color", r[2] if lit else r[2].lerp(Kit.DIM, 0.55))
	_about.add_theme_color_override("font_color", Kit.DIM.lerp(Kit.TEXT, 0.25))
	_about.visible = lit

## The patch of dark the words sit on: soft on every side, no edge.
func _text_rect() -> Rect2:
	var bottom: float = (_about.position.y + _about.get_combined_minimum_size().y) if _about.visible else (_line.position.y + 26.0)
	return Rect2(_name.position - Vector2(28, 20), Vector2(_name.size.x + 56, bottom - _name.position.y + 40))

func _scrim(rect: Rect2, alpha: float) -> void:
	var feather: float = 28.0
	var core := rect.grow(-feather)
	var clear := Color(Kit.INK, 0.0)
	var dark := Color(Kit.INK, alpha)
	draw_rect(core, dark)
	var o := rect.position
	var e := rect.end
	var co := core.position
	var ce := core.end
	var quads: Array = [
		[Vector2(co.x, o.y), Vector2(ce.x, o.y), Vector2(ce.x, co.y), Vector2(co.x, co.y), true],
		[Vector2(co.x, ce.y), Vector2(ce.x, ce.y), Vector2(ce.x, e.y), Vector2(co.x, e.y), false],
	]
	for q: Array in quads:
		var top_clear: bool = q[4]
		draw_polygon(PackedVector2Array([q[0], q[1], q[2], q[3]]), PackedColorArray([clear if top_clear else dark, clear if top_clear else dark, dark if top_clear else clear, dark if top_clear else clear]))
	draw_polygon(PackedVector2Array([Vector2(o.x, co.y), Vector2(co.x, co.y), Vector2(co.x, ce.y), Vector2(o.x, ce.y)]), PackedColorArray([clear, dark, dark, clear]))
	draw_polygon(PackedVector2Array([Vector2(ce.x, co.y), Vector2(e.x, co.y), Vector2(e.x, ce.y), Vector2(ce.x, ce.y)]), PackedColorArray([dark, clear, clear, dark]))
	# Corners: only the inner point is dark.
	draw_polygon(PackedVector2Array([o, Vector2(co.x, o.y), co, Vector2(o.x, co.y)]), PackedColorArray([clear, clear, dark, clear]))
	draw_polygon(PackedVector2Array([Vector2(ce.x, o.y), Vector2(e.x, o.y), Vector2(e.x, co.y), Vector2(ce.x, co.y)]), PackedColorArray([clear, clear, clear, dark]))
	draw_polygon(PackedVector2Array([ce, Vector2(e.x, ce.y), e, Vector2(ce.x, e.y)]), PackedColorArray([dark, clear, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(o.x, ce.y), Vector2(co.x, ce.y), Vector2(co.x, e.y), Vector2(o.x, e.y)]), PackedColorArray([clear, dark, clear, clear]))

## The figure answers being taken with its own attack, once.
func answer() -> void:
	if frames != null and frames.has_animation(&"Fire"): _answer = 0.0

func refresh() -> void:
	_layout()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(role)
		accept_event()

func _process(delta: float) -> void:
	_time += delta
	if _answer >= 0.0:
		_answer += delta
		if _answer * frames.get_animation_speed(&"Fire") >= frames.get_frame_count(&"Fire") + 2: _answer = -1.0
	_style()
	queue_redraw()

func _draw() -> void:
	var px: float = Kit.PX
	var r: Array = Kit.ramp(accent)
	var lit: bool = selected or _hover
	var cx: float = figure_x()
	var fy: float = floor_y()
	_scrim(_text_rect(), 0.62)
	# The yard light every picked operator stands in: a cone from overhead to a pool at the feet.
	# The plate over the head says whose.
	if selected or not picks.is_empty():
		var light := Color(1.0, 0.94, 0.84)
		draw_polygon(PackedVector2Array([Vector2(cx - 18 * px, 0), Vector2(cx + 18 * px, 0), Vector2(cx + 62 * px, fy), Vector2(cx - 62 * px, fy)]),
			PackedColorArray([Color(light, 0.0), Color(light, 0.0), Color(light, 0.09), Color(light, 0.09)]))
		# The pool: rows of light, widest at the middle row, so it reads as an ellipse on the
		# paving rather than a box.
		var pool: Color = light.lerp(r[2], 0.3)
		for row: int in range(-5, 6):
			var t: float = float(row) / 5.5
			var w: float = roundf(62.0 * sqrt(1.0 - t * t)) * 2.0 * px
			draw_rect(Rect2(cx - w * 0.5, fy + row * px, w, px), Color(pool, 0.1))
			draw_rect(Rect2(cx - w * 0.3, fy + row * px, w * 0.6, px), Color(pool, 0.06))
	draw_rect(Rect2(cx - 16 * px, fy - px, 32 * px, 2 * px), Color(Kit.INK, 0.7))
	if frames != null and frames.has_animation(&"Idle"):
		var anim: StringName = &"Idle"
		var index: int = 0
		if _answer >= 0.0:
			anim = &"Fire"
			index = mini(int(_answer * frames.get_animation_speed(anim)), frames.get_frame_count(anim) - 1)
		elif lit or not picks.is_empty():
			index = int(_time * frames.get_animation_speed(anim)) % frames.get_frame_count(anim)
		var atlas := frames.get_frame_texture(anim, index) as AtlasTexture
		if atlas != null:
			var dest_size: Vector2 = FIGURE.size * ZOOM
			# The crop's horizontal middle sits on the figure's middle; its bottom on the floor.
			var dest := Rect2(Vector2(cx - dest_size.x * 0.5, fy - dest_size.y + 2 * ZOOM), dest_size)
			var src := Rect2(atlas.region.position + FIGURE.position, FIGURE.size)
			var shade: Color = Color(0.3, 0.33, 0.42)
			if selected: shade = Color.WHITE
			elif _hover or not picks.is_empty(): shade = Color(0.62, 0.66, 0.78)
			# Turned round the figure's own middle, so the two face each other.
			if flip: draw_set_transform(Vector2(2.0 * cx, 0.0), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect_region(atlas.atlas, dest, src, shade)
			draw_set_transform(Vector2.ZERO)
	# Over the head, on plates: you in the operator's colour, the others dark. Alone, the spotlight
	# already says which one is yours, so no plate.
	var y: float = fy - (FIGURE.size.y - HEAD) * ZOOM - 8 * px
	var tags: Array = []
	if selected and me_name != "" and crew: tags.append([me_name + " (tú)" + (" ✓" if is_ready else ""), true])
	for who: String in picks: tags.append([who, false])
	for i: int in tags.size():
		var tag: Array = tags[i]
		var mine: bool = tag[1]
		var label: String = tag[0]
		var w: float = Kit.width(label) + 10 * px
		var plate := Rect2(roundf((cx - w * 0.5) / px) * px, y - 14 * px, w, 14 * px)
		draw_rect(plate, r[1] if mine else Kit.RAMPS["mute"][0])
		draw_rect(Rect2(plate.position.x, plate.end.y - px, plate.size.x, px), r[0] if mine else Kit.INK)
		Kit.text(self, plate.position + Vector2(5 * px, px), label, Kit.INK if mine else Kit.DIM)
		if i == 0:
			# A notch under the nearest plate, pointing down at the head.
			draw_rect(Rect2(cx - 3 * px, plate.end.y, 6 * px, px), r[0] if mine else Kit.INK)
			draw_rect(Rect2(cx - 2 * px, plate.end.y + px, 4 * px, px), r[0] if mine else Kit.INK)
		y -= 17 * px
