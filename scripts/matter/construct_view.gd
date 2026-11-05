## A disposable projection of server state. Never resolves gameplay locally.
## One construct keeps one view for its whole life; each phase is a body inside it, and a phase
## change is an animation between bodies rather than a swap, so identity reads on screen.
extends StaticBody3D
const Catalog = preload("res://scripts/matter/materials.gd")
const Meshes = preload("res://scripts/matter/matter_meshes.gd")
const Fx = preload("res://scripts/matter/matter_fx.gd")
const WORDS := {"broken": "ROTURA", "hit": "IMPACTO", "transformed": "CAMBIO", "pulsed": "PULSO",
	"push": "IMPULSO", "command": "DETONAR", "freeze": "CONGELAR", "heat": "CALENTAR"}
const SHARDS := 8

var system: Node
var construct_id: int
var collider: CollisionShape3D
var water_body: MeshInstance3D
var ice_body: MeshInstance3D
var fragments: MultiMeshInstance3D
var steam: Node3D
var glyph: Label3D
var hold_shadow: MeshInstance3D
var conduit: MeshInstance3D
## Fire, current and scrap: built by drawn_body.gd, one body that rebuilds with the shape.
var drawn: Node3D
var scrap_material: StandardMaterial3D
var water_material: ShaderMaterial
var ice_material: ShaderMaterial
var conduit_material: ShaderMaterial
var record: Dictionary = {}
var last_visual_key: String = ""
var _form: String = ""
## The size the current body was built at; a puddle's later spreading is a scale on it.
var _built_size: Vector3 = Vector3.ZERO
var _link: int = 0
## Seconds until the cloud condenses: the host's count at the last apply, run down by this view's
## own frames so a pause, a faster clock or a scald that holds it longer all read right.
var _condense_left: float = INF
## The cloud is drawn only in pixel puffs, dithered as they fade -- no soft volume behind them.
const STEAM_WHITE := Color(0.8, 0.88, 0.92, 1.0)
const STEAM_BRASS := Color(0.82, 0.7, 0.5, 1.0)
var _steam_particles: GPUParticles3D
var _spin: Array[Vector3] = []
var _shard_base: Array[Transform3D] = []
var _tweens: Dictionary = {}
## On a client, where the last snapshot put the matter and how fast it was going: the view eases
## toward it between snapshots instead of jumping ten times a second.
var _target: Vector3 = Vector3.ZERO
var _smoothing: bool = false

func _ready() -> void:
	add_to_group("matter_constructs")
	collider = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	add_child(collider)
	hold_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.65
	disc.bottom_radius = 0.65
	disc.height = 0.006
	disc.radial_segments = 24
	hold_shadow.mesh = disc
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_color = Color(0.01, 0.025, 0.03, 0.4)
	hold_shadow.material_override = shade
	hold_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hold_shadow.visible = false
	add_child(hold_shadow)
	var seed_value: float = float(construct_id % 97) * 0.731
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://scripts/matter/matter_water.gdshader")
	water_material.set_shader_parameter("seed", seed_value)
	ice_material = ShaderMaterial.new()
	ice_material.shader = preload("res://scripts/matter/matter_ice.gdshader")
	ice_material.set_shader_parameter("seed", seed_value)
	water_body = MeshInstance3D.new()
	water_body.material_override = water_material
	water_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_body)
	ice_body = MeshInstance3D.new()
	ice_body.material_override = ice_material
	add_child(ice_body)
	fragments = MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = Fx.shard_mesh()
	multi.instance_count = SHARDS
	fragments.multimesh = multi
	fragments.material_override = ice_material
	add_child(fragments)
	var rng := RandomNumberGenerator.new()
	rng.seed = construct_id * 31 + 5
	for i: int in SHARDS:
		_spin.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(2.0, 6.0))
	glyph = Label3D.new()
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.font_size = 44
	glyph.pixel_size = 0.0062
	glyph.outline_size = 10
	glyph.outline_modulate = Color(0.04, 0.035, 0.03, 0.9)
	glyph.modulate = Color(1.0, 0.74, 0.4)
	glyph.no_depth_test = true
	glyph.render_priority = 2
	glyph.visible = false
	add_child(glyph)
	conduit = MeshInstance3D.new()
	conduit.mesh = ImmediateMesh.new()
	conduit_material = ShaderMaterial.new()
	conduit_material.shader = preload("res://scripts/matter/conduit.gdshader")
	conduit.material_override = conduit_material
	conduit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	conduit.top_level = true
	conduit.visible = false
	add_child(conduit)
	for body: Node3D in [water_body, ice_body, fragments]: body.visible = false

