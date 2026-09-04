class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float, source: Node)
signal shield_changed(current: float)
signal died(source: Node)

@export var max_health: float = 100.0
var current_health: float = -1.0
var shield: float = 0.0


func _ready() -> void:
	_ensure_initialized()
	health_changed.emit(current_health, max_health)


func apply_damage(amount: float, source: Node = null) -> float:
	_ensure_initialized()
	var pending: float = maxf(amount, 0.0)
	if shield > 0.0:
		var absorbed: float = minf(shield, pending)
		shield -= absorbed
		pending -= absorbed
		shield_changed.emit(shield)
	if pending <= 0.0:
		return 0.0
	var previous: float = current_health
	current_health = maxf(current_health - pending, 0.0)
	var applied: float = previous - current_health
	damaged.emit(applied, source)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit(source)
	return applied


func heal(amount: float, source: Node = null) -> float:
	_ensure_initialized()
	var previous: float = current_health
	current_health = minf(current_health + maxf(amount, 0.0), max_health)
	var applied: float = current_health - previous
	if applied > 0.0:
		healed.emit(applied, source)
		health_changed.emit(current_health, max_health)
	return applied


func add_shield(amount: float) -> void:
	shield += maxf(amount, 0.0)
	shield_changed.emit(shield)


func get_health_ratio() -> float:
	_ensure_initialized()
	return current_health / max_health if max_health > 0.0 else 0.0


func is_alive() -> bool:
	_ensure_initialized()
	return current_health > 0.0


func _ensure_initialized() -> void:
	if current_health < 0.0:
		current_health = max_health
