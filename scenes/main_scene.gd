extends Node3D

@export var support_scene: PackedScene
@export var damage_scene: PackedScene
@onready var spawn_points: Node3D = $SpawnPoints
@onready var players: Node3D = $Players

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i: int in Game.players.size():
		var player_data: Statics.PlayerData = Game.players[i]
		if player_data.role == Statics.Role.DAMAGE:
			var player_inst = damage_scene.instantiate()
			player_inst.name = str(player_data.id)
			players.add_child(player_inst)
			player_inst.setup(player_data)
