## The operator's own pixel art, presented as a lit card standing in the yard. It mirrors the
## character's AnimatedSprite3D (which keeps choosing Idle/Walk/Fire) but draws it itself, so the
## art takes the scene's light and shadow, flashes on hits and keeps a silhouette behind cover.
extends Node3D
const CARD = preload("res://scripts/survivor/operator.gdshader")
const XRAY = preload("res://scripts/survivor/operator_xray.gdshader")
## Standing height of the drawn figure, in metres, when there is no pixel grid to match.
const FIGURE_HEIGHT: float = 2.35
var support: bool = false
## Height of the drawn figure above the floor, in world metres, once fitted.
var height: float = FIGURE_HEIGHT
var _quad: QuadMesh
var _grid: Vector2 = Vector2.ZERO
## World metres per texel of the art (across, upward) once fitted.
var _texel: Vector2 = Vector2.ONE * 0.03
var _spray: Node3D
## While the weapon is going, the operator faces the target even when walking away from it.
var _aiming: float = 0.0
var facing := Vector3.RIGHT
var source: AnimatedSprite3D
var card: MeshInstance3D
var art: ShaderMaterial
var xray: ShaderMaterial
var _recoil: float = 0.0
var _flash: float = 0.0
var _last_health: float = 100.0
var _flip: bool = false

func _ready() -> void:
	var body := get_parent() as Character
	source = body.animated_sprite_3d
	source.hide()
	art = ShaderMaterial.new()
	art.shader = CARD
	# The watchman's petrol oilskin sits close to the night's own blue; give it a touch more light.
	art.set_shader_parameter("self_light", 0.5 if support else 0.32)
	card = MeshInstance3D.new()
	card.name = "Card"
	var quad := QuadMesh.new()
	card.mesh = quad
	card.material_override = art
	add_child(card)
	_quad = quad
	_fit()
	# A soft contact patch: the card's real shadow falls away from the lamps, this one grounds it.
	var blob := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.orientation = PlaneMesh.FACE_Y
	plane.size = Vector2(1.3, 0.8)
	blob.mesh = plane
	var shade := ShaderMaterial.new()
	shade.shader = preload("res://scenes/environment/sector_08/runtime/contact_shadow.gdshader")
	blob.material_override = shade
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position.y = 0.03
	add_child(blob)
	_last_health = body.health
	_spray = preload("res://scripts/survivor/weapon_spray.gd").new()
	_spray.name = "Weapon"
	_spray.support = support
	_spray.muzzle = muzzle
	add_child(_spray)

## Size the card so its boots touch this node's origin, which sits on the floor. On the yard's
## pixel grid one texel is one buffer pixel, stretched upright so it stays square under the
## camera's pitch; otherwise the opaque figure, not the padded canvas, is FIGURE_HEIGHT tall.
func _fit() -> void:
	var texture: Texture2D = source.sprite_frames.get_frame_texture("Idle", 0)
	var atlas := texture as AtlasTexture
	var image: Image = atlas.atlas.get_image() if atlas != null else texture.get_image()
	if image.is_compressed(): image.decompress()
	if atlas != null: image = image.get_region(Rect2i(atlas.region))
	var top: int = image.get_height()
	var bottom: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	var metres := Vector2.ONE * FIGURE_HEIGHT / float(maxi(1, bottom - top + 1))
	if _grid != Vector2.ZERO: metres = Vector2(_grid.x, _grid.x * _grid.y)
	_quad.size = Vector2(image.get_width(), image.get_height()) * metres
	card.position.y = (float(bottom + 1) - image.get_height() * 0.5) * metres.y
	height = float(bottom + 1 - top) * metres.y
	_texel = metres

