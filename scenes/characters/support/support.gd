class_name Support
extends Character

var cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	cooldown = maxf(0.0, cooldown - delta)
	if is_multiplayer_authority() and Input.is_action_pressed("Fire") and not programming_block.code_block.has_focus():
		use_ability("heal")

func use_ability(ability: String) -> void:
	if ability not in ["heal", "fire"] or not is_multiplayer_authority() or cooldown > 0.0:
		return
	cooldown = 0.6
	request_heal.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_heal() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	var now: int = Time.get_ticks_msec()
	if now - int(get_meta("last_heal", -1000)) < 550:
		return
	set_meta("last_heal", now)
	var selected: Character
	# Below full health, not below 101: the old bound picked an untouched ally and spent the
	# cooldown healing nothing.
	var lowest_health: float = 100.0
	for ally: Node in get_tree().get_nodes_in_group("coop_players"):
		if ally != self and global_position.distance_to(ally.global_position) < 9.0:
			if ally.health < lowest_health:
				selected = ally as Character
				lowest_health = ally.health
	if selected != null:
		selected.receive_health.rpc(12.0)
		show_link.rpc(selected.get_path())
	else:
		show_out_of_range.rpc()

@rpc("any_peer", "call_local", "unreliable")
func show_out_of_range() -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1] or not is_multiplayer_authority():
		return
	# Rate-limit this hint independently from holding the ability button.
	var now: int = Time.get_ticks_msec()
	if now - int(get_meta("last_range_hint", -3000)) < 2500:
		return
	set_meta("last_range_hint", now)
	preload("res://scenes/actions/combat_fx.gd").number(get_tree().current_scene, global_position + Vector3.UP * 1.6, "Acércate a tu compañero", Color(0.25, 0.9, 1.0))

@rpc("any_peer", "call_local", "unreliable")
func show_link(path: NodePath) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	var ally := get_node_or_null(path) as Node3D
	if ally == null:
		return
	var operative := get_node_or_null("OperativeVisual")
	if operative != null:
		operative.aim_direction = Vector3(ally.global_position.x - global_position.x, 0, ally.global_position.z - global_position.z).normalized()
		operative.kick()
	var link := preload("res://scenes/actions/energy_link.gd").new()
	link.origin = self
	link.target = ally
	get_tree().current_scene.add_child(link)
