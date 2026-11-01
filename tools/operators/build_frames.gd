## Builds the operators' SpriteFrames from the generated strips (128x128 frames, left to right).
## Run: Godot --headless --path . -s tools/operators/build_frames.gd
extends SceneTree

const SETS := {
	"brasa": {"Idle": ["brasa_idle", 6.0], "Walk": ["brasa_walk", 11.0], "Fire": ["brasa_fire", 14.0]},
	"sereno": {"Idle": ["sereno_idle", 5.0], "Walk": ["sereno_walk", 10.0], "Fire": ["sereno_fire", 14.0]},
}

func _initialize() -> void:
	for operator: String in SETS:
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for animation: String in SETS[operator]:
			var spec: Array = SETS[operator][animation]
			var strip: Texture2D = load("res://materials/operators/%s.png" % spec[0])
			frames.add_animation(animation)
			frames.set_animation_speed(animation, spec[1])
			frames.set_animation_loop(animation, animation != "Fire")
			for index: int in strip.get_width() / 128:
				var atlas := AtlasTexture.new()
				atlas.atlas = strip
				atlas.region = Rect2(index * 128, 0, 128, 128)
				frames.add_frame(animation, atlas)
		var path := "res://materials/operators/%s_frames.tres" % operator
		print(path, " ", ResourceSaver.save(frames, path))
	quit()
