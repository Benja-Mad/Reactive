## The crew's UI kit: the hand-drawn pixel font, a glyph for every piece and tool, property marks,
## and the notched plates, all from res://ui/kit (written by tools/ui/export_kit.py). One UI pixel
## is two units of the 1152x648 canvas, the same grain as the yard's pixel buffer.
## WHEN fires (orange), DO shapes matter (cyan), THEN reacts (violet), tools are amber; rose is
## kept for the machines.
extends RefCounted

const PX: float = 2.0
## Font sizes on the canvas: body text, and the big numerals.
const TEXT_SIZE: int = 24
const BIG_SIZE: int = 48

const INK := Color("05070b")
const FILL := Color("0d1119")
const FILL_HI := Color("151c2a")
const BOARD := Color("090c13")
const LINE := Color("263042")
const LINE_HI := Color("3a4660")
const TEXT := Color("e8e4d8")
const DIM := Color("8a90a0")
const FAINT := Color("4a5266")

const RAMPS := {
	"when": [Color("7c2a12"), Color("ff6a24"), Color("ffad4a"), Color("fff0c8")],
	"do": [Color("1d6f80"), Color("36c8e0"), Color("93f3ff"), Color("effeff")],
	"then": [Color("352a6e"), Color("7a66e8"), Color("b4a6ff"), Color("f0ecff")],
	"tool": [Color("6e4614"), Color("e0a040"), Color("ffd27a"), Color("fff4d8")],
	"danger": [Color("5c1028"), Color("ff3b6b"), Color("ff8aa6"), Color("ffe0e8")],
	"mute": [Color("1a2130"), Color("3a4660"), Color("8a90a0"), Color("e8e4d8")],
}
const ACCENTS: Array[String] = ["when", "do", "then", "tool", "danger", "mute"]
const ICONS: Array[String] = ["cerca", "cada", "rastro", "grupo", "herido", "eco", "derribo", "agua", "fuego", "frio", "arco", "alzar", "empujar", "soltar", "pozo", "repeler", "cubrir", "fragmentos", "detonar", "estallar", "cadena", "colapso", "valvula", "doble", "bocas", "botas", "parche", "manometro", "otra", "charco", "chatarra", "si_mojada", "si_arde", "si_marcada", "mano"]
const PROPS: Array[String] = ["caliente", "frio", "mojado", "carga", "pozo", "repele", "vapor", "masa"]
## Build keys whose glyph goes by another name.
const GLYPH_OF := {
	"wall": "alzar", "raise": "alzar", "cold": "frio", "fire": "fuego", "arc": "arco", "coat": "cubrir", "push": "empujar",
	"well": "pozo", "repel": "repeler", "drop": "soltar",
	"cadence": "valvula", "power": "doble", "split": "bocas", "boots": "botas", "repair": "parche",
	"pressure": "manometro", "slot": "otra",
}
## A build slot's accent.
const SLOT_ACCENT := {"when": "when", "step": "do", "then": "then", "tool": "tool"}

static var _font: FontFile
static var _icons: Texture2D
static var _props: Texture2D
static var _cache: Dictionary = {}
static var _theme: Theme

static func font() -> FontFile:
	if _font == null: _font = load("res://ui/kit/font.fnt")
	return _font

static func ramp(accent: String) -> Array:
	return RAMPS.get(accent, RAMPS["mute"])

static func tex(name: String) -> Texture2D:
	if not _cache.has(name): _cache[name] = load("res://ui/kit/%s.png" % name)
	return _cache[name]

## The 12x12 glyph of a piece, tool or plain icon name, in its category colour or `accent`.
static func icon(key: String, accent: String = "") -> AtlasTexture:
	var name: String = GLYPH_OF.get(key, key)
	if accent == "": accent = accent_of(key)
	var id: String = "icon:%s:%s" % [name, accent]
	if not _cache.has(id):
		if _icons == null: _icons = load("res://ui/kit/icons.png")
		var atlas := AtlasTexture.new()
		atlas.atlas = _icons
		atlas.region = Rect2(maxi(0, ICONS.find(name)) * 12, maxi(0, ACCENTS.find(accent)) * 12, 12, 12)
		_cache[id] = atlas
	return _cache[id]

