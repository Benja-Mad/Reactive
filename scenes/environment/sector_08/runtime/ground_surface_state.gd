## Local presentation state. Gameplay/network authority must drive this API, not particles.
## Moisture and fracture are independent: cracked pavement can still be wet.
extends Node

const MAX_PATCHES := 8
var rain_intensity: float = 0.65
var moisture: float = 0.82
var patches: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var rain_emitters: Array[GPUParticles3D] = []
var rain_ratios: Array[float] = []

func setup(targets: Array[ShaderMaterial], emitters: Array[GPUParticles3D] = []) -> void:
	materials = targets
	rain_emitters = emitters
	for emitter: GPUParticles3D in rain_emitters:
		rain_ratios.append(emitter.amount_ratio / 0.65)
	_upload()

func set_rain(value: float) -> void:
	rain_intensity = clampf(value, 0.0, 1.0)
	for i in rain_emitters.size():
		rain_emitters[i].amount_ratio = minf(1.0, rain_ratios[i] * rain_intensity)
	_upload()

## Bounded, stable IDs allow a spell preview to update without allocating another patch.
## Fracture is a surface preview; it does not deform collision or spawn vegetation.
func set_patch(id: StringName, centre: Vector2, radius: float, wet: float, fracture: float = 0.0) -> bool:
	if radius <= 0.0 or (not patches.has(id) and patches.size() >= MAX_PATCHES):
		return false
	patches[id] = {"centre": centre, "radius": minf(radius, 12.0),
		"moisture": clampf(wet, 0.0, 1.0), "fracture": clampf(fracture, 0.0, 1.0)}
	_upload()
	return true

func remove_patch(id: StringName) -> void:
	patches.erase(id)
	_upload()

func _process(delta: float) -> void:
	# Rain fills slowly; evaporation is deliberately slower. No random frame dependence.
	var target: float = 0.9 if rain_intensity > 0.0 else 0.0
	var rate: float = 0.018 * rain_intensity if rain_intensity > 0.0 else 0.003
	moisture = move_toward(moisture, target, rate * delta)
	for patch: Dictionary in patches.values():
		patch["moisture"] = move_toward(float(patch["moisture"]), target, rate * delta)
	_upload()

func _upload() -> void:
	var areas := PackedVector4Array()
	var states := PackedVector4Array()
	areas.resize(MAX_PATCHES)
	states.resize(MAX_PATCHES)
	var index: int = 0
	for patch: Dictionary in patches.values():
		var centre: Vector2 = patch["centre"]
		areas[index] = Vector4(centre.x, centre.y, patch["radius"], 0.0)
		states[index] = Vector4(patch["moisture"], patch["fracture"], 0.0, 0.0)
		index += 1
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("wetness", moisture)
		material.set_shader_parameter("rainfall", rain_intensity)
		material.set_shader_parameter("surface_patch_count", index)
		material.set_shader_parameter("surface_patch_areas", areas)
		material.set_shader_parameter("surface_patch_states", states)