func apply(state: Dictionary) -> void:
	record = state
	_condense_left = float(state.get("condense", INF))
	_target = state["position"]
	var remote: bool = multiplayer.has_multiplayer_peer() and not multiplayer.is_server()
	# A long jump (a fresh record, a teleport) lands at once; ordinary motion is eased in _process.
	if not remote or not _smoothing or global_position.distance_to(_target) > 6.0: global_position = _target
	_smoothing = remote
	rotation.y = state["yaw"]
	hold_shadow.visible = state["shape"] == "orb"
	hold_shadow.position.y = float(state.get("ground_y", state["position"].y)) - state["position"].y + 0.02
	var key: String = str([state["material"],state["shape"],state["size"],state["attachments"],state.get("reaction",{}),state["integrity"],state.get("link",0),state.get("temp",0),state.get("fierce",false),state.get("charge",0)])
	if key == last_visual_key: return
	last_visual_key = key
	var size: Vector3 = state["size"]
	if state["shape"] == "orb":
		if not collider.shape is SphereShape3D: collider.shape = SphereShape3D.new()
		collider.shape.radius = size.x * 0.5
	else:
		if not collider.shape is BoxShape3D: collider.shape = BoxShape3D.new()
		collider.shape.size = size
	collider.position.y = size.y * 0.5
	var debris: bool = state["shape"] == "fragments"
	collision_layer = 1 if Catalog.has_property(state,"solid") and not debris and state["shape"] != "patch" else 0
	collision_mask = 1
	var form: String = state["material"] + "/" + state["shape"]
	if form != _form:
		_change_form(_form, form, state)
		_form = form
		_built_size = size
	elif state["shape"] == "patch" and size != _built_size:
		# A puddle drawn from or filled spreads and shrinks instead of being rebuilt.
		var spread := Vector3((size.x + 0.4) / (_built_size.x + 0.4), 1.0, (size.z + 0.4) / (_built_size.z + 0.4))
		var body: Node3D = drawn if drawn != null and drawn.visible else (water_body if state["material"] == "water" else ice_body)
		_tween("spread", body, "scale", body.scale, spread, 0.35)
	if drawn != null: drawn.set_state(int(state.get("temp", 0)), state.get("fierce", false), int(state.get("charge", 0)))
	var coated: bool = state["attachments"].has("nanites")
	var reaction: Dictionary = state.get("reaction", {})
	for material: ShaderMaterial in [water_material, ice_material]:
		material.set_shader_parameter("coated", coated)
		material.set_shader_parameter("armed", not reaction.is_empty())
		material.set_shader_parameter("extent", size)
	ice_material.set_shader_parameter("damage", clampf(1.0 - float(state["integrity"]) / 20.0, 0.0, 1.0))
	if steam != null and _steam_particles != null:
		# Nanites suspended in the cloud tint it toward brass.
		(_steam_particles.material_override as StandardMaterial3D).albedo_color = STEAM_BRASS if coated else STEAM_WHITE
	glyph.visible = not reaction.is_empty() and get_tree().get_first_node_in_group("survivor_run") == null
	if glyph.visible:
		glyph.text = WORDS.get(reaction["trigger"], "?") + "  ▸  " + WORDS.get(reaction["action"], "?")
	glyph.position.y = _top() + 0.42
	var link: int = int(state.get("link", 0))
	if link != _link:
		if link != 0: _tween("conduit_grow", conduit_material, "shader_parameter/grow", 0.0, 1.0, 0.5)
		_link = link
	conduit.visible = _link != 0

func _top() -> float:
	match record.get("shape", "patch"):
		"wall", "orb": return record["size"].y
		"cloud": return record["size"].y * 0.85
		"fragments": return 0.6
	return 0.15

## Where a conduit plugs into this construct.
func anchor() -> Vector3:
	var height: float = 0.12
	match record.get("shape", "patch"):
		"wall": height = minf(record["size"].y * 0.82, 1.5)
		"cloud", "orb": height = record["size"].y * 0.5
		"fragments": height = 0.45
	return global_position + Vector3.UP * height

