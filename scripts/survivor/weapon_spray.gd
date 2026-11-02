## The operator's weapon, seen by every peer and drawn like the cast: on the yard's texel grid, in
## each operator's own palette, hard-edged. Brasa's arm pours a stream of pixel fireballs from the
## palm that swell, rise and cool as they roll out and down onto what she burns, shedding sparks
## and soot, and lights the yard around her. El Sereno's ward looses ánimas -- little rain-spirits
## with faces -- that wander to their machine on a weaving, looping path, dripping, and burst
## against it into a ring of water. Presentation only: the host decides what was hit.
extends Node3D
const Fx = preload("res://scenes/actions/combat_fx.gd")
const FLAME = preload("res://scripts/survivor/flame.gdshader")
## The roaring core at the palm, before the stream breaks up into rolling fireballs.
const CORE_LENGTH: float = 2.4
const CORE_WIDTH: float = 1.0
const ANIMA_ART = preload("res://materials/effects/anima.png")
## Seconds an ánima takes from the ward to its machine; the host lands the blast after the same.
const ANIMA_FLIGHT: float = 0.42
## How far an ánima's burst of water reaches around where it lands.
const ANIMA_BLAST: float = 2.2
## The stream's fireballs: launch speed and braking, so they roll out about the flame's reach.
const FIRE_SPEED: float = 16.0
const FIRE_BRAKE: float = 14.0
const FIRE_LIFE: float = 0.55
## Fireball sprite size in texels before it swells.
const FIREBALL: float = 16.0
## One texel of the yard's grid until the pixel view says otherwise (see _fit).
const TEXEL: float = 0.03
const ANIMA_FRAMES: int = 6
var support: bool = false
## Where the weapon leaves the drawn figure, asked every frame so the fire stays in the palm as
## she runs. Set by the operator's sprite.
var muzzle: Callable
var _light: OmniLight3D
var _stream: CPUParticles3D
var _core: MeshInstance3D
var _fire: ShaderMaterial
var _power: float = 0.0
var _sparks: CPUParticles3D
var _soot: CPUParticles3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _aim := Vector3.ZERO
var _animas: Array[Dictionary] = []
var _next: int = 0
var _on: float = 0.0
var _age: float = 0.0
## Every pixel-sized mesh and how many texels it spans, resized once the grid is known.
var _quads: Array = []
var _texel: float = 0.0

static func _ramp(stops: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(stop: Array) -> float: return stop[0]))
	gradient.colors = PackedColorArray(stops.map(func(stop: Array) -> Color: return stop[1]))
	return gradient

## A square of `texels` pixels, flat colour from the particle, solid (or adding light).
func _pixel(texels: float, additive: bool = false) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * texels * TEXEL
	_quads.append([quad, texels])
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = paint
	return quad

static func _particles(parent: Node, mesh: Mesh) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.local_coords = false
	particles.emitting = false
	particles.mesh = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
	return particles

## A fireball as the cast's pixels: a lumpy disc, white-hot in the middle and darker toward its rim;
## the stream's colour ramp tints it from core-white through orange to ember as it cools.
static func _fireball_texture() -> ImageTexture:
	const SIZE: int = 14
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var lobes: Array[Vector3] = [Vector3(7.0, 7.5, 5.6), Vector3(4.5, 6.0, 3.4), Vector3(9.5, 5.5, 3.6), Vector3(7.0, 4.0, 3.4)]
	for y: int in SIZE:
		for x: int in SIZE:
			var depth: float = -1.0
			for lobe: Vector3 in lobes:
				depth = maxf(depth, 1.0 - Vector2(x + 0.5 - lobe.x, y + 0.5 - lobe.y).length() / lobe.z)
			if depth <= 0.0: continue
			var tone: float = 0.62
			if depth > 0.22: tone = 0.82
			if depth > 0.5: tone = 1.0
			image.set_pixel(x, y, Color(tone, tone, tone, 1.0))
	return ImageTexture.create_from_image(image)

static func _fade(points: Array) -> Curve:
	var curve := Curve.new()
	for point: Vector2 in points: curve.add_point(point)
	return curve

