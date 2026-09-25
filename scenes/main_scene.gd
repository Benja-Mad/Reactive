extends Node3D

@export var support_scene: PackedScene
@export var damage_scene: PackedScene
@onready var arena: DioramaArena = $Arena
@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner


func _ready() -> void:
	player_spawner.spawn_function = _spawn_player
	# The arena owns the framing, so movement input is expressed in its camera's horizontal
	# frame. Set before any character spawns, since Character reads it every physics tick.
	Character.movement_basis = _movement_basis()
	arena.activate_camera()
	# Identical stable paths on every peer; the host alone resolves sentry combat.
	var sentry_positions: Array[Vector3] = [Vector3(-10, 0.05, -9), Vector3(8, 0.05, -10), Vector3(-7, 0.05, 16)]
	for index in sentry_positions.size():
		var sentry := preload("res://scenes/characters/yard_sentry.gd").new()
		sentry.name = "YardSentry%d" % index
		sentry.position = sentry_positions[index]
		add_child(sentry)
	players.child_entered_tree.connect(_on_player_spawned)
	if not multiplayer.is_server():
		return
	await get_tree().create_timer(0.2).timeout
	for player_data: Statics.PlayerData in Game.instance.players:
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
		if has_node("MatterConsole"):
			character.programming_block.hide()
			character.programming_block.code_block.release_focus()
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