func _change_form(previous: String, form: String, state: Dictionary) -> void:
	var size: Vector3 = state["size"]
	var material: String = state["material"]
	var shape: String = state["shape"]
	var was: String = previous.get_slice("/", 0)
	var was_shape: String = previous.get_slice("/", 1) if previous != "" else ""
	var fx_parent: Node = _fx_parent()
	for slot: String in ["lift", "gather"]:
		if _tweens.has(slot) and _tweens[slot].is_valid(): _tweens[slot].kill()
	water_body.scale = Vector3.ONE
	ice_body.scale = Vector3.ONE
	if _tweens.has("spread") and _tweens["spread"].is_valid(): _tweens["spread"].kill()
	if material in ["fire", "current", "scrap"]:
		_change_drawn(was, state)
		return
	if drawn != null: drawn.visible = false
	if material == "water":
		water_body.visible = true
		water_material.set_shader_parameter("wall", shape == "wall")
		water_material.set_shader_parameter("orb", shape == "orb")
		if shape == "orb":
			var sphere := SphereMesh.new()
			sphere.radius = size.x * 0.5
			sphere.height = size.y
			sphere.radial_segments = 32
			sphere.rings = 16
			water_body.mesh = sphere
			water_body.position.y = size.y * 0.5
			if was_shape == "patch":
				_tween("lift", water_body, "position:y", -Catalog.HOLD_HEIGHT, size.y * 0.5, 0.45)
				_tween("gather", water_body, "scale", Vector3(1.8, 0.15, 1.8), Vector3.ONE, 0.45)
		elif shape == "wall":
			var curtain := BoxMesh.new()
			curtain.size = Vector3(size.x, size.y, maxf(size.z, 0.2) * 0.8)
			curtain.subdivide_width = 40
			curtain.subdivide_height = 16
			curtain.subdivide_depth = 1
			water_body.mesh = curtain
			water_body.position.y = size.y * 0.5
			if was == "water" and was_shape == "patch":
				_tween("rise", water_material, "shader_parameter/rise", 0.08, 1.0, 0.42, Tween.TRANS_BACK)
		else:
			var puddle := PlaneMesh.new()
			puddle.size = Vector2(size.x + 0.4, size.z + 0.4)
			puddle.subdivide_width = 36
			puddle.subdivide_depth = 28
			water_body.mesh = puddle
			water_body.position.y = 0.02
		if was == "ice":
			_tween("presence", water_material, "shader_parameter/presence", 0.0, 1.0, 0.6)
			_tween("formation", ice_material, "shader_parameter/formation", 1.08, 0.0, 0.6)
			Fx.splash(fx_parent, global_position, Vector3(size.x * 0.4, 0.2, 0.4))
			_hide_later([ice_body, fragments], 0.6)
		elif was == "steam":
			_tween("presence", water_material, "shader_parameter/presence", 0.0, 1.0, 0.8)
			_fade_steam(0.8)
			Fx.splash(fx_parent, global_position, Vector3(size.x * 0.4, 0.3, size.z * 0.4))
		elif was == "":
			_tween("presence", water_material, "shader_parameter/presence", 0.0, 1.0, 0.3)
		else:
			water_material.set_shader_parameter("presence", 1.0)
	elif material == "ice":
		ice_material.set_shader_parameter("orb", shape == "orb")
		if shape == "fragments":
			ice_body.visible = false
			fragments.visible = true
			_scatter_shards(size)
		else:
			if shape == "orb":
				var crystal := SphereMesh.new()
				crystal.radius = size.x * 0.5
				crystal.height = size.y
				crystal.radial_segments = 10
				crystal.rings = 5
				ice_body.mesh = crystal
				ice_body.position.y = size.y * 0.5
			else:
				ice_body.mesh = Meshes.crystal_wall(size, construct_id) if shape == "wall" else Meshes.crystal_floe(size, construct_id)
				ice_body.position.y = 0.0
			ice_body.visible = true
			fragments.visible = false
		if was == "water":
			_tween("formation", ice_material, "shader_parameter/formation", 0.0, 1.08, 0.55, Tween.TRANS_SINE)
			_tween("presence", water_material, "shader_parameter/presence", 1.0, 0.0, 0.5)
			_hide_later([water_body], 0.5)
			Fx.frost(fx_parent, global_position + Vector3.UP * size.y * 0.5, Vector3(size.x * 0.45, size.y * 0.4, 0.3))
		elif was != "ice":
			ice_material.set_shader_parameter("formation", 1.08)
		if was == "ice" and shape == "fragments":
			ice_material.set_shader_parameter("formation", 1.08)
	elif material == "steam":
		_build_steam(size)
		if was == "water":
			_tween("presence", water_material, "shader_parameter/presence", 1.0, 0.0, 0.45)
			_hide_later([water_body], 0.45)
			Fx.boil(fx_parent, global_position + Vector3.UP * 0.6, Vector3(size.x * 0.3, 0.4, 0.3))