## A 7x7 property mark: caliente, frio, mojado, carga, pozo, masa.
static func prop(name: String) -> AtlasTexture:
	var id: String = "prop:" + name
	if not _cache.has(id):
		if _props == null: _props = load("res://ui/kit/props.png")
		var atlas := AtlasTexture.new()
		atlas.atlas = _props
		atlas.region = Rect2(maxi(0, PROPS.find(name)) * 7, 0, 7, 7)
		_cache[id] = atlas
	return _cache[id]

## The category of any build key: a piece's slot, or tool.
static func accent_of(key: String) -> String:
	var Build = load("res://scripts/survivor/build.gd")
	if Build.PIECES.has(key): return SLOT_ACCENT[Build.PIECES[key]["slot"]]
	if Build.TOOLS.has(key): return "tool"
	var index: int = ICONS.find(key)
	if index < 0: return "mute"
	if index < 7: return "when"
	if index < 17: return "do"
	if index < 22: return "then"
	return "tool"

## A 9-slice plate from the kit. Margins are in UI pixels; content margins pad what sits inside.
static func plate(name: String, margin: Vector4, content: Vector4 = Vector4(-1, -1, -1, -1), expand_left: float = 0.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex(name)
	box.texture_margin_left = margin.x * PX
	box.texture_margin_top = margin.y * PX
	box.texture_margin_right = margin.z * PX
	box.texture_margin_bottom = margin.w * PX
	if content.x >= 0:
		box.content_margin_left = content.x * PX
		box.content_margin_top = content.y * PX
		box.content_margin_right = content.z * PX
		box.content_margin_bottom = content.w * PX
	box.expand_margin_left = expand_left * PX
	return box

static func panel_box(accent: String = "tool", pad: float = 8.0) -> StyleBoxTexture:
	return plate("panel_" + accent, Vector4(12, 12, 12, 12), Vector4(pad, pad, pad, pad))

static func tape_box(accent: String = "tool", dark: bool = false) -> StyleBoxTexture:
	return plate("tape_%s%s" % [accent, "_dark" if dark else ""], Vector4(3, 3, 3, 3), Vector4(5, 1, 5, 1))

static func keycap_box() -> StyleBoxTexture:
	return plate("keycap", Vector4(2, 2, 2, 3), Vector4(3, 0, 3, 1))

static func chip_box(accent: String, state: String = "") -> StyleBoxTexture:
	return plate("chip_%s%s" % [accent, "" if state == "" else "_" + state], Vector4(4, 4, 4, 4))

## The shared theme: pixel font everywhere, menu plates for buttons, dark fields.
static func theme() -> Theme:
	if _theme != null: return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = TEXT_SIZE
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 0)
	var pad := Vector4(7, 2, 7, 2)
	t.set_stylebox("normal", "Button", plate("button_normal", Vector4(13, 3, 3, 3), pad, 10))
	t.set_stylebox("hover", "Button", plate("button_hover", Vector4(13, 3, 3, 3), pad, 10))
	t.set_stylebox("pressed", "Button", plate("button_pressed", Vector4(13, 3, 3, 3), pad, 10))
	t.set_stylebox("disabled", "Button", plate("button_disabled", Vector4(13, 3, 3, 3), pad, 10))
	# Keyboard focus looks like the mouse being over it.
	t.set_stylebox("focus", "Button", plate("button_hover", Vector4(13, 3, 3, 3), pad, 10))
	t.set_stylebox("hover_pressed", "Button", plate("button_pressed", Vector4(13, 3, 3, 3), pad, 10))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", RAMPS["tool"][3])
	t.set_color("font_focus_color", "Button", RAMPS["tool"][3])
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", FAINT)
	var field := plate("field", Vector4(3, 3, 3, 3), Vector4(6, 2, 6, 2))
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", plate("field_focus", Vector4(3, 3, 3, 3), Vector4(6, 2, 6, 2)))
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", FAINT)
	t.set_color("caret_color", "LineEdit", RAMPS["tool"][2])
	t.set_color("selection_color", "LineEdit", Color(RAMPS["tool"][0], 0.8))
	t.set_constant("caret_width", "LineEdit", int(PX))
	t.set_stylebox("panel", "PanelContainer", panel_box("tool"))
	t.set_stylebox("panel", "Panel", panel_box("tool"))
	# Variations.
	t.set_type_variation("Dim", "Label")
	t.set_color("font_color", "Dim", DIM)
	t.set_type_variation("Big", "Label")
	t.set_font_size("font_size", "Big", BIG_SIZE)
	# The lobby scenes' own variations.
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", DIM)
	t.set_type_variation("Title", "Label")
	t.set_stylebox("normal", "Title", tape_box("tool"))
	t.set_color("font_color", "Title", INK)
	t.set_type_variation("Wordmark", "Label")
	t.set_font_size("font_size", "Wordmark", BIG_SIZE * 2)
	t.set_type_variation("Darker", "Panel")
	t.set_stylebox("panel", "Darker", panel_box("mute"))
	t.set_type_variation("Zero", "MarginContainer")
	for side: String in ["left", "top", "right", "bottom"]:
		t.set_constant("margin_" + side, "Zero", 0)
		t.set_constant("margin_" + side, "Tight", int(8 * PX))
		t.set_constant("margin_" + side, "MarginContainer", int(12 * PX))
	t.set_constant("separation", "Zero", 0)
	t.set_stylebox("panel", "Zero", StyleBoxEmpty.new())
	t.set_type_variation("Tight", "MarginContainer")
	t.set_constant("separation", "VBoxContainer", int(6 * PX))
	t.set_constant("separation", "HBoxContainer", int(8 * PX))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", font())
	t.set_font_size("normal_font_size", "RichTextLabel", TEXT_SIZE)
	t.set_font_size("bold_font_size", "RichTextLabel", TEXT_SIZE)
	for accent: String in ACCENTS:
		var tape_name: String = "Tape" + accent.capitalize()
		t.set_type_variation(tape_name, "Label")
		t.set_stylebox("normal", tape_name, tape_box(accent))
		t.set_color("font_color", tape_name, INK)
		var panel_name: String = "Panel" + accent.capitalize()
		t.set_type_variation(panel_name, "PanelContainer")
		t.set_stylebox("panel", panel_name, panel_box(accent))
	_theme = t
	return t

