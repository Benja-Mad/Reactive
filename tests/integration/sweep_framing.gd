## Renders the arena from one candidate framing and measures what that framing costs or buys.
##
## Called once per variant with the pitch, yaw, distance and field of view on the command line.
## The arena declares its framing as exported data, so the variant is applied to the instanced
## scene *before* it enters the tree -- which means the depth-of-field band, the foreground board
## and the parallax dust are all built for that framing rather than retro-fitted to it.
##
## Two frames are saved per variant: the shipped presentation, and the same frame with the diorama
## world filter off. The difference between them *is* the depth-of-field, so measuring it at a few
## world anchors says whether the gameplay plane is still sharp and the rest still soft -- which
## is the part of "the feeling of depth" that a closer camera can actually destroy.
##
## Everything else measured here is geometry, and the interesting numbers are ratios:
##
##   figure_px        how tall 1.6 m is at the gameplay plane -- the apparent closeness
##   size_gradient    a 1 m post at z=-20 against one at z=+10, in pixels. 1.0 is an orthographic
##                    projection with no perspective depth at all; higher means the lens is
##                    telling you about distance
##   parallax_ratio   screen travel of a near marker against a far one over a 12 m dolly. This is
##                    the depth cue the translating camera generates, and it is the one that
##                    matters most in motion
##   yard_in_frame    fraction of the walkable box the player can see at once
extends Node

## Height of the reference posts, and of the figure, in metres.
const POST_HEIGHT := 1.0
const FIGURE_HEIGHT := 1.6
## World anchors the depth-of-field is judged at: near foreground, gameplay plane, far facade.
const ANCHORS := {
	"near": Vector3(-8.0, 2.5, 16.0),
	"gameplay": Vector3(0.0, 0.9, -2.0),
	"far": Vector3(-2.0, 9.0, -30.0),
}
## Depths the parallax is sampled at, along the yard's own axis.
const PARALLAX_MARKERS := {
	"near": Vector3(2.0, 0.5, 10.0),
	"mid": Vector3(0.0, 0.5, -2.0),
	"far": Vector3(-2.0, 0.5, -22.0),
}

var scene: Node
var arena: Node
var out: String
var id: String


func _ready() -> void: call_deferred("run")


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func shot(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [id, suffix]))


## Screen height of a vertical segment of `height` metres standing at `base`.
func vertical_px(camera: Camera3D, base: Vector3, height: float) -> float:
	if camera.is_position_behind(base):
		return -1.0
	return absf(camera.unproject_position(base).y - camera.unproject_position(base + Vector3.UP * height).y)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out = args[0]
	id = args[1]
	var pitch: float = float(args[2])
	var yaw: float = float(args[3])
	var distance: float = float(args[4])
	var fov: float = float(args[5])
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.SUPPORT)]

	scene = load("res://scenes/main_scene.tscn").instantiate()
	# Applied before the scene enters the tree, so the arena builds itself around this framing.
	arena = scene.get_node("Arena")
	arena.framing_pitch_degrees = pitch
	arena.framing_yaw_degrees = yaw
	arena.framing_distance = distance
	arena.framing_fov = fov
	add_child(scene)
	await frames(80)

	var camera: Camera3D = arena.gameplay_camera
	var report: Dictionary = {
		"id": id, "pitch_deg": pitch, "yaw_deg": yaw, "distance_m": distance, "fov": fov,
		"camera_at": str(camera.global_position.snappedf(0.01)),
	}

	# Put the figure on a known spot so apparent size is comparable across variants.
	var characters: Array[Node] = scene.get_node("Players").get_children()
	if not characters.is_empty():
		var local: Character = characters[0]
		var code_block: Control = local.programming_block.get_node("CodeBlock") as Control
		code_block.release_focus()
		local.global_position = Vector3(0.0, 1.2, -2.0)
		local.velocity = Vector3.ZERO
		await frames(40)
		report["figure_px"] = snappedf(vertical_px(camera, Vector3(0.0, 0.05, -2.0), FIGURE_HEIGHT), 0.1)

	# Perspective: identical posts at two depths. A long lens flattens this towards 1.0.
	var near_post: float = vertical_px(camera, Vector3(0.0, 0.05, 10.0), POST_HEIGHT)
	var far_post: float = vertical_px(camera, Vector3(0.0, 0.05, -22.0), POST_HEIGHT)
	report["post_near_px"] = snappedf(near_post, 0.2)
	report["post_far_px"] = snappedf(far_post, 0.2)
	report["size_gradient"] = snappedf(near_post / maxf(far_post, 0.001), 0.001)

	# How much of the walkable box is on screen at once.
	var rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var inside: int = 0
	var total: int = 0
	for xi in range(-26, 27, 2):
		for zi in range(-26, 15, 2):
			var point := Vector3(float(xi), 0.05, float(zi))
			total += 1
			if not camera.is_position_behind(point) and rect.has_point(camera.unproject_position(point)):
				inside += 1
	report["yard_in_frame"] = snappedf(float(inside) / float(total), 0.001)

	# Parallax from the camera's own travel: screen displacement per depth over a 12 m dolly.
	arena.camera_rig.set_enabled(true)
	var travel: Dictionary = {}
	var before: Dictionary = {}
	arena.camera_rig.offset = Vector2(-6.0, 0.0)
	arena.camera_rig._apply()
	await frames(4)
	for key: String in PARALLAX_MARKERS:
		before[key] = camera.unproject_position(PARALLAX_MARKERS[key])
	arena.camera_rig.offset = Vector2(6.0, 0.0)
	arena.camera_rig._apply()
	await frames(4)
	for key: String in PARALLAX_MARKERS:
		travel[key] = snappedf((camera.unproject_position(PARALLAX_MARKERS[key]) - (before[key] as Vector2)).length(), 0.1)
	report["parallax_px_over_12m"] = travel
	report["parallax_ratio"] = snappedf(float(travel["near"]) / maxf(float(travel["far"]), 0.001), 0.001)
	arena.camera_rig.offset = Vector2.ZERO
	arena.camera_rig._apply()
	await frames(20)

	# Where the depth-of-field anchors land, so the pair of frames can be sampled at them.
	var anchors: Dictionary = {}
	for key: String in ANCHORS:
		anchors[key] = str(Vector2i(camera.unproject_position(ANCHORS[key])))
	report["anchor_pixels"] = anchors

	# The shipped frame, then the same frame with the world filter off. Their difference is the
	# depth-of-field, which is what a dolly-in can quietly leave behind.
	await shot("on")
	arena.pixel_presentation.set_diorama(false)
	await frames(10)
	await shot("off")
	arena.pixel_presentation.set_diorama(true)

	print("FRAMING ", JSON.stringify(report))
	get_tree().quit()
