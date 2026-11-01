## Run this scene for a playable trial. --capture writes paired real-engine frames and exits.
extends Node
const Trial = preload("res://scenes/environment/sector_08/stylized/yard_art_trial.gd")
var trial: Node3D
var run: Node
var scene: Node3D
var city_view: bool = false
var output: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/stylized_yard_20261016/iteration_30"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("start")

func frames(count: int) -> void:
	for i: int in count: await get_tree().process_frame

func start() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size = Vector2i(1600, 900)
	Game.instance.multiplayer_test = false
	var support: bool = "support" in OS.get_cmdline_user_args()
	Game.instance.players = [Statics.PlayerData.new(1, "Prueba visual", 0, Statics.Role.SUPPORT if support else Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	scene.polished_environment_enabled = false
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	if "vista" in OS.get_cmdline_user_args():
		scene.get_node("Arena").framing_pitch_degrees = 26.0
		scene.get_node("Arena").framing_distance = 66.0
		scene.get_node("Arena").framing_fov = 44.0
		city_view = true
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(100)
	var player: Character = run.local_player()
	player.global_position = Vector3(-3, 1.15, 4) if "south" in OS.get_cmdline_user_args() else Vector3(-7, 1.15, -9)
	for zone: String in ["east", "west", "far_south", "transit", "north", "barrels"]:
		if zone in OS.get_cmdline_user_args():
			player.global_position = {"barrels": Vector3(-15,1.15,2), "north": Vector3(-4,1.15,-21), "east": Vector3(23,1.15,9), "west": Vector3(-25,1.15,9), "far_south": Vector3(0,1.15,23), "transit": Vector3(9,1.15,20)}[zone]
	await frames(90)
	if "capture" in OS.get_cmdline_user_args():
		var crowd_count: int = 18 if "crowd" in OS.get_cmdline_user_args() else 6
		for i: int in (0 if "clean" in OS.get_cmdline_user_args() else crowd_count):
			var angle: float = float(i) * TAU / float(crowd_count)
			run.spawn_machine(800 + i, player.global_position + Vector3(cos(angle) * (5.0 + float(i % 3) * 2.0), -1.1, sin(angle) * (5.0 + float(i % 3) * 2.0)), i % 3, 1.0)
			# Let the spawn presentation settle before pausing the whole scene.
	if "capture" in OS.get_cmdline_user_args() and "clean" not in OS.get_cmdline_user_args(): await frames(60)
	if "overview" in OS.get_cmdline_user_args():
		var arena: Node3D = scene.get_node("Arena")
		arena.camera_rig.enabled = false
		arena.gameplay_camera.global_position = Vector3(48, 38, 56)
		arena.gameplay_camera.look_at(Vector3(-8, 1, -25))
		arena.gameplay_camera.fov = 52.0
		arena.pixel_presentation.presentation_material.set_shader_parameter("focus_distance", 105.0)
	var collisions: Dictionary = collision_snapshot()
	trial = Trial.new()
	trial.name = "YardArtTrial"
	scene.get_node("Arena").add_child(trial)
	if "baseline" not in OS.get_cmdline_user_args():
		trial.setup(scene.get_node("Arena"))
	assert_original_collision_integrity(collisions)
	if "baseline" not in OS.get_cmdline_user_args():
		assert(trial.stats["models_rebuilt"] > 0 and trial.stats["surfaces"] > 0)
		trial.set_enabled(false)
		for path: String in collisions:
			assert(collision_snapshot()[path] == collisions[path])
		for shape: CollisionShape3D in trial.replacement_collisions: assert(shape.disabled)
		for item: Dictionary in trial.changed:
			assert(item["node"].material_override == item["original"])
			assert(item["node"].visible == item["visible"])
		for item: Dictionary in trial.atmosphere_changes:
			assert(item["node"].visible == item["visible"])
		trial.set_enabled(true)
	if "capture" in OS.get_cmdline_user_args():
		# Freeze animation, particles and simulation for a matched comparison.
		run.set_physics_process(false)
		run.hud.hide()
		get_tree().paused = true
		var suffix: String = "baseline" if "baseline" in OS.get_cmdline_user_args() else ("sereno" if support else "brasa")
		if "south" in OS.get_cmdline_user_args(): suffix += "_south"
		for zone: String in ["east", "west", "far_south", "transit", "north", "barrels"]:
			if zone in OS.get_cmdline_user_args(): suffix += "_" + zone
		if "vista" in OS.get_cmdline_user_args(): suffix += "_vista"
		if "overview" in OS.get_cmdline_user_args(): suffix += "_overview"
		trial.set_enabled(false)
		await shot("before_" + suffix)
		trial.set_enabled(true)
		await shot("after_" + suffix)
		if "patrol" in OS.get_cmdline_user_args():
			var patrol = trial.get_node("AerialPatrol")
			patrol.set_process(false)
			for phase: float in [0.3,0.65]:
				patrol.sample_pass(phase,Vector3(player.global_position.x,0,player.global_position.z))
				await shot("patrol_%d_" % int(phase*100) + suffix)
		trial.set_enabled(false)
		await frames(4)
		get_tree().paused = false
		scene.queue_free()
		await frames(4)
		get_tree().quit()
	else:
		run.test_mode = false
		var layer := CanvasLayer.new()
		layer.layer = 30
		add_child(layer)
		var hint := Label.new()
		hint.text = "PRUEBA DE ARTE · F6: original / estilizado · F7: vista ciudad / combate"
		hint.position = Vector2(24, 136)
		hint.add_theme_color_override("font_color", Color("e4e1d0"))
		layer.add_child(hint)

func shot(title: String) -> void:
	await frames(8)
	# macOS may suspend presentation when the capture window is occluded.
	# Draw explicitly so automation does not depend on foreground focus.
	RenderingServer.force_draw(false)
	var result: Error = get_viewport().get_texture().get_image().save_png(output.path_join(title + ".png"))
	assert(result == OK)
	print("ART CAPTURE ", title)

func _unhandled_key_input(event: InputEvent) -> void:
	if trial != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		trial.set_enabled(not trial.enabled)
		get_viewport().set_input_as_handled()

	elif trial != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		toggle_city_view()
		get_viewport().set_input_as_handled()

## Original geometry stays unchanged; only declared retired colliders may be disabled.
func assert_original_collision_integrity(original: Dictionary) -> void:
	var current := collision_snapshot()
	for path: String in original:
		assert(current.has(path))
		assert(current[path][0] == original[path][0] and current[path][1] == original[path][1])
		if current[path][2] != original[path][2]:
			var declared: bool = false
			for item: Dictionary in trial.collision_changes:
				if str(scene.get_path_to(item["node"])) == path: declared = true
			assert(declared, "Undeclared collision change: " + path)

## Snapshot includes disabled state for reversal and camera checks.
func collision_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in scene.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		result[str(scene.get_path_to(shape))] = [shape.shape, shape.global_transform, shape.disabled]
	return result


## Optional wider framing for reviewing the district; main gameplay framing is untouched.
func toggle_city_view() -> void:
	city_view = not city_view
	var arena: Node3D = scene.get_node("Arena")
	arena.framing_pitch_degrees = 26.0 if city_view else 38.0
	arena.framing_distance = 66.0 if city_view else 50.0
	arena.framing_fov = 44.0 if city_view else 38.0
	arena.apply_framing()
	arena.approved_transform = arena.gameplay_camera.global_transform
	arena.camera_rig.setup(arena.gameplay_camera, arena.approved_transform)
	arena.camera_rig.offset = Vector2.ZERO
	arena.pixel_presentation.set_mode(arena.presentation_mode)
