## Renders the front-end backdrop (ui/art/sector08_backdrop.png) from the shift as it plays now:
## Brasa and the Sereno holding the yard against a pack, matter on the paving, no HUD and no
## labels. The menu's dark falls over the left half, so the fight sits right of centre. Rerun it
## whenever the yard or the crew change, so the menu never shows a game that no longer exists:
## godot --path . tests/ui/menu_backdrop.tscn
extends "res://tests/survivor/capture.gd"
const Build = preload("res://scripts/survivor/build.gd")
const TARGET := "res://ui/art/sector08_backdrop.png"

func capture() -> void:
	get_window().size = Vector2i(1920, 1080)
	Game.instance.multiplayer_test = false
	Game.instance.players = [
		Statics.PlayerData.new(1, "Brasa", 0, Statics.Role.DAMAGE),
		Statics.PlayerData.new(2, "Sereno", 1, Statics.Role.SUPPORT),
	]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(60)
	# Offline only the host's seat spawns by itself; the Sereno is seated by hand.
	scene.player_spawner.spawn(Game.instance.players[1].to_dict())
	await frames(10)
	var brasa: Character = scene.get_node("Players/1")
	var sereno: Character = scene.get_node("Players/2")
	brasa.global_position = Vector3(4.0, 1.15, -0.6)
	sereno.global_position = Vector3(2.2, 1.15, 1.8)
	# The camera frames a spot left of the crew, so they and the pack land right of the menu.
	var rig: Node = scene.find_children("CameraRig", "", true, false)[0]
	var framed := Node3D.new()
	scene.add_child(framed)
	framed.global_position = Vector3(-1.5, 1.15, 0.4)
	rig.set_target(framed)
	run.open_sources()
	run.world.residue = true
	run.builds[1] = Build.fresh()
	run.builds[1]["attack"]["steps"] = ["push", "coat"]
	run.builds[2] = Build.fresh()
	run.builds[2]["attack"]["steps"] = ["cold"]
	await frames(30)
	# A pack coming in from the right and the back of the yard, the kinds mixed.
	var kinds: Array[int] = [0, 1, 0, 2, 1, 0, 3, 5, 0, 1, 4, 0]
	for i: int in kinds.size():
		var angle: float = lerpf(-1.25, 0.55, float(i) / (kinds.size() - 1))
		var reach: float = 6.5 + (i % 3) * 1.6
		run.spawn_machine(700 + i, brasa.global_position + Vector3(cos(angle), -1.1, sin(angle)) * Vector3(reach, 1.0, reach * 0.8), kinds[i], 3.0)
	# Let the fight run: the flame and the ánimas firing, puddles and fire landing on the yard.
	await frames(150)
	run.set_physics_process(false)
	run.world.set_physics_process(false)
	for machine: Node in run.machines.get_children(): machine.set_physics_process(false)
	run.hud.hide()
	var console: Node = scene.get_node_or_null("MatterConsole")
	if console: console.hide()
	# Labels are instruments, not scenery.
	for label: Node in scene.find_children("*", "Label3D", true, false): label.visible = false
	await frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(OS.get_environment("BACKDROP_OUT") if OS.has_environment("BACKDROP_OUT") else TARGET)
	print("BACKDROP SAVED ", image.get_size(), " machines ", run.machines.get_child_count())
	get_tree().quit()
