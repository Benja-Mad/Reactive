extends Camera3D
## Translation-only follow. The player's existing authority still chooses the active camera.
## A shallow oblique view reveals the depth of the market stalls.
@export_range(12.0, 30.0, 0.5) var view_height: float = 17.5
@export_range(20.0, 65.0, 1.0) var pitch_degrees: float = 24.0
@export var follow_speed: float = 7.0
@export var dead_zone: Vector2 = Vector2(0.7, 0.5)

var _target: Node3D
var _center: Vector3
var _offset: Vector3

func _ready() -> void:
	_target = get_parent() as Node3D
	if _target == null:
		return
	set_as_top_level(true)
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = view_height
	near = 0.1
	far = 150.0
	rotation_degrees = Vector3(-pitch_degrees, -6.0, 0.0)
	_offset = global_basis.z * 32.0
	_center = Vector3(_target.global_position.x, 3.5, _target.global_position.z)
	global_position = _center + _offset

func _process(delta: float) -> void:
	if not current or not is_instance_valid(_target):
		return
	var desired := Vector3(_target.global_position.x, 3.5, _target.global_position.z)
	var distance := desired - _center
	var correction := Vector3(
		signf(distance.x) * maxf(absf(distance.x) - dead_zone.x, 0.0),
		0.0,
		signf(distance.z) * maxf(absf(distance.z) - dead_zone.y, 0.0))
	_center += correction * (1.0 - exp(-follow_speed * delta))
	global_position = _center + _offset
