class_name ReactiveDistrictController
extends Node

signal reactive_state_changed(values: Dictionary)

@export_range(0.0, 1.0, 0.01) var network_load: float = 0.42
@export_range(0.0, 1.0, 0.01) var alert_level: float = 0.08
@export_range(0.0, 1.0, 0.01) var corruption: float = 0.08
@export_range(0.0, 1.0, 0.01) var power: float = 0.88
@export_range(0.0, 1.0, 0.01) var electric_activity: float = 0.35
@export_range(0.0, 1.0, 0.01) var heat_level: float = 0.18
@export_range(0.0, 1.0, 0.01) var biological_activity: float = 0.12
@export_range(0.0, 1.0, 0.01) var wave_intensity: float = 0.72
@export_range(0.0, 1.0, 0.01) var blackout_amount: float = 0.0
@export var wave_direction: Vector2 = Vector2(0.72, 0.68)
@export_range(0.01, 1.0, 0.01) var wave_speed: float = 0.12
@export_range(0.02, 0.45, 0.01) var wave_width: float = 0.16
@export var wave_phase: float = 0.0
@export var transition_speed: float = 3.5
@export var auto_demo: bool = true

var effect_time: float = 0.0
var _demo_time: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _uniforms_by_material: Dictionary = {}
var _targets: Dictionary = {}
var _values: Dictionary = {}


func _ready() -> void:
	_targets = _state_dictionary()
	_values = _targets.duplicate(true)
	_push_material_parameters()


func _process(delta: float) -> void:
	effect_time += delta
	if auto_demo:
		_update_auto_demo(delta)
	var blend: float = 1.0 - exp(-transition_speed * delta)
	for key_value: Variant in _targets.keys():
		var key: String = str(key_value)
		_values[key] = lerpf(float(_values.get(key, 0.0)), float(_targets[key]), blend)
	_sync_exported_values()
	_push_material_parameters()
	reactive_state_changed.emit(_values.duplicate())


func set_materials(materials: Array[ShaderMaterial]) -> void:
	_materials = materials
	_uniforms_by_material.clear()
	for material: ShaderMaterial in _materials:
		var uniform_names: Dictionary = {}
		if material.shader != null:
			for entry: Dictionary in material.shader.get_shader_uniform_list():
				uniform_names[StringName(str(entry.get("name", "")))] = true
		_uniforms_by_material[material.get_instance_id()] = uniform_names
	_push_material_parameters()


func set_signal_target(signal_name: String, value: float, disable_demo: bool = true) -> void:
	if not _targets.has(signal_name):
		return
	_targets[signal_name] = clampf(value, 0.0, 1.0)
	if disable_demo:
		auto_demo = false


func set_wave_direction(direction: Vector2) -> void:
	wave_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2(0.72, 0.68)


func set_wave_speed(value: float) -> void:
	wave_speed = clampf(value, 0.01, 1.0)


