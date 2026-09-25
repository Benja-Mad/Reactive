extends SceneTree

func _initialize() -> void:
	var state := preload("res://scenes/environment/sector_08/runtime/ground_surface_state.gd").new()
	var emitter := GPUParticles3D.new()
	emitter.amount_ratio = 0.45
	state.setup([], [emitter])
	assert(state.set_patch("crater", Vector2.ZERO, 4.0, 0.0, 0.8))
	state.set_rain(1.0)
	state._process(10.0)
	assert(state.patches["crater"]["moisture"] > 0.0)
	assert(is_equal_approx(state.patches["crater"]["fracture"], 0.8))
	state.set_rain(0.0)
	assert(emitter.amount_ratio == 0.0)
	var before: float = state.patches["crater"]["moisture"]
	state._process(10.0)
	assert(state.patches["crater"]["moisture"] < before)
	for i in 7:
		assert(state.set_patch(StringName(str(i)), Vector2(i, 0), 1.0, 0.5))
	assert(not state.set_patch("overflow", Vector2.ZERO, 2.0, 0.5))
	assert(state.set_patch("crater", Vector2.ONE, 4.0, 1.0, 0.3))
	assert(state.patches.size() == 8)
	assert(not state.set_patch("crater", Vector2.ZERO, 0.0, 0.0))
	state.remove_patch("crater")
	assert(state.set_patch("replacement", Vector2.ZERO, 3.0, 0.5))
	state._process(10000.0)
	assert(state.moisture == 0.0)
	state.free()
	emitter.free()
	print("GROUND SURFACE STATE PASS: rain, drying, independent fracture, capacity, replacement, invalid radius")
	quit()
