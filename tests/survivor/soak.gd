## Accelerated complete shift. A movement-only pilot collects upgrades and avoids nearby danger.
extends Node
const Build = preload("res://scripts/survivor/build.gd")
var scene: Node
var run: Node
var frames_run: int = 0
var peak_enemies: int = 0
var peak_matter: int = 0
var peak_pickups: int = 0
var chosen: Array[String] = []
var kinds_seen: Dictionary = {}
var pilot: Character
var invulnerable: bool = false
var peak_snapshot: int = 0
var peak_machine_sync: int = 0
var damage_dealt: float = 0.0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("start")
func start() -> void:
	# `support` flies the Sereno instead of Brasa.
	Game.instance.players = [Statics.PlayerData.new(1,"Pilot",0,Statics.Role.SUPPORT if "support" in OS.get_cmdline_user_args() else Statics.Role.DAMAGE)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	# `seed=N` replays the shift on another spawn seed, to average a tuning change over several.
	run._rng.seed = 8026
	for arg: String in OS.get_cmdline_user_args(): if arg.begins_with("seed="): run._rng.seed = int(arg.substr(5))
	for i: int in 40: await get_tree().physics_frame
	pilot = run.local_player()
	Engine.time_scale = 6
	# To exercise late waves even if the pilot loses, an optional durability run is explicit.
	invulnerable = "durability" in OS.get_cmdline_user_args()
	# `norules` turns heat and conduction off, for a baseline on the same seed; `showcase` starts
	# the shift with routines that put the rules to work (charge in crowds, boiling trail, ice).
	run.spellwork.rules.enabled = not "norules" in OS.get_cmdline_user_args()
	if "showcase" in OS.get_cmdline_user_args():
		run.builds[1]["routines"] = [
			{"when": "cerca", "steps": ["raise", "cold"], "then": "fragmentos"},
			{"when": "grupo", "steps": ["arc", "arc"], "then": ""},
			{"when": "rastro", "steps": ["fire", "fire"], "then": ""},
		]
func _physics_process(_delta: float) -> void:
	if pilot == null: return
	frames_run += 1
	if run.phase == "upgrade":
		var options: Array = run.offers.get(1, [])
		if not options.is_empty():
			# A plain heuristic player: put a piece where it leaves a routine working and fills an
			# empty slot; otherwise take a tool, otherwise box the first piece.
			var key: String = options[0]
			var target: int = -1
			var build: Dictionary = run.builds[1]
			# A condition goes right before a routine's last DO, the way a player would ask
			# before the step worth asking about.
			for option: String in options:
				if not Build.is_gate(option): continue
				for index: int in build["routines"].size():
					var steps: Array = build["routines"][index]["steps"]
					if build["routines"][index]["when"] == "" or steps.is_empty() or steps.any(func(step: String) -> bool: return Build.is_gate(step)): continue
					var asked: Dictionary = Build.put(build, option, {"routine": index, "slot": "step", "index": steps.size() - 1})
					if asked.is_empty() or Build.problem(asked["routines"][index]) != "": continue
					chosen.append(option)
					run.choose_upgrade(option, -1, asked)
					return

			for option: String in options:
				if Build.is_tool_key(option): continue
				var slot: String = Build.PIECES[option]["slot"]
				if slot == "step" and "attackfirst" in OS.get_cmdline_user_args() and Build.attack_steps(build).size() < Build.Attack.MAX_STEPS: continue
				for index: int in build["routines"].size():
					var routine: Dictionary = build["routines"][index]
					if slot != "step" and routine[slot] != "": continue
					if slot == "step" and routine["when"] == "": continue
					var trial: Dictionary = Build.place(build, option, index)
					if trial.is_empty() or Build.problem(trial["routines"][index]) != "": continue
					key = option
					target = index
					break
				if target >= 0: break
			# A DO piece no routine can use goes into the weapon while it has room; `attackfirst`
			# plugs DO pieces into the weapon before any routine.
			if "attackfirst" in OS.get_cmdline_user_args():
				for option: String in options:
					if not Build.is_tool_key(option) and Build.PIECES[option]["slot"] == "step" and Build.attack_steps(build).size() < Build.Attack.MAX_STEPS:
						key = option
						target = Build.ATTACK
						break
			if target == -1:
				for option: String in options:
					if not Build.is_tool_key(option) and Build.PIECES[option]["slot"] == "step" and Build.attack_steps(build).size() < Build.Attack.MAX_STEPS:
						key = option
						target = Build.ATTACK
						break
			if target == -1:
				for option: String in options:
					if Build.is_tool_key(option): key = option
			chosen.append(key)
			run.choose_upgrade(key, target)
		return
	if run.phase in ["lost", "won"]:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
		print("SURVIVOR SOAK ", JSON.stringify({"phase":run.phase,"time":run.elapsed,"kills":run.kills,"level":run.level,"upgrades":chosen,"peak_enemies":peak_enemies,"peak_matter":peak_matter,"peak_pickups":peak_pickups,"automations":run.automations_fired,"water":run.water_log,"kinds_seen":kinds_seen,"durability":invulnerable,
			"rules":run.spellwork.rules.enabled,"rule_stats":run.spellwork.rules.stats,"peak_snapshot_bytes":peak_snapshot,"peak_machine_sync_bytes":peak_machine_sync,"routines":run.builds[1]["routines"],"attack":Build.attack_steps(run.builds[1]),"damage":run.damage_log}))
		Engine.time_scale = 1
		get_tree().paused = false
		get_tree().quit(0 if run.elapsed > 20 else 1)
		return
	if invulnerable: pilot.health = 100
	# The pilot clicks too: on the nearest machine in sight, about once a second.
	if run.phase == "running" and frames_run % 60 == 0:
		var seen: Array[Node3D] = run.targets(pilot)
		if not seen.is_empty(): run.cue(seen[0].global_position)
	peak_enemies = maxi(peak_enemies, run.machines.get_child_count())
	for enemy: Node in run.machines.get_children(): kinds_seen[str(enemy.kind)] = true
	peak_matter = maxi(peak_matter, run.world.records.size())
	peak_pickups = maxi(peak_pickups, run.pickups.get_child_count())
	peak_snapshot = maxi(peak_snapshot, run.world.snapshot_bytes)
	if frames_run % 30 == 0:
		# What `publish` sends for the machines, properties included.
		var sync: Dictionary = {}
		for enemy: Node3D in run.machines.get_children():
			sync[str(enemy.name)] = [enemy.global_position, enemy.velocity]
			if enemy.props_code() != 0: sync[str(enemy.name)].append(enemy.props_code())
		peak_machine_sync = maxi(peak_machine_sync, var_to_bytes(sync).size())
	if frames_run % 3 != 0: return
	var escape := Vector3.ZERO
	for enemy: Node3D in run.machines.get_children():
		var away: Vector3 = pilot.global_position - enemy.global_position
		away.y = 0
		if away.length() < 6: escape += away.normalized() * (6 - away.length()) * 0.9
	var goal := Vector3.ZERO
	var best: float = INF
	for pickup: Node3D in run.pickups.get_children():
		var distance: float = pickup.global_position.distance_to(pilot.global_position)
		if distance < best:
			best = distance
			goal = (pickup.global_position - pilot.global_position).normalized() * 2
	var drift: Vector3 = Vector3(sin(run.elapsed * 0.22),0,cos(run.elapsed*0.22))
	var wish: Vector3 = (goal + escape + drift * 0.7).normalized()
	# Stay in the central paved court and reject directions blocked by scenery.
	if absf(pilot.global_position.x) > 15: wish.x = -signf(pilot.global_position.x)
	if pilot.global_position.z < -14: wish.z = 1
	if pilot.global_position.z > 18: wish.z = -1
	var space: PhysicsDirectSpaceState3D = pilot.get_world_3d().direct_space_state
	for turn: int in 8:
		var query := PhysicsRayQueryParameters3D.create(pilot.global_position, pilot.global_position + wish * 2, 1)
		query.exclude = [pilot.get_rid()]
		if space.intersect_ray(query).is_empty(): break
		wish = wish.rotated(Vector3.UP, PI/4)
	var local: Vector3 = Character.movement_basis.inverse() * wish
	Input.action_press("move_right", maxf(0,local.x))
	Input.action_press("move_left", maxf(0,-local.x))
	Input.action_press("move_down", maxf(0,local.z))
	Input.action_press("move_up", maxf(0,-local.z))
