extends StaticBody3D

const ACQUIRE_AT := 2.5
const LOCK_AT := 3.25
const FIRE_AT := 3.6
const Discharge = preload("res://scenes/actions/sentry_discharge.gd")

var health: float = 30.0
var cycle: float = 0.0
var target_path: NodePath
var sprite: AnimatedSprite3D
var label: Label3D
var telegraph: Node3D
var lock_point := Vector3.ZERO
var locked: bool = false
var down: bool = false
var operative: Node3D

func _ready() -> void:
	add_to_group("yard_sentries")
	add_to_group("matter_damageable")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.65
	shape.height = 2.6
	collision.shape = shape
	collision.position.y = 1.3
	add_child(collision)
	# Reuse the shipped animated character atlas instead of introducing unrelated art.
	var source := preload("res://scenes/characters/damage/damage.tscn").instantiate()
	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = source.get_node("AnimatedSprite3D").sprite_frames
	source.free()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.065
	sprite.position.y = 1.35
	sprite.modulate = Color(0.65, 0.72, 0.86)
	add_child(sprite)
	sprite.play("Idle")
	sprite.hide()
	operative = preload("res://scenes/characters/operative_visual.gd").new()
	operative.accent = Color(1.0, 0.075, 0.18)
	operative.hostile = true
	add_child(operative)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.45
	label.font_size = 32
	label.pixel_size = 0.009
	label.modulate = Color(1.0, 0.15, 0.25)
	label.text = "━━━━━\n⌄"
	add_child(label)
	telegraph = preload("res://scenes/characters/sentry_telegraph.gd").new()
	telegraph.name = "Telegraph"
	telegraph.operative = operative
	add_child(telegraph)

## Host-only cadence: idle, acquire, hunt with the beam, commit to a point, fire at it.
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or down:
		return
	cycle += delta
	if cycle >= ACQUIRE_AT and target_path.is_empty():
		var nearest: Node3D
		var distance: float = 22.0
		for candidate: Node in get_tree().get_nodes_in_group("coop_players"):
			var separation: float = global_position.distance_to(candidate.global_position)
			if separation < distance and _can_see(candidate):
				nearest = candidate
				distance = separation
		if nearest != null:
			target_path = nearest.get_path()
			locked = false
			begin_track.rpc(target_path, LOCK_AT - ACQUIRE_AT)
		else:
			cycle = 0.0
	if not target_path.is_empty() and not locked and cycle >= LOCK_AT:
		var tracked := get_node_or_null(target_path) as Node3D
		if tracked == null:
			_abort()
			return
		lock_point = tracked.global_position
		locked = true
		commit.rpc(lock_point)
	if cycle >= FIRE_AT and not target_path.is_empty():
		_fire()

## Acquisition sees through matter constructs (they are what the sentry is meant to break) but
## not through scenery, and not through the dense core of a cloud.
func _can_see(candidate: Node3D) -> bool:
	var eye: Vector3 = global_position + Vector3.UP * 1.3
	var chest: Vector3 = candidate.global_position + Vector3.UP * 0.4
	var ray := PhysicsRayQueryParameters3D.create(eye, chest)
	ray.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.collider != candidate and not hit.collider.is_in_group("matter_constructs"):
		return false
	var matter := _matter()
	return matter == null or not matter.sight_blocked(eye, chest)

