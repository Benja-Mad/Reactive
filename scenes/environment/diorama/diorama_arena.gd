## Base for every diorama-style arena in the game.
##
## The house style is a fixed *orientation*, not a fixed camera: the basis and the field of view
## are approved once per level and never change, while the position translates to follow the
## player. That is what keeps the parallax honest — the world moves across the frame because the
## camera really moved through it, not because layers were slid around — and it is why the depth
## blur, the ground redistribution and any foreground framing device can be calibrated against a
## single known angle.
##
## A level scene deriving from this must contain:
##   GameplayCamera    : Camera3D
##   RuntimeEnvironment : WorldEnvironment
##
## Everything below is exported, so a second level keeps the discipline while choosing its own
## target, palette and densities. Sector 08's approved values are the defaults.
class_name DioramaArena
extends Node3D

# --- Approved framing -------------------------------------------------------------------------

## Point the framing is composed around, in world space.
@export var framing_target: Vector3 = Vector3(0.0, 6.15, -2.0)
@export var framing_distance: float = 85.8
@export var framing_yaw_degrees: float = 35.0
@export var framing_pitch_degrees: float = 30.0
## "P30". The whole look is calibrated to this; changing it invalidates the depth blur ramp and
## every screen-space composition rule that depends on it.
@export var framing_fov: float = 30.0
@export var framing_near: float = 0.5
@export var framing_far: float = 420.0

# --- Follow -----------------------------------------------------------------------------------

## Fraction of the frame the target may move within before the camera starts translating.
@export var follow_dead_zone: Vector2 = Vector2(0.10, 0.13)
## Metres the camera may travel from the approved origin, along its own right and up axes.
@export var follow_limit: Vector2 = Vector2(9.0, 3.0)
@export var follow_speed: float = 3.2

# --- Presentation -----------------------------------------------------------------------------

## Lookdev affordances: debug overlay, the static stand-in figure, the lateral sweep. Off in game.
@export var lookdev_tools: bool = true
## World filter mode: 0 CLEAN, 1 SOFT, 2 MEDIUM.
@export_range(0, 2) var presentation_mode: int = 0
@export var diorama_enabled: bool = true

var gameplay_camera: Camera3D
var runtime_environment: WorldEnvironment
var camera_rig: Node
var pixel_presentation: Node
var approved_transform: Transform3D


## Call from the derived scene's _ready() before any level-specific setup.
func _initialise_diorama() -> void:
	gameplay_camera = get_node("GameplayCamera") as Camera3D
	runtime_environment = get_node("RuntimeEnvironment") as WorldEnvironment
	# Thin rails and cables need edge coverage at a framing this stable.
	get_viewport().msaa_3d = Viewport.MSAA_2X
	apply_framing()
	approved_transform = gameplay_camera.global_transform


## Places the camera on the approved framing. Position is derived, so a level only states where
## it is looking and from how far, never a hand-tuned transform.
func apply_framing() -> void:
	var pitch: float = deg_to_rad(framing_pitch_degrees)
	var yaw: float = deg_to_rad(framing_yaw_degrees)
	var horizontal: float = cos(pitch) * framing_distance
	var offset := Vector3(sin(yaw) * horizontal, sin(pitch) * framing_distance, cos(yaw) * horizontal)
	gameplay_camera.global_position = framing_target + offset
	gameplay_camera.look_at(framing_target, Vector3.UP)
	gameplay_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	gameplay_camera.keep_aspect = Camera3D.KEEP_WIDTH
	gameplay_camera.fov = framing_fov
	gameplay_camera.near = framing_near
	gameplay_camera.far = framing_far


## Built after the level has finished placing its own content, so the rig captures the approved
## transform rather than whatever the level was mid-way through setting up.
func build_camera_rig() -> Node:
	camera_rig = preload("res://scenes/environment/diorama/diorama_camera_rig.gd").new()
	camera_rig.name = "CameraRig"
	camera_rig.dead_zone = follow_dead_zone
	camera_rig.limit = follow_limit
	camera_rig.follow_speed = follow_speed
	add_child(camera_rig)
	camera_rig.setup(gameplay_camera, approved_transform)
	return camera_rig


func build_presentation() -> Node:
	pixel_presentation = preload("res://scenes/environment/sector_08/runtime/sector_08_pixel_presentation.gd").new()
	add_child(pixel_presentation)
	pixel_presentation.setup(gameplay_camera)
	pixel_presentation.set_mode(presentation_mode)
	pixel_presentation.set_diorama(diorama_enabled)
	return pixel_presentation


## The arena owns the framing, so it owns which camera is current.
func activate_camera() -> void:
	gameplay_camera.current = true


func follow(target: Node3D) -> void:
	if camera_rig == null:
		return
	camera_rig.set_target(target)
	camera_rig.set_enabled(target != null)


## Spawn positions a level offers the game. Overridden per level; the base returns the framing
## target projected to the ground so an arena without authored spawns is still playable.
func get_spawn_positions() -> Array[Vector3]:
	return [Vector3(framing_target.x, 0.0, framing_target.z)]


## Where the wave director may place enemies. Returns a position on the ring at `angle`, pulled
## inward until it is clear of static geometry, or the ring position if nothing blocks.
func find_clear_spawn(angle: float, radius: float) -> Vector3:
	var origin := Vector3(framing_target.x, 0.0, framing_target.z)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	for step in 6:
		var distance: float = radius * (1.0 - 0.13 * float(step))
		var candidate: Vector3 = origin + Vector3(cos(angle), 0.0, sin(angle)) * distance
		query.transform = Transform3D(Basis(), candidate + Vector3.UP * 0.9)
		if space.intersect_shape(query, 1).is_empty():
			return candidate
	return origin + Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.35


func get_framing_report() -> Dictionary:
	return {
		"fov": gameplay_camera.fov if gameplay_camera != null else -1.0,
		"basis_preserved": gameplay_camera != null and gameplay_camera.global_basis.is_equal_approx(approved_transform.basis),
		"target": str(framing_target),
		"distance_m": framing_distance,
		"yaw_deg": framing_yaw_degrees,
		"pitch_deg": framing_pitch_degrees,
		"follow_limit_m": str(follow_limit),
		"lookdev_tools": lookdev_tools,
	}
