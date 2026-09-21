## NOT INSTANTIATED. An articulated procedural-mesh operative, written to replace the players'
## sprites. It is kept because the 3D-character direction may be worth revisiting, but the game
## uses the pixel-art AnimatedSprite3D: the whole presentation is built around it -- nearest
## filtering, alpha-cut, and the pixel world filter the arena renders through. Swapping in meshes
## changed the game's identity, and was not asked for. To try it again, call it from
## Sector08LookDev.configure_player_presentation instead of the sprite fit.
## Articulated presentation only. The owning network body keeps movement and combat authority.
extends Node3D

var accent := Color(0.12, 0.88, 1.0)
var hostile: bool = false
var torso: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var weapon: Node3D
var phase: float = 0.0
var recoil: float = 0.0
var aim_direction := Vector3(0, 0, -1)
var disabled: bool = false
var plates: StandardMaterial3D
var glow: StandardMaterial3D

func _ready() -> void:
	var dark := _material(Color(0.075, 0.105, 0.14), 0.18, 0.58)
	plates = _material(Color(0.38, 0.095, 0.11) if accent.r > 0.7 else Color(0.085, 0.32, 0.38), 0.38, 0.42)
	var steel := _material(Color(0.22, 0.29, 0.33), 0.8, 0.27)
	glow = _material(accent, 0.25, 0.23)
	glow.emission_enabled = true
	glow.emission = accent
	glow.emission_energy_multiplier = 2.1
	torso = Node3D.new()
	add_child(torso)
	_box(torso, Vector3(0, 1.22, 0), Vector3(0.57, 0.61, 0.34), dark)
	_box(torso, Vector3(0, 1.35, -0.19), Vector3(0.53, 0.35, 0.12), plates)
	_box(torso, Vector3(0, 1.48, -0.265), Vector3(0.23, 0.035, 0.025), glow)
	_box(torso, Vector3(0, 0.94, 0), Vector3(0.52, 0.13, 0.39), steel)
	# Curved shoulder shells and layered hip plates break the rectangular silhouette.
	for side: float in [-1.0, 1.0]:
		var shell := MeshInstance3D.new()
		var shell_mesh := SphereMesh.new()
		shell_mesh.radius = 0.20
		shell_mesh.height = 0.32
		shell_mesh.radial_segments = 16
		shell_mesh.rings = 8
		shell.mesh = shell_mesh
		shell.material_override = plates
		shell.position = Vector3(side * 0.37, 1.53, 0)
		torso.add_child(shell)
		var skirt := _box(torso, Vector3(side * 0.23, 0.82, 0.04), Vector3(0.18, 0.36, 0.38), plates)
		skirt.rotation.z = side * 0.14
		_box(torso, Vector3(side * 0.40, 1.55, -0.17), Vector3(0.14, 0.035, 0.04), glow)
	# A restrained local fill keeps the armor readable under the yard's overhead lights.
	var bounce := OmniLight3D.new()
	bounce.position = Vector3(0, 2.5, 0.7)
	bounce.light_color = Color(0.58, 0.73, 0.9)
	bounce.light_energy = 0.7
	bounce.omni_range = 2.8
	bounce.light_specular = 0.1
	add_child(bounce)
	for side: float in [-1.0, 1.0]:
		_box(torso, Vector3(side * 0.2, 1.02, -0.22), Vector3(0.12, 0.16, 0.11), dark)
		_box(torso, Vector3(side * 0.17, 1.31, -0.266), Vector3(0.025, 0.2, 0.018), steel)
	var head := MeshInstance3D.new()
	var helmet := SphereMesh.new()
	helmet.radius = 0.235
	helmet.height = 0.47
	helmet.radial_segments = 16
	helmet.rings = 8
	head.mesh = helmet
	head.material_override = plates
	head.position = Vector3(0, 1.86, -0.01)
	torso.add_child(head)
	_box(torso, Vector3(0, 1.88, -0.208), Vector3(0.36, 0.095, 0.065), dark)
	_box(torso, Vector3(0, 1.89, -0.248), Vector3(0.30, 0.027, 0.025), glow)
	_box(torso, Vector3(0, 1.7, -0.15), Vector3(0.22, 0.12, 0.16), steel)
	_box(torso, Vector3(0, 1.35, 0.29), Vector3(0.43, 0.57, 0.24), dark)
	for side: float in [-1.0, 1.0]:
		_box(torso, Vector3(side * 0.15, 1.36, 0.425), Vector3(0.05, 0.39, 0.035), glow)
	left_leg = _limb(Vector3(-0.18, 0.91, 0), false, dark, steel)
	right_leg = _limb(Vector3(0.18, 0.91, 0), false, dark, steel)
	left_arm = _limb(Vector3(-0.38, 1.52, 0), true, dark, steel)
	right_arm = _limb(Vector3(0.38, 1.52, 0), true, dark, steel)
	weapon = Node3D.new()
	torso.add_child(weapon)
	weapon.position = Vector3(0.31, 1.15, -0.48)
	_box(weapon, Vector3.ZERO, Vector3(0.16, 0.2, 0.52), dark)
	_box(weapon, Vector3(0, 0.05, -0.31), Vector3(0.09, 0.1, 0.28), steel)
	_box(weapon, Vector3(0, 0.05, -0.455), Vector3(0.08, 0.06, 0.02), glow)
	_box(weapon, Vector3(0, 0.13, -0.08), Vector3(0.08, 0.07, 0.13), steel)
	if not hostile and accent.r < 0.7:
		_box(torso, Vector3(0, 1.36, 0.433), Vector3(0.24, 0.06, 0.02), glow)
		_box(torso, Vector3(0, 1.36, 0.435), Vector3(0.06, 0.24, 0.02), glow)

