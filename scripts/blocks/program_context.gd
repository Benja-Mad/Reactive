class_name ProgramContext
extends RefCounted

var character: Character
## Lo que pasó en esta ejecución, en orden, para mostrarle al jugador por qué.
var trace: PackedStringArray = []


func _init(p_character: Character) -> void:
	character = p_character
