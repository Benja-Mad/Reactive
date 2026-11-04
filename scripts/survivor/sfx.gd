## The game's sounds (made by tools/audio/synth.py), in two layers. The program's are local: each
## player hears their own routines at the instant the HUD lights the piece (`play`). The yard's are
## everyone's: each reaction sounds where it happens, panned by where it is on screen (`at`).
class_name Sfx
extends Node

const SOUNDS: Array[String] = ["step", "draw", "idle", "armed", "fire", "combo", "cue", "cue_idle",
	"zap", "hiss", "sizzle", "ignite", "frost", "nanites", "grind", "thud", "whoosh", "boom", "clatter",
	"crunch", "pick", "hurt", "level"]
## The yard's voices, placed where the reaction happens and heard by everyone.
const WORLD_VOICES := 10
const WORLD_DB := -4.0
## About the camera's distance, so anything on screen sounds near full and only panning moves.
const WORLD_UNIT := 55.0
const VOICES := 8
## The same sound no closer than this, so a crowd of routines thickens instead of buzzing.
const GAP := 0.045
const VOLUME_DB := -6.0
## A major pentatonic, so any run of DO steps makes a phrase and never a clash.
const SCALE: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25]
## Each row of the program starts on its own note, so two routines can be told apart by ear.
const ROWS: Array[float] = [1.0, 0.75, 1.125, 0.8333]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last: Dictionary = {}
var _world: Array[AudioStreamPlayer3D] = []
var _world_next: int = 0

## The one Sfx under the tree's root, made on first use.
## Kept here too, so calls in the frame before it joins the tree reach the same one.
static var _one: Sfx = null

static func of(node: Node) -> Sfx:
	if is_instance_valid(_one): return _one
	_one = Sfx.new()
	_one.name = "Sfx"
	node.get_tree().root.add_child.call_deferred(_one)
	return _one

const SETTINGS := "user://settings.cfg"

## Whether the player turned the sound off; kept between runs.
static func muted() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS) != OK: return false
	return bool(config.get_value("audio", "muted", false))

static func set_muted(value: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("audio", "muted", value)
	config.save(SETTINGS)
	AudioServer.set_bus_mute(0, value)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(0, muted())
	for sound: String in SOUNDS: _streams[sound] = load("res://assets/audio/%s.wav" % sound)
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
		add_child(player)
		_players.append(player)
	for i: int in WORLD_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = WORLD_UNIT
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.max_db = 0.0
		# From that far everything on screen sits within a few degrees; widen it so left is left.
		voice.panning_strength = 3.0
		add_child(voice)
		_world.append(voice)

func play(sound: String, pitch: float = 1.0, gain_db: float = 0.0) -> void:
	if _players.is_empty() or not _streams.has(sound): return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -1.0)) < GAP: return
	_last[sound] = now
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.pitch_scale = pitch
	player.volume_db = VOLUME_DB + gain_db
	player.play()

## A reaction's sound at `where` in the yard, a little detuned each time so repeats don't drill.
func at(sound: String, where: Vector3, gain_db: float = 0.0, pitch: float = 0.0) -> void:
	if _world.is_empty() or not _streams.has(sound): return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -1.0)) < GAP * 1.5: return
	_last[sound] = now
	var voice: AudioStreamPlayer3D = _world[_world_next]
	_world_next = (_world_next + 1) % _world.size()
	voice.stream = _streams[sound]
	voice.global_position = where
	voice.pitch_scale = pitch if pitch > 0.0 else randf_range(0.93, 1.07)
	voice.volume_db = WORLD_DB + gain_db
	voice.play()

## The pitch of DO number `k` in program row `row`.
static func note(row: int, k: int) -> float:
	return ROWS[posmod(row, ROWS.size())] * SCALE[clampi(k, 0, SCALE.size() - 1)]
