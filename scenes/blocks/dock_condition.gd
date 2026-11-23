extends ConditionBlock

enum Sensor { CHILLED, STALLED, RESCUE }
@export var sensor := Sensor.CHILLED


func evaluate(context: ProgramContext) -> bool:
	var actor := context.character
	if sensor == Sensor.RESCUE:
		for ally: Character in actor.get_tree().get_nodes_in_group("players"):
			if ally != actor and ally.is_dead and actor.global_position.distance_to(ally.global_position) <= Character.RESCUE_RANGE:
				return true
	else:
		for enemy: Enemy in actor.get_tree().get_nodes_in_group("enemies"):
			if enemy.dying or actor.global_position.distance_to(enemy.global_position) > Damage.FLAME_WAVE_RADIUS:
				continue
			if sensor == Sensor.CHILLED and enemy.slow_time > 0.0:
				return true
			if sensor == Sensor.STALLED and enemy is Lunger and enemy.is_stalled():
				return true
	return false


func describe(_context: ProgramContext) -> String:
	return $Row/Label.text
