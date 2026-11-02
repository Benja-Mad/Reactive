## A painted shop board, baked once into a SubViewport: Spanish lettering in the crew's pixel font
## (res://ui/kit/font.fnt, never a SystemFont that changes per machine), muted paint, no glow.
## The English ad screens it used to draw (optics, ramen, clinic, memory banks) are retired; the
## depot's street signs are built in depot_edges.gd. Kept for any painted board that needs a texture.
extends Control

const FONT := preload("res://ui/kit/font.fnt")
## Each variant: [ground colour, ink colour, lines]. Words from the scene brief's sign list.
const BOARDS: Array = [
	["c9c4b2", "2f4a3e", ["FUENTE DE SODA", "LA PARADA"]],
	["33404a", "d4cbb2", ["BOTILLERÍA"]],
	["8b8466", "2b2b26", ["VULCANIZACIÓN"]],
	["b0a68c", "2c3438", ["TALLER", "MECÁNICA EN GENERAL"]],
	["8a7a62", "d9d2bf", ["SE ARRIENDA"]],
]
var variant: int = 0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var board: Array = BOARDS[clampi(variant, 0, BOARDS.size() - 1)]
	draw_rect(Rect2(Vector2.ZERO, size), Color(board[0]))
	var lines: Array = board[2]
	# Pixel font at whole multiples of its 12 px size so the letters stay crisp.
	var scale_px: int = 96 if lines.size() == 1 else 60
	var step: float = size.y / float(lines.size() + 1)
	for i: int in lines.size():
		var text: String = lines[i]
		var width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, scale_px).x
		draw_string(FONT, Vector2((size.x - width) * 0.5, step * (i + 1) + scale_px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, scale_px, Color(board[1]))
