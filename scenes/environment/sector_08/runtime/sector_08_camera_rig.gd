## Follow rig for the approved P30 camera.
##
## P30 is a fixed framing: FOV 30 and a fixed basis. So the rig only ever translates, exactly
## as the lookdev's lateral parallax does, and never rotates or zooms. It slides the camera
## along its own screen-right and screen-up axes to keep the player inside a dead zone, then
## clamps that offset so the diorama never dollies past its authored edges.
##
## The offset is additive on top of the lookdev's parallax offset, so both can be active without
## either one fighting the other for the camera transform.
extends Node

## Fraction of the frame the player can move within before the camera starts following.
const DEAD_ZONE := Vector2(0.10, 0.13)
## Metres the rig may translate from the approved transform, on each camera axis.
const LIMIT := Vector2(9.0, 3.0)
const FOLLOW_SPEED: float = 3.2

var camera: Camera3D
var anchor: Transform3D
var target: Node3D
var offset: Vector2 = Vector2.ZERO
var enabled: bool = false
var extra_offset: Callable = Callable()


func setup(gameplay_camera: Camera3D, approved: Transform3D) -> void:
	camera = gameplay_camera
	anchor = approved


func set_target(node: Node3D) -> void:
	target = node


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		offset = Vector2.ZERO
	_apply()


func _process(delta: float) -> void:
	if not enabled or target == null:
		return
	var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
	var screen: Vector2 = camera.unproject_position(target.global_position + Vector3.UP * 1.1)
	var normalised := Vector2(screen.x / viewport.x - 0.5, screen.y / viewport.y - 0.5)
	# Only the excursion past the dead zone asks the camera to move.
	var excess := Vector2(
		signf(normalised.x) * maxf(absf(normalised.x) - DEAD_ZONE.x, 0.0),
		signf(normalised.y) * maxf(absf(normalised.y) - DEAD_ZONE.y, 0.0))
	if not excess.is_zero_approx():
		# Convert the screen excursion into metres at the target's depth.
		var depth: float = camera.global_basis.z.dot(camera.global_position - target.global_position)
		var metres_per_unit: float = 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5)
		offset.x = clampf(offset.x + excess.x * metres_per_unit * FOLLOW_SPEED * delta, -LIMIT.x, LIMIT.x)
		offset.y = clampf(offset.y - excess.y * metres_per_unit * FOLLOW_SPEED * delta, -LIMIT.y, LIMIT.y)
	_apply()


func _apply() -> void:
	if camera == null:
		return
	var lateral: float = 0.0
	if extra_offset.is_valid():
		lateral = float(extra_offset.call())
	var origin: Vector3 = anchor.origin + anchor.basis.x * (offset.x + lateral) + anchor.basis.y * offset.y
	# Basis is never written, so FOV 30 and the approved orientation survive by construction.
	camera.global_transform = Transform3D(anchor.basis, origin)


func get_report() -> Dictionary:
	return {
		"enabled": enabled,
		"offset_right_m": snappedf(offset.x, 0.001),
		"offset_up_m": snappedf(offset.y, 0.001),
		"limit_m": str(LIMIT),
		"fov": camera.fov if camera != null else -1.0,
		"basis_preserved": camera != null and camera.global_basis.is_equal_approx(anchor.basis),
	}
