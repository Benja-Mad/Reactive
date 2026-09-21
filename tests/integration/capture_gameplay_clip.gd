## Records a real play sequence from the shipped game scene, for eyes rather than for assertions.
##
## Everything else in tests/ measures. This one exists so the arena can be *watched*: the camera
## actually following, the rain and the wet ground moving, the sodium shaft holding, a bolt
## crossing the yard and a sentry reacting. Frames are written one per two physics ticks and the
## encode runs at 30 fps, so the clip plays at the speed the game runs at.
extends Node

const FPS_DIVISOR: int = 2

var scene: Node
var arena: Node
var local: Character
var out: String
var frame_index: int = 0


func _ready() -> void: call_deferred("run")


## One captured frame per FPS_DIVISOR physics ticks, holding whatever inputs are pressed.
func record(ticks: int) -> void:
	for tick in ticks:
		await get_tree().physics_frame
		if tick % FPS_DIVISOR != 0:
			continue
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("f%04d.png" % frame_index))
		frame_index += 1


func hold(action: String, ticks: int) -> void:
	Input.action_press(action)
	await record(ticks)
	Input.action_release(action)


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	# Captured at the resolution it is encoded at: rescaling the clip afterwards destroys the
	# pixel lattice, which is most of what the presentation is.
	get_window().size = Vector2i(1920, 1080)
	Game.instance.players = [
		Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.DAMAGE),
		Statics.PlayerData.new(multiplayer.get_unique_id() + 1, "Aliada", 1, Statics.Role.SUPPORT),
	]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	for i in 90: await get_tree().process_frame
	arena = scene.get_node("Arena")
	var characters: Array[Node] = scene.get_node("Players").get_children()
	local = characters[0] as Character
	# The code editor grabs focus on spawn and Character returns early while it has it.
	(local.programming_block.get_node("CodeBlock") as Control).release_focus()
	for i in 30: await get_tree().process_frame

	await record(40)                      # settle on the composed framing
	await hold("move_right", 130)         # camera picks the player up and travels
	await record(30)
	await hold("move_up", 90)             # into the yard, toward the sentries
	await hold("Fire", 90)                # bolts cross the yard
	await hold("move_left", 150)          # back across, camera travels the other way
	await hold("Fire", 60)
	await record(40)

	print("CLIP frames=", frame_index, " at ", out)
	get_tree().quit()
