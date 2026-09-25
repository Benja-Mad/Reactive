extends Node
const World = preload("res://scripts/matter/world_matter.gd")
var world: Node3D
var checks: Dictionary = {}
var events: Array[String] = []

func _ready() -> void: call_deferred("run")
func check(key: String, condition: bool) -> void:
	checks[key] = condition
	if not condition: push_error("MATTER FAILED: " + key)
func frames(count: int = 2) -> void:
	for i in count: await get_tree().physics_frame
func create(point: Vector3 = Vector3(0,0.05,0)) -> int:
	var result: Dictionary = world.execute(1,"create",0,{"point": point})
	check("create_succeeds",result["ok"])
	return result.get("id",0)
func run() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60,1,60)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	add_child(floor_body)
	var player := Node3D.new()
	player.name = "Player"
	player.position = Vector3(-4,0,0)
	player.add_to_group("coop_players")
	add_child(player)
	var other := Node3D.new()
	other.set_multiplayer_authority(2)
	other.add_to_group("coop_players")
	add_child(other)
	world = World.new()
	world.name = "WorldMatter"
	add_child(world)
	world.matter_event.connect(func(event: Dictionary): events.append(event["kind"]))
	await frames()
	check("unknown_rejected",not world.execute(1,"combo_magic")["ok"])
	check("range_rejected",not world.execute(1,"create",0,{"point": Vector3(50,0,0)})["ok"])
	var id: int = create()
	var original_view: Node = world.views[id]
	check("water_not_breakable",not world.execute(1,"impact",id)["ok"])
	check("not_movable",not world.execute(1,"push",id,{"vector":Vector3.RIGHT})["ok"])
	check("foreign_owner_rejected",not world.execute(2,"remove",id)["ok"])
	check("coat_water",world.execute(1,"coat",id,{"coating":"nanites"})["ok"])
	check("duplicate_coat_rejected",not world.execute(1,"coat",id)["ok"])
	check("raise",world.execute(1,"raise",id,{"vector":Vector3.RIGHT})["ok"])
	var actor = preload("res://tests/matter/test_actor.gd").new()
	add_child(actor)
	await frames()
	check("occupied_freeze_rejected",not world.execute(1,"freeze",id)["ok"])
	check("rejected_transition_keeps_water",world.records[id]["material"] == "water")
	actor.position = Vector3(5,0,0)
	await frames()
	check("freeze",world.execute(1,"freeze",id)["ok"])
	check("same_identity",world.views[id] == original_view)
	check("coating_survives_freeze",world.records[id]["attachments"].has("nanites"))
	check("solid_collision",world.views[id].collision_layer == 1)
	var bolt: Node3D = preload("res://scenes/actions/fire_attack.tscn").instantiate()
	bolt.direction = Vector3.RIGHT
	player.add_child(bolt)
	bolt.global_position = Vector3(-6,0.6,0)
	await frames(45)
	check("existing_projectile_damage",is_equal_approx(world.records[id]["integrity"],15.0))
	check("impact",world.execute(1,"impact",id)["ok"])
	check("shards_aggregated",world.records[id]["shape"] == "fragments" and world.views[id].fragments.multimesh.instance_count == 8)
	check("collision_removed_on_break",world.views[id].collision_layer == 0)
	check("coating_survives_shatter",world.records[id]["attachments"].has("nanites"))
	check("push",world.execute(1,"push",id,{"vector":Vector3.RIGHT*14})["ok"])
	await frames(40)
	check("shards_damage_actor",actor.health < 100.0)
	check("shards_consumed_on_hit",not world.records.has(id))
	id = create(Vector3(3,0.05,0))
	world.execute(1,"coat",id)
	var old_health: float = actor.health
	check("command",world.execute(1,"command",id,{"command":"detonate"})["ok"])
	check("blast_damage",actor.health < old_health)
	check("coating_consumed",world.records[id]["attachments"].is_empty())
	check("double_detonation_rejected",not world.execute(1,"command",id,{"command":"detonate"})["ok"])
	check("water_still_water",world.records[id]["material"] == "water")
	world.execute(1,"remove",id)
	await frames()
	var base_count: int = world.get_child_count()
	for i in 40:
		id = create()
		world.execute(1,"freeze",id)
		world.execute(1,"remove",id)
		await frames()
	check("cycle_cleanup",world.records.is_empty() and world.views.is_empty() and world.get_child_count() == base_count)
	for i in 8: create(Vector3(i,0.05,-4))
	check("owner_cap",not world.execute(1,"create",0,{"point":Vector3.ZERO})["ok"])
	for record: Dictionary in world.records.values(): record["ttl"] = 0.01
	await frames(10)
	check("lifetime_cleanup",world.records.is_empty() and world.get_child_count() == base_count)
	for kind: String in ["created","coated","reshaped","transformed","hit","broken","impulsed","collided","commanded","detonated","removed","expired"]:
		check("event_"+kind,kind in events)
	for peer_id in [3,4]:
		var peer_player := Node3D.new()
		peer_player.set_multiplayer_authority(peer_id)
		peer_player.add_to_group("coop_players")
		add_child(peer_player)
	for index in 32:
		var owner_id: int = 1 + index / 8
		var position := Vector3((float(index % 8)-3.5)*6,0.05,(float(index / 8)-1.5)*6)
		world._player(owner_id).global_position = position + Vector3.LEFT
		var made: Dictionary = world.execute(owner_id,"create",0,{"point":position})
		check("benchmark_create",made["ok"])
		var matter_id: int = made.get("id",0)
		world.execute(owner_id,"freeze",matter_id)
		world.execute(owner_id,"impact",matter_id)
		world.execute(owner_id,"push",matter_id,{"vector":Vector3(0,0,2)})
	var count_at_limit: int = world.records.size()
	check("global_capacity",count_at_limit == 32)
	var full_bytes: int = world.snapshot_bytes
	var total_before: int = world.tick_usec_total
	var ticks_before: int = world.tick_count
	await frames(120)
	var mean_usec: float = float(world.tick_usec_total-total_before)/maxi(1,world.tick_count-ticks_before)
	for record: Dictionary in world.records.values(): record["ttl"] = 0.01
	await frames(10)
	check("capacity_cleanup",world.records.is_empty() and world.get_child_count() == base_count)
	var failures: Array = checks.keys().filter(func(key): return not checks[key])
	var report := {"checks":checks,"failures":failures,"event_count":events.size(),"max_tick_usec":world.tick_usec_max,"capacity_count":count_at_limit,"moving_tick_mean_usec":mean_usec,"capacity_snapshot_bytes":full_bytes,"last_snapshot_bytes":world.snapshot_bytes}
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MATTER ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
