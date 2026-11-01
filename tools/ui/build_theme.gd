## Writes the kit theme into res://lobby/lobby_theme.tres (keeping its uid, so every scene that
## uses it picks it up). Run: godot --headless --path . -s tools/ui/build_theme.gd
extends SceneTree
const Kit = preload("res://scripts/ui/kit.gd")

func _init() -> void:
	var path: String = "res://lobby/lobby_theme.tres"
	var theme: Theme = load(path)
	theme.clear()
	theme.default_font = null
	theme.merge_with(Kit.theme())
	theme.default_font = Kit.font()
	theme.default_font_size = Kit.TEXT_SIZE
	var err: Error = ResourceSaver.save(theme, path)
	# Saving a cleared theme drops the uid the scenes point at; put it back.
	ResourceSaver.set_uid(path, ResourceUID.text_to_id("uid://bwgdrcgopd0s1"))
	print("theme saved: ", error_string(err))
	quit()
