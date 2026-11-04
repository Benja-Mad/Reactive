## Draws the forces the crew's matter puts on the yard, on every peer, from replicated records:
## a well's whirl and the ring of its matter going round, a repulsor's wave and bubble, the scald
## under boiling steam, and a quick
## ring for each push, fall and burst. It also draws the properties the rules read, the same on
## matter and machines: a 1 px orange or cyan ring for heat or cold, crawling sparks and a humming
## light for charge, and the arcs, puffs and frost the rules make (see rules.gd). An arc is a
## jagged white-hot bolt with a yellow body and a soft halo, forking as it goes, that pops a spark
## and a flash of light on everything it runs through. And it draws where the matter comes from:
## the burst mains that keep the yard's puddles full, the water running along the floor from a
## puddle to where a routine acts, and the beam from an operator for each energy a step puts in.
extends Node3D
const Recipe = preload("res://scripts/survivor/recipe.gd")
const Catalog = preload("res://scripts/matter/materials.gd")
const GRAVITY_SHADER = preload("res://scripts/survivor/gravity_field.gdshader")
const SHADER = preload("res://scripts/survivor/field_ring.gdshader")
const GRAVITY := Color("8d7bff")
const REPEL := Color("b4a6ff")
const SCALD := Color("e8a85a")
const BURST := Color("efe6cf")
const HOT := Color("e8763a")
const FLAME_CORE := Color("ffd27a")
const COLD := Color("4fc3d6")
const SPARK := Color("f4e86a")
const CORE := Color("fffdf0")
const HALO := Color(0.95, 0.78, 0.25, 0.34)
## Running water, deep to bright, the same ramp the matter's own water is drawn in.
const WATER_DEEP := Color("1d6f80")
const WATER_BODY := Color("36c8e0")
const WATER_LIT := Color("93f3ff")
const BRASS := Color("d9a441")
## A drawn draught's ribbon by substance: deep under-colour, body, lit thread.
const STREAM := {"water": [WATER_DEEP, WATER_BODY, WATER_LIT], "fire": [Color("5a1a08"), HOT, Color("ffd27a")],
	"current": [Color("3a3410"), SPARK, CORE], "scrap": [Color("1e1a16"), Color("6b5a48"), Color("b08a6a")]}
## What a ring of each material looks like going round: deep under-colour, body, lit edge.
const RING := {"water": [WATER_DEEP, WATER_BODY, WATER_LIT], "ice": [Color("1f4c66"), COLD, Color("d8f6ff")],
	"steam": [Color("5d6a70"), Color("c3cfd0"), Color("f2f7f8")], "fire": [Color("5a1a08"), HOT, FLAME_CORE],
	"current": [Color("3a3410"), SPARK, CORE], "scrap": [Color("1e1a16"), Color("6b5a48"), Color("b08a6a")]}
## A step's beam colour by its piece; an arc is drawn as a bolt instead.
const TETHER := {"cold": COLD, "fire": HOT, "coat": BRASS, "push": BURST, "well": GRAVITY, "repel": REPEL}
const TETHER_LIFE := 0.32
## Seconds a discharge stays on screen; the shape is redrawn every BEAT so it crackles.
const ARC_LIFE := 0.34
const BEAT := 0.05
const CombatFx = preload("res://scenes/actions/combat_fx.gd")
const Attack = preload("res://scripts/survivor/attack.gd")
## Weapon balls on their way up and down: the ball, its shadow, where it lands and when.
var _falls: Array[Dictionary] = []
## Where the player just clicked for «on cue»: four corners on the floor closing in, amber when a
## routine answers, grey when none was ready. Local to the one who clicked.
var _aims: Array[Dictionary] = []
const AIM_READY := Color("f0a04a")
const AIM_IDLE := Color("6a6f7a")
var world: Node
var machines: Node3D
var _fields: Dictionary = {}
## Property marks and live arcs, redrawn every frame as 1 px lines.
var _lines: ImmediateMesh
var _arcs: Array[Dictionary] = []
var _time: float = 0.0
## The additive halo round every bolt and crawling spark.
var _glow: ImmediateMesh
## Charged matter hums: one flickering light under each, by record id.
var _live: Dictionary = {}
## The camera's forward, so bolts are ribbons that face it.
var _view: Vector3 = Vector3.FORWARD
var _rng := RandomNumberGenerator.new()
## The meshes with a ribbon surface begun this frame (an empty surface is an error).
var _open: Dictionary = {}
## Captures hold arcs and sparks still instead of flickering them.
var steady: bool = false
## Drawn water on its way: {"from", "to", "left", "life"}.
var _streams: Array[Dictionary] = []
## Operators' beams into their matter: {"from", "to", "color", "left"}.
var _beams: Array[Dictionary] = []
## The burst main over each source puddle, by record id.
var _sources: Dictionary = {}
var _aftermath: Dictionary = {}

