## The operator's instrument language: blackened plates, brass edges, sodium text, and a small
## set of glyphs drawn as line work rather than borrowed icons. Shared by the HUD and the editor.
extends RefCounted

const INK := Color(0.03, 0.035, 0.04, 0.9)
const PLATE := Color(0.065, 0.07, 0.072, 0.94)
const PLATE_HI := Color(0.1, 0.105, 0.1, 0.96)
const BRASS := Color(0.86, 0.64, 0.34)
const BRASS_DIM := Color(0.46, 0.35, 0.2)
const SODIUM := Color(1.0, 0.757, 0.478)
const SPINE := Color(0.525, 0.894, 0.976)
const TEXT := Color(0.88, 0.85, 0.78)
const TEXT_DIM := Color(0.55, 0.56, 0.54)
const FAULT := Color(1.0, 0.38, 0.27)
const CORRUPT := Color(0.72, 0.04, 0.38)

static var _display: SystemFont
static var _mono: SystemFont

## Condensed industrial face, the same family as the yard's stencilled signage.
static func display() -> Font:
	if _display == null:
		_display = SystemFont.new()
		_display.font_names = PackedStringArray(["DIN Condensed", "Bahnschrift SemiCondensed", "Bahnschrift", "Barlow Condensed", "Roboto Condensed", "Arial Narrow", "Helvetica Neue", "Arial"])
		_display.font_weight = 600
		_display.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_display.hinting = TextServer.HINTING_LIGHT
	return _display

static func mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["SF Mono", "Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
		_mono.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _mono

## A plate with its top-left and bottom-right corners clipped, edged in brass.
static func plate(canvas: CanvasItem, rect: Rect2, fill: Color = PLATE, edge: Color = BRASS_DIM, cut: float = 10.0, edge_width: float = 1.0) -> void:
	var points := PackedVector2Array([
		rect.position + Vector2(cut, 0), rect.position + Vector2(rect.size.x, 0),
		rect.position + Vector2(rect.size.x, rect.size.y - cut), rect.position + Vector2(rect.size.x - cut, rect.size.y),
		rect.position + Vector2(0, rect.size.y), rect.position + Vector2(0, cut)])
	canvas.draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, edge, edge_width, true)

## Short brass ticks at a plate's corners, like the clamps on the yard's fixtures.
static func clamps(canvas: CanvasItem, rect: Rect2, color: Color = BRASS, length: float = 7.0) -> void:
	var a := rect.position
	var b := rect.position + rect.size
	canvas.draw_line(Vector2(b.x - length, a.y - 2), Vector2(b.x + 2, a.y - 2), color, 2.0)
	canvas.draw_line(Vector2(b.x + 2, a.y - 2), Vector2(b.x + 2, a.y + length), color, 2.0)
	canvas.draw_line(Vector2(a.x - 2, b.y - length), Vector2(a.x - 2, b.y + 2), color, 2.0)
	canvas.draw_line(Vector2(a.x - 2, b.y + 2), Vector2(a.x + length, b.y + 2), color, 2.0)