## Fire, current and scrap take their body from drawn_body.gd; scrap broken into shrapnel uses
## the shard pieces in its own metal. A source's fire and terminals belong to its prop instead.
func _change_drawn(was: String, state: Dictionary) -> void:
	var material: String = state["material"]
	var shape: String = state["shape"]
	for body: Node3D in [water_body, ice_body]: body.visible = false
	_fade_steam(0.4)
	if drawn == null:
		drawn = preload("res://scripts/matter/drawn_body.gd").new()
		add_child(drawn)
	drawn.scale = Vector3.ONE
	if material == "scrap" and shape == "fragments":
		if scrap_material == null:
			scrap_material = StandardMaterial3D.new()
			scrap_material.albedo_color = Color("3a2a20")
			scrap_material.metallic = 0.5
			scrap_material.roughness = 0.7
		fragments.material_override = scrap_material
		fragments.visible = true
		drawn.visible = false
		_scatter_shards(state["size"])
		return
	fragments.visible = false
	fragments.material_override = ice_material
	drawn.visible = not (state.get("source", false) and material in ["fire", "current"])
	drawn.build(material, shape, state["size"], construct_id)
	drawn.set_state(int(state.get("temp", 0)), state.get("fierce", false), int(state.get("charge", 0)))
	var fx_parent: Node = _fx_parent()
	if was == "water" or was == "ice": Fx.boil(fx_parent, global_position + Vector3.UP * 0.4, Vector3(0.6, 0.3, 0.6))

## Effects live beside the world, never under it: the world's children are its views.
func _fx_parent() -> Node:
	return system.get_parent() if system != null and system.get_parent() != null else get_parent()

func _scatter_shards(size: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = construct_id * 17 + 3
	_shard_base.clear()
	for i: int in SHARDS:
		var spot := Vector3((float(i % 4) - 1.5) * size.x * 0.23 + rng.randf_range(-0.2, 0.2), 0.2 + rng.randf_range(0.0, 0.5), (float(i / 4) - 0.5) * 0.7 + rng.randf_range(-0.2, 0.2))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))).scaled(Vector3.ONE * rng.randf_range(0.9, 1.7))
		_shard_base.append(Transform3D(basis, spot))
		fragments.multimesh.set_instance_transform(i, _shard_base[i])

func _build_steam(size: Vector3) -> void:
	if steam != null: return
	steam = Node3D.new()
	add_child(steam)
	steam.position.y = size.y * 0.5
	_steam_particles = GPUParticles3D.new()
	_steam_particles.amount = 64
	_steam_particles.lifetime = 4.0
	_steam_particles.local_coords = false
	_steam_particles.visibility_aabb = AABB(-size, size * 2.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 1.0
	process.emission_shape_scale = size * 0.3
	process.direction = Vector3.UP
	process.spread = 60.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.35
	process.gravity = Vector3(0, 0.12, 0)
	process.damping_min = 0.2
	process.damping_max = 0.4
	# Upright puffs: a turned pixel sprite stops reading as pixels.
	process.scale_min = 2.6
	process.scale_max = 4.0
	process.scale_curve = Fx.grow_curve(0.6, 1.2)
	process.color_ramp = Fx.hold_ramp(0.15, 0.65)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 3.0
	_steam_particles.process_material = process
	# Prewarm only after assigning the process material, avoiding an orphan fallback shader.
	_steam_particles.preprocess = 1.5
	_steam_particles.draw_pass_1 = Fx.quad(1.0)
	_steam_particles.material_override = Fx.puff_material(STEAM_WHITE, 0.34)
	_steam_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	steam.add_child(_steam_particles)

func _fade_steam(duration: float) -> void:
	if steam == null: return
	var dying := steam
	steam = null
	if _steam_particles != null: _steam_particles.emitting = false
	_steam_particles = null
	var tween := create_tween()
	tween.tween_interval(maxf(duration, 2.0))
	tween.tween_callback(dying.queue_free)

func _hide_later(bodies: Array, delay: float) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		var current: String = record.get("material", "")
		for body: Node3D in bodies:
			if body == water_body and current == "water": continue
			if (body == ice_body or body == fragments) and current == "ice": continue
			body.visible = false)

func _tween(slot: String, target: Object, property: String, from: Variant, to: Variant, duration: float, transition: Tween.TransitionType = Tween.TRANS_CUBIC) -> void:
	if _tweens.has(slot) and _tweens[slot].is_valid(): _tweens[slot].kill()
	target.set(property, from)
	var tween := create_tween()
	tween.tween_property(target, property, to, duration).set_trans(transition).set_ease(Tween.EASE_OUT)
	_tweens[slot] = tween

