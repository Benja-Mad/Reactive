## Walkable character for Sector 08, driven by the project's existing WASD actions.
##
## Movement is expressed in the camera's own horizontal frame, so "up" walks into the screen
## from the player's point of view even though the camera never rotates. The camera basis is
## read once and cached: P30 is fixed, and re-reading it every frame would couple the player's
## heading to the lookdev's lateral dolly.
extends CharacterBody3D

const SPEED: float = 4.4
const ACCELERATION: float = 34.0
const FRICTION: float = 42.0
const GRAVITY: float = 22.0
## Metres of visible figure, matching the lookdev's grounding of the same sprite.
const FIGURE_HEIGHT: float = 2.2

var sprite: Sprite3D
var _forward: Vector3 = Vector3.FORWARD
var _right: Vector3 = Vector3.RIGHT
var _facing: float = 1.0


func setup(camera: Camera3D, source_sprite: Sprite3D) -> void:
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	var basis: Basis = camera.global_basis
	_right = Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	_forward = Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	var collider := CollisionShape3D.new()
	collider.name = "Body"
	collider.shape = capsule
	add_child(collider)
	collider.position.y = capsule.height * 0.5

	# Reuse the authored sprite exactly as the lookdev presents it, so the walkable character
	# and the static lookdev character are visually the same figure.
	sprite = Sprite3D.new()
	sprite.name = "Sprite"
	sprite.texture = source_sprite.texture
	sprite.billboard = source_sprite.billboard
	sprite.shaded = source_sprite.shaded
	sprite.alpha_cut = source_sprite.alpha_cut
	sprite.alpha_scissor_threshold = source_sprite.alpha_scissor_threshold
	sprite.texture_filter = source_sprite.texture_filter
	sprite.pixel_size = source_sprite.pixel_size
	sprite.render_priority = source_sprite.render_priority
	sprite.scale = source_sprite.scale
	sprite.position = source_sprite.position
	add_child(sprite)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# move_down is +Y from get_vector but walks away from the camera, hence the negation.
	var wish: Vector3 = (_right * input.x - _forward * input.y).normalized() * SPEED * minf(input.length(), 1.0)
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = ACCELERATION if wish.length_squared() > 0.0 else FRICTION
	planar = planar.move_toward(wish, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	# Flip on the camera's screen-space right so the figure faces where it is going.
	var lateral: float = planar.dot(_right)
	if absf(lateral) > 0.15:
		_facing = signf(lateral)
	sprite.flip_h = _facing < 0.0
