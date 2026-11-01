## Builds the specialists' SpriteFrames from the strips and manifests enemy_strips.py writes
## (128x128 frames, left to right). Each animation's anchor texel -- the one that sits on the
## machine's origin -- is kept in the resource's "anchors" metadata.
## Run: Godot --headless --path . -s tools/operators/build_enemy_frames.gd
extends SceneTree

const CREATURES: Array[String] = ["gargola", "raya", "novia", "quiltro", "repartidor", "animita"]

func _initialize() -> void:
	for creature: String in CREATURES:
		var folder := "res://materials/enemies/%s" % creature
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/manifest.json"))
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		var anchors: Dictionary = {}
		for animation: String in manifest:
			var spec: Dictionary = manifest[animation]
			var strip: Texture2D = load(spec["file"])
			frames.add_animation(animation)
			frames.set_animation_speed(animation, float(spec["fps"]))
			frames.set_animation_loop(animation, bool(spec["loop"]))
			for index: int in int(spec["frames"]):
				var atlas := AtlasTexture.new()
				atlas.atlas = strip
				atlas.region = Rect2(index * 128, 0, 128, 128)
				frames.add_frame(animation, atlas)
			anchors[animation] = Vector2(spec["anchor"][0], spec["anchor"][1])
		frames.set_meta(&"anchors", anchors)
		var path := folder + "/frames.tres"
		print(path, " ", ResourceSaver.save(frames, path))
	quit()
