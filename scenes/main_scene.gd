extends Node3D

const DistrictEnvironment = preload("res://scenes/environment/sector_08/stylized/yard_art_trial.gd")
## The comparison harness opts out so it can restore the original environment.
@export var polished_environment_enabled: bool = true
@export var support_scene: PackedScene
@export var damage_scene: PackedScene
@onready var arena: DioramaArena = $Arena
@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
## Peers that have this scene loaded. The host spawns nobody until every seat has reported in:
## a spawn sent to a peer still loading the scene is dropped, and that peer never gets a body.
var _loaded_peers: Dictionary = {}
var _spawned: Dictionary = {}


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	# The arena owns the framing, so movement input is expressed in its camera's horizontal
	# frame. Set before any character spawns, since Character reads it every physics tick.
	Character.movement_basis = _movement_basis()
	arena.activate_camera()
	players.child_entered_tree.connect(_on_player_spawned)
	_start_session.call_deferred()


func _start_session() -> void:
	# Arena dressing and perimeter fill finish on earlier deferred calls. Apply the
	# visual replacements and their collision repairs before announcing readiness.
	if polished_environment_enabled:
		var environment := DistrictEnvironment.new()
		environment.name = "DistrictEnvironment"
		arena.add_child(environment)
		environment.setup(arena)
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(func(_id: int) -> void: _spawn_when_loaded.call_deferred())
		_mark_loaded.call_deferred(multiplayer.get_unique_id())
		# A seat that never reports in must not hold the others hostage.
		get_tree().create_timer(12.0).timeout.connect(_spawn_seats.bind(true))
	else:
		_announce_loaded()


## Repeats until this peer's body exists: the host may still be loading the scene when the first
## report arrives, and an RPC to a node that does not exist yet is simply lost.
func _announce_loaded() -> void:
	while is_inside_tree() and not players.has_node(str(multiplayer.get_unique_id())):
		_report_loaded.rpc_id(1)
		await get_tree().create_timer(0.5).timeout


@rpc("any_peer", "reliable")
func _report_loaded() -> void:
	if multiplayer.is_server():
		_mark_loaded(multiplayer.get_remote_sender_id())


func _mark_loaded(peer: int) -> void:
	_loaded_peers[peer] = true
	_spawn_when_loaded()


## Seats that belong to someone actually here: the host, or a connected peer. Test rosters can
## list more seats than there are running instances.
func _present_seats() -> Array[Statics.PlayerData]:
	var present: Array[Statics.PlayerData] = []
	if not is_inside_tree():
		return present
	var peers: PackedInt32Array = multiplayer.get_peers()
	for player_data: Statics.PlayerData in Game.instance.players:
		if player_data.id == multiplayer.get_unique_id() or player_data.id in peers:
			present.append(player_data)
	return present


func _spawn_when_loaded() -> void:
	for player_data: Statics.PlayerData in _present_seats():
		if not _loaded_peers.has(player_data.id):
			return
	_spawn_seats(false)


func _spawn_seats(forced: bool) -> void:
	if not is_inside_tree():
		return
	for player_data: Statics.PlayerData in _present_seats():
		if _spawned.has(player_data.id) or not (forced or _loaded_peers.has(player_data.id)):
			continue
		_spawned[player_data.id] = true
		player_spawner.spawn(player_data.to_dict())


## Screen-right and screen-forward on the ground plane, from the approved camera. The camera
## never rotates, so this is read once rather than tracked.
func _movement_basis() -> Basis:
	var camera_basis: Basis = arena.gameplay_camera.global_basis
	var right: Vector3 = Vector3(camera_basis.x.x, 0.0, camera_basis.x.z).normalized()
	var forward: Vector3 = Vector3(camera_basis.z.x, 0.0, camera_basis.z.z).normalized()
	return Basis(right, Vector3.UP, forward)


## The diorama camera follows whoever this client is playing, so the rig has to wait until that
## character actually exists rather than being pointed at spawn time on the server.
func _on_player_spawned(node: Node) -> void:
	var character := node as Character
	if character == null:
		return
	# use_own_camera is read in Character._ready(), and child_entered_tree fires before that, so
	# set the flag now and only touch the camera itself once the node has resolved its @onready.
	character.use_own_camera = false
	if not character.is_node_ready():
		await character.ready
	character.camera_3d.current = false
	arena.configure_player_presentation(character)
	if character.is_multiplayer_authority():
		if has_node("MatterConsole") or has_node("SurvivorRun"):
			character.programming_block.hide()
			character.programming_block.set_process_input(false)
			character.programming_block.code_list.hide()
			character.programming_block.cast_timer.stop()
			character.programming_block.code_block.release_focus()
		if character.has_node("ShiftWorker"):
			character.get_node("ShiftWorker").mark_local()
		arena.follow(character)


func _spawn_player(data: Dictionary) -> Node:
	var player_data: Statics.PlayerData = Statics.PlayerData.from_dict(data)
	var player_inst: Node
	if player_data.role == Statics.Role.DAMAGE:
		player_inst = damage_scene.instantiate()
	else:
		player_inst = support_scene.instantiate()
	player_inst.set_multiplayer_authority(player_data.id)
	player_inst.name = str(player_data.id)
	var spawns: Array[Vector3] = arena.get_spawn_positions()
	# Damage left, support right -- but only when the two seats actually differ. Keying purely on
	# role put two damage players on the same slab.
	var slot: int = player_data.index
	if player_data.index < 2 and _roles_differ():
		slot = 0 if player_data.role == Statics.Role.DAMAGE else 1
	player_inst.position = spawns[slot % spawns.size()]
	return player_inst


## Whether the first two seats hold different roles, which is what makes a role-keyed spawn
## unambiguous.
func _roles_differ() -> bool:
	var seats: Array = Game.instance.players
	if seats.size() < 2:
		return false
	return (seats[0] as Statics.PlayerData).role != (seats[1] as Statics.PlayerData).role