func _ready() -> void:
	top_level = true
	_light = OmniLight3D.new()
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	if support:
		# Water carries a cold pale tint of the night, not a saturated cyan pool on the floor.
		_light.light_color = Color(0.70, 0.84, 0.88)
		_light.omni_range = 5.0
		for index: int in 4: _animas.append(_make_anima())
		return
	_light.light_color = Color(1.0, 0.56, 0.24)
	_light.omni_range = 7.0
	# The stream: fireballs leave the palm small and white, swell, brake, rise and cool to ember.
	var ball := QuadMesh.new()
	ball.size = Vector2.ONE * FIREBALL * TEXEL
	_quads.append([ball, FIREBALL])
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	paint.albedo_texture = _fireball_texture()
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Dying fireballs break into pixels rather than going see-through.
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	ball.material = paint
	_stream = _particles(self, ball)
	_stream.name = "Flame"
	_stream.amount = 190
	_stream.lifetime = FIRE_LIFE
	# Index order: sorting by lifetime pairs colours with the wrong fireballs (the white-hot ones end up mid-stream).
	_stream.draw_order = CPUParticles3D.DRAW_ORDER_INDEX
	_stream.spread = 6.0
	_stream.initial_velocity_min = FIRE_SPEED * 0.92
	_stream.initial_velocity_max = FIRE_SPEED * 1.06
	_stream.damping_min = FIRE_BRAKE * 0.9
	_stream.damping_max = FIRE_BRAKE * 1.1
	_stream.gravity = Vector3(0, 3.5, 0)
	_stream.scale_amount_min = 0.8
	_stream.scale_amount_max = 1.2
	# Some fireballs burn a little deeper than others, so the stream is not one flat orange.
	_stream.color_initial_ramp = _ramp([[0.0, Color.WHITE], [0.6, Color(1.0, 0.93, 0.86)], [1.0, Color(1.0, 0.8, 0.7)]])
	_stream.scale_amount_curve = _fade([Vector2(0, 0.45), Vector2(0.4, 1.0), Vector2(1, 1.7)])
	# The bloom already whitens the hottest steps, so the ramp leaves white-yellow early.
	_stream.color_ramp = _ramp([[0.0, Color("fff0c8")], [0.05, Color("ffd27a")], [0.12, Color("ffad4a")], [0.3, Color("ff6a24")],
			[0.56, Color("d4461a")], [0.78, Color("9a3214")], [0.92, Color("7c2a12")], [1.0, Color(0.49, 0.16, 0.07, 0.0)]])
	_fire = ShaderMaterial.new()
	_fire.shader = FLAME
	_fire.set_shader_parameter("texels", Vector2(CORE_LENGTH, CORE_WIDTH) / TEXEL)
	_fire.set_shader_parameter("throat", 0.18)
	_fire.set_shader_parameter("cool", 0.25)
	# No black soot in the core: it is all still burning this close to the palm.
	_fire.set_shader_parameter("soot", Color("7c2a12"))
	var card := QuadMesh.new()
	card.size = Vector2.ONE
	_core = MeshInstance3D.new()
	_core.mesh = card
	_core.material_override = _fire
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.visible = false
	add_child(_core)
	# Sparks thrown ahead of the fire, cooling as they go.
	_sparks = _particles(self, _pixel(2.0, true))
	_sparks.amount = 40
	_sparks.lifetime = 0.5
	_sparks.spread = 16.0
	_sparks.initial_velocity_min = 6.0
	_sparks.initial_velocity_max = 10.5
	_sparks.damping_min = 5.0
	_sparks.damping_max = 9.0
	_sparks.gravity = Vector3(0, 2.2, 0)
	_sparks.scale_amount_curve = _fade([Vector2(0, 1.0), Vector2(0.7, 1.0), Vector2(1, 0.0)])
	_sparks.color_ramp = _ramp([[0.0, Color("fff0c8")], [0.25, Color("ffad4a")], [0.6, Color("ff6a24")], [1.0, Color("7c2a12")]])
	# Soot rolling off the tip: the dark mass the fire leaves.
	_soot = _particles(self, _pixel(5.0))
	_soot.amount = 14
	_soot.lifetime = 0.7
	_soot.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_soot.emission_sphere_radius = 0.45
	_soot.direction = Vector3.UP
	_soot.spread = 35.0
	_soot.initial_velocity_min = 0.6
	_soot.initial_velocity_max = 1.4
	_soot.gravity = Vector3(0, 0.8, 0)
	_soot.scale_amount_min = 0.6
	_soot.scale_amount_max = 1.0
	_soot.scale_amount_curve = _fade([Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 0.0)])
	_soot.color_ramp = _ramp([[0.0, Color("3a1a12")], [0.4, Color("1d1214")], [1.0, Color("111016")]])
	_soot.draw_order = CPUParticles3D.DRAW_ORDER_INDEX

