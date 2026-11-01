## La Novia del canal (absorbedora): a drowned bride that hunts the crew's standing water. She
## settles over a puddle and drinks it through her hair -- her LED veil lights from the hem up with
## every charge -- then draws breath while she marks a lane, and wails the water back down it as a
## jet that leaves water. Counters: heat the puddle while she drinks (she inhales steam), freeze it
## (her hair is caught), or bait her with a puddle and hit her while she is still and open. A
## repulsor's wave while she takes aim knocks her off it: the wail chokes, and she keeps the water.
extends "res://scripts/survivor/enemy.gd"
const Telegraph = preload("res://scripts/survivor/telegraph.gd")
const Catalog = preload("res://scripts/matter/materials.gd")
const DRINK: float = 2.2
const AIM: float = 0.9
const SPRAY: float = 0.35
const STUNNED: float = 2.4
const CHOKE: float = 0.5
const CHOKE_BACK: float = 1.8
const JET: float = 7.5
const JET_WIDTH: float = 1.1
const MAX_CHARGE: int = 3
const WATER := Color("6fd6ff")
var gulps: int = 0 # puddles drunk; `charge` is the electric one every machine has
var cooldown: float = 1.0
var puddle_id: int = 0
var card: Node3D
var jet: MeshInstance3D
var jet_art: ShaderMaterial
const JET_LOOK: Dictionary = {"core": Color("effeff"), "hot": Color("93f3ff"), "flame": Color("36c8e0"),
		"ember": Color("1d6f80"), "soot": Color("0b2c3a"), "throat": 0.5, "cool": 0.2, "seed": 3.7}
var swell: float = 1.0

func _capsule() -> Vector2:
	return Vector2(0.72, 1.5)
func _base_color() -> Color:
	return Color("323a40")

## The canal bride: her art on the crew's card. Her veil lights from the hem up with the water
## she carries; the jet itself is a separate stream so it can run the whole marked lane.
func _build(_dark: Material) -> void:
	card = preload("res://scripts/survivor/enemy_card.gd").new()
	card.name = "Art"
	add_child(card)
	card.setup("res://materials/enemies/novia/frames.tres")
	# The jet: the same pixel stream as Brasa's fire, in canal water -- white core, cyan, deep teal.
	var strip := QuadMesh.new()
	strip.size = Vector2.ONE
	jet = MeshInstance3D.new()
	jet.mesh = strip
	jet_art = ShaderMaterial.new()
	jet_art.shader = preload("res://scripts/survivor/flame.gdshader")
	for key: String in JET_LOOK: jet_art.set_shader_parameter(key, JET_LOOK[key])
	jet.material_override = jet_art
	jet.visible = false
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(jet)

func _behave(delta: float, target: Character) -> void:
	var gap: Vector3 = target.global_position - global_position
	gap.y = 0
	match state:
		"":
			cooldown -= delta
			if gulps > 0 and cooldown <= 0.0 and gap.length() < JET - 0.5 and gap.length() > 1.8:
				set_state("aim", global_position, global_position + gap.normalized() * JET, gulps)
				return
			var puddle: int = _nearest_puddle(14.0) if gulps < MAX_CHARGE else 0
			if puddle != 0:
				var at: Vector3 = run.world.records[puddle]["position"]
				var reach: float = Vector2(at.x - global_position.x, at.z - global_position.z).length()
				if reach < 2.3:
					puddle_id = puddle
					set_state("drink", global_position, at, gulps)
					return
				walk_toward(delta, at)
			else:
				var blocker: Node = walk_toward(delta, target.global_position)
				if blocker != null and blocker.is_in_group("matter_constructs") and hit_timer <= 0:
					blocker.take_damage(12.0)
					hit_timer = 0.9
			if gap.length() < 1.3 and hit_timer <= 0:
				target.receive_health.rpc(-8.0)
				hit_timer = 0.9
		"drink":
			velocity = Vector3.ZERO
			var record: Dictionary = run.world.records.get(puddle_id, {})
			if record.is_empty():
				set_state("", global_position, global_position, gulps)
			elif record["material"] == "steam":
				# Heated mid-draught: she pulls scalding vapour up through her hair.
				take_damage(16.0)
				if not down: set_state("stunned", global_position, state_to, gulps)
			elif record["material"] == "ice":
				# Frozen mid-draught: her hair is caught in the puddle until she tears free.
				set_state("stunned", global_position, state_to, gulps)
			elif state_time >= DRINK:
				_drain(puddle_id)
				gulps = mini(gulps + 1, MAX_CHARGE)
				cooldown = 0.6
				set_state("", global_position, global_position, gulps)
		"aim":
			velocity = Vector3.ZERO
			if state_time >= AIM: _fire()
		"spray":
			velocity = Vector3.ZERO
			if state_time >= SPRAY: set_state("", global_position, global_position, gulps)
		"choke":
			velocity = Vector3.ZERO
			global_position = choke_point(state_time / CHOKE)
			if state_time >= CHOKE:
				cooldown = 1.6
				set_state("", global_position, global_position, gulps)
		"stunned":
			velocity = Vector3.ZERO
			if state_time >= STUNNED:
				cooldown = 0.8
				set_state("", global_position, global_position, gulps)

## A repulsor breaks her aim: she staggers back off the lane with the water still in her.
func pulled(field: String, at: Vector3) -> bool:
	if field != "repel" or state != "aim": return false
	var from: Vector3 = global_position
	var away := Vector3(from.x - at.x, 0.0, from.z - at.z)
	away = away.normalized() if away.length() > 0.1 else -Vector3(state_to.x - from.x, 0.0, state_to.z - from.z).normalized()
	var back: Vector3 = from + away * CHOKE_BACK
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.6, back + Vector3.UP * 0.6, 1)
	ray.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): back = from + away * maxf(0.0, Vector2(hit.position.x - from.x, hit.position.z - from.z).length() - 0.75)
	set_state("choke", from, back, gulps)
	return true

