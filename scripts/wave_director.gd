class_name WaveDirector
extends Node3D

@export var enemy_scene: PackedScene
@export var wave_duration: float = 14.0
@export var initial_count: int = 5
@export var max_active: int = 36
@export var spawn_radius: float = 14.8
var wave: int = 0
var _wave_timer: float = 2.5
var _hud_label: Label


func _ready() -> void:
	_build_hud()


func _process(delta: float) -> void:
	if _is_program_editor_open():
		_update_hud()
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = wave_duration
		_start_next_wave()
	_update_hud()


func _start_next_wave() -> void:
	wave += 1
	var active: int = get_tree().get_nodes_in_group(&"enemies").size()
	var available: int = maxi(max_active - active, 0)
	var count: int = mini(initial_count + wave * 2, available)
	for index: int in count:
		_spawn_enemy(index)


func _spawn_enemy(index: int) -> void:
	if enemy_scene == null:
		return
	var enemy: SurvivorEnemy = enemy_scene.instantiate() as SurvivorEnemy
	if enemy == null:
		return
	var type: SurvivorEnemy.Archetype = SurvivorEnemy.Archetype.CHASER
	if wave >= 2 and index % 4 == 1:
		type = SurvivorEnemy.Archetype.FAST
	if wave >= 3 and index % 7 == 0:
		type = SurvivorEnemy.Archetype.TANK
	enemy.configure(type, wave)
	var angle: float = TAU * float(index) / maxf(float(initial_count + wave * 2), 1.0) + randf_range(-0.2, 0.2)
	enemy.position = Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
	add_child(enemy)


func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	var backing: ColorRect = ColorRect.new()
	backing.color = Color(0.02, 0.035, 0.055, 0.82)
	backing.position = Vector2(20.0, 228.0)
	backing.size = Vector2(250.0, 68.0)
	canvas.add_child(backing)
	_hud_label = Label.new()
	_hud_label.position = Vector2(34.0, 238.0)
	_hud_label.add_theme_font_size_override(&"font_size", 20)
	canvas.add_child(_hud_label)


func _update_hud() -> void:
	if _hud_label == null:
		return
	if _is_program_editor_open():
		_hud_label.text = "SAFE SETUP · COMPILE PROGRAM\nP toggles the block editor"
		return
	_hud_label.text = "WAVE %02d  ·  ENEMIES %02d\nNext pressure: %.1fs · P: program" % [wave, get_tree().get_nodes_in_group(&"enemies").size(), maxf(_wave_timer, 0.0)]


func _is_program_editor_open() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"program_editors"):
		var editor: ProgrammingBlock = node as ProgrammingBlock
		if editor != null and editor.is_editor_open():
			return true
	return false
