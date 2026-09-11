## Turns the framing trial renders into something you can decide from: one labelled contact sheet,
## and each frame again at full size with its own caption burned in.
##
## The renders themselves are named by their parameters, which is unambiguous but unreadable at a
## glance when you are comparing twelve of them. Text cannot be drawn into an Image directly, so
## the labels are real Control nodes rendered into a SubViewport -- crisp rather than blitted, and
## offscreen because the OS clamps a window to the display, which silently cropped the bottom row
## off the first version of this sheet.
extends Node

## id, caption, and the numbers that decide it. Order is the comparison: dolly, lens, pitch, yaw.
const TRIALS: Array = [
	["A0_p30_y35_d86_f30_current", "A0 · ACTUAL · 86 m · pitch 30 · FOV 30", "figura 55 px · profundidad 1.173 · paralaje 1.312 · patio 79%"],
	["A1_p30_y35_d72_f30", "A1 · 72 m · pitch 30 · FOV 30   ← recomendada", "figura 65 px · profundidad 1.207 · paralaje 1.378 · patio 68%"],
	["A2_p30_y35_d60_f30", "A2 · 60 m · pitch 30 · FOV 30", "figura 77 px · profundidad 1.249 · paralaje 1.463 · patio 58%"],

	["A3_p30_y35_d86_f25", "A3 · 86 m · FOV 25 (lente, no dolly)", "figura 66 px · profundidad 1.174 · paralaje 1.312 · patio 67%"],
	["A4_p30_y35_d86_f21", "A4 · 86 m · FOV 21 (lente, no dolly)", "figura 80 px · profundidad 1.176 · paralaje 1.312 · patio 55%"],
	["D1_p30_y35_d72_f26", "D1 · 72 m · FOV 26 (dolly + lente)", "figura 75 px · profundidad 1.208 · paralaje 1.378 · patio 60%"],

	["B1_p24_y35_d72_f30", "B1 · 72 m · pitch 24 (más tumbada)", "figura 69 px · profundidad 1.276 · paralaje 1.405 · patio 70%"],
	["B2_p36_y35_d72_f30", "B2 · 72 m · pitch 36 (más cenital)", "figura 60 px · profundidad 1.127 · paralaje 1.347 · patio 67%"],
	["B3_p42_y35_d72_f30", "B3 · 72 m · pitch 42 (cenital)", "figura 54 px · profundidad 1.037 ← casi ortográfico · patio 63%"],

	["C1_p30_y25_d72_f30", "C1 · 72 m · yaw 25", "figura 65 px · profundidad 1.232 · paralaje 1.411 · patio 70%"],
	["C2_p30_y45_d72_f30", "C2 · 72 m · yaw 45", "figura 65 px · profundidad 1.176 · paralaje 1.333 · patio 67%"],
	["E1_p34_y35_d76_f27", "E1 · 76 m · pitch 34 · FOV 27 (mixta)", "figura 65 px · profundidad 1.148 · paralaje 1.337 · patio 64%"],
]

const COLUMNS := 3
const CELL := Vector2i(864, 486)
const CAPTION_HEIGHT := 74

var source: String
var out: String


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func texture_for(id: String) -> ImageTexture:
	var image: Image = Image.load_from_file(source.path_join(id + ".png"))
	return ImageTexture.create_from_image(image)


func caption(title: String, numbers: String, title_size: int, number_size: int, highlight: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override(&"font_size", title_size)
	heading.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.4) if highlight else Color(0.93, 0.95, 1.0))
	var detail := Label.new()
	detail.text = numbers
	detail.add_theme_font_size_override(&"font_size", number_size)
	detail.add_theme_color_override(&"font_color", Color(0.66, 0.72, 0.82))
	box.add_child(heading)
	box.add_child(detail)
	return box


## Renders a Control tree at an exact size, whatever the display happens to be.
func render(content: Control, size: Vector2i, path: String) -> void:
	var view := SubViewport.new()
	view.size = size
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var back := ColorRect.new()
	back.color = Color(0.055, 0.06, 0.075)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.add_child(back)
	view.add_child(content)
	await frames(4)
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(path)
	view.queue_free()
	await frames(2)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	source = args[0]
	out = args[1]
	DirAccess.make_dir_recursive_absolute(out)

	# --- the contact sheet --------------------------------------------------------------------
	var rows: int = int(ceil(float(TRIALS.size()) / float(COLUMNS)))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 0)
	grid.add_theme_constant_override(&"v_separation", 0)
	for trial: Array in TRIALS:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(CELL.x, CELL.y + CAPTION_HEIGHT)
		cell.add_theme_constant_override(&"separation", 0)
		var frame := TextureRect.new()
		frame.texture = texture_for(str(trial[0]))
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.custom_minimum_size = Vector2(CELL)
		cell.add_child(frame)
		var label: Control = caption(str(trial[1]), str(trial[2]), 23, 19, str(trial[0]).begins_with("A1"))
		label.custom_minimum_size = Vector2(CELL.x, CAPTION_HEIGHT)
		cell.add_child(label)
		grid.add_child(cell)
	await render(grid, Vector2i(CELL.x * COLUMNS, (CELL.y + CAPTION_HEIGHT) * rows), out.path_join("contact_sheet.png"))

	# --- each frame again, full size, with its own caption ------------------------------------
	for trial: Array in TRIALS:
		var page := Control.new()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		var frame := TextureRect.new()
		frame.texture = texture_for(str(trial[0]))
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		page.add_child(frame)
		# A plate behind the caption, so it stays legible over whatever the frame puts there.
		var plate := ColorRect.new()
		plate.color = Color(0.02, 0.025, 0.035, 0.82)
		plate.size = Vector2(1920, 86)
		page.add_child(plate)
		var label: Control = caption(str(trial[1]), str(trial[2]), 30, 23, str(trial[0]).begins_with("A1"))
		label.position = Vector2(28, 12)
		page.add_child(label)
		await render(page, Vector2i(1920, 1080), out.path_join(str(trial[0]).split("_")[0] + "_labelled.png"))

	print("LABELLED ", TRIALS.size(), " trials into ", out)
	get_tree().quit()
