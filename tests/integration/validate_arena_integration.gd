## Boots the real game scene and checks that the diorama arena has actually replaced the old
## map: the approved framing owns the camera, the players spawn on the arena floor, movement is
## expressed in the camera's frame, and the rig follows without ever rotating.
##
## Runs as a scene, not with --script, because it needs the Game/Lobby autoloads.
extends Node

const SETTLE_FRAMES: int = 45

var report: Dictionary = {}
## Kept apart from `report` so an informational field that happens to be false -- "the code block
## did not have focus", say -- is never miscounted as a failed check.
var checks: Dictionary = {}
var _out: String = "res://arena_integration.json"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	call_deferred("_run")


func _run() -> void:
	get_window().size = Vector2i(1920, 1080)
	# Two seats, so index-based spawn placement is exercised rather than a single default.
	Game.instance.players = [
		Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.SUPPORT),
		Statics.PlayerData.new(multiplayer.get_unique_id() + 1, "Remote", 1, Statics.Role.DAMAGE),
	]
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	for i in SETTLE_FRAMES: await get_tree().process_frame

	var arena: DioramaArena = scene.get_node("Arena")
	var camera: Camera3D = arena.gameplay_camera
	var approved: Transform3D = arena.approved_transform

	_check("arena_replaced_world_map", scene.get_node_or_null("WorldMap") == null and arena != null)
	_check("no_stray_scene_lights", scene.get_node_or_null("DirectionalLight3D") == null)
	_check("arena_camera_is_current", camera.current)
	_check("fov_is_30", is_equal_approx(camera.fov, 30.0))
	_check("basis_preserved", camera.global_basis.is_equal_approx(approved.basis))
	_check("lookdev_tools_off", not arena.lookdev_tools)
	_check("stand_in_hidden", not arena.test_character.visible)
	_check("debug_overlay_hidden", not arena.debug_layer.visible)
	_check("collision_built", int(arena.sector_runtime.collision.stats.get("total_shapes", 0)) > 100)

	# Movement frame must be the camera's, not world axes.
	var camera_right: Vector3 = Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
	_check("movement_frame_is_camera_relative", Character.movement_basis.x.normalized().dot(camera_right) > 0.999)
	_check("movement_frame_not_world_aligned", absf(Character.movement_basis.x.dot(Vector3.RIGHT)) < 0.999)

	var players: Node3D = scene.get_node("Players")
	var characters: Array[Character] = []
	for child: Node in players.get_children():
		var character := child as Character
		if character != null:
			characters.append(character)
	_check("players_spawned", characters.size() >= 1)
	report["player_count"] = characters.size()

	if characters.is_empty():
		_finish()
		return

	var local: Character = characters[0]
	# The programming block's editor grabs focus, and Character._physics_process returns early
	# while it has it -- so move_and_slide never runs and the body neither settles nor walks.
	var code_block: Control = local.programming_block.get_node("CodeBlock") as Control
	report["code_block_had_focus"] = code_block.has_focus()
	code_block.release_focus()
	for i in 60: await get_tree().process_frame
	# Feet, not origin: this capsule is centred on the body, unlike the lookdev walker's.
	var body_shape: CollisionShape3D = local.get_node("CollisionShape3D")
	var feet: float = local.global_position.y + body_shape.position.y - (body_shape.shape as CapsuleShape3D).height * 0.5
	report["feet_height_m"] = snappedf(feet, 0.001)
	report["rest_height_m"] = snappedf(local.global_position.y, 0.001)
	_check("player_rests_on_arena_floor", local.is_on_floor() and absf(feet) < 0.35)
	for character: Character in characters:
		_check("character_camera_yielded_%s" % character.name, not character.camera_3d.current)

	# Drive the local player and confirm both that it moves in the camera's frame and that the
	# rig translates after it without touching the basis.
	var start: Vector3 = local.global_position
	var camera_start: Vector3 = camera.global_position
	# Drive real actions: InputSynchronizer rewrites move_input from Input every physics tick on
	# the authority, so assigning the field directly would be overwritten before it was read.
	report["rig_enabled"] = arena.camera_rig.enabled
	report["rig_has_target"] = arena.camera_rig.target != null
	_check("rig_follows_local_player", arena.camera_rig.enabled and arena.camera_rig.target == local)
	Input.action_press("move_right")
	for i in 120: await get_tree().process_frame
	Input.action_release("move_right")
	for i in 20: await get_tree().process_frame
	var travelled: Vector3 = local.global_position - start
	report["travel_m"] = snappedf(travelled.length(), 0.01)
	_check("player_moved", travelled.length() > 1.0)
	_check("moved_along_camera_right", travelled.normalized().dot(camera_right) > 0.9)
	# Walking distance is not a reliable way to leave the dead zone: the yard has props, and a
	# run that clips one travels half as far and legitimately moves the camera not at all. Place
	# the target at a known excursion instead, so this measures the rig and not the pathing.
	var excursion: Vector3 = local.global_position
	excursion = Vector3(arena.framing_target.x, local.global_position.y, arena.framing_target.z) + camera_right * 11.0
	local.global_position = excursion
	local.velocity = Vector3.ZERO
	for i in 120: await get_tree().process_frame
	report["camera_translated_m"] = snappedf(camera.global_position.distance_to(camera_start), 0.01)
	_check("camera_followed", camera.global_position.distance_to(camera_start) > 0.25)
	report["rig_offset"] = arena.camera_rig.get_report()
	_check("basis_still_preserved", camera.global_basis.is_equal_approx(approved.basis))
	_check("fov_still_30", is_equal_approx(camera.fov, 30.0))
	_check("camera_within_travel_limit", absf(arena.camera_rig.offset.x) <= arena.follow_limit.x + 0.01 and absf(arena.camera_rig.offset.y) <= arena.follow_limit.y + 0.01)

	# Respawn anchors: the spawn function runs on every peer with the replicated seat data, so the
	# position is set before the body enters the tree and _ready() captures a real spawn rather
	# than the world origin. Asserted rather than assumed, since a regression here teleports a
	# defeated player into the middle of nowhere.
	var anchors: Array = []
	for character: Character in characters:
		anchors.append(str(character.respawn_position.snappedf(0.01)))
		_check("respawn_anchor_is_a_spawn_%s" % character.name, character.respawn_position.length() > 0.5)
	report["respawn_anchors"] = anchors

	# --- the lateral edges ---------------------------------------------------------------------
	# The reported defect was standing on nothing at the left edge and walking through the fence.
	# Both are geometry facts, so they are asserted as geometry rather than by driving the player
	# into a corner and hoping the run reproduces it.
	var runtime: Node = arena.sector_runtime
	var perimeter: Node = runtime.perimeter
	_check("perimeter_built", perimeter != null)
	if perimeter != null:
		report["perimeter"] = perimeter.stats
		_check("walkable_area_paved", float(perimeter.stats["walkable_paved_pct_after"]) > 92.0)
		# Ground under the ring the player can actually reach, which is where the holes were.
		# "Reachable" has to mean a body fits there: a ring sample inside a building wall is not
		# a hole in the floor, and counting those made this read 81.9% when the walkable edge was
		# in fact covered.
		var ring: Dictionary = _ring_coverage(perimeter)
		report["reachable_ring"] = ring
		# 96%, not 100%: coverage is sampled on a 1 m grid while the yard is tiled at 3.25 m, so a
		# sample can land in the 3 cm joint between two slabs. Those show up as unpaved and are
		# reported with their neighbours, which is how a real hole is told from a joint -- a joint
		# has paving on all four sides of it.
		_check("reachable_ring_paved", float(ring["paved_pct"]) > 96.0)
		# The fence has to stand on the wall that stops the player, not inside the yard behind it.
		var fence: MultiMeshInstance3D = perimeter.get_node_or_null("PerimeterFence")
		_check("fence_exists", fence != null)
		if fence != null:
			var side_panels: int = 0
			var off_line: int = 0
			for i in fence.multimesh.instance_count:
				var origin: Vector3 = fence.multimesh.get_instance_transform(i).origin
				if absf(absf(origin.x) - perimeter.FENCE_LINE) < 0.05:
					side_panels += 1
				elif absf(origin.z - perimeter.FENCE_SOUTH_Z) > 0.05:
					off_line += 1
			report["fence_side_panels"] = side_panels
			report["fence_panels_off_line"] = off_line
			_check("fence_on_the_bound_line", side_panels >= 24 and off_line == 0)
	# A wall the player meets before the fence plane, on all three reachable sides.
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	probe.shape = capsule
	var blocked: Dictionary = {}
	for entry: Array in [["west", Vector3(runtime.collision.YARD_MIN.x - 0.2, 1.0, 0.0)], ["east", Vector3(runtime.collision.YARD_MAX.x + 0.2, 1.0, 0.0)], ["south", Vector3(0.0, 1.0, runtime.collision.YARD_MAX.y + 0.2)]]:
		probe.transform = Transform3D(Basis(), entry[1])
		blocked[str(entry[0])] = not space.intersect_shape(probe, 1).is_empty()
	report["bounds_blocked"] = blocked
	_check("bounds_stop_player_at_fence", blocked["west"] and blocked["east"] and blocked["south"])

	# The foreground board is placed in screen space, so a change of framing is exactly when it can
	# quietly grow. Its band is measured here rather than assumed -- and measured at each end of the
	# rig's vertical travel as well as on the composed framing, because the board is world geometry
	# and the camera moving up or down slides it across the frame.
	if runtime.billboard != null:
		report["billboard"] = runtime.billboard.get_report()
		var height: float = get_viewport().get_visible_rect().size.y
		var bands: Dictionary = {}
		for entry: Array in [["composed", 0.0], ["rig_up", arena.follow_limit.y], ["rig_down", -arena.follow_limit.y]]:
			arena.camera_rig.offset = Vector2(0.0, float(entry[1]))
			arena.camera_rig._apply()
			await get_tree().process_frame
			bands[str(entry[0])] = snappedf(1.0 - camera.unproject_position(runtime.billboard.global_position).y / height, 0.001)
		arena.camera_rig.offset = Vector2.ZERO
		arena.camera_rig._apply()
		await get_tree().process_frame
		report["billboard_band"] = bands
		report["billboard_band_swing"] = snappedf(absf(float(bands["rig_up"]) - float(bands["rig_down"])), 0.001)
		_check("billboard_closes_edge_without_dominating", float(bands["composed"]) > 0.03 and float(bands["composed"]) < 0.14)
		# The board rides the rig's vertical travel, so the band it holds should be the same at
		# every height. Before that it swung a third of the frame.
		_check("billboard_band_holds_through_travel", float(report["billboard_band_swing"]) < 0.02)

	report["framing"] = arena.get_framing_report()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.get_base_dir().path_join("arena_integration.png"))
	_finish()