func _ready() -> void:
	world.matter_event.connect(_on_event)
	_lines = ImmediateMesh.new()
	var holder := MeshInstance3D.new()
	holder.mesh = _lines
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.vertex_color_use_as_albedo = true
	holder.material_override = ink
	add_child(holder)
	_glow = ImmediateMesh.new()
	var haze := MeshInstance3D.new()
	haze.mesh = _glow
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.vertex_color_use_as_albedo = true
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	haze.material_override = light
	add_child(haze)

## What each rule's moment sounds like (tools/audio/synth.py).
const SOUND: Dictionary = {"arc": "zap", "steam": "hiss", "smoke": "sizzle", "ignite": "ignite", "frost": "frost",
	"nanites": "nanites", "grind": "grind", "sling": "whoosh", "flare": "boom", "shrapnel": "clatter", "bowl": "thud"}

## A rule's moment, sent by the host (spellwork.rule_fx).
func rule(kind: String, points: PackedVector3Array) -> void:
	if not points.is_empty() and SOUND.has(kind): Sfx.of(self).at(SOUND[kind], points[0])
	match kind:
		"arc":
			_arcs.append({"points": points, "left": ARC_LIFE, "life": ARC_LIFE, "seed": randi(), "width": 1.0})
			CombatFx.flash(get_parent(), points[0] + Vector3.UP * 0.4, SPARK, 4.5, 4.5, 0.3)
			for i: int in range(1, points.size()): CombatFx.spark(get_parent(), points[i], SPARK, 10 if i < 4 else 6)
		"steam": CombatFx.smoke(get_parent(), points[0] + Vector3.UP * 0.9, Color("c3cfd0"), 10)
		# A fire put out: dark smoke where it was. A machine catching: a flare of flame on it.
		"smoke": CombatFx.smoke(get_parent(), points[0] + Vector3.UP * 0.5, Color("3a3634"), 14)
		"ignite":
			CombatFx.burst(get_parent(), points[0] + Vector3.UP * 0.8, HOT)
			CombatFx.spark(get_parent(), points[0] + Vector3.UP * 1.0, HOT, 8)
		"frost":
			CombatFx.burst(get_parent(), points[0] + Vector3.UP * 0.8, COLD)
			CombatFx.ripple(get_parent(), points[0], COLD, 1.1, 0.35)
		# Nanites going off on a machine: a brass flash and a ring.
		"nanites":
			CombatFx.burst(get_parent(), points[0] + Vector3.UP * 0.7, BRASS)
			CombatFx.ripple(get_parent(), points[0], BRASS, 2.4, 0.35)
		# Scrap or ice going round a ring, biting into a machine riding it.
		"grind":
			CombatFx.spark(get_parent(), points[0] + Vector3.UP * 0.5, BRASS, 5)
		# A well letting go: a ring knocked outward and the camera jolts.
		"sling":
			CombatFx.ripple(get_parent(), points[0], GRAVITY, Catalog.VORTEX_RING + 1.2, 0.3)
			get_tree().call_group("camera_shakers", "add_shake", 0.04)
		# A drum set off: a ring of flame out to what it lights, and the camera jolts.
		"flare":
			CombatFx.burst(get_parent(), points[0] + Vector3.UP * 0.9, HOT)
			CombatFx.ripple(get_parent(), points[0], HOT, 3.5, 0.4)
			CombatFx.spark(get_parent(), points[0] + Vector3.UP * 1.2, HOT, 16)
			get_tree().call_group("camera_shakers", "add_shake", 0.05)
		# A heap burst by a hit: metal flying out to the edge of what it reaches.
		"shrapnel":
			CombatFx.burst(get_parent(), points[0] + Vector3.UP * 0.6, BRASS)
			CombatFx.ripple(get_parent(), points[0], BRASS, 3.5, 0.3)
			CombatFx.spark(get_parent(), points[0] + Vector3.UP * 0.7, BRASS, 18)
			get_tree().call_group("camera_shakers", "add_shake", 0.05)
		# Two machines meeting at speed.
		"bowl":
			CombatFx.burst(get_parent(), points[0] + Vector3.UP * 0.7, BURST)
			CombatFx.spark(get_parent(), points[0] + Vector3.UP * 0.8, BRASS, 8)

## A draught running low along the floor to where a routine acts, from the operator's hands or
## off the puddle «on wade» works.
func stream(from: Vector3, to: Vector3, duration: float, substance: String = "water") -> void:
	_streams.append({"from": from + Vector3.UP * 0.08, "to": to + Vector3.UP * 0.08, "left": duration + 0.22, "life": duration, "colors": STREAM.get(substance, STREAM["water"])})
	CombatFx.ripple(get_parent(), from, STREAM.get(substance, STREAM["water"])[1], 1.3, 0.4)
	match substance:
		"water": preload("res://scripts/matter/matter_fx.gd").splash(get_parent(), from, Vector3(0.4, 0.05, 0.4))
		"fire": CombatFx.spark(get_parent(), from + Vector3.UP * 0.6, HOT, 10)
		"current":
			_arcs.append({"points": PackedVector3Array([from + Vector3.UP * 0.6, to + Vector3.UP * 0.1]), "left": duration + 0.1, "life": duration + 0.1, "seed": randi(), "width": 0.7})
		"scrap": CombatFx.smoke(get_parent(), from + Vector3.UP * 0.3, Color("4a4038"), 8)

