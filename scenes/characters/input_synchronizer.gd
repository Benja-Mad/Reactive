class_name InputSynchronizer
extends MultiplayerSynchronizer

@export var move_input: Vector2
@export var jump: bool
@export var aim_direction: Vector3 = Vector3.ZERO
var mouse_aim_active: bool = false


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var editor := get_parent().get_node("ProgrammingBlock/CodeBlock") as TextEdit
	if editor.has_focus():
		move_input = Vector2.ZERO
		jump = false
		return
	
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# A single mouse movement used to disable keyboard facing for the rest of the session. Moving
	# on the keyboard hands it back.
	if mouse_aim_active and move_input.length_squared() > 0.25:
		mouse_aim_active = false
		aim_direction = Vector3.ZERO
	if mouse_aim_active:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var mouse := get_viewport().get_mouse_position()
			var body := get_parent() as Node3D
			var plane := Plane(Vector3.UP, body.global_position.y + 0.55)
			var point: Variant = plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
			if point != null:
				var direction: Vector3 = point - body.global_position
				direction.y = 0.0
				if direction.length_squared() > 0.16:
					aim_direction = direction.normalized()
	
	if Input.is_action_just_pressed("ui_accept"):
		broadcast_jump.rpc()
	
@rpc("call_local")
func broadcast_jump() -> void:
	jump = true

func _unhandled_input(event: InputEvent) -> void:
	if is_multiplayer_authority() and event is InputEventMouseMotion:
		mouse_aim_active = true