## One spirit: its sprite, the drops it sheds, the splash it ends in and the ripple it leaves.
func _make_anima() -> Dictionary:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_texture = ANIMA_ART
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	paint.alpha_scissor_threshold = 0.5
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	paint.uv1_scale = Vector3(1.0 / ANIMA_FRAMES, 1, 1)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(ANIMA_ART.get_height()) * TEXEL
	_quads.append([quad, float(ANIMA_ART.get_height())])
	var head := MeshInstance3D.new()
	head.mesh = quad
	head.material_override = paint
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.visible = false
	add_child(head)
	var trail := _particles(self, _pixel(2.0))
	# Ectoplasm: motes shed along the path that hang, then drift up and go out -- a spirit, not a drip.
	trail.amount = 30
	trail.lifetime = 0.6
	trail.direction = Vector3.UP
	trail.spread = 180.0
	trail.initial_velocity_min = 0.05
	trail.initial_velocity_max = 0.35
	trail.damping_min = 0.5
	trail.damping_max = 1.0
	trail.gravity = Vector3(0, 0.9, 0)
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.0
	trail.scale_amount_curve = _fade([Vector2(0, 1.0), Vector2(0.55, 1.0), Vector2(1, 0.0)])
	trail.color_ramp = _ramp([[0.0, Color("effeff")], [0.25, Color("93f3ff")], [0.6, Color("36c8e0")], [1.0, Color("6d5bd0")]])
	var splash := _particles(self, _pixel(2.0))
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.amount = 26
	splash.lifetime = 0.5
	splash.direction = Vector3.UP
	splash.spread = 85.0
	splash.initial_velocity_min = 3.0
	splash.initial_velocity_max = 6.5
	splash.gravity = Vector3(0, -14, 0)
	splash.scale_amount_curve = _fade([Vector2(0, 1.0), Vector2(1, 0.4)])
	splash.color_ramp = _ramp([[0.0, Color("effeff")], [0.3, Color("93f3ff")], [1.0, Color("2fa9c2")]])
	return {"head": head, "paint": paint, "trail": trail, "splash": splash, "t": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO,
			"target": null, "out": Vector3.ZERO, "in": Vector3.ZERO, "weave": Vector4.ZERO, "last": Vector3.ZERO}

## Fires from `from` (the palm, or the ward over the hand) toward `to`; an ánima homes on `target`
## while it is still there.
func spray(from: Vector3, to: Vector3, target: Node3D = null) -> void:
	var aim: Vector3 = to - from
	aim.y = 0
	if aim.length() < 0.01: return
	aim = aim.normalized()
	if support:
		_light.global_position = from + aim * 0.4
		var anima: Dictionary = _animas[_next]
		_next = (_next + 1) % _animas.size()
		anima["from"] = from
		anima["to"] = to + Vector3.UP * 0.7
		anima["target"] = weakref(target) if target != null else null
		anima["last"] = from
		# Each spirit wanders its own way: it leaves up and off to one side, comes in from another,
		# and weaves about the path on the way.
		var side: Vector3 = aim.cross(Vector3.UP)
		var lean: float = 1.0 if randf() < 0.5 else -1.0
		anima["out"] = side * lean * randf_range(1.2, 2.6) + Vector3.UP * randf_range(1.0, 2.2) - aim * randf_range(0.0, 1.0)
		anima["in"] = -side * lean * randf_range(0.6, 2.0) + Vector3.UP * randf_range(0.6, 1.8)
		anima["weave"] = Vector4(randf_range(1.5, 2.8), randf_range(0.0, TAU), randf_range(2.0, 3.6), randf_range(0.35, 0.6))
		anima["t"] = 0.0
		anima["head"].visible = true
		anima["head"].global_position = from
		anima["trail"].global_position = from
		anima["trail"].emitting = true
		_on = 0.16
		return
	_from = from
	_to = to
	if _aim == Vector3.ZERO or _on <= 0.0: _aim = _goal(from)
	_on = 0.18
	# Put every emitter at the palm before it starts, or the first puffs come from where it last was.
	_burn(0.0)
	# Only switch on what is off: re-arming a running emitter throws its particles' ages out of step.
	for emitter: CPUParticles3D in [_stream, _sparks, _soot]:
		if not emitter.emitting: emitter.emitting = true

## The stream's heading from the palm: out toward the target and down onto the floor where it
## stands, so the fire lands on what it burns instead of passing over it.
func _goal(from: Vector3) -> Vector3:
	var floor_y: float = (get_parent() as Node3D).global_position.y if get_parent() is Node3D else from.y - 1.2
	var goal: Vector3 = Vector3(_to.x, floor_y + 0.35, _to.z) - from
	return goal.normalized() if goal.length() > 0.01 else Vector3.FORWARD

## Size everything to the pixel view's texel, so effects share the cast's pixels.
func _fit() -> void:
	var pixels: Node = get_tree().get_first_node_in_group("pixel_view")
	var texel: float = pixels.metres_per_pixel if pixels != null else TEXEL
	if is_equal_approx(texel, _texel): return
	_texel = texel
	for entry: Array in _quads: (entry[0] as QuadMesh).size = Vector2.ONE * entry[1] * texel
	if _fire != null: _fire.set_shader_parameter("texels", Vector2(CORE_LENGTH, CORE_WIDTH) / texel)

