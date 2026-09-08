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
	# Walk well past the dead zone. The spawn sits near frame centre and the dead zone is a tenth
	# of a 46 m wide frame, so a couple of metres would legitimately move the camera not at all.
	Input.action_press("move_right")
	for i in 260: await get_tree().process_frame
	Input.action_release("move_right")
	for i in 20: await get_tree().process_frame
	var travelled: Vector3 = local.global_position - start
	report["travel_m"] = snappedf(travelled.length(), 0.01)
	_check("player_moved", travelled.length() > 1.0)
	_check("moved_along_camera_right", travelled.normalized().dot(camera_right) > 0.9)
	report["camera_translated_m"] = snappedf(camera.global_position.distance_to(camera_start), 0.01)
	_check("camera_followed", camera.global_position.distance_to(camera_start) > 0.25)
	report["rig_offset"] = arena.camera_rig.get_report()
	_check("basis_still_preserved", camera.global_basis.is_equal_approx(approved.basis))
	_check("fov_still_30", is_equal_approx(camera.fov, 30.0))
	_check("camera_within_travel_limit", camera.global_position.distance_to(approved.origin) <= arena.follow_limit.length() + 0.01)

	report["framing"] = arena.get_framing_report()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.get_base_dir().path_join("arena_integration.png"))
	_finish()


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
