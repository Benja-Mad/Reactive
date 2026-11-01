## Animita: the roadside shrine from the corner, walking on the wax of every candle anyone lit in
## it. The seal sleeps where the saint's picture was. While its candles burn it shrugs off damage
## and burns at +2 with a wide heat (the heat rule melts the crew's ice around it); it shoves
## whoever it walks into. It is wax: fire hurries the relight, it does not hurt it.
## The ánimas' water puts the candles out: it stops, the glass door swings open and the seal is
## bare for a few seconds, until it sputters and catches again. Brasa's flame relights it sooner.
extends "res://scripts/survivor/enemy.gd"
const DOUSED: float = 3.5
const SPUTTER: float = 0.7
## After it catches, the candles are too hot for a splash to put them out again at once.
const CAUGHT: float = 2.0
const LIT_EXPOSURE: float = 0.75
const OPEN_EXPOSURE: float = 1.6
const HEAT_RADIUS: float = 2.6
const CONTACT: float = 18.0
const FLAME := Color("ffad4a")
## Host only: how much Brasa's fire has hurried the relight since the douse.
var kindled: float = 0.0
var card: Node3D
## The candles' sparks drifting up off her while she burns; stopped while she is doused.
var embers: CPUParticles3D

func _capsule() -> Vector2:
	return Vector2(0.8, 1.9)
func _base_color() -> Color:
	return Color("202935")

func _ready() -> void:
	super()
	exposure = LIT_EXPOSURE
	temp = 2

func _build(_dark: Material) -> void:
	card = preload("res://scripts/survivor/enemy_card.gd").new()
	card.name = "Art"
	add_child(card)
	card.setup("res://materials/enemies/animita/frames.tres")
	embers = CPUParticles3D.new()
	embers.amount = 6
	embers.lifetime = 1.0
	embers.local_coords = false
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(0.3, 0.2, 0.15)
	embers.direction = Vector3.UP
	embers.spread = 15.0
	embers.initial_velocity_min = 0.5
	embers.initial_velocity_max = 1.1
	embers.gravity = Vector3(0, 0.3, 0)
	var cooling := Gradient.new()
	cooling.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	cooling.colors = PackedColorArray([Color("fff0c8"), FLAME, Color("7c2a12")])
	embers.color_ramp = cooling
	embers.mesh = preload("res://scenes/actions/combat_fx.gd")._square(0.03, true)
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	embers.position = Vector3.UP * 1.3
	add_child(embers)

func lit() -> bool:
	return state == ""

func rest_temp() -> int:
	return 2 if lit() else 0

func heat_reach() -> float:
	return HEAT_RADIUS - 2.3

func _behave(delta: float, target: Character) -> void:
	match state:
		"":
			var gap: Vector3 = target.global_position - global_position
			gap.y = 0
			gnaw(walk_toward(delta, target.global_position), 16.0)
			if gap.length() < 1.55 and hit_timer <= 0:
				target.receive_health.rpc(-CONTACT)
				target.knock.rpc(gap.normalized() * 4.0)
				hit_timer = 1.0
		"doused":
			velocity = Vector3.ZERO
			if state_time + kindled >= DOUSED: set_state("sputter")
		"sputter":
			velocity = Vector3.ZERO
			if state_time >= SPUTTER: set_state("")

func soak(push: Vector3) -> void:
	if not multiplayer.is_server() or down: return
	shove += push * 0.3
	soaked = 1.6
	if state == "" and state_time >= CAUGHT:
		kindled = 0.0
		temp = 0
		set_state("doused")

func burn(_origin: Vector3) -> void:
	# Every lick of flame on the cold wicks brings the relight closer.
	if state == "doused": kindled += 0.12

func _on_state() -> void:
	exposure = LIT_EXPOSURE if state == "" else OPEN_EXPOSURE
	if state == "": temp = 2
	match state:
		"doused":
			preload("res://scenes/actions/combat_fx.gd").burst(effects_parent(), global_position + Vector3.UP * 1.6, Color("6fd6ff"))
			preload("res://scenes/actions/combat_fx.gd").ripple(effects_parent(), global_position, Color("93f3ff"), 1.3, 0.4)
			preload("res://scenes/actions/combat_fx.gd").smoke(effects_parent(), global_position + Vector3.UP * 1.5)
		"":
			if age > 0.5: preload("res://scenes/actions/combat_fx.gd").burst(effects_parent(), global_position + Vector3.UP * 1.9, FLAME)

func _process(delta: float) -> void:
	super(delta)
	if card == null: return
	card.hit_flash(flash > 0.0)
	embers.emitting = lit()
	(embers.mesh as QuadMesh).size = Vector2.ONE * card._texel.x
	match state:
		"doused": card.play("Doused")
		"sputter": card.play("Sputter")
		_: card.play("Walk")
