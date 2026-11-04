## The program's sounds (made by tools/audio/synth.py). Local only: each player hears their own
## routines, at the instant the HUD lights the piece, so what you hear is what the program did.
class_name Sfx
extends Node

const SOUNDS: Array[String] = ["step", "draw", "idle", "armed", "fire", "combo", "cue", "cue_idle"]
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

## The one Sfx under the tree's root, made on first use.
static func of(node: Node) -> Sfx:
	var root: Window = node.get_tree().root
	var found: Node = root.get_node_or_null("Sfx")
	if found is Sfx: return found
	var made := Sfx.new()
	made.name = "Sfx"
	root.add_child.call_deferred(made)
	return made

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound: String in SOUNDS: _streams[sound] = load("res://assets/audio/%s.wav" % sound)
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
		add_child(player)
		_players.append(player)

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

## The pitch of DO number `k` in program row `row`.
static func note(row: int, k: int) -> float:
	return ROWS[posmod(row, ROWS.size())] * SCALE[clampi(k, 0, SCALE.size() - 1)]
