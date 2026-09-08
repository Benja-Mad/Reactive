## Ground dressing redistribution for the fixed P30 framing.
##
## The authored scatter states its own intent in cyberslice/vegetation.py -- plants belong
## "in joints, at wall bases, under drips, along the trench - never in the middle of the
## kiting space" -- but the shipped GLB drifted: a continuous weed row crosses the gameplay
## line and the moss quads cluster around the character.
##
## Blender is not available on this host, so the authored export cannot be regenerated.
## This pass therefore re-places the already-imported nodes instead: transforms only, so the
## GLB, UV0, cs_* metadata, manifests, route data and the baked PBR surfaces are untouched.
## No node is created and no material is instanced, so draw calls only ever go down.
##
## Only cs_system=bio decoration is touched. Anything carrying cs_hazard, cs_states or a
## reactive channel (Puddle, Drain, Trench, HazardZone paint) is left exactly where authored.
extends Node

## XZ of the approved CENTER character position; the composition is read from P30, not from top view.
const CORE := Vector2(0.0, -2.0)
const CORE_RADIUS := 5.0
const TRANSITION_RADIUS := 13.0
const SEED := 20260907

## Decorative families that may be redistributed, with the share of displaced elements that is
## relocated to a perimeter anchor rather than hidden.
## Per family: share of displaced elements relocated to an anchor (the rest are hidden), and
## how strongly the family is thinned. Moss quads are large and flat, so a single one costs far
## more legibility than a weed tuft and is thinned harder.
const FAMILIES := {
	"Weeds": {"relocate": 0.70, "weight": 1.00},
	"Moss": {"relocate": 0.75, "weight": 0.55},
	"Yard_Fragment": {"relocate": 0.80, "weight": 0.85},
	"Ground_Stain": {"relocate": 0.55, "weight": 1.00},
}

## Never moved: these are the anchors that give relocation its spatial logic, and several of
## them carry functional metadata.
const ANCHOR_FAMILIES := ["Kerb_Stone", "ChainlinkPanel", "Puddle", "Drain", "Trench", "Ground_Patch", "JerseyBarrier"]

## A decorative node must be inert on every axis the district reacts on. Anything carrying a
## hazard, a state list, an fx hook or a non-structural channel stays exactly where authored --
## Puddle (cs_hazard=water), Drain (cs_states), Manhole (cs_fx=steam_vent), Trench (data_conduit)
## and the HazardZone paint all fail this test and are never moved.
const FUNCTIONAL_KEYS := ["cs_hazard", "cs_states", "cs_fx", "cs_prog", "cs_local_u", "cs_group"]

## Approved CENTER character position, used for the screen-space legibility term.
const CHARACTER_WORLD := Vector3(0.0, 0.9, -2.0)

var stats: Dictionary = {}
var _camera: Camera3D
var _character_screen: Vector2
var _screen_scale: float = 1080.0
var _changed: Array[Dictionary] = []
var _applied: bool = false


## `camera` is the framing the composition is judged from. It is optional: without one the
## redistribution still runs on the world-space rule alone, so a headless or editor context
## that has no current camera degrades instead of failing.
func setup(environment: Node, camera: Camera3D = null) -> void:
	var anchors: PackedVector3Array = _collect_anchors(environment)
	if anchors.is_empty():
		push_warning("Sector08GroundDressing: no perimeter anchors found; ground left as authored.")
		return
	# Composition is judged from the approved P30 framing, so thinning is driven by apparent
	# density around the character on screen as well as by distance across the yard.
	_camera = camera
	if _camera != null:
		_character_screen = _camera.unproject_position(CHARACTER_WORLD)
		_screen_scale = maxf(float(_camera.get_viewport().get_visible_rect().size.y), 1.0)
	for family: String in FAMILIES:
		var settings: Dictionary = FAMILIES[family]
		_redistribute(environment, family, anchors, float(settings["relocate"]), float(settings["weight"]))
	_applied = true


## Anchor points are existing world features -- kerb edges, fence lines, drains, puddles and
## conduit trenches -- so relocated growth reads as "wet, sheltered, untrafficked" rather than
## as a scatter with a hole punched in it.
func _collect_anchors(environment: Node) -> PackedVector3Array:
	var anchors := PackedVector3Array()
	for node: Node in environment.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var name_text: String = str(mesh.name)
		var matched: bool = false
		for family: String in ANCHOR_FAMILIES:
			if name_text.begins_with(family):
				matched = true
				break
		if not matched:
			continue
		var position: Vector3 = mesh.global_position
		# Keep the yard slab area only; background plinths and far kerbs would pull growth offscreen.
		if absf(position.x) > 26.0 or position.z < -26.0 or position.z > 14.0:
			continue
		# Ground-level features only: a trench lip or barrier top would leave growth reading as
		# though it sprouted out of the object rather than beside it.
		if position.y > 0.55:
			continue
		if Vector2(position.x - CORE.x, position.z - CORE.y).length() < CORE_RADIUS + 1.5:
			continue
		anchors.append(position)
	return anchors


