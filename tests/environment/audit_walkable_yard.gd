## Physics-based census: actual player capsule, floor rays and swept links at 0.5 m spacing.
extends SceneTree
func _initialize() -> void: call_deferred("audit")
func audit() -> void:
	var preview = load("res://tests/environment/stylized_yard.tscn").instantiate()
	root.add_child(preview)
	while preview.trial == null or not preview.trial.enabled: await process_frame
	preview.run.test_mode = true
	paused = true
	var arena = preview.scene.get_node("Arena")
	var yard = arena.sector_runtime.collision
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	var player = preview.run.local_player()
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = player.get_node("CollisionShape3D").shape
	probe.collision_mask = 1
	probe.margin = 0.02
	probe.exclude = [player.get_rid()]
	# A visible open frame must be traversable; its old single convex hull filled the doorway.
	var frame: MeshInstance3D = arena.sector_runtime.imported_environment.find_child("Barrier_Frame",true,false)
	var opening: Vector3 = frame.global_transform * frame.get_aabb().get_center()
	opening.y = 1.1
	probe.transform.origin = opening
	assert(space.intersect_shape(probe,1).is_empty(), "Empty barrier doorway still blocks the player")
	probe.transform.origin = opening - frame.global_basis.z*1.4
	probe.motion = frame.global_basis.z*2.8
	assert(space.cast_motion(probe)[0] > 0.999, "Capsule cannot cross the open frame")
	probe.motion = Vector3.ZERO
	if frame.is_visible_in_tree():
		probe.transform.origin = frame.global_transform * Vector3(3.0,1.1,0)
		probe.motion = -frame.global_basis.x
		assert(space.cast_motion(probe)[0] < 1.0, "Frame post lost its solid collision")
		probe.motion = Vector3.ZERO
	else:
		# The depot retired the mid-yard «C/S TRANSIT» frame (depot_yard.gd): a bus stop with no
		# street. Retired, it must leave no solid behind where its posts stood.
		probe.transform.origin = frame.global_transform * Vector3(2.0,1.1,0)
		assert(space.intersect_shape(probe,1).is_empty(), "Retired frame left a solid post")
		probe.transform.origin = frame.global_transform * Vector3(-2.0,1.1,0)
		assert(space.intersect_shape(probe,1).is_empty(), "Retired frame left a solid post")
	for name: String in ["Barrier_Field", "Hologram_001", "Stack_Diagnostic"]:
		assert(yard.get_node("Obstacle_"+name).disabled, "Projection collider remains active")
	var old_court: Node = arena.find_child("ContainmentCourt",true,false)
	for mesh: MeshInstance3D in old_court.find_children("*","MeshInstance3D",true,false):
		assert(not mesh.visible, "Retired block assembly is still visible")
	for shape: CollisionShape3D in old_court.find_children("*","CollisionShape3D",true,false):
		assert(shape.disabled, "Retired block assembly leaves a ghost collider")
	var furniture: Node = preview.trial.get_node("DistrictServiceArchitecture")
	for shape: CollisionShape3D in furniture.shapes:
		var mesh: MeshInstance3D = shape.get_parent().get_parent()
		assert(shape.shape.size == mesh.mesh.size, "Furniture collider does not match its visible solid part")
		assert(shape.global_transform.is_equal_approx(mesh.global_transform))
	var cells: Dictionary = {}
	var missing_floor: int = 0
	for z: int in range(int(yard.YARD_MIN.y*2)+1, int(yard.YARD_MAX.y*2)):
		for x: int in range(int(yard.YARD_MIN.x*2)+1, int(yard.YARD_MAX.x*2)):
			var p := Vector3(x*0.5,1.1,z*0.5)
			probe.transform.origin = p
			probe.motion = Vector3.ZERO
			if not space.intersect_shape(probe,1).is_empty(): continue
			var ray := PhysicsRayQueryParameters3D.create(p, p-Vector3.UP*2,1,probe.exclude)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y < 0.9:
				missing_floor += 1
				continue
			cells[Vector2i(x,z)] = true
	var remaining := cells.duplicate()
	var regions: Array[int] = []
	var largest: Array[Vector2i] = []
	var components: Array[Dictionary] = []
	while not remaining.is_empty():
		var queue: Array[Vector2i] = [remaining.keys()[0]]
		remaining.erase(queue[0])
		var head: int = 0
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = cell + step
				if not remaining.has(next): continue
				probe.transform.origin = Vector3(cell.x*0.5,1.1,cell.y*0.5)
				probe.motion = Vector3(step.x*0.5,0,step.y*0.5)
				var sweep := space.cast_motion(probe)
				if sweep[0] < 0.999: continue
				remaining.erase(next)
				queue.append(next)
		var min_cell := Vector2i(999,999)
		var max_cell := Vector2i(-999,-999)
		var spawn_cells: int = 0
		for cell: Vector2i in queue:
			min_cell = min_cell.min(cell)
			max_cell = max_cell.max(cell)
			if absi(cell.x) <= 52 and cell.y >= -30 and cell.y <= 56: spawn_cells += 1
		components.append({"samples":queue.size(),"min":str(Vector2(min_cell)*0.5),"max":str(Vector2(max_cell)*0.5),"within_spawn_rectangle":spawn_cells})
		regions.append(queue.size())
		if queue.size() > largest.size(): largest = queue
	regions.sort()
	regions.reverse()
	var destinations: Dictionary = {}
	for entry: Dictionary in [{"name":"central", "p":Vector2i(-14,-18)}, {"name":"west", "p":Vector2i(-50,18)}, {"name":"east", "p":Vector2i(46,18)}, {"name":"south", "p":Vector2i(0,46)}]:
		var nearest := Vector2i(999,999)
		for cell: Vector2i in largest:
			if cell.distance_squared_to(entry["p"]) < nearest.distance_squared_to(entry["p"]): nearest = cell
		destinations[entry["name"]] = {"nearest_connected_cell":str(Vector2(nearest)*0.5),"distance_m":nearest.distance_to(entry["p"])*0.5}
		assert(nearest.distance_to(entry["p"])*0.5 < 3.0, "District disconnected from main arena")
	# Continuous capsule sweeps must hit each perimeter wall, not escape through its seams.
	var walls_checked: int = 0
	for side: int in 4:
		var checked: bool = false
		for along: int in range(-22,23):
			var starts: Array[Vector3] = [Vector3(-33,1.1,along),Vector3(33,1.1,along),Vector3(along,1.1,27),Vector3(along,1.1,-25)]
			var motions: Array[Vector3] = [Vector3(-3,0,0),Vector3(3,0,0),Vector3(0,0,3),Vector3(0,0,-3)]
			probe.transform.origin = starts[side]
			probe.motion = Vector3.ZERO
			if not space.intersect_shape(probe,1).is_empty(): continue
			probe.motion = motions[side]
			assert(space.cast_motion(probe)[0] < 1.0, "Open perimeter collision")
			checked = true
			break
		assert(checked, "No clear test position on perimeter side")
		walls_checked += 1
	var hidden_colliders: Array[String] = []
	for item: Dictionary in preview.trial.changed:
		if not item["hide"]: continue
		var mesh: MeshInstance3D = item["node"]
		var shape: Node = yard.get_node_or_null("Obstacle_"+str(mesh.name))
		if shape != null and not shape.disabled and not preview.trial.has_node("Painted_"+str(mesh.name)): hidden_colliders.append(str(mesh.name))
	var span: Vector2 = yard.YARD_MAX-yard.YARD_MIN
	var report := {"open_frame_capsule_pass":true,"frame_post_still_solid":true,"retired_block_assembly_clear":true,"furniture_shapes_match_visuals":true,"projection_colliders_disabled":true,"components":components,"retired_colliders":preview.trial.collision_changes.size(),"replacement_shapes":preview.trial.replacement_collisions.size(),"district_connections":destinations,"perimeter_sweeps_passed":walls_checked,"bounds_min":str(yard.YARD_MIN),"bounds_max":str(yard.YARD_MAX),"nominal_area_m2":span.x*span.y,"free_capsule_samples":cells.size(),"connected_regions_samples":regions,"largest_connected_area_m2_approx":regions[0]*0.25,"sampling_step_m":0.5,"missing_floor_samples":missing_floor,"straight_crossing_seconds_at_base_speed":str(span/3.5),"hidden_source_colliders":hidden_colliders}
	print("YARD AUDIT ",JSON.stringify(report))
	var file := FileAccess.open(preview.output.path_join("walkability.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	assert(hidden_colliders.is_empty(), "Removed decor leaves an active collider")
	assert(missing_floor == 0, "Walkable sample has no supporting floor")
	assert(regions[0]*0.25 > 1800, "Main connected arena too small")
	paused = false
	preview.queue_free()
	for i in 4: await process_frame
	quit()
