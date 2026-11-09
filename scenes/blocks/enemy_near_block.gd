extends ConditionBlock

@export var radius: float = 4.0


func evaluate(context: ProgramContext) -> bool:
	return nearest_enemy_distance(context) <= radius


func describe(context: ProgramContext) -> String:
	var distance := nearest_enemy_distance(context)
	if distance == INF:
		return "sin enemigos"
	return "enemigo a %.1f m ≤ %d m" % [distance, roundi(radius)]


static func nearest_enemy_distance(context: ProgramContext) -> float:
	var character := context.character
	if character == null:
		return INF
	var nearest := INF
	for node in character.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy != null:
			nearest = minf(nearest, enemy.global_position.distance_to(character.global_position))
	return nearest