func _redistribute(environment: Node, family: String, anchors: PackedVector3Array, relocate_share: float, weight: float) -> void:
	var candidates: Array[MeshInstance3D] = []
	for node: Node in environment.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not str(mesh.name).begins_with(family):
			continue
		# Foreground-band growth is part of the approved diorama foreground; leave it alone.
		if str(mesh.get_meta("cs_band", "")) != "PLAY":
			continue
		if not _is_inert_decoration(mesh):
			continue
		candidates.append(mesh)
	var kept: int = 0
	var moved: int = 0
	var hidden: int = 0
	var index: int = 0
	for mesh: MeshInstance3D in candidates:
		var position: Vector3 = mesh.global_position
		var radius: float = Vector2(position.x - CORE.x, position.z - CORE.y).length()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%d|%.3f|%.3f" % [family, SEED, position.x, position.z])
		if rng.randf() < _keep_probability(position, radius) * weight:
			kept += 1
			index += 1
			continue
		var entry: Dictionary = {"mesh": mesh, "authored_transform": mesh.transform, "authored_visible": mesh.visible}
		if rng.randf() < relocate_share:
			var anchor: Vector3 = anchors[rng.randi_range(0, anchors.size() - 1)]
			# Small jitter only: growth hugs the feature it was relocated to.
			var offset := Vector3(rng.randfn(0.0, 0.55), 0.0, rng.randfn(0.0, 0.55))
			mesh.global_position = Vector3(anchor.x + offset.x, position.y, anchor.z + offset.z)
			mesh.rotate_y(rng.randf_range(-PI, PI))
			moved += 1
		else:
			mesh.visible = false
			hidden += 1
		entry["pass_transform"] = mesh.transform
		entry["pass_visible"] = mesh.visible
		_changed.append(entry)
		index += 1
	stats[family] = {"total": candidates.size(), "kept": kept, "relocated": moved, "hidden": hidden}


func _is_inert_decoration(mesh: MeshInstance3D) -> bool:
	for key: String in FUNCTIONAL_KEYS:
		if mesh.has_meta(key):
			return false
	if str(mesh.get_meta("cs_channel", "")) != "structure":
		return false
	return is_zero_approx(float(mesh.get_meta("cs_reactive", 1.0)))


## Radial falloff, deliberately imperfect: two low-frequency terms keep some directions denser
## than others so the result reads as an unevenly used yard, not as a printed gradient.
func _keep_probability(position: Vector3, radius: float) -> float:
	var base: float
	if radius <= CORE_RADIUS:
		base = 0.14
	elif radius <= TRANSITION_RADIUS:
		base = lerpf(0.30, 0.80, (radius - CORE_RADIUS) / (TRANSITION_RADIUS - CORE_RADIUS))
	else:
		base = 1.0
	var angle: float = atan2(position.z - CORE.y, position.x - CORE.x)
	var bias: float = 0.17 * sin(angle * 3.0 + 1.3) + 0.11 * sin(position.x * 0.31) * cos(position.z * 0.27)
	var world_term: float = clampf(base + bias * clampf(radius / TRANSITION_RADIUS, 0.0, 1.0), 0.0, 1.0)
	if _camera == null:
		return world_term
	# Screen term: clears the reading area the character, enemies and projectiles occupy at P30,
	# which is a much narrower band than the same radius measured across the ground plane.
	var screen: Vector2 = _camera.unproject_position(position)
	var screen_distance: float = (screen - _character_screen).length() / _screen_scale
	var screen_term: float = clampf(inverse_lerp(0.075, 0.27, screen_distance), 0.0, 1.0)
	screen_term = lerpf(0.10, 1.0, screen_term)
	return minf(world_term, screen_term)


## Lets the capture harness shoot the authored placement as BEFORE through the identical camera,
## so the comparison isolates placement and nothing else.
func set_enabled(enabled: bool) -> void:
	if not _applied:
		return
	for entry: Dictionary in _changed:
		var mesh := entry["mesh"] as MeshInstance3D
		mesh.transform = entry["pass_transform"] if enabled else entry["authored_transform"]
		mesh.visible = bool(entry["pass_visible"] if enabled else entry["authored_visible"])
