## The workshop with four routines, one per source, each caught mid-routine on the preview: the
## source node names where the matter comes from and clicking it cycles. Run windowed:
## godot --path . tests/survivor/substances_editor_look.tscn
extends "res://tests/survivor/capture.gd"
func capture() -> void:
	out = "res://authored/substances_20261021"
	get_window().size = Vector2i(1600, 900)
	Game.instance.multiplayer_test = false
	Game.instance.players = [Statics.PlayerData.new(1, "Operador", 0, Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	await frames(60)
	run.builds[1]["routines"] = [
		{"when": "cerca", "steps": ["raise", "push"], "then": "estallar", "on": "contact", "from": "fire"},
		{"when": "grupo", "steps": ["fire"], "then": "", "on": "contact", "from": "current"},
		{"when": "rastro", "steps": ["wall", "fire"], "then": "", "on": "contact", "from": "scrap"},
		{"when": "cada", "steps": ["raise", "cold", "push"], "then": "fragmentos", "on": "broken"},
	]
	run.set_phase("paused")
	await frames(10)
	for row: int in 4:
		run.hud._editor.focus = row
		run.hud._editor._time = [2.6, 2.2, 2.4, 3.0][row]
		await shot("11_workshop_row%d" % (row + 1))
	get_tree().quit()
