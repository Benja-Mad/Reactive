## Turns the framing trial renders into something you can decide from: one labelled contact sheet,
## and each frame again at full size with its own caption burned in.
##
## The renders themselves are named by their parameters, which is unambiguous but unreadable at a
## glance when you are comparing twelve of them. Text cannot be drawn into an Image directly, so
## the labels are real Control nodes rendered into a SubViewport -- crisp rather than blitted, and
## offscreen because the OS clamps a window to the display, which silently cropped the bottom row
## off the first version of this sheet.
##
## The captions come from a manifest written by the sweep itself, so the numbers under each frame
## are the ones that run measured -- not a set retyped by hand alongside it.
extends Node

const COLUMNS := 3
const CELL := Vector2i(864, 486)
const CAPTION_HEIGHT := 74

var trials: Array = []
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
	trials = JSON.parse_string(FileAccess.get_file_as_string(args[2])) as Array
	DirAccess.make_dir_recursive_absolute(out)

	# --- the contact sheet --------------------------------------------------------------------
	var rows: int = int(ceil(float(trials.size()) / float(COLUMNS)))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 0)
	grid.add_theme_constant_override(&"v_separation", 0)
	for trial: Array in trials:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(CELL.x, CELL.y + CAPTION_HEIGHT)
		cell.add_theme_constant_override(&"separation", 0)
		var frame := TextureRect.new()
		frame.texture = texture_for(str(trial[0]))
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.custom_minimum_size = Vector2(CELL)
		cell.add_child(frame)
		var label: Control = caption(str(trial[1]), str(trial[2]), 23, 19, bool(trial[3]))
		label.custom_minimum_size = Vector2(CELL.x, CAPTION_HEIGHT)
		cell.add_child(label)
		grid.add_child(cell)
	await render(grid, Vector2i(CELL.x * COLUMNS, (CELL.y + CAPTION_HEIGHT) * rows), out.path_join("contact_sheet.png"))

	# --- each frame again, full size, with its own caption ------------------------------------
	for trial: Array in trials:
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
		var label: Control = caption(str(trial[1]), str(trial[2]), 30, 23, bool(trial[3]))
		label.position = Vector2(28, 12)
		page.add_child(label)
		await render(page, Vector2i(1920, 1080), out.path_join(str(trial[0]).split("_")[0] + "_labelled.png"))

	print("LABELLED ", trials.size(), " trials into ", out)
	get_tree().quit()
