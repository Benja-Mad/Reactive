extends SceneTree
func _initialize() -> void: call_deferred("check")
func check() -> void:
	var preview = load("res://tests/environment/stylized_yard.tscn").instantiate()
	root.add_child(preview)
	while preview.trial == null or not preview.trial.enabled: await process_frame
	preview.run.test_mode = true
	paused = true
	# Reflective decorative overlays must remain absent in the proposed presentation.
	for item: Dictionary in preview.trial.changed:
		var title: String = str(item["node"].name)
		if item["hide"] and (title.begins_with("Puddle") or title.begins_with("Ground_Damp") or title.begins_with("Ground_Patch") or title.begins_with("Road_Patch")):
			assert(not item["node"].visible)
	for item: Dictionary in preview.trial.atmosphere_changes:
		assert(not item["node"].visible)
	var before: Dictionary = preview.collision_snapshot()
	var arena: Node3D = preview.scene.get_node("Arena")
	preview.toggle_city_view()
	for i: int in 30: await process_frame
	assert(is_equal_approx(arena.gameplay_camera.fov,44.0))
	assert(is_equal_approx(arena.framing_distance,66.0))
	preview.toggle_city_view()
	for i: int in 30: await process_frame
	assert(is_equal_approx(arena.gameplay_camera.fov,38.0))
	assert(is_equal_approx(arena.framing_pitch_degrees,38.0))
	assert(preview.collision_snapshot() == before)
	preview.trial.set_enabled(false)
	for item: Dictionary in preview.trial.changed:
		assert(item["node"].visible == item["visible"])
		assert(item["node"].material_override == item["original"])
	for item: Dictionary in preview.trial.atmosphere_changes:
		assert(item["node"].visible == item["visible"])
	for item: Dictionary in preview.trial.collision_changes:
		assert(item["node"].disabled == item["disabled"])
	for shape: CollisionShape3D in preview.trial.replacement_collisions: assert(shape.disabled)
	print("CITY VIEW PASS: wide/combat framing, stable collisions during camera switches, reversible collider repairs, decorative patches hidden, landmark atmosphere restored, original materials and visibility restored")
	paused = false
	preview.queue_free()
	for i: int in 4: await process_frame
	quit()