# --- Drawing helpers for custom-drawn controls (in canvas units; sizes in UI pixels × PX) --------

## Text with its 12-row cell top at `at` (canvas units). `scale` multiplies the UI size.
static func text(item: CanvasItem, at: Vector2, value: String, color: Color, scale: int = 1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, shadow: bool = false) -> void:
	var size: int = TEXT_SIZE * scale
	var x: float = at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER: x -= width(value, scale) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT: x -= width(value, scale)
	var base := Vector2(roundf(x / PX) * PX, roundf(at.y / PX) * PX + 10.0 * PX * scale)
	if shadow: item.draw_string(font(), base + Vector2(PX, PX) * scale, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
	item.draw_string(font(), base, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func width(value: String, scale: int = 1) -> float:
	return font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE * scale).x - PX * scale

## A notched plate: corners cut at 45 degrees, 1 UI px edge.
static func notched(item: CanvasItem, rect: Rect2, fill: Color, edge: Color, cut: float = 2.0) -> void:
	var c: float = cut * PX
	var outer := PackedVector2Array([
		rect.position + Vector2(c, 0), Vector2(rect.end.x - c, rect.position.y), Vector2(rect.end.x, rect.position.y + c),
		Vector2(rect.end.x, rect.end.y - c), Vector2(rect.end.x - c, rect.end.y), Vector2(rect.position.x + c, rect.end.y),
		Vector2(rect.position.x, rect.end.y - c), Vector2(rect.position.x, rect.position.y + c)])
	if edge.a > 0: item.draw_colored_polygon(outer, edge)
	if fill.a > 0:
		var inner := rect.grow(-PX)
		var ci: float = maxf(0.0, c - PX * 0.6)
		item.draw_colored_polygon(PackedVector2Array([
			inner.position + Vector2(ci, 0), Vector2(inner.end.x - ci, inner.position.y), Vector2(inner.end.x, inner.position.y + ci),
			Vector2(inner.end.x, inner.end.y - ci), Vector2(inner.end.x - ci, inner.end.y), Vector2(inner.position.x + ci, inner.end.y),
			Vector2(inner.position.x, inner.end.y - ci), Vector2(inner.position.x, inner.position.y + ci)]), fill)

## A dashed 1 UI px outline: an empty socket.
static func dashed(item: CanvasItem, rect: Rect2, color: Color) -> void:
	var step: float = PX * 3.0
	var x: float = rect.position.x
	while x < rect.end.x:
		item.draw_rect(Rect2(x, rect.position.y, minf(PX * 2.0, rect.end.x - x), PX), color)
		item.draw_rect(Rect2(x, rect.end.y - PX, minf(PX * 2.0, rect.end.x - x), PX), color)
		x += step
	var y: float = rect.position.y
	while y < rect.end.y:
		item.draw_rect(Rect2(rect.position.x, y, PX, minf(PX * 2.0, rect.end.y - y)), color)
		item.draw_rect(Rect2(rect.end.x - PX, y, PX, minf(PX * 2.0, rect.end.y - y)), color)
		y += step

## A segmented gauge: lit segments in the accent, spent ones as dark sockets.
static func bar(item: CanvasItem, at: Vector2, segments: int, filled: float, accent: String, seg_w: float = 4.0, h: float = 5.0) -> void:
	var r: Array = ramp(accent)
	var w: float = seg_w * PX
	var hh: float = h * PX
	item.draw_rect(Rect2(at - Vector2(PX, PX), Vector2(segments * (w + PX) + PX, hh + PX * 2)), INK)
	for i: int in segments:
		var x: float = at.x + i * (w + PX)
		var amount: float = clampf(filled - i, 0.0, 1.0)
		item.draw_rect(Rect2(x, at.y, w, hh), FILL)
		item.draw_rect(Rect2(x, at.y + hh - PX, w, PX), LINE)
		if amount > 0.0:
			var lit_w: float = maxf(PX, roundf(w * amount / PX) * PX)
			item.draw_rect(Rect2(x, at.y, lit_w, hh), r[1])
			item.draw_rect(Rect2(x, at.y, lit_w, PX), r[2])
			item.draw_rect(Rect2(x, at.y + hh - PX, lit_w, PX), r[0])

## Ordered-dither cover of `rect` with `color` at `amount` 0..1, on the UI pixel grid. The item
## needs texture_repeat enabled, since the 4x4 pattern is tiled.
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
static func dither(item: CanvasItem, rect: Rect2, color: Color, amount: float) -> void:
	var level: int = clampi(roundi(amount * 16.0), 0, 16)
	if level == 0: return
	var id: String = "dither:%d" % level
	if not _cache.has(id):
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y: int in 8:
			for x: int in 8:
				var on: bool = BAYER[(x / 2) % 4 + ((y / 2) % 4) * 4] < level
				image.set_pixel(x, y, Color.WHITE if on else Color(1, 1, 1, 0))
		_cache[id] = ImageTexture.create_from_image(image)
	item.draw_texture_rect(_cache[id], rect, true, color)

## A dither that varies over the rect: `amount_at(u, v)` gives the cover at each UI pixel. Built
## once into a texture under `id`; draw it with draw_texture_rect at the same rect.
static func dither_field(id: String, size_px: Vector2i, color: Color, amount_at: Callable) -> ImageTexture:
	if not _cache.has(id):
		var image := Image.create(size_px.x, size_px.y, false, Image.FORMAT_RGBA8)
		for y: int in size_px.y:
			for x: int in size_px.x:
				var amount: float = amount_at.call(float(x) / maxf(1, size_px.x - 1), float(y) / maxf(1, size_px.y - 1))
				if (BAYER[(x % 4) + (y % 4) * 4] + 0.5) / 16.0 < amount: image.set_pixel(x, y, color)
		_cache[id] = ImageTexture.create_from_image(image)
	return _cache[id]

## A keycap with its label: returns its width.
static func keycap(item: CanvasItem, at: Vector2, label: String) -> float:
	var w: float = maxf(9.0 * PX, width(label) + 6.0 * PX)
	item.draw_style_box(keycap_box(), Rect2(at, Vector2(w, 11 * PX)))
	text(item, at + Vector2(3 * PX, -2 * PX), label, TEXT)
	return w

## A label on coloured tape: returns its width.
static func tape(item: CanvasItem, at: Vector2, label: String, accent: String = "tool", dark: bool = false) -> float:
	var w: float = width(label) + 8.0 * PX
	item.draw_style_box(tape_box(accent, dark), Rect2(at - Vector2(PX, PX), Vector2(w + 2 * PX, 15 * PX)))
	text(item, at + Vector2(4 * PX, 0), label, ramp(accent)[2] if dark else INK)
	return w

## A panel with its lit corners and an optional tape title on the top edge.
static func panel(item: CanvasItem, rect: Rect2, accent: String = "tool", title: String = "") -> void:
	item.draw_style_box(panel_box(accent), rect.grow(PX))
	if title != "": tape(item, rect.position + Vector2(12, -6) * PX, title, accent)
