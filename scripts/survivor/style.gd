## Municipal night-shift signage: chalk, faded safety orange and petrol-painted steel.
extends RefCounted
const INK := Color("172b2f")
const PAPER := Color("e4e1d0")
const MUTED := Color("a5b6ae")
const ORANGE := Color("d98555")
const GREEN := Color("aac8ae")
static var _font: SystemFont
static var _mono: SystemFont
static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Helvetica Neue", "Arial", "DejaVu Sans"])
		_font.font_weight = 500
	return _font
static func mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono"])
	return _mono
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 20
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = INK if state in ["hover", "pressed"] else Color(0, 0, 0, 0)
		s.border_width_bottom = 1
		s.border_color = Color(0.2, 0.3, 0.3, 0.25)
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 12
		s.content_margin_bottom = 12
		if state == "focus":
			s.bg_color = Color.TRANSPARENT
			s.border_width_left = 3
			s.border_color = ORANGE
		t.set_stylebox(state, "Button", s)
		t.set_color("font_" + state + "_color" if state != "normal" else "font_color", "Button", PAPER if state in ["hover", "pressed"] else INK)
	t.set_color("font_color", "Label", PAPER)
	return t