## Where the pointer is on the floor while a routine on cue is ready, or null: small dim corners
## that follow it, so the click is offered without a word.
var hover: Variant = null
## The machine this player marked with a click (run.marked): amber corners that ride it.
var mark: Node3D = null
const AIM_HOVER := Color("c98a3e")
const AIM_INK := Color("0d0f14")

## Four floor corners round `at`, each an L of arm `arm`, on an ink outline so they read over
## anything the yard has on it.
func _corners(at: Vector3, half: float, arm: float, width: float, colour: Color) -> void:
	for pass_ink: bool in [true, false]:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				# The ink a little under the colour, so the colour wins the depth test over it.
				var tip: Vector3 = at + Vector3(sx * half, 0.12 if pass_ink else 0.16, sz * half)
				var l := PackedVector3Array([tip - Vector3(sx * arm, 0, 0), tip, tip - Vector3(0, 0, sz * arm)])
				_ribbon(_lines, l, width + (2.0 * CombatFx._texel(self) if pass_ink else 0.0), AIM_INK if pass_ink else colour)

## Two of this player's routines meeting here (spellwork.combo_fx): the amber of the program's
## combo bracket, rung out once on the floor so the eye finds where the HUD's join came from.
func combo(at: Vector3) -> void:
	CombatFx.ripple(get_parent(), Vector3(at.x, at.y + 0.1, at.z), AIM_READY, 2.2, 0.45)

func aim(at: Vector3, ready: bool) -> void:
	_aims.append({"at": at, "left": 0.6 if ready else 0.3, "life": 0.6 if ready else 0.3, "ready": ready})

## Sparks thrown from a fire let go, out to `radius`.
func sparks(at: Vector3, radius: float) -> void:
	CombatFx.burst(get_parent(), at + Vector3.UP * 0.5, HOT)
	CombatFx.ripple(get_parent(), at, HOT, radius, 0.4)
	for i: int in 8: CombatFx.spark(get_parent(), at + Vector3(cos(i * TAU / 8.0), 0, sin(i * TAU / 8.0)) * radius * 0.6 + Vector3.UP * 0.5, HOT, 4)

## An operator putting a step's energy into the matter: a beam that reaches out from their hands.
func tether(key: String, from: Vector3, to: Vector3) -> void:
	var hands: Vector3 = from + Vector3.UP * 0.9
	if key == "arc":
		_arcs.append({"points": PackedVector3Array([hands, to]), "left": ARC_LIFE * 0.8, "life": ARC_LIFE * 0.8, "seed": randi(), "width": 0.8})
		return
	_beams.append({"from": hands, "to": to, "color": TETHER.get(key, BURST), "left": TETHER_LIFE})

## A weapon's ball: up from the operator's hands on a beam, then down on `spot`, landing `time`
## seconds from now. A third of the time it rises; the rest it falls, faster and faster, while its
## shadow on the floor darkens and tightens under it.
func fall(from: Vector3, spot: Vector3, base: String, time: float) -> void:
	var colors: Array = STREAM.get(base, STREAM["water"])
	var ball := MeshInstance3D.new()
	var body := SphereMesh.new()
	body.radius = 0.32
	body.height = 0.64
	body.radial_segments = 10
	body.rings = 5
	ball.mesh = body
	ball.material_override = _flat(colors[1], 1.0)
	# The lit side: a smaller ball set into the top of it.
	var lit := MeshInstance3D.new()
	var core := SphereMesh.new()
	core.radius = 0.17
	core.height = 0.34
	core.radial_segments = 8
	core.rings = 4
	lit.mesh = core
	var shine: StandardMaterial3D = _flat(colors[2], 1.0)
	# Drawn over the body, so an unshaded ball still reads as round and lit from above.
	shine.no_depth_test = true
	shine.render_priority = 1
	lit.material_override = shine
	lit.position = Vector3(-0.08, 0.12, 0.0)
	ball.add_child(lit)
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.01
	disc.radial_segments = 12
	shadow.mesh = disc
	shadow.material_override = _flat(Color(0.02, 0.02, 0.03), 0.25)
	add_child(ball)
	add_child(shadow)
	var hands: Vector3 = from + Vector3.UP * 0.9
	ball.global_position = hands
	shadow.global_position = spot + Vector3.UP * 0.03
	_falls.append({"ball": ball, "shadow": shadow, "spot": spot, "from": hands, "left": time, "life": time, "base": base, "colors": colors, "trail": 0.0})
	_beams.append({"from": hands, "to": spot + Vector3.UP * Attack.FALL_HEIGHT, "color": colors[1], "left": time / 3.0})

