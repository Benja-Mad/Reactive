## Experience is collected by movement. Host owns attraction and awards; peers render the result.
extends Node3D
const Art = preload("res://scripts/survivor/worker_visual.gd")
var value: int = 1
var run: Node
var age: float = 0
var body: MeshInstance3D
func _ready() -> void:
	var m := Art.material(Color("b9d6bf"))
	m.emission_enabled = true
	m.emission = Color("88ad91")
	m.emission_energy_multiplier = 0.6
	body = Art.box(self, Vector3(0, 0.22, 0), Vector3(0.22, 0.15, 0.32), m)
	body.rotation.y = 0.6
func _physics_process(delta: float) -> void:
	age += delta
	body.position.y = 0.22 + sin(age * 3) * 0.05
	if not multiplayer.is_server(): return
	var player: Character = run.nearest_player(global_position)
	if player == null: return
	var distance: float = global_position.distance_to(player.global_position)
	var build: Dictionary = run.builds.get(player.get_multiplayer_authority(), {}).get("tools", {})
	if distance < 2.8 + int(build.get("boots", 0)) * 1.2:
		global_position = global_position.move_toward(player.global_position, delta * (5.0 + age * 0.3))
	if distance < 0.8:
		run.collect_pickup.rpc(str(name))
		run.salvage(player.get_multiplayer_authority())
		run.gain_xp(value)
