## Real (unstaged) frames from a piloted shift, for reviewing how play actually reads.
extends "res://tests/survivor/soak.gd"
var marks: Array = [20.0, 75.0, 140.0, 200.0]
var dir: String = OS.get_environment("LOOK_DIR") if OS.has_environment("LOOK_DIR") else "res://authored/survivor_20261016"
func _ready() -> void:
	super()
	get_window().size = Vector2i(1600, 900)
	invulnerable = true
func _process(_delta: float) -> void:
	if run == null or marks.is_empty() or run.phase != "running": return
	if run.elapsed >= marks[0]:
		var t: float = marks.pop_front()
		Engine.time_scale = 0.0001
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("t%03d.png" % int(t)))
		print("LOOK ", t, " at=", pilot.global_position, " enemies=", run.machines.get_child_count(), " matter=", run.world.records.size(), " kills=", run.kills, " lvl=", run.level)
		Engine.time_scale = 4
		if marks.is_empty():
			get_tree().quit()