static func _flat(color: Color, alpha: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(color, alpha)
	if alpha < 1.0: paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return paint

func _drop_balls(delta: float) -> void:
	for index: int in range(_falls.size() - 1, -1, -1):
		var fall: Dictionary = _falls[index]
		fall["left"] -= delta
		var ball: MeshInstance3D = fall["ball"]
		var top: Vector3 = fall["spot"] + Vector3.UP * Attack.FALL_HEIGHT
		var t: float = 1.0 - fall["left"] / fall["life"]
		if fall["left"] <= 0.0:
			_land(fall)
			ball.queue_free()
			fall["shadow"].queue_free()
			_falls.remove_at(index)
			continue
		if t < 1.0 / 3.0:
			ball.global_position = fall["from"].lerp(top, ease(t * 3.0, 0.5))
		else:
			var down: float = (t - 1.0 / 3.0) * 1.5
			ball.global_position = top.lerp(fall["spot"] + Vector3.UP * 0.32, down * down)
		# The shadow: three hard steps darker and tighter as the ball comes down.
		var near: float = clampf((t - 1.0 / 3.0) * 1.5, 0.0, 1.0)
		var step: int = int(near * 2.99)
		fall["shadow"].scale = Vector3.ONE * [1.3, 1.0, 0.8][step]
		var shade: StandardMaterial3D = fall["shadow"].material_override
		shade.albedo_color.a = [0.3, 0.5, 0.7][step]
		fall["trail"] -= delta
		if fall["base"] == "fire" and fall["trail"] <= 0.0:
			fall["trail"] = 0.08
			CombatFx.spark(get_parent(), ball.global_position, HOT, 3)

## What a ball leaves where it lands, on top of the host's ring: water splashes, fire scatters.
func _land(fall: Dictionary) -> void:
	var spot: Vector3 = fall["spot"]
	CombatFx.ripple(get_parent(), spot, fall["colors"][1], Attack.FALL_RADIUS, 0.3)
	match fall["base"]:
		"water": preload("res://scripts/matter/matter_fx.gd").splash(get_parent(), spot, Vector3(0.6, 0.05, 0.6))
		"fire":
			CombatFx.burst(get_parent(), spot + Vector3.UP * 0.4, HOT)
			for i: int in 6: CombatFx.spark(get_parent(), spot + Vector3(cos(i * TAU / 6.0), 0.3, sin(i * TAU / 6.0)) * Attack.FALL_RADIUS * 0.6, HOT, 4)
			CombatFx.smoke(get_parent(), spot + Vector3.UP * 0.3, Color("3a3634"), 8)
	get_tree().call_group("camera_shakers", "add_shake", 0.03)

## The yard's sources as props, following their records.
func _keep_sources() -> void:
	for id: int in _sources.keys():
		if not world.records.has(id):
			_sources[id].queue_free()
			_sources.erase(id)
	for id: int in world.records:
		var record: Dictionary = world.records[id]
		if not record.get("source", false): continue
		if not _sources.has(id):
			if record["material"] == "water": _sources[id] = preload("res://scripts/survivor/water_source.gd").new()
			else:
				_sources[id] = preload("res://scripts/survivor/yard_store.gd").new()
				_sources[id].kind = record["material"]
			add_child(_sources[id])
		_sources[id].global_position = Vector3(record["position"].x, float(record.get("ground_y", record["position"].y)), record["position"].z)
		if record["material"] == "fire": _sources[id].set_lit(float(record.get("quenched_left", 0.0)) <= 0.0)
		_sources[id].set_fill(float(record.get("volume", 0.0)) / Catalog.MAX_VOLUME)

func _draw_marks(delta: float) -> void:
	_time += delta
	_lines.clear_surfaces()
	_glow.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if camera != null: _view = -camera.global_basis.z
	for index: int in range(_arcs.size() - 1, -1, -1):
		_arcs[index]["left"] -= delta
		if _arcs[index]["left"] <= 0.0: _arcs.remove_at(index)
	for list: Array[Dictionary] in [_streams, _beams, _aims]:
		for index: int in range(list.size() - 1, -1, -1):
			list[index]["left"] -= delta
			if list[index]["left"] <= 0.0: list.remove_at(index)
	# Heat and cold: 1 px rings at the feet.
	var rings: bool = false
	# Where a weapon's ball will land: its reach on the floor, dashed until the last instant.
	for fall: Dictionary in _falls:
		if not rings: _lines.surface_begin(Mesh.PRIMITIVE_LINES)
		rings = true
		var solid: bool = fall["left"] < 0.18
		for i: int in 16:
			if not solid and i % 2 == 1: continue
			var a: Vector3 = fall["spot"] + Vector3(cos(i * TAU / 16), 0.04, sin(i * TAU / 16)) * Attack.FALL_RADIUS
			var b: Vector3 = fall["spot"] + Vector3(cos((i + 1) * TAU / 16), 0.04, sin((i + 1) * TAU / 16)) * Attack.FALL_RADIUS
			_segment(a, b, fall["colors"][2] if solid else fall["colors"][1])
	if machines != null:
		for enemy: Node3D in machines.get_children():
			if enemy.down or enemy.temp == 0: continue
			if not rings: _lines.surface_begin(Mesh.PRIMITIVE_LINES)
			rings = true
			_ring(enemy.global_position + Vector3.UP * 0.05, 0.55 + 0.12 * absi(enemy.temp), HOT if enemy.temp > 0 else COLD)
	if rings: _lines.surface_end()
	# Everything electric is ribbons: the body and core on the ink, the halo on the glow.
	_open.clear()
	var texel: float = CombatFx._texel(self)
	var beat: int = 0 if steady else int(_time / BEAT)
	# The click's corners, on ribbons so they hold up over a busy floor: wide when it lands,
	# snapping in to the spot.
	if hover != null and _aims.is_empty(): _corners(hover, 0.75, 0.35, 3.0 * texel, AIM_HOVER)
	if mark != null and (not is_instance_valid(mark) or mark.down): mark = null
	if mark != null: _corners(mark.global_position, 1.15 + 0.06 * sin(_time * 5.0), 0.3, 3.0 * texel, AIM_READY)
	for aim_mark: Dictionary in _aims:
		var t: float = 1.0 - aim_mark["left"] / aim_mark["life"]
		_corners(aim_mark["at"], lerpf(1.6, 0.9, minf(1.0, t * 4.0)), 0.5, 4.0 * texel, AIM_READY if aim_mark["ready"] else AIM_IDLE)
	# A struck machine still crackles: two short sparks crawling over it.
	if machines != null:
		for enemy: Node3D in machines.get_children():
			if enemy.down or enemy.charge <= 0: continue
			_rng.seed = hash(enemy.get_instance_id() + beat)
			for i: int in 2:
				var from: Vector3 = enemy.global_position + Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(0.3, 1.3), _rng.randf_range(-0.35, 0.35))
				_crackle(from, from + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.2), _rng.randf_range(-0.4, 0.4)), texel)
	# Nanites planted by an attack: brass motes circling the machine until they go off.
	if machines != null:
		for enemy: Node3D in machines.get_children():
			if enemy.down or enemy.nanites <= 0: continue
			for i: int in 4:
				var angle: float = _time * 2.4 + i * TAU / 4.0 + enemy.get_instance_id() % 7
				var mote: Vector3 = enemy.global_position + Vector3(cos(angle) * 0.5, 0.8 + 0.25 * sin(angle * 1.7), sin(angle) * 0.5)
				_ribbon(_lines, PackedVector3Array([mote, mote + Vector3(-sin(angle), 0, cos(angle)) * 0.2]), 5.0 * texel, BRASS)
	# A burning machine is on fire where everyone can see it: tongues of flame licking up off it.
	if machines != null:
		for enemy: Node3D in machines.get_children():
			if enemy.down or enemy.temp < 2: continue
			_rng.seed = hash(enemy.get_instance_id() * 31 + beat)
			for i: int in 3:
				var base: Vector3 = enemy.global_position + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.3, 0.8), _rng.randf_range(-0.3, 0.3))
				var tip: Vector3 = base + Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(0.35, 0.7), 0)
				var tongue := PackedVector3Array([base, base.lerp(tip, 0.5) + Vector3(_rng.randf_range(-0.08, 0.08), 0, 0), tip])
				_ribbon(_lines, tongue, 6.0 * texel, HOT)
				_ribbon(_lines, tongue.slice(0, 2), 2.5 * texel, FLAME_CORE)
	# Live matter: sparks running over its surface, more when doubly charged.
	for record: Dictionary in world.records.values():
		var charge: int = int(record.get("charge", 0))
		if charge <= 0: continue
		_rng.seed = hash(int(record["id"]) * 977 + beat)
		var basis := Basis(Vector3.UP, record["yaw"])
		var reach: Vector3 = record["size"] * 0.4
		var tall: bool = record["shape"] == "wall"
		for i: int in 1 + charge:
			var local := Vector3(_rng.randf_range(-reach.x, reach.x), _rng.randf_range(0.1, record["size"].y) if tall else 0.08, _rng.randf_range(-reach.z, reach.z))
			var from: Vector3 = record["position"] + basis * local
			var step := Vector3(_rng.randf_range(-0.9, 0.9), _rng.randf_range(-0.4, 0.4) if tall else 0.0, _rng.randf_range(-0.9, 0.9))
			_crackle(from, from + basis * step, texel)
	# A well's own matter going round its ring: streaks of water, tongues of flame, tumbling scrap,
	# current crackling along it. It thins out in the last moments before the well lets go.
	for record: Dictionary in world.records.values():
		if Catalog.field(record) != "well": continue
		var center: Vector3 = Catalog.field_center(record) + Vector3.UP * 0.18
		var colors: Array = RING.get(record["material"], RING["water"])
		var spin: float = _time * Catalog.ORBIT_SPEED * Catalog.gravity(record) / Catalog.VORTEX_RING
		var pieces: int = 6 if float(record.get("grav_left", 1.0)) > 0.6 else 3
		for i: int in pieces:
			var start: float = spin + i * TAU / pieces
			var arc := PackedVector3Array()
			for j: int in 5: arc.append(center + Vector3(cos(start + j * 0.09), 0, sin(start + j * 0.09)) * Catalog.VORTEX_RING)
			match record["material"]:
				"current": _crackle(arc[0], arc[4], texel)
				"fire":
					_ribbon(_lines, arc, 6.0 * texel, colors[1])
					_ribbon(_lines, PackedVector3Array([arc[3], arc[3] + Vector3.UP * 0.45]), 4.0 * texel, colors[1])
					_ribbon(_lines, arc.slice(2, 5), 2.0 * texel, colors[2])
				"scrap":
					_ribbon(_lines, arc.slice(1, 3), 9.0 * texel, colors[0])
					_ribbon(_lines, arc.slice(1, 3), 5.0 * texel, colors[1])
					_ribbon(_lines, arc.slice(3, 5), 5.0 * texel, colors[2])
				_:
					_ribbon(_lines, arc, 8.0 * texel, colors[0])
					_ribbon(_lines, arc, 5.0 * texel, colors[1])
					_ribbon(_lines, arc.slice(2, 5), 1.5 * texel, colors[2])
	## La estela sigue posiciones simuladas y replicadas; no inventa proyectiles ni fuerza.
	for record: Dictionary in world.records.values():
		var tail: Array = record.get("motion_tail", [])
		if tail.size() < 2 or record["velocity"].length() < 0.3: continue
		var points := PackedVector3Array()
		for point: Vector3 in tail: points.append(point + Vector3.UP * 0.12)
		points.append(record["position"] + Vector3.UP * 0.12)
		var colors: Array = STREAM.get(Catalog.substance_of(record["material"]), STREAM["water"])
		_ribbon(_lines, points, 5.0 * texel, colors[0])
		_ribbon(_lines, points, 2.0 * texel, colors[1])
	# Drawn water: a head racing ahead and a tail that follows it off the puddle, deep teal under a
	# bright body with a lit thread down its middle, lifting a hand's breadth off the floor.
	for flow: Dictionary in _streams:
		var age: float = flow["life"] + 0.22 - flow["left"]
		var head: float = clampf(age / flow["life"], 0.0, 1.0)
		var tail: float = clampf((age - 0.22) / flow["life"], 0.0, 1.0)
		if head - tail < 0.01: continue
		var run := PackedVector3Array()
		var length: float = flow["from"].distance_to(flow["to"])
		var pieces: int = clampi(int(length / 0.35), 2, 40)
		for i: int in pieces + 1:
			var t: float = lerpf(tail, head, float(i) / pieces)
			var ripple: float = sin(t * length * 2.2 - _time * 14.0) * 0.05
			run.append(flow["from"].lerp(flow["to"], t) + Vector3.UP * (sin(t * PI) * minf(0.35, length * 0.05) + ripple))
		var colors: Array = flow.get("colors", STREAM["water"])
		_ribbon(_lines, run, 10.0 * texel, colors[0])
		_ribbon(_lines, run, 7.0 * texel, colors[1])
		_ribbon(_lines, run, 2.0 * texel, colors[2])
	# Beams: they reach the matter in a tenth of a second, then thin out and fade.
	for beam: Dictionary in _beams:
		var age: float = TETHER_LIFE - beam["left"]
		var reach: float = clampf(age / 0.1, 0.0, 1.0)
		var fade: float = beam["left"] / TETHER_LIFE
		var line := PackedVector3Array()
		for i: int in 9:
			var t: float = reach * i / 8.0
			line.append(beam["from"].lerp(beam["to"], t) + Vector3.UP * sin(t * PI) * 0.4)
		var color: Color = beam["color"]
		_ribbon(_glow, line, 8.0 * texel * fade, Color(color, 0.35 * fade))
		_ribbon(_lines, line, (2.0 if fade > 0.5 else 1.0) * texel, color)
	# Discharges.
	for arc: Dictionary in _arcs:
		var fade: float = arc["left"] / arc["life"]
		if not steady and fade < 0.45 and fmod(arc["left"], 0.07) > 0.045: continue
		_rng.seed = hash(int(arc["seed"]) + (0 if steady else int((arc["life"] - arc["left"]) / BEAT)))
		var points: PackedVector3Array = arc["points"]
		var thick: float = float(arc["width"]) * (0.55 + 0.45 * fade)
		for i: int in points.size() - 1:
			var bolt: PackedVector3Array = _bolt(points[i], points[i + 1], 1.0)
			_ribbon(_glow, bolt, 10.0 * texel * thick, Color(HALO, HALO.a * 1.4 * fade))
			if fade > 0.3: _ribbon(_lines, bolt, 3.0 * texel * thick, SPARK)
			_ribbon(_lines, bolt, (1.5 if fade > 0.3 else 1.0) * texel, CORE if fade > 0.3 else SPARK)
			# Forks: short dead ends off the bends, thinner, that never reach anything.
			for j: int in range(1, bolt.size() - 1):
				if _rng.randf() > 0.3: continue
				var out := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.9, 0.2), _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(0.25, 0.6)
				var fork: PackedVector3Array = _bolt(bolt[j], bolt[j] + out, 0.6)
				_ribbon(_glow, fork, 4.0 * texel * thick, Color(HALO, HALO.a * 0.6 * fade))
				_ribbon(_lines, fork, 1.0 * texel, SPARK)
	for mesh: ImmediateMesh in _open: mesh.surface_end()

