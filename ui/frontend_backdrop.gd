## The actual yard behind the front-end screens, still raining. The menu and the forms keep their
## dark on the left where the text column sits and leave the fight in the light; the crew screen
## dims the whole yard so the two operators stand out in front of it.
## Also the few pieces every front-end screen shares: the title lettered like the yard's own
## signs, the plain text actions, the one filled button per screen, "[Esc] volver" in the same
## spot on every screen, and the name you play under.
extends Control
const Kit = preload("res://scripts/ui/kit.gd")
const BACKDROP := preload("res://ui/art/sector08_backdrop.png")

## "menu": dark on the left only. "column": the same, with the yard pushed back a little.
## "stage": the whole yard dimmed evenly, for the crew screen.
@export var mode: String = "column"
## Kept so older scenes that still set it load; the dark is now set by `mode`.
@export var shade_left: float = 0.82

## The part of the backdrop the crew screen shows (texels from the top-left corner).
const STAGE_CROP := Vector2(1060, 596)
const DROPS: int = 110
var _drops: Array[Vector3] = []
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for i: int in DROPS:
		# x, phase, speed: each drop falls the height of the screen and starts again.
		_drops.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.8, 1.25)))

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var lit: Color = Color(0.86, 0.9, 0.94) if mode == "menu" else Color(0.78, 0.82, 0.88)
	if mode == "stage":
		# The quiet corner of the yard, up by the fence: the fight (and the small crew in it)
		# stays out of frame, so nobody stands on top of their own copy.
		var aspect: float = size.x / maxf(1.0, size.y)
		var src_h: float = minf(STAGE_CROP.y, STAGE_CROP.x / aspect)
		draw_texture_rect_region(BACKDROP, Rect2(Vector2.ZERO, size), Rect2(Vector2.ZERO, Vector2(src_h * aspect, src_h)), Color(0.7, 0.74, 0.8))
	else:
		var cover: float = maxf(size.x / BACKDROP.get_width(), size.y / BACKDROP.get_height())
		var image_size: Vector2 = BACKDROP.get_size() * cover
		draw_texture_rect(BACKDROP, Rect2((size - image_size) * 0.5, image_size), false, lit)
	_draw_rain()
	if mode == "stage":
		draw_rect(Rect2(Vector2.ZERO, size), Color(Kit.INK, 0.8))
		# Darker towards the top and bottom edges, where the lines of text sit.
		_vertical_shade(0.0, size.y * 0.22, 0.35, 0.0)
		_vertical_shade(size.y * 0.72, size.y, 0.0, 0.5)
		return
	if mode == "column": draw_rect(Rect2(Vector2.ZERO, size), Color(Kit.INK, 0.2))
	# The dark the text column stands in: solid at the edge, gone by the middle of the screen.
	var reach: float = size.x * (0.62 if mode == "menu" else 0.66)
	var solid: float = 0.9 if mode == "menu" else 0.94
	var steps: int = 24
	for i: int in steps:
		var u0: float = float(i) / steps
		var u1: float = float(i + 1) / steps
		var a0: float = solid * _falloff(u0)
		var a1: float = solid * _falloff(u1)
		var x0: float = roundf(reach * u0 / Kit.PX) * Kit.PX
		var x1: float = roundf(reach * u1 / Kit.PX) * Kit.PX
		draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, size.y), Vector2(x0, size.y)]),
			PackedColorArray([Color(Kit.INK, a0), Color(Kit.INK, a1), Color(Kit.INK, a1), Color(Kit.INK, a0)]))

## Full dark over the column, then easing out across the rest of the reach.
func _falloff(u: float) -> float:
	var hold: float = 0.4
	return 1.0 if u <= hold else pow(1.0 - (u - hold) / (1.0 - hold), 1.7)

func _vertical_shade(y0: float, y1: float, a0: float, a1: float) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
		PackedColorArray([Color(Kit.INK, a0), Color(Kit.INK, a0), Color(Kit.INK, a1), Color(Kit.INK, a1)]))

## Rain on the UI pixel grid: short streaks leaning a little with the wind.
func _draw_rain() -> void:
	var px: float = Kit.PX
	var fall: float = size.y + 40 * px
	for drop: Vector3 in _drops:
		var y: float = fmod(drop.y * fall + _time * 260.0 * drop.z, fall) - 20 * px
		var x: float = fmod(drop.x * (size.x + 60 * px) - y * 0.18, size.x + 60 * px)
		var length: int = 5 + int(drop.z * 4.0)
		var color := Color(0.72, 0.82, 0.92, 0.1 + 0.12 * (drop.z - 0.8) / 0.45)
		for k: int in length:
			var at := Vector2(roundf((x - k * px * 0.18) / px) * px, roundf((y - k * px) / px) * px)
			draw_rect(Rect2(at, Vector2(px, px)), color)

# --- Shared pieces ------------------------------------------------------------------------------

