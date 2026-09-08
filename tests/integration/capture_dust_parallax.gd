## Cinematic dust: a still, and a lateral dolly that proves each depth layer parallaxes by a
## different amount. Layers are world-anchored, so the only thing producing the shift is the
## camera genuinely translating -- which is exactly what has to be visible in motion.
extends Node

var scene: Node
var arena: Node
var out: String
var report: Dictionary = {}


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(id + ".png"))


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [
		Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.SUPPORT),
		Statics.PlayerData.new(multiplayer.get_unique_id() + 1, "Remote", 1, Statics.Role.DAMAGE),
	]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(70)
	arena = scene.get_node("Arena")
	var dust: Node3D = arena.cinematic_dust
	var camera: Camera3D = arena.gameplay_camera
	report["dust"] = dust.get_report()

	await shot("still_center")

	# Probe points sitting on each layer's plane, plus the gameplay plane and the architecture,
	# so the measured shift can be compared against depths the pass already characterised.
	var basis: Basis = arena.approved_transform.basis
	var eye: Vector3 = arena.approved_transform.origin
	var probes: Dictionary = {}
	for entry: Array in [["lens_motes", 13.0], ["foreground_drift", 37.0], ["middle_dust", 64.0]]:
		probes[entry[0]] = eye - basis.z * float(entry[1])
	probes["gameplay_plane"] = Vector3(0.0, 0.9, -2.0)
	probes["architecture"] = Vector3(-5.415864, 6.3, -24.32433)

	var samples: Dictionary = {}
	var offsets: Array[float] = [-6.0, 0.0, 6.0]
	var labels: Array[String] = ["left", "center", "right"]
	for i in offsets.size():
		arena.camera_rig.set_enabled(true)
		arena.camera_rig.offset = Vector2(offsets[i], 0.0)
		arena.camera_rig._apply()
		await frames(6)
		var frame: Dictionary = {}
		for key: String in probes:
			frame[key] = camera.unproject_position(probes[key]).x
		samples[labels[i]] = frame
		await shot("dolly_" + labels[i])

	var shift: Dictionary = {}
	for key: String in probes:
		shift[key] = snappedf(absf(float(samples["left"][key]) - float(samples["right"][key])), 0.01)
	report["screen_shift_px_over_12m"] = shift
	report["basis_preserved"] = camera.global_basis.is_equal_approx(arena.approved_transform.basis)
	report["fov"] = camera.fov

	# Motion strip: a continuous sweep so the layers can be seen sliding past each other.
	for frame_index in 96:
		var t: float = float(frame_index) / 95.0
		arena.camera_rig.offset = Vector2(lerpf(-6.0, 6.0, smoothstep(0.0, 1.0, t)), 0.0)
		arena.camera_rig._apply()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join("sweep_%03d.jpg" % frame_index), 0.94)

	arena.camera_rig.offset = Vector2.ZERO
	arena.camera_rig._apply()
	FileAccess.open(out.path_join("dust.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("DUST PARALLAX ", JSON.stringify(report))
	get_tree().quit()