static func text(canvas: CanvasItem, position: Vector2, value: String, size: int, color: Color = TEXT, font: Font = null, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	canvas.draw_string(font if font != null else display(), position, value, align, width, size, color)

static func text_width(value: String, size: int, font: Font = null) -> float:
	return (font if font != null else display()).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## A keycap: the key in a small brass-edged cell, its meaning beside it.
static func keycap(canvas: CanvasItem, position: Vector2, key: String, meaning: String, size: int = 14) -> float:
	var key_width: float = maxf(text_width(key, size, mono()) + 10.0, 20.0)
	var cell := Rect2(position + Vector2(0, -size), Vector2(key_width, size + 7))
	canvas.draw_rect(cell, INK)
	canvas.draw_rect(cell, BRASS_DIM, false, 1.0)
	text(canvas, Vector2(cell.position.x, position.y + 1), key, size - 1, SODIUM, mono(), HORIZONTAL_ALIGNMENT_CENTER, key_width)
	text(canvas, position + Vector2(key_width + 6, 0), meaning, size, TEXT_DIM)
	return key_width + 6 + text_width(meaning, size) + 18

## Line-work glyphs for the matter vocabulary. `c` centre, `s` half-size.
static func glyph(canvas: CanvasItem, name: String, c: Vector2, s: float, color: Color, width: float = 2.0) -> void:
	match name:
		"water":
			var drop := PackedVector2Array()
			for i: int in 17:
				var a: float = PI * 0.15 + TAU * 0.85 * float(i) / 16.0
				drop.append(c + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5) * -1.0) * s * 0.55 + Vector2(0, s * 0.2))
			drop.insert(0, c + Vector2(0, -s * 0.85))
			drop.append(c + Vector2(0, -s * 0.85))
			canvas.draw_polyline(drop, color, width, true)
		"raise":
			canvas.draw_rect(Rect2(c + Vector2(-s * 0.75, s * 0.15), Vector2(s * 1.5, s * 0.55)), color, false, width)
			canvas.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.2), c + Vector2(0, -s * 0.7), c + Vector2(s * 0.45, -s * 0.2)]), color, width, true)
			canvas.draw_line(c + Vector2(0, -s * 0.65), c + Vector2(0, s * 0.1), color, width)
		"freeze":
			for i: int in 3:
				var a: float = PI * float(i) / 3.0 + PI * 0.5
				var d := Vector2(cos(a), sin(a)) * s * 0.8
				canvas.draw_line(c - d, c + d, color, width)
				for tip: float in [-1.0, 1.0]:
					var at: Vector2 = c + d * tip * 0.6
					var perp := Vector2(-d.y, d.x).normalized() * s * 0.22
					canvas.draw_line(at, at + d.normalized() * tip * s * 0.2 + perp, color, width * 0.8)
					canvas.draw_line(at, at + d.normalized() * tip * s * 0.2 - perp, color, width * 0.8)
		"heat":
			for offset: float in [-0.45, 0.0, 0.45]:
				var wave := PackedVector2Array()
				for i: int in 11:
					var t: float = float(i) / 10.0
					wave.append(c + Vector2(offset * s + sin(t * TAU) * s * 0.13, s * 0.75 - t * s * 1.5))
				canvas.draw_polyline(wave, color, width, true)
		"coat":
			for spot: Vector2 in [Vector2(-0.38, 0.22), Vector2(0.38, 0.22), Vector2(0, -0.44)]:
				var hex := PackedVector2Array()
				for i: int in 7:
					var a: float = TAU * float(i) / 6.0
					hex.append(c + spot * s + Vector2(cos(a), sin(a)) * s * 0.34)
				canvas.draw_polyline(hex, color, width, true)
		"impact":
			for i: int in 8:
				var a: float = TAU * float(i) / 8.0 + 0.2
				var inner: float = s * (0.25 if i % 2 == 0 else 0.4)
				canvas.draw_line(c + Vector2(cos(a), sin(a)) * inner, c + Vector2(cos(a), sin(a)) * s * (0.85 if i % 2 == 0 else 0.6), color, width)
		"push":
			canvas.draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.75, 0), color, width)
			canvas.draw_polyline(PackedVector2Array([c + Vector2(s * 0.35, -s * 0.38), c + Vector2(s * 0.8, 0), c + Vector2(s * 0.35, s * 0.38)]), color, width, true)
			for row: float in [-0.35, 0.0, 0.35]:
				canvas.draw_line(c + Vector2(-s * 0.85, row * s), c + Vector2(-s * 0.5, row * s), color, width * 0.8)
		"broken":
			# A block split down a jagged fault, its two halves pushed apart.
			var crack := [Vector2(0.05, -0.7), Vector2(-0.12, -0.25), Vector2(0.14, 0.05), Vector2(-0.08, 0.35), Vector2(0.06, 0.7)]
			for half: float in [-1.0, 1.0]:
				var outline := PackedVector2Array()
				var shift := Vector2(half * 0.12, half * 0.04)
				outline.append(c + (Vector2(half * 0.7, -0.7) + shift) * s)
				for point: Vector2 in crack: outline.append(c + (point + shift) * s)
				outline.append(c + (Vector2(half * 0.7, 0.7) + shift) * s)
				outline.append(c + (Vector2(half * 0.7, -0.7) + shift) * s)
				canvas.draw_polyline(outline, color, width, true)
		"hit":
			canvas.draw_arc(c, s * 0.6, 0, TAU, 24, color, width, true)
			canvas.draw_circle(c, s * 0.14, color)
			for i: int in 4:
				var d := Vector2.RIGHT.rotated(PI * 0.5 * float(i))
				canvas.draw_line(c + d * s * 0.6, c + d * s * 0.9, color, width)
		"transformed":
			canvas.draw_arc(c, s * 0.6, PI * 0.15, PI * 0.95, 14, color, width, true)
			canvas.draw_arc(c, s * 0.6, PI * 1.15, PI * 1.95, 14, color, width, true)
			for a: float in [PI * 0.95, PI * 1.95]:
				var tip: Vector2 = c + Vector2(cos(a), sin(a)) * s * 0.6
				var tangent := Vector2(-sin(a), cos(a))
				canvas.draw_line(tip, tip - tangent * s * 0.3 + Vector2(cos(a), sin(a)) * s * 0.2, color, width)
				canvas.draw_line(tip, tip - tangent * s * 0.3 - Vector2(cos(a), sin(a)) * s * 0.2, color, width)
		"pulsed":
			var line := PackedVector2Array()
			for i: int in 13:
				var t: float = float(i) / 12.0
				var y: float = 0.0
				if t > 0.35 and t < 0.65: y = sin((t - 0.35) / 0.3 * TAU) * -s * 0.6
				line.append(c + Vector2(-s * 0.85 + t * s * 1.7, y))
			canvas.draw_polyline(line, color, width, true)
			canvas.draw_circle(c + Vector2(s * 0.85, 0), s * 0.13, color)
		"command":
			canvas.draw_arc(c, s * 0.32, 0, TAU, 18, color, width, true)
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0
				canvas.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.5, c + Vector2(cos(a), sin(a)) * s * 0.9, color, width)
		"chain":
			canvas.draw_arc(c + Vector2(-s * 0.3, 0), s * 0.36, 0, TAU, 18, color, width, true)
			canvas.draw_arc(c + Vector2(s * 0.3, 0), s * 0.36, 0, TAU, 18, color, width, true)
		"empty":
			canvas.draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), color, width)
			canvas.draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), color, width)

## A dashed straight segment, for empty slots and pending conduits.
static func dashed(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, dash: float = 5.0, width: float = 1.0) -> void:
	var length: float = from.distance_to(to)
	var direction: Vector2 = (to - from) / maxf(length, 0.001)
	var at: float = 0.0
	while at < length:
		canvas.draw_line(from + direction * at, from + direction * minf(at + dash, length), color, width)
		at += dash * 2.0