## The stagger, identical on every peer: thrown back fast, settling at the end.
func choke_point(t: float) -> Vector3:
	return state_from.lerp(state_to, ease(clampf(t, 0.0, 1.0), 0.4))
func _client_motion(delta: float) -> void:
	if state == "choke": global_position = choke_point(state_time / CHOKE)
	else: super(delta)

## Water it could drink: any standing puddle on the yard, the crew's or its own spill.
func _nearest_puddle(within: float) -> int:
	var best: int = 0
	var distance: float = within
	for id: int in run.world.records:
		var record: Dictionary = run.world.records[id]
		if not Catalog.drawable(record): continue
		var d: float = Vector2(record["position"].x - global_position.x, record["position"].z - global_position.z).length()
		if d < distance:
			distance = d
			best = id
	return best

## One draught out of the puddle: she drinks what a routine would draw, and a puddle drunk dry is gone.
func _drain(id: int) -> void:
	var world: Node = run.world
	if not world.records.has(id): return
	world.draw_from(id, minf(1.0, float(world.records[id].get("volume", 1.0))))

func _fire() -> void:
	var from: Vector3 = state_from
	var direction: Vector3 = (state_to - state_from)
	direction.y = 0
	direction = direction.normalized()
	for player: Character in run.players():
		if player.eliminated: continue
		var offset: Vector3 = player.global_position - from
		offset.y = 0
		var along: float = offset.dot(direction)
		if along < 0.0 or along > JET: continue
		if (offset - direction * along).length() > JET_WIDTH * 0.5 + 0.35: continue
		player.receive_health.rpc(-(6.0 + 5.0 * gulps))
		player.knock.rpc(direction * (3.0 + gulps))
	# What it fires lands as water the crew can freeze or flash to steam.
	_spill(from + direction * JET * 0.85, gulps)
	gulps = 0
	cooldown = 3.2
	set_state("spray", state_from, state_to, 0)

## The water she carried lands on the yard, joining any puddle already there.
func _spill(point: Vector3, volume: float = 1.0) -> void:
	point.y = global_position.y + 0.07
	run.world.spill(point, volume)

## A burst tank floods the ground it dies on.
func _on_killed() -> void:
	if gulps > 0: _spill(global_position, gulps)

func _on_state() -> void:
	gulps = int(state_value)
	exposure = {"drink": 1.5, "stunned": 1.6}.get(state, 1.0)
	match state:
		"aim":
			mark(Telegraph.lane(effects_parent(), state_from, state_to, JET_WIDTH))
		"spray":
			jet.visible = true
			preload("res://scenes/actions/combat_fx.gd").burst(effects_parent(), state_to.lerp(state_from, 0.15) + Vector3.UP * 0.3, WATER)
			preload("res://scenes/actions/combat_fx.gd").ripple(effects_parent(), state_to, Color("93f3ff"), 1.4, 0.4)
		"choke":
			# The wail chokes in her throat: a gout of canal water where her mouth was.
			jet.visible = false
			preload("res://scenes/actions/combat_fx.gd").burst(effects_parent(), state_from + Vector3.UP * 1.2, WATER)
		_:
			jet.visible = false

## Her open mouth in the Wail frames, in art texels: where the jet leaves her.
const MOUTH := Vector2(81, 56)

func _process(delta: float) -> void:
	super(delta)
	if card == null: return
	card.hit_flash(flash > 0.0)
	# Kept for the swelling read the tests measure: how much she is carrying, eased.
	swell = lerpf(swell, 1.0 + 0.14 * gulps + (0.05 * state_time / DRINK if state == "drink" else 0.0), 1.0 - exp(-delta * 4))
	card.position.x = 0.0
	match state:
		"drink":
			card.play("Drink")
			card.aim(state_to - global_position)
		"aim":
			card.play("Aim")
			card.aim(state_to - state_from)
			if not marks.is_empty(): Telegraph.fill(marks[0], state_time / AIM)
		"spray":
			card.play("Wail")
			card.aim(state_to - state_from)
		"choke":
			card.play("Aim")
			card.position.x = sin(age * 60.0) * 0.03
		"stunned":
			# Scalded or caught: she shudders over the puddle.
			card.play("Drink")
			card.position.x = sin(age * 60.0) * 0.03
		_:
			card.play("Wander%d" % clampi(gulps, 0, 3))
	if jet.visible:
		var nozzle: Vector3 = card.point(MOUTH)
		var finish: Vector3 = state_to + Vector3.UP * 0.4
		var span: float = nozzle.distance_to(finish)
		var thin: float = 1.0 - clampf(state_time / SPRAY, 0, 1) * 0.6
		var along: Vector3 = (finish - nozzle).normalized()
		# Lie along the jet, turned about it to face the camera, like the flame card.
		var camera: Camera3D = get_viewport().get_camera_3d()
		var back: Vector3 = camera.global_basis.z if camera != null else Vector3.UP
		var facing: Vector3 = (back - along * back.dot(along)).normalized()
		var across: Vector3 = facing.cross(along).normalized()
		var width: float = 0.75 * thin
		jet_art.set_shader_parameter("texels", Vector2(span, width) / card._texel.x)
		jet.global_transform = Transform3D(Basis(along * span, across * width, facing), nozzle.lerp(finish, 0.5))

func _face(point: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-(point.x - global_position.x), -(point.z - global_position.z)), 1.0 - exp(-delta * 10))
