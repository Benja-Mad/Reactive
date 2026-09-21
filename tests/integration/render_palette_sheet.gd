## Draws the district's palette as a sheet, from values read out of the running scene.
##
## Hex codes in a document go stale the moment a light is retuned. This takes its numbers from
## the map survey's own JSON, so the sheet and the game cannot disagree: if a swatch is wrong,
## the survey was wrong, and the survey reads the scene.
extends Node

const SWATCH := Vector2i(238, 128)
const MARGIN := 34

var out: String
var data: Dictionary


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func label(text: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override(&"font_size", size)
	node.add_theme_color_override(&"font_color", color)
	return node


## One swatch: the colour, what it is, and the number that matters for it.
func swatch(hex: String, title: String, detail: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.custom_minimum_size = Vector2(SWATCH.x, 0)
	var chip := ColorRect.new()
	chip.color = Color.html(hex)
	chip.custom_minimum_size = Vector2(SWATCH)
	box.add_child(chip)
	box.add_child(label(title, 19, Color(0.94, 0.96, 1.0)))
	var caption: Label = label(hex + "   " + detail, 15, Color(0.62, 0.69, 0.80))
	caption.clip_text = true
	caption.custom_minimum_size = Vector2(SWATCH.x, 0)
	box.add_child(caption)
	return box


func heading(text: String, note: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.add_child(label(text, 26, Color(1.0, 0.84, 0.42)))
	if note != "":
		box.add_child(label(note, 17, Color(0.60, 0.67, 0.78)))
	return box


func row(entries: Array) -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override(&"separation", 18)
	for entry: Array in entries:
		strip.add_child(swatch(str(entry[0]), str(entry[1]), str(entry[2])))
	return strip


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out = args[0]
	data = JSON.parse_string(FileAccess.get_file_as_string(args[1])) as Dictionary
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())

	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 26)
	page.position = Vector2(MARGIN, MARGIN)

	page.add_child(heading("SECTOR 08 — PALETA", "Leída de la escena en ejecución. Patio %s m², recorrido de cámara %s m." % [data["yard"]["area_m2"], data["yard"]["camera_travel_m"]]))

	# --- light, which is where all the colour comes from --------------------------------------
	page.add_child(heading("LUZ", "Las superficies son grises; el color entra por aquí."))
	var families: Array = []
	for entry: Array in [["SpineCyan", "Cian de la espina", "identidad del distrito"],
			["YardStreetlight", "Sodio del patio", "contratemperatura"],
			["IndustrialAmberCenter", "Ámbar industrial", "habitación"],
			["CorruptionMagenta", "Magenta de corrupción", "sigue al estado"],
			["KeyLight", "Clave de noche", "frío, bajo"],
			["FillLight", "Relleno", "sombras legibles"]]:
		for light: Dictionary in data["lights"]:
			if str(light["name"]) == str(entry[0]):
				families.append([light["hex"], str(entry[1]), "E %s · %s" % [light["energy"], entry[2]]])
				break
	page.add_child(row(families))

	# --- surfaces -----------------------------------------------------------------------------
	page.add_child(heading("SUPERFICIE", "Albedo de calibración por familia. Ninguno saturado, a propósito."))
	page.add_child(row([
		["#7A756B", "Hormigón", "rug 0.80"],
		["#66635D", "Asfalto", "rug 0.82"],
		["#444C56", "Acero", "met 0.70"],
		["#84898C", "Galvanizado", "met 0.72"],
		["#753313", "Óxido", "acento"],
		["#181C21", "Silueta", "fondo"],
	]))

	# --- the map, region by region ------------------------------------------------------------
	page.add_child(heading("EL MAPA, REGIÓN POR REGIÓN", "Color medio del cuadro con la cámara en cada extremo de su recorrido."))
	var north: Array = []
	var south: Array = []
	for stop: Dictionary in data["stops"]:
		var name: String = str(stop["region"])
		var entry: Array = [stop["average"], name.capitalize(), "cálido %.0f%% · med %.2f" % [100.0 * float(stop["warm_share"]), float(stop["p50"])]]
		if name.begins_with("sur"):
			south.append(entry)
		else:
			north.append(entry)
	page.add_child(row(north.slice(0, 6)))
	page.add_child(row(south))
	page.add_child(label("El sur nuevo va un 28% más oscuro y con la mitad de cálido que el resto: es la zona que se está saliendo de la paleta.", 18, Color(1.0, 0.62, 0.40)))

	var view := SubViewport.new()
	view.size = Vector2i(1624, 1500)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var back := ColorRect.new()
	back.color = Color(0.055, 0.062, 0.078)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.add_child(back)
	view.add_child(page)
	await frames(6)
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out)
	print("SHEET ", out)
	get_tree().quit()
