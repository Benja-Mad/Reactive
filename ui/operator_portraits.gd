## Portraits of the two operators, cut from their own idle sprite so the lobby shows the people
## you will play, not an engine logo.
extends RefCounted

const FRAMES := {
	1: preload("res://materials/operators/sereno_frames.tres"),
	2: preload("res://materials/operators/brasa_frames.tres"),
}
## Head-and-shoulders crops inside the 128 px idle frame (Statics.Role values as keys).
const BUST := {1: Rect2(46, 40, 48, 48), 2: Rect2(42, 40, 48, 48)}
const FULL := {1: Rect2(36, 38, 64, 88), 2: Rect2(34, 38, 64, 88)}

static func portrait(role: int, bust: bool = false) -> Texture2D:
	var frames: SpriteFrames = FRAMES.get(role, FRAMES[2])
	var source := frames.get_frame_texture(&"Idle", 0) as AtlasTexture
	var crop := AtlasTexture.new()
	crop.atlas = source.atlas
	var region: Rect2 = (BUST if bust else FULL).get(role, FULL[2])
	crop.region = Rect2(source.region.position + region.position, region.size)
	return crop