func _fire() -> void:
	var eye: Vector3 = global_position + Vector3.UP * 1.3
	var matter := _matter()
	# With nobody under the lock, the shot carries on past the aim to whatever is behind it.
	var outcome: int = Discharge.Outcome.SCENERY
	var impact_point: Vector3 = _first_surface(eye, lock_point + Vector3.UP * 0.9)
	var missed_veil: Variant = matter.sight_obstruction(eye, impact_point) if matter != null else null
	if missed_veil != null:
		impact_point = missed_veil
		outcome = Discharge.Outcome.VEILED
	for candidate: Node in get_tree().get_nodes_in_group("coop_players"):
		if Vector2(candidate.global_position.x - lock_point.x, candidate.global_position.z - lock_point.z).length() < 1.15:
			# Recheck cover at impact: a player may move behind a barrier during the warning.
			var chest: Vector3 = candidate.global_position + Vector3.UP * 0.4
			var ray := PhysicsRayQueryParameters3D.create(eye, chest)
			ray.exclude = [get_rid()]
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
			var veiled: Variant = matter.sight_obstruction(eye, hit.position if not hit.is_empty() else chest) if matter != null else null
			if veiled != null:
				# The beam scatters in the vapour short of anything solid.
				impact_point = veiled
				outcome = Discharge.Outcome.VEILED
				continue
			if not hit.is_empty(): impact_point = hit.position
			if not hit.is_empty() and hit.collider.is_in_group("matter_constructs"):
				hit.collider.take_damage(8.0)
				outcome = Discharge.Outcome.COVER
			elif hit.is_empty() or hit.collider == candidate:
				candidate.receive_health.rpc(-16.0)
				var shove := Vector3(candidate.global_position.x - global_position.x, 0.0, candidate.global_position.z - global_position.z)
				candidate.knock.rpc(shove.normalized() * 4.5)
				impact_point = candidate.global_position + Vector3.UP * 0.9
				outcome = Discharge.Outcome.PLAYER
			else:
				outcome = Discharge.Outcome.SCENERY
	finish_shot.rpc(impact_point, outcome)
	target_path = NodePath()
	locked = false
	cycle = 0.0

func _first_surface(from: Vector3, through: Vector3) -> Vector3:
	var reach: Vector3 = from + (through - from) * 1.8
	var ray := PhysicsRayQueryParameters3D.create(from, reach)
	ray.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return through if hit.is_empty() else hit.position

func _abort() -> void:
	target_path = NodePath()
	locked = false
	cycle = 0.0
	cancel_track.rpc()

func _matter() -> Node:
	return get_tree().get_first_node_in_group("world_matter")

@rpc("authority", "call_local", "reliable")
func begin_track(path: NodePath, duration: float) -> void:
	var tracked := get_node_or_null(path) as Node3D
	if tracked == null: return
	telegraph.begin(tracked, duration)
	sprite.modulate = Color(1.0, 0.45, 0.45)

@rpc("authority", "call_local", "reliable")
func commit(point: Vector3) -> void:
	lock_point = point
	telegraph.lock(point)

@rpc("authority", "call_local", "reliable")
func cancel_track() -> void:
	telegraph.cancel()
	sprite.modulate = Color(0.65, 0.72, 0.86)

@rpc("authority", "call_local", "reliable")
func finish_shot(impact_point: Vector3, outcome: int) -> void:
	operative.kick()
	telegraph.release()
	Discharge.fire(get_tree().current_scene, telegraph.muzzle(), impact_point, outcome)
	sprite.modulate = Color(0.65, 0.72, 0.86)

func take_damage(amount: float) -> void:
	if not multiplayer.is_server() or down:
		return
	update_health.rpc(maxf(0.0, health - amount))
	if health <= 0.0:
		await get_tree().create_timer(8.0).timeout
		health = 30.0
		update_health.rpc(health)

@rpc("authority", "call_local", "reliable")
func update_health(value: float) -> void:
	if value < health:
		preload("res://scenes/actions/combat_fx.gd").number(get_tree().current_scene, global_position + Vector3.UP * 2.1, str(int(health - value)), Color(1, 0.7, 0.3))
	health = value
	down = health <= 0.0
	operative.disabled = down
	label.text = "REBOOTING" if down else "━".repeat(ceili(health / 6.0)) + "\n⌄"
	sprite.modulate = Color(0.18, 0.22, 0.27) if down else Color(1.0, 0.6, 0.55)
	sprite.rotation.z = -0.8 if down else 0.0
	if down:
		telegraph.cancel()
		cycle = 0.0
		locked = false
		target_path = NodePath()