## A short spark: a few pixels of yellow wandering from a to b, white at its start, in a halo.
func _crackle(a: Vector3, b: Vector3, texel: float) -> void:
	var bolt: PackedVector3Array = _bolt(a, b, 2.2)
	_ribbon(_glow, bolt, 5.0 * texel, Color(HALO, HALO.a * 0.8))
	_ribbon(_lines, bolt, 1.5 * texel, SPARK)
	_ribbon(_lines, bolt.slice(0, 3), 1.0 * texel, CORE)

## A jagged line from a to b, from _rng: many small kinks on a drift that wanders off the line
## and comes back, so it reads as lightning rather than a zigzag.
func _bolt(a: Vector3, b: Vector3, sway: float) -> PackedVector3Array:
	var length: float = a.distance_to(b)
	var steps: int = clampi(int(length / 0.16), 3, 24)
	var side: Vector3 = (b - a).cross(_view).normalized()
	var amount: float = minf(length * 0.1, 0.28) * sway
	var bolt := PackedVector3Array([a])
	var drift: float = 0.0
	var rise: float = 0.0
	for i: int in range(1, steps):
		var t: float = float(i) / steps
		drift = drift * 0.55 + _rng.randf_range(-1.0, 1.0)
		rise = rise * 0.5 + _rng.randf_range(-0.5, 0.5)
		bolt.append(a.lerp(b, t) + (side * drift + Vector3.UP * rise) * amount * sin(t * PI))
	bolt.append(b)
	return bolt

