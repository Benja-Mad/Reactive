## Procedural billboard artwork, baked once. Every displayed word is English.
extends Control
var variant: int = 0
var face: SystemFont
var mono: SystemFont

func _ready() -> void:
	face = SystemFont.new()
	face.font_names = PackedStringArray(["Helvetica Neue", "Arial"])
	face.font_weight = 900
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas"])
	queue_redraw()

func words(at: Vector2, text: String, size: int, color: Color, technical: bool = false) -> void:
	draw_string(mono if technical else face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if face == null: return
	var ink := Color("100e24")
	var pink := Color("ee599e")
	var violet := Color("8c64e8")
	var cream := Color("eee4d7")
	var cyan := Color("63dfd0")
	draw_rect(Rect2(0, 0, 960, 400), ink)
	if variant == 0:
		# Fashion-tech campaign: oversized cropped halo and an angular synthetic face.
		draw_colored_polygon(PackedVector2Array([Vector2(555,0),Vector2(960,0),Vector2(960,400),Vector2(470,400)]), pink)
		draw_arc(Vector2(739,188), 180, 0, TAU, 48, cream, 14, false)
		var head := PackedVector2Array([Vector2(696,51),Vector2(804,66),Vector2(844,126),Vector2(824,186),Vector2(853,218),Vector2(817,232),Vector2(805,283),Vector2(752,304),Vector2(685,266),Vector2(663,183),Vector2(671,101)])
		draw_colored_polygon(head, ink)
		draw_colored_polygon(PackedVector2Array([Vector2(741,74),Vector2(799,87),Vector2(819,130),Vector2(793,175),Vector2(813,222),Vector2(783,267),Vector2(751,281),Vector2(753,199)]), violet)
		draw_colored_polygon(PackedVector2Array([Vector2(683,156),Vector2(830,144),Vector2(821,174),Vector2(688,190)]), cyan)
		for x: int in range(695, 815, 15): draw_line(Vector2(x,158), Vector2(x-4,179), ink, 4)
		draw_colored_polygon(PackedVector2Array([Vector2(710,281),Vector2(785,294),Vector2(802,332),Vector2(897,400),Vector2(585,400),Vector2(689,327)]), ink)
		words(Vector2(30,42), "AFTERHUMAN / OPTICS", 23, cyan, true)
		words(Vector2(25,157), "YOUR EYES.", 76, cream)
		words(Vector2(25,244), "NO LIMITS.", 76, cream)
		draw_rect(Rect2(30,283,366,54), cyan)
		words(Vector2(43,323), "UPGRADE YOUR NIGHT", 28, ink)
		words(Vector2(32,378), "AH—08    SEE WHAT THEY HIDE.", 19, cream, true)
		words(Vector2(860,54), "08", 47, ink)
	elif variant == 1:
		# Street-food shop: warm orange, graphic bowl, deliberately unlike the optics ad.
		var orange := Color("f29b52")
		draw_rect(Rect2(0,0,960,400), Color("231a26"))
		draw_circle(Vector2(196,196), 161, orange)
		draw_arc(Vector2(196,181), 107, 0, PI, 16, ink, 21, false)
		draw_line(Vector2(80,181),Vector2(311,181),ink,16)
		for x: float in [156,198,240]:
			draw_polyline(PackedVector2Array([Vector2(x,151),Vector2(x-16,126),Vector2(x+12,102),Vector2(x,77)]), ink, 10)
		draw_line(Vector2(202,165),Vector2(300,68),ink,9)
		words(Vector2(388,142), "GHOST", 104, cream)
		words(Vector2(390,244), "RAMEN", 104, orange)
		words(Vector2(394,310), "REAL HEAT. SYNTH MEAT.", 26, cream, true)
		words(Vector2(394,365), "OPEN ALL NIGHT  /  LEVEL -02", 22, orange, true)
	elif variant == 3:
		# Clinic identity: a broken cross and a pulse, large enough to read from combat.
		draw_rect(Rect2(0,0,960,400), Color("142b32"))
		draw_rect(Rect2(95,70,90,260), cyan)
		draw_rect(Rect2(10,155,260,90), cyan)
		draw_polyline(PackedVector2Array([Vector2(10,202),Vector2(80,202),Vector2(111,156),Vector2(141,252),Vector2(173,202),Vector2(270,202)]), ink, 13)
		words(Vector2(318,155), "DRIFT", 105, cream)
		words(Vector2(318,265), "CLINIC", 105, cyan)
		words(Vector2(320,350), "AFTER-HOURS REPAIRS", 27, cream, true)
	elif variant == 4:
		draw_rect(Rect2(0,0,960,400), Color("201a30"))
		for i: int in 3:
			draw_rect(Rect2(45+i*26,65+i*68,200,52), violet)
			draw_rect(Rect2(68+i*26,81+i*68,35,20), cream)
		words(Vector2(340,150), "MEMORY", 92, cream)
		words(Vector2(340,252), "BANKS", 100, violet)
		words(Vector2(342,345), "KEEP A COPY OF YOURSELF", 24, cream, true)
	else:
		# Repeated only in the distant city, with a bold single symbol.
		draw_rect(Rect2(0,0,960,400), Color("182e40"))
		words(Vector2(35,180), "NIGHTLINE", 120, cyan)
		words(Vector2(43,295), "THE CITY NEVER STOPS.", 45, cream)
		draw_line(Vector2(45,350),Vector2(905,350),violet,13)
