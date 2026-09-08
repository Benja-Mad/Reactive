## The blown-out spot on the pavement, isolated and then dialled in.
##
## Rendering the variants settled it: zeroing SpineCyan's specular alone takes the region peak
## from 255 to 77, the same as zeroing every light's specular. The lamp is a 22-energy omni
## standing in for a volumetric landmark, and a wet slab turns it into a point glint that
## saturates and blooms. This sweep finds the largest specular value that does not clip.
extends Node

var scene: Node
var arena: Node
var out: String


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
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(), "Local", 0, Statics.Role.SUPPORT)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	await frames(70)
	arena = scene.get_node("Arena")
	var light: Light3D = arena.find_child("SpineCyan", true, false) as Light3D
	print("SPINE SPECULAR NOW ", light.light_specular)
	for value: float in [0.0, 0.02, 0.04, 0.08, 0.14]:
		light.light_specular = value
		await frames(6)
		await shot("spec_%03d" % int(value * 100.0))
	get_tree().quit()