## Paving under the ring just inside the bounds, counting only samples where a player capsule
## actually fits. Returns the unpaved reachable points too, so a failure names locations.
func _ring_coverage(perimeter: Node) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	probe.shape = capsule
	var points: Array[Vector3] = []
	for step in range(int(perimeter.YARD_MIN.x) + 1, int(perimeter.YARD_MAX.x)):
		points.append(Vector3(float(step), 0.05, -25.0))
		points.append(Vector3(float(step), 0.05, perimeter.YARD_MAX.y - 1.0))
	for step in range(int(perimeter.YARD_MIN.y) + 1, int(perimeter.YARD_MAX.y)):
		points.append(Vector3(perimeter.YARD_MIN.x + 1.0, 0.05, float(step)))
		points.append(Vector3(perimeter.YARD_MAX.x - 1.0, 0.05, float(step)))
	var reachable: int = 0
	var paved: int = 0
	var holes: Array = []
	for point: Vector3 in points:
		probe.transform = Transform3D(Basis(), point + Vector3.UP)
		if not space.intersect_shape(probe, 1).is_empty():
			continue
		reachable += 1
		if perimeter.is_paved(point):
			paved += 1
		elif holes.size() < 10:
			var enclosed: int = 0
			for step: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
				if perimeter.is_paved(point + step):
					enclosed += 1
			holes.append("%s neighbours_paved=%d/4" % [str(Vector2i(int(point.x), int(point.z))), enclosed])
	return {
		"samples": points.size(), "reachable": reachable, "paved": paved,
		"paved_pct": snappedf(100.0 * float(paved) / maxf(float(reachable), 1.0), 0.1),
		"unpaved_reachable": holes,
	}


func _check(label: String, condition: bool) -> void:
	checks[label] = condition
	if not condition:
		push_error("ARENA INTEGRATION FAILED: " + label)


func _finish() -> void:
	var failures: PackedStringArray = []
	for key: String in checks:
		if not bool(checks[key]):
			failures.append(key)
	report["checks"] = checks
	report["checks_run"] = checks.size()
	report["failures"] = failures
	FileAccess.open(_out, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("ARENA INTEGRATION ", "PASS" if failures.is_empty() else "FAIL", " ", JSON.stringify(report))
	get_tree().quit()