func _process(delta: float) -> void:
	_age += delta
	if int(_age * 4.0) != int((_age - delta) * 4.0) or _texel == 0.0: _fit()
	_on = maxf(0.0, _on - delta)
	if _stream != null: _burn(delta)
	for anima: Dictionary in _animas: _fly(anima, delta)
	var goal: float = 0.0
	if _on > 0.0: goal = 1.6 if support else 2.4 + sin(_age * 37.0) * 0.5 + sin(_age * 23.0) * 0.4
	_light.light_energy = move_toward(_light.light_energy, goal, delta * 30.0)

## The stream stays in the palm as she moves and swings smoothly onto each new target.
func _burn(delta: float) -> void:
	_power = move_toward(_power, 1.0 if _on > 0.0 else 0.0, delta * (10.0 if _on > 0.0 else 7.0))
	if _on <= 0.0:
		_stream.emitting = false
		_sparks.emitting = false
		_soot.emitting = false
	_core.visible = _power > 0.01
	if not _core.visible: return
	var from: Vector3 = muzzle.call() if muzzle.is_valid() else _from
	_aim = _aim.slerp(_goal(from), 1.0 - exp(-delta * 18.0)).normalized()
	# The core lies along the aim, turned about it to face the camera, anchored in the palm.
	_fire.set_shader_parameter("power", ease(_power, 0.6))
	var camera: Camera3D = get_viewport().get_camera_3d()
	var back: Vector3 = camera.global_basis.z if camera != null else Vector3.UP
	var facing: Vector3 = (back - _aim * back.dot(_aim)).normalized()
	var across: Vector3 = facing.cross(_aim).normalized()
	_core.global_transform = Transform3D(Basis(_aim * CORE_LENGTH, across * CORE_WIDTH, facing), from + _aim * CORE_LENGTH * 0.5)
	_stream.global_position = from
	_stream.direction = _aim
	_sparks.global_position = from
	_sparks.direction = _aim
	_soot.global_position = from + _aim * 5.5
	_light.global_position = from + _aim * 2.2

## One spirit's flight along its weaving curve, homing on its machine, then its burst.
func _fly(anima: Dictionary, delta: float) -> void:
	if anima["t"] < 0.0: return
	var target: Node3D = anima["target"].get_ref() if anima["target"] != null else null
	if target != null and target.is_inside_tree() and not target.get("down"): anima["to"] = target.global_position + Vector3.UP * 0.7
	anima["t"] = minf(1.0, anima["t"] + delta / ANIMA_FLIGHT)
	var t: float = anima["t"]
	var from: Vector3 = anima["from"]
	var to: Vector3 = anima["to"]
	var a: Vector3 = from + anima["out"]
	var b: Vector3 = to + anima["in"]
	var u: float = 1.0 - t
	var at: Vector3 = from * u * u * u + a * 3.0 * u * u * t + b * 3.0 * u * t * t + to * t * t * t
	# The weave: side to side and up and down about the path, dying out as it strikes.
	var path: Vector3 = (to - from)
	path.y = 0
	var across: Vector3 = path.normalized().cross(Vector3.UP) if path.length() > 0.01 else Vector3.RIGHT
	var weave: Vector4 = anima["weave"]
	var settle: float = sin(PI * minf(t * 1.15, 1.0))
	at += (across * sin(t * weave.x * TAU + weave.y) + Vector3.UP * 0.6 * sin(t * weave.z * TAU + weave.y * 1.7)) * weave.w * settle
	# The sprite's tail streams up and to the right: mirror it when it flies screen-right.
	var camera: Camera3D = get_viewport().get_camera_3d()
	var moved: Vector3 = at - anima["last"]
	anima["last"] = at
	var rightward: bool = camera != null and moved.dot(camera.global_basis.x) > 0.0
	var frame: int = int(_age * 14.0) % ANIMA_FRAMES
	var paint: StandardMaterial3D = anima["paint"]
	paint.uv1_scale = Vector3((-1.0 if rightward else 1.0) / ANIMA_FRAMES, 1, 1)
	paint.uv1_offset = Vector3(float(frame + (1 if rightward else 0)) / ANIMA_FRAMES, 0, 0)
	anima["head"].global_position = at
	anima["trail"].global_position = at
	if t >= 1.0:
		anima["t"] = -1.0
		anima["head"].visible = false
		anima["trail"].emitting = false
		anima["splash"].global_position = to
		anima["splash"].restart()
		# The burst: a ring of water out to the edge of what it soaks, and a second close behind.
		var floor_point := Vector3(to.x, to.y - 0.7, to.z)
		Fx.ripple(self, floor_point, Color("93f3ff"), ANIMA_BLAST, 0.38)
		Fx.ripple(self, floor_point, Color("36c8e0"), ANIMA_BLAST * 0.6, 0.5)