## The weapon goes off toward `to` (an ánima chases `target`): turn to it, play the attack and spray.
func spray(to: Vector3, target: Node3D = null) -> void:
	var aim: Vector3 = to - global_position
	aim.y = 0
	if aim.length() > 0.01: facing = aim.normalized()
	_aiming = 0.35
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and absf(facing.dot(camera.global_basis.x)) > 0.15: _flip = facing.dot(camera.global_basis.x) < 0.0
	if _spray != null: _spray.spray(muzzle(), to, target)
	kick()

## Where the attack leaves the drawn figure: Brasa's palm, or the ward over the Sereno's hand,
## as texels from the frame's centre and from the soles, in the Fire pose.
func muzzle() -> Vector3:
	var offset: Vector2 = Vector2(24.0, 65.0) if support else Vector2(31.0, 53.0)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var side: Vector3 = camera.global_basis.x if camera != null else Vector3.RIGHT
	side.y = 0
	side = side.normalized() * (-1.0 if _flip else 1.0)
	return global_position + side * offset.x * _texel.x + Vector3.UP * offset.y * _texel.y

func kick() -> void:
	_recoil = 1.0
	var body := get_parent() as Character
	if body != null: body.play_action(&"Fire", 0.28)

## Local operator only: a silhouette through scenery and machines, and a ring painted at the feet.
func mark_local() -> void:
	xray = ShaderMaterial.new()
	xray.shader = XRAY
	xray.set_shader_parameter("tint", Color(0.42, 0.68, 0.65, 0.8) if support else Color(0.9, 0.55, 0.33, 0.8))
	xray.render_priority = 1
	art.next_pass = xray
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.7
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.04
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.62, 0.75, 0.72, 0.85) if support else Color(0.9, 0.67, 0.39, 0.85)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.no_depth_test = true
	paint.render_priority = 2
	ring.material_override = paint
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func _process(delta: float) -> void:
	var body := get_parent() as Character
	if body == null or source.sprite_frames == null: return
	visible = not body.eliminated
	var pixels: Node = get_tree().get_first_node_in_group("pixel_view")
	if pixels != null and Vector2(pixels.metres_per_pixel, pixels.stand) != _grid:
		_grid = Vector2(pixels.metres_per_pixel, pixels.stand)
		_fit()
	# Face where the operator moves, or where they last fired; the art is drawn facing right.
	var camera: Camera3D = get_viewport().get_camera_3d()
	var moving := Vector3(body.velocity.x, 0, body.velocity.z)
	_aiming = maxf(0.0, _aiming - delta)
	if moving.length() > 0.2 and _aiming <= 0.0: facing = moving.normalized()
	if camera != null:
		var across: float = facing.dot(camera.global_basis.x)
		if absf(across) > 0.15: _flip = across < 0.0
	var texture: Texture2D = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	var atlas := texture as AtlasTexture
	if atlas != null:
		var whole: Vector2 = atlas.atlas.get_size()
		art.set_shader_parameter("frame", atlas.atlas)
		art.set_shader_parameter("region", Vector4(atlas.region.position.x / whole.x, atlas.region.position.y / whole.y, atlas.region.size.x / whole.x, atlas.region.size.y / whole.y))
	else:
		art.set_shader_parameter("frame", texture)
		art.set_shader_parameter("region", Vector4(0, 0, 1, 1))
	art.set_shader_parameter("flip", _flip)
	if xray != null:
		xray.set_shader_parameter("frame", art.get_shader_parameter("frame"))
		xray.set_shader_parameter("region", art.get_shader_parameter("region"))
		xray.set_shader_parameter("flip", _flip)
	# A hit flashes the art warm white and squashes it; firing gives a short upward stretch.
	if body.health < _last_health - 0.5: _flash = 1.0
	_last_health = body.health
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	_recoil = move_toward(_recoil, 0.0, delta * 7.0)
	art.set_shader_parameter("flash", _flash * 0.85)
	card.scale = Vector3(1.0 + _flash * 0.08, 1.0 - _flash * 0.08 + _recoil * 0.04, 1.0)
