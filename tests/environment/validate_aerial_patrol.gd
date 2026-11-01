extends SceneTree
func _initialize() -> void: call_deferred("check")
func check() -> void:
	var preview = load("res://tests/environment/stylized_yard.tscn").instantiate()
	root.add_child(preview)
	while preview.trial == null or not preview.trial.enabled: await process_frame
	var patrol = preview.trial.get_node("AerialPatrol")
	patrol.set_process(false)
	var collisions: Dictionary = environment_collisions(preview)
	patrol.elapsed = 0.0
	patrol._process(4.0)
	assert(patrol.lamp.light_energy == 0.0)
	patrol._process(3.0)
	assert(patrol.in_pass and patrol.lamp.light_energy > 0.0)
	var first: Vector3 = patrol.lamp.global_position
	var origin: Vector3 = patrol.route_origin
	var player = preview.run.local_player()
	player.global_position += Vector3(2,0,0)
	patrol._process(2.0)
	assert(patrol.route_origin == origin, "Patrol must not track the player mid-pass")
	assert(patrol.lamp.global_position.distance_to(first) > 1.0)
	patrol._process(6.0)
	assert(not patrol.in_pass and patrol.lamp.light_energy == 0.0)
	patrol._process(30.0)
	assert(patrol.in_pass and patrol.lamp.light_energy > 0.0, "Patrol must recur")
	patrol.sample_pass(0.0,origin)
	assert(patrol.lamp.light_energy == 0.0)
	patrol.sample_pass(1.0,origin)
	assert(patrol.lamp.light_energy == 0.0)
	patrol.set_process(true)
	paused = true
	var clock_before: float = patrol.elapsed
	for i: int in 12: await process_frame
	assert(patrol.elapsed == clock_before, "Patrol advanced during pause")
	paused = false
	preview.trial.set_enabled(false)
	patrol._process(0.1)
	assert(patrol.lamp.light_energy == 0.0)
	preview.trial.set_enabled(true)
	assert(environment_collisions(preview) == collisions)
	preview.queue_free()
	for i: int in 4: await process_frame
	assert(not is_instance_valid(patrol))
	print("AERIAL PATROL PASS: schedule, sweep, fixed route, recurrence, fades, pause, visibility, collisions, teardown")
	quit()

func environment_collisions(preview: Node) -> Dictionary:
	var result: Dictionary = {}
	var arena: Node = preview.scene.get_node("Arena")
	for shape: CollisionShape3D in arena.find_children("*","CollisionShape3D",true,false):
		result[str(arena.get_path_to(shape))] = [shape.shape,shape.global_transform,shape.disabled]
	return result