func trigger_wave(intensity: float = 1.0) -> void:
	auto_demo = false
	_targets["wave_intensity"] = clampf(intensity, 0.0, 1.0)
	wave_phase = fmod(effect_time * wave_speed + 0.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_method(func(value: float) -> void: _targets["wave_intensity"] = value, float(_targets["wave_intensity"]), 0.18, 1.6)


func trigger_blackout() -> void:
	auto_demo = false
	_targets["blackout_amount"] = 1.0
	_targets["power"] = 0.28


func recover_power() -> void:
	auto_demo = false
	_targets["blackout_amount"] = 0.0
	_targets["power"] = 0.9


func preset_normal() -> void:
	_apply_preset({"network_load": 0.28, "alert_level": 0.04, "corruption": 0.02, "power": 0.92, "electric_activity": 0.25, "heat_level": 0.16, "biological_activity": 0.12, "wave_intensity": 0.18, "blackout_amount": 0.0})


func preset_alert() -> void:
	_apply_preset({"network_load": 0.55, "alert_level": 0.82, "corruption": 0.08, "power": 0.82, "electric_activity": 0.62, "heat_level": 0.48, "biological_activity": 0.12, "wave_intensity": 0.48, "blackout_amount": 0.08})


func preset_network_overload() -> void:
	_apply_preset({"network_load": 1.0, "alert_level": 0.42, "corruption": 0.16, "power": 0.72, "electric_activity": 1.0, "heat_level": 0.66, "biological_activity": 0.1, "wave_intensity": 1.0, "blackout_amount": 0.16})


func preset_corrupted() -> void:
	_apply_preset({"network_load": 0.74, "alert_level": 0.55, "corruption": 0.92, "power": 0.58, "electric_activity": 0.78, "heat_level": 0.36, "biological_activity": 0.28, "wave_intensity": 0.78, "blackout_amount": 0.34})


func get_values() -> Dictionary:
	return _values.duplicate()


func _apply_preset(preset: Dictionary) -> void:
	auto_demo = false
	for key_value: Variant in preset.keys():
		_targets[str(key_value)] = float(preset[key_value])


func _update_auto_demo(delta: float) -> void:
	_demo_time = fmod(_demo_time + delta, 18.0)
	_targets["wave_intensity"] = 0.78
	if _demo_time < 7.0:
		_targets["blackout_amount"] = 0.0
		_targets["power"] = 0.9
	elif _demo_time < 11.0:
		_targets["blackout_amount"] = smoothstep(7.0, 11.0, _demo_time)
		_targets["power"] = lerpf(0.9, 0.3, smoothstep(7.0, 11.0, _demo_time))
	elif _demo_time < 14.0:
		_targets["blackout_amount"] = 1.0
		_targets["power"] = 0.3
	else:
		var recovery: float = smoothstep(14.0, 18.0, _demo_time)
		_targets["blackout_amount"] = 1.0 - recovery
		_targets["power"] = lerpf(0.3, 0.9, recovery)


func _state_dictionary() -> Dictionary:
	return {
		"network_load": network_load,
		"alert_level": alert_level,
		"corruption": corruption,
		"power": power,
		"electric_activity": electric_activity,
		"heat_level": heat_level,
		"biological_activity": biological_activity,
		"wave_intensity": wave_intensity,
		"blackout_amount": blackout_amount,
	}


func _sync_exported_values() -> void:
	network_load = float(_values["network_load"])
	alert_level = float(_values["alert_level"])
	corruption = float(_values["corruption"])
	power = float(_values["power"])
	electric_activity = float(_values["electric_activity"])
	heat_level = float(_values["heat_level"])
	biological_activity = float(_values["biological_activity"])
	wave_intensity = float(_values["wave_intensity"])
	blackout_amount = float(_values["blackout_amount"])


func _push_material_parameters() -> void:
	for material: ShaderMaterial in _materials:
		_set_if_present(material, &"cs_network_load", network_load)
		_set_if_present(material, &"cs_alert_level", alert_level)
		_set_if_present(material, &"cs_corruption", corruption)
		_set_if_present(material, &"cs_power", power)
		_set_if_present(material, &"cs_electric_activity", electric_activity)
		_set_if_present(material, &"cs_wave_intensity", wave_intensity)
		_set_if_present(material, &"cs_wave_direction", wave_direction.normalized())
		_set_if_present(material, &"cs_wave_speed", wave_speed)
		_set_if_present(material, &"cs_wave_width", wave_width)
		_set_if_present(material, &"cs_wave_phase", wave_phase)
		_set_if_present(material, &"cs_blackout", blackout_amount)
		_set_if_present(material, &"cs_effect_time", effect_time)


func _set_if_present(material: ShaderMaterial, parameter: StringName, value: Variant) -> void:
	var uniform_names: Dictionary = _uniforms_by_material.get(material.get_instance_id(), {}) as Dictionary
	if uniform_names.has(parameter):
		material.set_shader_parameter(parameter, value)