## A strip `width` wide along the points, facing the camera; each piece runs a little past its
## ends so the bends close.
func _ribbon(mesh: ImmediateMesh, points: PackedVector3Array, width: float, color: Color) -> void:
	for i: int in points.size() - 1:
		var along: Vector3 = points[i + 1] - points[i]
		if along.length_squared() < 0.000001: continue
		var side: Vector3 = along.cross(_view).normalized() * width * 0.5
		var lap: Vector3 = along.normalized() * width * 0.5
		if not _open.has(mesh):
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			_open[mesh] = true
		var a: Vector3 = points[i] - lap
		var b: Vector3 = points[i + 1] + lap
		for corner: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(corner)

func _segment(a: Vector3, b: Vector3, color: Color) -> void:
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(a)
	_lines.surface_set_color(color)
	_lines.surface_add_vertex(b)

func _ring(at: Vector3, radius: float, color: Color) -> void:
	for i: int in 16:
		_segment(at + Vector3(cos(i * TAU / 16), 0, sin(i * TAU / 16)) * radius, at + Vector3(cos((i + 1) * TAU / 16), 0, sin((i + 1) * TAU / 16)) * radius, color)

## Charged matter hums: a light under it that flickers, brighter for a double charge.
func _hum() -> void:
	for id: int in _live.keys():
		var record: Dictionary = world.records.get(id, {})
		if record.is_empty() or int(record.get("charge", 0)) <= 0:
			_live[id].queue_free()
			_live.erase(id)
	for id: int in world.records:
		var record: Dictionary = world.records[id]
		var charge: int = int(record.get("charge", 0))
		if charge <= 0: continue
		# A live store (the downed cable, the cabinet's guts) carries its own cold light, pool and
		# crackle (yard_store.gd); the amber hum is for charged matter only.
		if record.get("source", false): continue
		if not _live.has(id):
			if _live.size() >= 8: continue
			var light := OmniLight3D.new()
			light.light_color = SPARK
			light.omni_range = 3.5
			light.shadow_enabled = false
			add_child(light)
			_live[id] = light
		var hum: OmniLight3D = _live[id]
		hum.global_position = record["position"] + Vector3.UP * (0.9 if record["shape"] == "wall" else 0.45)
		_rng.seed = hash(id * 31 + int(_time / BEAT))
		hum.light_energy = (1.0 + 0.6 * charge) * (1.0 if steady else _rng.randf_range(0.55, 1.15))