## Replicated events that need a visible answer from this construct.
func react_to(event: Dictionary) -> void:
	var fx_parent: Node = _fx_parent()
	match event["kind"]:
		"created", "splashed", "dropped":
			Fx.splash(fx_parent, global_position, Vector3(1.4, 0.1, 1.0))
		"hit":
			for material: ShaderMaterial in [water_material, ice_material]:
				_tween("impact_" + str(material.get_instance_id()), material, "shader_parameter/impact", 1.0, 0.0, 0.28)
			if record.get("material", "") == "ice":
				Fx.chips(fx_parent, global_position + Vector3.UP * minf(_top() * 0.6, 1.2), ice_material)
		"broken":
			Fx.shatter(fx_parent, global_position, scrap_material if record.get("material", "") == "scrap" and scrap_material != null else ice_material)
		"coated":
			for material: ShaderMaterial in [water_material, ice_material]:
				_tween("coat_" + str(material.get_instance_id()), material, "shader_parameter/coat_progress", 0.0, 1.0, 0.9, Tween.TRANS_SINE)
		"armed":
			glyph.scale = Vector3.ONE * 1.7
			var tween := create_tween()
			tween.tween_property(glyph, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"pulse":
			conduit_material.set_shader_parameter("pulse_at", 0.0)
			var tween := create_tween()
			tween.tween_property(conduit_material, "shader_parameter/pulse_at", 1.0, float(event.get("duration", 0.5)))
			tween.tween_callback(func() -> void: conduit_material.set_shader_parameter("pulse_at", -1.0))
		"pulsed":
			Fx.arrival(fx_parent, anchor())
			for material: ShaderMaterial in [water_material, ice_material]:
				_tween("pulse_" + str(material.get_instance_id()), material, "shader_parameter/pulse", 1.0, 0.0, 0.6)

func _process(delta: float) -> void:
	if record.is_empty(): return
	if _smoothing:
		_target += record["velocity"] * delta
		global_position = global_position.lerp(_target, 1.0 - exp(-delta * 18.0))
	if fragments.visible and record["velocity"].length_squared() > 0.04:
		# Debris in flight tumbles; at rest it settles where it fell.
		var speed: float = record["velocity"].length()
		for i: int in _shard_base.size():
			var spun: Basis = _shard_base[i].basis.rotated(_spin[i].normalized(), _spin[i].length() * delta * speed * 0.25)
			_shard_base[i] = Transform3D(spun, _shard_base[i].origin)
			fragments.multimesh.set_instance_transform(i, _shard_base[i])
	if steam != null and _steam_particles != null:
		# The cloud thins in its last second before it condenses: fewer, fainter puffs.
		_condense_left -= delta
		_steam_particles.amount_ratio = clampf(_condense_left / 1.2, 0.15, 1.0)
	if conduit.visible:
		_draw_conduit()

func _draw_conduit() -> void:
	var target_view: Node3D = system.views.get(_link) if system != null else null
	if target_view == null or not is_instance_valid(target_view):
		conduit.visible = false
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var a: Vector3 = anchor()
	var b: Vector3 = target_view.anchor()
	var distance: float = a.distance_to(b)
	var lift: float = 0.35 + distance * 0.07
	var target_record: Dictionary = target_view.record
	conduit_material.set_shader_parameter("length", distance)
	conduit_material.set_shader_parameter("armed_end", 1.0 if target_record.get("reaction", {}).get("trigger", "") == "pulsed" else 0.0)
	var geometry := conduit.mesh as ImmediateMesh
	geometry.clear_surfaces()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps: int = 28
	var toward: Vector3 = camera.global_position
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var point: Vector3 = a.lerp(b, t) + Vector3.UP * sin(PI * t) * lift
		var ahead: Vector3 = a.lerp(b, minf(t + 0.02, 1.0)) + Vector3.UP * sin(PI * minf(t + 0.02, 1.0)) * lift
		var behind: Vector3 = a.lerp(b, maxf(t - 0.02, 0.0)) + Vector3.UP * sin(PI * maxf(t - 0.02, 0.0)) * lift
		var tangent: Vector3 = (ahead - behind).normalized()
		var side: Vector3 = tangent.cross((toward - point).normalized()).normalized() * 0.055
		geometry.surface_set_uv(Vector2(t, 0.0))
		geometry.surface_add_vertex(point - side)
		geometry.surface_set_uv(Vector2(t, 1.0))
		geometry.surface_add_vertex(point + side)
	geometry.surface_end()

func take_damage(amount: float) -> void:
	if multiplayer.is_server():
		system.damage_construct(construct_id, amount)