## The title, lettered the way the yard letters its own signs (the C/S TRANSIT 08 board): heavy
## square capitals in the signs' teal. One cell per row, `X` is paint.
const SIGN_TEAL := Color("4aaec0")
const LETTERS := {
	"R": ["XXXXXXX.", "XXXXXXXX", "XX....XX", "XX....XX", "XXXXXXXX", "XXXXXXX.", "XX..XXX.", "XX...XXX", "XX....XX", "XX....XX", "XX....XX"],
	"E": ["XXXXXXX", "XXXXXXX", "XX.....", "XX.....", "XXXXXX.", "XXXXXX.", "XX.....", "XX.....", "XX.....", "XXXXXXX", "XXXXXXX"],
	"A": ["..XXXX..", ".XXXXXX.", "XXX..XXX", "XX....XX", "XX....XX", "XX....XX", "XXXXXXXX", "XXXXXXXX", "XX....XX", "XX....XX", "XX....XX"],
	"C": ["..XXXXX.", ".XXXXXXX", "XXX...XX", "XX......", "XX......", "XX......", "XX......", "XX......", "XXX...XX", ".XXXXXXX", "..XXXXX."],
	"T": ["XXXXXXXX", "XXXXXXXX", "...XX...", "...XX...", "...XX...", "...XX...", "...XX...", "...XX...", "...XX...", "...XX...", "...XX..."],
	"I": ["XX", "XX", "XX", "XX", "XX", "XX", "XX", "XX", "XX", "XX", "XX"],
	"V": ["XX....XX", "XX....XX", "XX....XX", "XX....XX", "XXX..XXX", ".XX..XX.", ".XX..XX.", ".XXXXXX.", "..XXXX..", "..XXXX..", "...XX..."],
}

## The sign-lettered word as a texture, one texel per cell, the letters two cells apart.
static func signword(word: String, paint: Color = SIGN_TEAL) -> ImageTexture:
	var gap: int = 2
	var w: int = 0
	for c: String in word: w += (LETTERS[c][0] as String).length() + gap
	var image := Image.create(w - gap, 11, false, Image.FORMAT_RGBA8)
	var x: int = 0
	for c: String in word:
		var rows: Array = LETTERS[c]
		for y: int in rows.size():
			var row: String = rows[y]
			for i: int in row.length():
				if row[i] == "X": image.set_pixel(x + i, y, paint)
		x += (rows[0] as String).length() + gap
	return ImageTexture.create_from_image(image)

# --- The name you play under ----------------------------------------------------------------

const PROFILE := "user://frontend.cfg"

## The last name typed on the host or join screen; else the computer's user name.
static func player_name() -> String:
	var config := ConfigFile.new()
	if config.load(PROFILE) == OK:
		var saved: String = String(config.get_value("crew", "name", "")).strip_edges()
		if saved != "": return saved
	var user: String = OS.get_environment("USERNAME")
	if user.is_empty(): user = OS.get_environment("USER")
	return user if not user.is_empty() else "Operador"

static func remember(key: String, value: String) -> void:
	var config := ConfigFile.new()
	config.load(PROFILE)
	config.set_value("crew", key, value.strip_edges())
	config.save(PROFILE)

static func recall(key: String) -> String:
	var config := ConfigFile.new()
	if config.load(PROFILE) != OK: return ""
	return String(config.get_value("crew", key, ""))

## A text action with no box: the label is the control. Focus and hover turn it amber.
static func link(button: Button, color: Color = Kit.TEXT, font_size: int = Kit.TEXT_SIZE) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Kit.RAMPS["tool"][2])
	button.add_theme_color_override("font_focus_color", Kit.RAMPS["tool"][2])
	button.add_theme_color_override("font_pressed_color", Kit.RAMPS["tool"][1])
	button.add_theme_color_override("font_hover_pressed_color", Kit.RAMPS["tool"][1])
	button.add_theme_color_override("font_disabled_color", Kit.FAINT)
	button.add_theme_font_size_override("font_size", font_size)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## The one filled button a screen has: amber paint, ink letters, a darker lip under it. Focus is
## the paint going lighter.
static func primary(button: Button) -> void:
	var tool: Array = Kit.RAMPS["tool"]
	button.add_theme_stylebox_override("normal", _flat(tool[1], tool[0]))
	button.add_theme_stylebox_override("hover", _flat(tool[2], tool[1]))
	button.add_theme_stylebox_override("focus", _flat(tool[2], tool[1]))
	button.add_theme_stylebox_override("pressed", _flat(tool[0], tool[0]))
	button.add_theme_stylebox_override("hover_pressed", _flat(tool[0], tool[0]))
	button.add_theme_stylebox_override("disabled", _flat(Kit.RAMPS["mute"][0], Kit.INK))
	button.add_theme_color_override("font_color", Kit.INK)
	button.add_theme_color_override("font_hover_color", Kit.INK)
	button.add_theme_color_override("font_focus_color", Kit.INK)
	button.add_theme_color_override("font_pressed_color", tool[3])
	button.add_theme_color_override("font_hover_pressed_color", tool[3])
	button.add_theme_color_override("font_disabled_color", Kit.FAINT)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func _flat(fill: Color, lip: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = lip
	box.border_width_bottom = int(Kit.PX)
	box.content_margin_left = 8 * Kit.PX
	box.content_margin_right = 8 * Kit.PX
	box.content_margin_top = 2 * Kit.PX
	box.content_margin_bottom = 3 * Kit.PX
	return box

## "volver": the verb as a text button, dim until the mouse is on it. Keyboard users have Esc, so it
## never takes focus and no keycap names it.
static func back_row(row: HBoxContainer, back: Button) -> void:
	row.add_theme_constant_override("separation", int(4 * Kit.PX))
	link(back, Kit.DIM)
	back.focus_mode = Control.FOCUS_NONE
	back.text = "volver"

## Where "volver" sits on every lobby screen: bottom left, on the column's edge.
const BACK_SPOT := Vector2(56, -64)