func _material(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	return material

func _box(parent: Node3D, point: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.material_override = material
	piece.position = point
	parent.add_child(piece)
	return piece

func _limb(point: Vector3, arm: bool, dark: Material, steel: Material) -> Node3D:
	var pivot := Node3D.new()
	torso.add_child(pivot)
	pivot.position = point
	var width: float = 0.19 if arm else 0.22
	_box(pivot, Vector3(0, -0.19, 0), Vector3(width, 0.35, 0.23), plates)
	_box(pivot, Vector3(0, -0.39, -0.035), Vector3(width * 0.8, 0.12, 0.22), steel)
	_box(pivot, Vector3(0, -0.57, 0), Vector3(width * 0.8, 0.3, 0.19), dark)
	if not arm:
		_box(pivot, Vector3(0, -0.79, -0.07), Vector3(0.24, 0.18, 0.38), dark)
		_box(pivot, Vector3(0, -0.53, -0.105), Vector3(0.14, 0.22, 0.045), plates)
	return pivot

func kick() -> void:
	recoil = 1.0

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var speed: float = Vector2(body.velocity.x, body.velocity.z).length() if body != null else 0.0
	phase += delta * (9.0 if speed > 0.1 else 2.0)
	recoil = move_toward(recoil, 0.0, delta * 7.0)
	if body != null and speed > 0.1:
		aim_direction = Vector3(body.velocity.x, 0, body.velocity.z).normalized()
	if body is Damage:
		aim_direction = body.facing_dir
	if aim_direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-aim_direction.x, -aim_direction.z), 1.0 - exp(-delta * 12.0))
	torso.rotation.z = lerp_angle(torso.rotation.z, -1.2 if disabled else -stride_lean(speed), minf(delta * 6.0, 1.0))
	torso.position.y = sin(phase * 2.0) * (0.035 if speed > 0.1 else 0.012)
	var stride: float = sin(phase) * minf(speed / 3.5, 1.0) * 0.55
	left_leg.rotation.x = stride
	right_leg.rotation.x = -stride
	left_arm.rotation.x = -0.8 - stride * 0.15
	right_arm.rotation.x = -1.05 + recoil * 0.18
	weapon.position.z = -0.48 + recoil * 0.1

func stride_lean(speed: float) -> float:
	return sin(phase) * minf(speed / 3.5, 1.0) * 0.045
