class_name SpriteHeading
extends RefCounted

## Atlas columns run clockwise from screen-down through screen-right.
static func from_motion(x: float, z: float, camera: Camera3D) -> int:
	var camera_yaw := camera.global_rotation.y if camera else 0.0
	return posmod(roundi((atan2(x, z) - camera_yaw) / (PI / 4.0)), 8)