func _process(delta: float) -> void:
	_draw_marks(delta)
	_drop_balls(delta)
	_hum()
	_keep_sources()
	_keep_aftermath()
	for id: int in _fields.keys():
		var kind: String = _kind(world.records.get(id, {}))
		if kind != _fields[id]["kind"]:
			_fields[id]["mesh"].queue_free()
			_fields.erase(id)
	for id: int in world.records:
		var record: Dictionary = world.records[id]
		var kind: String = _kind(record)
		if kind == "": continue
		if not _fields.has(id): _fields[id] = {"kind": kind, "mesh": _disc(kind)}
		var mesh: MeshInstance3D = _fields[id]["mesh"]
		mesh.global_position = Catalog.field_center(record) + Vector3.UP * 0.06
		var paint: ShaderMaterial = mesh.material_override
		match kind:
			"well":
				paint.set_shader_parameter("matter", RING.get(record["material"], RING["water"])[1])
				paint.set_shader_parameter("turns", Catalog.ORBIT_SPEED * Catalog.gravity(record) / (TAU * Catalog.VORTEX_RING))
				paint.set_shader_parameter("life", clampf(float(record.get("grav_left", 1.0)) / 0.4, 0.0, 1.0))
			"repel":
				paint.set_shader_parameter("matter", RING.get(record["material"], RING["water"])[2])
				var front: float = Catalog.wave_front(float(record.get("wave_age", 99.0)))
				paint.set_shader_parameter("front", front / Catalog.BLAST_REACH if front < Catalog.BLAST_REACH else -1.0)
				paint.set_shader_parameter("life", clampf(float(record.get("grav_left", 1.0)) / 0.5, 0.0, 1.0))
			_: paint.set_shader_parameter("speed", Catalog.gravity(record))

