class_name CombatFeedback
extends RefCounted

enum Burst { MUZZLE, ICE_CAST, HIT, ICE_HIT, VENT, EJECT, SLASH, HEAL }

const CELL_SIZE := 112

const ATLAS := preload("res://materials/combat/bursts.png")
const SOUNDS: Array[AudioStream] = [
	preload("res://materials/combat/ignition.wav"), preload("res://materials/combat/ice_cast.wav"),
	preload("res://materials/combat/impact.wav"), preload("res://materials/combat/impact.wav"),
	preload("res://materials/combat/vent.wav"), preload("res://materials/combat/eject.wav"),
	preload("res://materials/combat/slice.wav"), null,
]


static func sound(source: Node3D, stream: AudioStream, gain: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.unit_size = 26.0
	voice.max_distance = 64.0
	voice.volume_db = gain
	source.get_tree().current_scene.add_child(voice)
	voice.global_position = source.global_position
	voice.finished.connect(voice.queue_free)
	voice.play()
	return voice


static func burst(source: Node3D, kind: Burst, at: Vector3, size: float, duration: float) -> void:
	var sparks := Sprite3D.new()
	sparks.texture = ATLAS
	sparks.hframes = ATLAS.get_width() / CELL_SIZE
	sparks.vframes = ATLAS.get_height() / CELL_SIZE
	sparks.frame = kind * sparks.hframes
	sparks.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sparks.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sparks.pixel_size = size / float(CELL_SIZE)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == Burst.HEAL:
		sparks.offset = Vector2(-36, 16)
	var parent := source if kind == Burst.HEAL else source.get_tree().current_scene
	parent.add_child(sparks)
	sparks.global_position = at
	sparks.render_priority = 3
	play_frames(sparks, duration)
	if SOUNDS[kind]:
		sound(sparks, SOUNDS[kind], -7.5 if kind < Burst.VENT else -5.0)


static func play_frames(sprite: Sprite3D, duration: float) -> void:
	var first := sprite.frame
	var count := sprite.hframes
	var tween := sprite.create_tween()
	tween.tween_method(func(progress: float) -> void:
		sprite.frame = first + mini(count - 1, floori(progress * count)), 0.0, 1.0, duration)
	tween.tween_callback(sprite.queue_free)


static func shed_part(source: Node3D, ground: Vector3, drive: bool) -> void:
	var shell := Sprite3D.new()
	shell.texture = preload("res://materials/combat/salvage.png")
	shell.hframes = 2
	shell.frame = int(drive)
	shell.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shell.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shell.pixel_size = 0.023
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	source.get_tree().current_scene.add_child(shell)
	shell.global_position = source.global_position + Vector3.UP * 0.15
	var land := ground + Vector3(0.85 if drive else -0.60, 0.17, 0.24)
	var arc := shell.create_tween()
	arc.tween_property(shell, "position", (shell.position + land) * 0.5 + Vector3.UP * 0.78, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(shell, "position", land, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	arc.tween_property(shell, "position:y", land.y + 0.12, 0.06)
	arc.tween_property(shell, "position:y", land.y, 0.07)
	arc.tween_interval(1.2)
	arc.tween_property(shell, "modulate:a", 0.0, 0.38)
	arc.tween_callback(shell.queue_free)
