## The yard drawn on the operators' own pixel grid. The 3D world (scenery, machines, matter and the
## operator cards) renders into a small buffer where one pixel is one texel of the operator art at
## the play plane, then scales up sharp. The camera is snapped to that grid and the image slid back
## by the remainder, so pixels hold still while the view follows. Local presentation only: the HUD
## keeps drawing at native resolution above it.
extends Node
const UPSCALE = preload("res://scripts/survivor/pixel_upscale.gdshader")
## Buffer width. At the 50 m framing this is ~3 cm a pixel: one texel of the operator sprites.
const WIDTH: int = 1152
## Spare pixels on every side, so sliding by the snap remainder never shows the buffer's edge.
const MARGIN: int = 2
var source: Camera3D
var focus_distance: float = 50.0
## Size of one buffer pixel at the focus distance; the operator cards size their texels from it.
var metres_per_pixel: float = 0.03
## How much a standing card must stretch so its texels stay square under the camera's pitch.
var stand: float = 1.0
var view: SubViewport
var eye: Camera3D
var screen: TextureRect
var _root: Viewport
var _height: int = 648

func setup(camera: Camera3D, distance: float) -> void:
	source = camera
	focus_distance = distance
	name = "PixelView"
	add_to_group("pixel_view")
	# Runs after the camera rig has placed the camera for this frame.
	process_priority = 100
	_root = camera.get_viewport()
	view = SubViewport.new()
	view.name = "WorldPixels"
	view.world_3d = _root.find_world_3d()
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	view.use_taa = false
	view.positional_shadow_atlas_size = _root.positional_shadow_atlas_size
	view.audio_listener_enable_3d = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	eye = Camera3D.new()
	eye.name = "PixelEye"
	view.add_child(eye)
	eye.current = true
	var layer := CanvasLayer.new()
	layer.layer = -20
	add_child(layer)
	screen = TextureRect.new()
	screen.texture = view.get_texture()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sharp := ShaderMaterial.new()
	sharp.shader = UPSCALE
	screen.material = sharp
	layer.add_child(screen)
	# The window itself no longer draws the world; it only shows the buffer and the HUD.
	# The diorama blur was tuned on a full-width frame; this buffer is about half that: one level less.
	var presentation: Node = source.get_parent().get("pixel_presentation") if source.get_parent() != null else null
	if presentation != null:
		presentation.presentation_material.set_shader_parameter("blur_levels", 2.25)
		# The operators are drawn on this grid; the band they stand in stays sharp.
		presentation.presentation_material.set_shader_parameter("play_band", 1.0)
	_root.disable_3d = true
	_root.size_changed.connect(_resize)
	_resize()
	_sync()

func _exit_tree() -> void:
	if _root != null: _root.disable_3d = false

func _resize() -> void:
	var visible: Vector2 = _root.get_visible_rect().size
	_height = maxi(1, roundi(WIDTH * visible.y / visible.x))
	view.size = Vector2i(WIDTH + MARGIN * 2, _height + MARGIN * 2)
	screen.size = Vector2(view.size) * (visible.x / WIDTH)

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	if source == null or not is_instance_valid(source): return
	var half: float = tan(deg_to_rad(source.fov) * 0.5)
	# Same pixel size as the window camera's view, with the margin added around it.
	eye.keep_aspect = Camera3D.KEEP_WIDTH
	eye.fov = rad_to_deg(2.0 * atan(half * float(WIDTH + MARGIN * 2) / WIDTH))
	eye.near = source.near
	eye.far = source.far
	eye.cull_mask = source.cull_mask
	eye.environment = source.environment
	eye.attributes = source.attributes
	eye.compositor = source.compositor
	metres_per_pixel = 2.0 * focus_distance * half / WIDTH
	var forward: Vector3 = -source.global_basis.z
	stand = 1.0 / maxf(0.2, Vector2(forward.x, forward.z).length())
	# Snap the eye to whole pixels across the view plane; slide the image by what was rounded off.
	var basis: Basis = source.global_basis
	var origin: Vector3 = source.global_position
	var across: float = origin.dot(basis.x) / metres_per_pixel
	var upward: float = origin.dot(basis.y) / metres_per_pixel
	var dx: float = roundf(across) - across
	var dy: float = roundf(upward) - upward
	eye.global_transform = Transform3D(basis, origin + (basis.x * dx + basis.y * dy) * metres_per_pixel)
	var scale: float = _root.get_visible_rect().size.x / WIDTH
	screen.position = Vector2(-MARGIN + dx, -MARGIN - dy) * scale