func _keep_aftermath() -> void:
	var alive: Dictionary = {}
	for mark: Dictionary in world.floor_marks:
		var id: int = mark["id"]
		alive[id] = true
		if not _aftermath.has(id):
			var mesh := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(2.8, 2.2)
			mesh.mesh = plane
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var paint := ShaderMaterial.new()
			paint.shader = preload("res://scripts/survivor/aftermath.gdshader")
			paint.set_shader_parameter("electric", mark["kind"] == "current")
			mesh.material_override = paint
			add_child(mesh)
			mesh.global_position = mark["position"] + Vector3.UP * 0.035
			_aftermath[id] = mesh
		(_aftermath[id].material_override as ShaderMaterial).set_shader_parameter("life", minf(1.0, float(mark["left"]) / 2.0))
	for id: int in _aftermath.keys():
		if not alive.has(id):
			_aftermath[id].queue_free()
			_aftermath.erase(id)

func _kind(record: Dictionary) -> String:
	if record.is_empty(): return ""
	var field: String = Catalog.field(record)
	if field != "": return field
	return "scald" if Catalog.scald(record) else ""

func _disc(kind: String) -> MeshInstance3D:
	if kind in ["well", "repel"]:
		var reach: float = Catalog.VORTEX_REACH if kind == "well" else Catalog.BLAST_REACH
		var field := _plane(reach)
		var ink := ShaderMaterial.new()
		ink.shader = GRAVITY_SHADER
		ink.set_shader_parameter("tint", GRAVITY if kind == "well" else REPEL)
		ink.set_shader_parameter("mode", 0.0 if kind == "well" else 1.0)
		ink.set_shader_parameter("ring", Catalog.VORTEX_RING / reach)
		ink.set_shader_parameter("bubble", Catalog.BUBBLE / reach)
		field.material_override = ink
		add_child(field)
		return field
	var radius: float = 2.6
	var mesh := _plane(radius)
	var material: ShaderMaterial = mesh.material_override
	material.set_shader_parameter("tint", {"well": GRAVITY, "repel": REPEL, "scald": SCALD}[kind])
	material.set_shader_parameter("flow", -1.0 if kind == "well" else 1.0)
	material.set_shader_parameter("core", 1.0 if kind == "well" else 0.0)
	add_child(mesh)
	return mesh

func _plane(radius: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	mesh.material_override = material
	return mesh

## One expanding ring: a repulsor's push, matter landing, a burst.
func _on_event(event: Dictionary) -> void:
	if event["kind"] == "charged":
		_charged(event["position"], world.records.get(int(event["id"]), {}))
		return
	var setting: Variant = {"dropped": [2.5, BURST], "burst": [Recipe.BURST_RADIUS, BURST]}.get(event["kind"])
	if setting == null: return
	var mesh := _plane(setting[0])
	var material: ShaderMaterial = mesh.material_override
	material.set_shader_parameter("tint", setting[1])
	add_child(mesh)
	mesh.global_position = event["position"] + Vector3.UP * 0.08
	var inward: bool = event["kind"] == "well"
	var tween := mesh.create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("pulse", value), 1.0 if inward else 0.05, 0.05 if inward else 0.97, 0.45)
	tween.parallel().tween_method(func(value: float) -> void: material.set_shader_parameter("life", value), 1.0, 0.0, 0.45).set_delay(0.15)
	tween.tween_callback(mesh.queue_free)

## The moment matter takes a charge: a flash, a ring of it across the floor, and three bolts
## coming down into it.
func _charged(at: Vector3, record: Dictionary) -> void:
	CombatFx.flash(get_parent(), at + Vector3.UP * 0.6, SPARK, 5.0, 4.5, 0.35)
	CombatFx.ripple(get_parent(), at, SPARK, 1.9, 0.4)
	var top: float = 1.8 if record.get("shape", "") == "wall" else 0.08
	for i: int in 3:
		var angle: float = randf() * TAU
		var land: Vector3 = at + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.2, 0.9) + Vector3.UP * top * randf()
		_arcs.append({"points": PackedVector3Array([land + Vector3(randf_range(-0.5, 0.5), 2.2, randf_range(-0.5, 0.5)), land]), "left": 0.2, "life": 0.2, "seed": randi(), "width": 0.6})
