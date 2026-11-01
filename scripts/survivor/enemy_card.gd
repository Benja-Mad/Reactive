## A specialist's pixel art on the same lit card the operators stand on: upright, facing the camera,
## one texel of art to one pixel of the yard's grid, so machines and crew share scale and light.
## The machine picks the animation and where it is heading; the card mirrors the art toward that
## heading and keeps the animation's anchor texel (feet, or a flyer's body) on the machine's origin.
## Directional sets (the Raya) come as Name0..Name4 -- away, three-quarters away, across,
## three-quarters toward, toward -- drawn heading right and mirrored for the left half.
extends Node3D
const CARD = preload("res://scripts/survivor/operator.gdshader")
var frames: SpriteFrames
var directional: bool = false
var animation: String = ""
var frame: int = 0
## The hit pulse: set on the start of each hit, gone in a tenth of a second, so a machine under a
## stream of fire flickers rather than turning into a white cut-out.
var flash: float = 0.0
var _hit: bool = false
## Where the machine faces, flat in the world. Movement sets it unless `hold` keeps an aim.
var heading := Vector3.RIGHT
var hold: float = 0.0
var flip: bool = false
var card: MeshInstance3D
var art: ShaderMaterial
var _quad: QuadMesh
var _clock: float = 0.0
var _played: String = ""
var _anchors: Dictionary = {}
var _grid := Vector2.ZERO
var _texel := Vector2.ONE * 0.03
var _last := Vector3.INF
var _slot: int = 2
## What the shader was last given, so a still frame costs nothing.
var _shown: Array = []
var _pixels: Node

func setup(path: String, is_directional: bool = false) -> void:
	frames = load(path)
	directional = is_directional
	_anchors = frames.get_meta(&"anchors", {})
	art = ShaderMaterial.new()
	art.shader = CARD
	art.set_shader_parameter("self_light", 0.34)
	card = MeshInstance3D.new()
	card.name = "Card"
	_quad = QuadMesh.new()
	card.mesh = _quad
	card.material_override = art
	card.top_level = true
	add_child(card)
	_fit()

## Called every frame with whether the machine is being hit; pulses only when a hit begins.
func hit_flash(active: bool) -> void:
	if active and not _hit: flash = 1.0
	_hit = active

func play(name: String) -> void:
	animation = name

## Turn to `direction` and keep it for `seconds`, whatever the machine's motion says.
func aim(direction: Vector3, seconds: float = 0.25) -> void:
	direction.y = 0
	if direction.length() > 0.01:
		heading = direction.normalized()
		hold = seconds

## World position of an art texel in the current frame (a mouth, a nozzle).
func point(texel: Vector2) -> Vector3:
	var side: Vector3 = _side()
	var center: Vector3 = card.global_position if card != null else global_position
	return center + side * (texel.x - 64.0) * _texel.x * (-1.0 if flip else 1.0) + Vector3.UP * (64.0 - texel.y) * _texel.y

func _side() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var side: Vector3 = camera.global_basis.x if camera != null else Vector3.RIGHT
	side.y = 0
	return side.normalized()

func _fit() -> void:
	var pixels: Node = get_tree().get_first_node_in_group("pixel_view") if is_inside_tree() else null
	if pixels != null:
		_grid = Vector2(pixels.metres_per_pixel, pixels.stand)
		_texel = Vector2(_grid.x, _grid.x * _grid.y)
	_quad.size = Vector2(128, 128) * _texel

func _process(delta: float) -> void:
	if frames == null: return
	if _pixels == null: _pixels = get_tree().get_first_node_in_group("pixel_view")
	if _pixels != null and Vector2(_pixels.metres_per_pixel, _pixels.stand) != _grid: _fit()
	# Heading from the machine's own travel (clients only see positions), unless held on an aim.
	hold = maxf(0.0, hold - delta)
	var moved: Vector3 = global_position - _last if _last != Vector3.INF else Vector3.ZERO
	moved.y = 0
	_last = global_position
	if hold <= 0.0 and moved.length() > 0.004: heading = heading.slerp(moved.normalized(), 1.0 - exp(-delta * 10.0)).normalized()
	var camera: Camera3D = get_viewport().get_camera_3d()
	var right: Vector3 = _side()
	var toward := Vector3(0, 0, 1)
	if camera != null:
		toward = camera.global_basis.z
		toward.y = 0
		toward = toward.normalized()
	var across: float = heading.dot(right)
	if absf(across) > 0.15: flip = across < 0.0
	var name: String = animation
	if directional:
		var angle: float = rad_to_deg(atan2(heading.dot(toward), absf(across)))
		# A little stickiness between neighbouring headings, so a turn does not flicker.
		var wanted: int = clampi(int(round((angle + 90.0) / 45.0)), 0, 4)
		if wanted != _slot and absf((angle + 90.0) / 45.0 - float(_slot)) > 0.65: _slot = wanted
		name = animation + str(_slot)
	if not frames.has_animation(name): return
	if name != _played:
		# Switching heading inside the same action keeps the frame; a new action starts over.
		if directional and _played.rstrip("01234") == animation: frame = mini(frame, frames.get_frame_count(name) - 1)
		else:
			frame = 0
			_clock = 0.0
		_played = name
	_clock += delta * frames.get_animation_speed(name)
	while _clock >= 1.0:
		_clock -= 1.0
		frame += 1
		if frame >= frames.get_frame_count(name): frame = 0 if frames.get_animation_loop(name) else frames.get_frame_count(name) - 1
	if _shown != [name, frame, flip]:
		_shown = [name, frame, flip]
		var atlas := frames.get_frame_texture(name, frame) as AtlasTexture
		var whole: Vector2 = atlas.atlas.get_size()
		art.set_shader_parameter("frame", atlas.atlas)
		art.set_shader_parameter("region", Vector4(atlas.region.position.x / whole.x, atlas.region.position.y / whole.y, atlas.region.size.x / whole.x, atlas.region.size.y / whole.y))
		art.set_shader_parameter("flip", flip)
	if flash > 0.0:
		flash = move_toward(flash, 0.0, delta * 10.0)
		art.set_shader_parameter("flash", flash * 0.4)
	# Keep the anchor texel on the origin: the card's centre is the frame's centre.
	var anchor: Vector2 = _anchors.get(name, Vector2(64, 120))
	card.global_position = global_position + right * (64.0 - anchor.x) * _texel.x * (-1.0 if flip else 1.0) + Vector3.UP * (anchor.y - 64.0) * _texel.y
	card.scale = Vector3(1.0 + flash * 0.06, 1.0 - flash * 0.06, 1.0)
