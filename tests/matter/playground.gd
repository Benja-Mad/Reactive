## Development-only entry point. The shipped main scene has no extra UI or bindings.
extends Node
var world: Node
var arena: Node
var player: Character
var selected: int = 0
var operation: String = "create"
var cursor := Vector3.ZERO
var ghost: MeshInstance3D
var ghost_material: StandardMaterial3D
var direction_preview: MeshInstance3D
var label: Label
var result_text: String = ""
const KEYS := {KEY_1:"create",KEY_2:"raise",KEY_3:"freeze",KEY_4:"impact",KEY_5:"push",KEY_6:"coat",KEY_7:"command",KEY_8:"remove"}

func _ready() -> void: call_deferred("start")
func start() -> void:
	Game.instance.players = [Statics.PlayerData.new(multiplayer.get_unique_id(),"Operador",0,Statics.Role.DAMAGE)]
	var scene: Node = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	scene.get_node("MatterConsole").hide()
	arena = scene.get_node("Arena")
	world = scene.get_node("WorldMatter")
	for i in 45: await get_tree().physics_frame
	player = scene.get_node("Players").get_child(0)
	player.programming_block.show()
	player.programming_block.code_block.release_focus()
	world.operation_result.connect(func(result: Dictionary):
		result_text = "Aplicado" if result["ok"] else result.get("reason", "Rechazado")
		if result["ok"]: selected = result["id"])
	ghost = MeshInstance3D.new()
	ghost.mesh = BoxMesh.new()
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = ghost_material
	add_child(ghost)
	direction_preview = MeshInstance3D.new()
	var arrow := CylinderMesh.new()
	arrow.top_radius = 0.0
	arrow.bottom_radius = 0.18
	arrow.radial_segments = 6
	direction_preview.mesh = arrow
	direction_preview.material_override = ghost_material
	direction_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(direction_preview)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(20,120)
	label.add_theme_font_size_override("font_size",16)
	ui.add_child(label)

func arguments() -> Dictionary:
	var direction: Vector3 = cursor - world.records.get(selected,{}).get("position",cursor-Vector3.RIGHT)
	return {"point":cursor,"material":"water","vector":direction.limit_length(16),"coating":"nanites","command":"detonate"}

func _process(_delta: float) -> void:
	if ghost == null or not is_instance_valid(player): return
	var camera: Camera3D = arena.gameplay_camera
	var point: Variant = Plane(Vector3.UP,0.07).intersects_ray(camera.project_ray_origin(get_viewport().get_mouse_position()),camera.project_ray_normal(get_viewport().get_mouse_position()))
	if point == null:
		ghost.hide()
		return
	cursor = point
	var verdict: Dictionary = world.preview(multiplayer.get_unique_id(),operation,selected,arguments())
	ghost.visible = true
	var record: Dictionary = world.records.get(selected,{})
	ghost.mesh.size = verdict.get("size",Vector3(0.5,0.08,0.5)) + Vector3.ONE*0.04
	ghost.position = verdict.get("position",cursor) + Vector3.UP*ghost.mesh.size.y*0.5
	ghost.rotation.y = record.get("yaw",0.0)
	if operation == "raise": ghost.rotation.y = -atan2(arguments()["vector"].z,arguments()["vector"].x)
	direction_preview.visible = operation == "push" and not record.is_empty()
	if direction_preview.visible:
		var direction: Vector3 = arguments()["vector"]
		direction.y = 0.0
		if direction.length() > 0.01:
			var axis: Vector3 = direction.normalized()
			var side: Vector3 = axis.cross(Vector3.UP).normalized()
			var length: float = minf(direction.length()*0.4,6.0)
			direction_preview.mesh.height = maxf(length,0.1)
			direction_preview.basis = Basis(side,axis,side.cross(axis))
			direction_preview.position = record["position"]+Vector3.UP*0.7+axis*length*0.5
	ghost_material.albedo_color = Color(0.76,0.82,0.6,0.22) if verdict["ok"] else Color(0.85,0.3,0.25,0.3)
	label.text = "MATERIA · herramienta de desarrollo\n1 Crear agua · 2 Elevar · 3 Congelar · 4 Impacto\n5 Impulso hacia cursor · 6 Recubrir · 7 Orden: detonar · 8 Retirar\nTab: siguiente objeto · clic: confirmar\n%s · objeto %d · %s\n%s" % [operation,selected,"Compatible" if verdict["ok"] else verdict.get("reason",""),result_text]

func _unhandled_input(event: InputEvent) -> void:
	if ghost == null or player.programming_block.code_block.has_focus(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if KEYS.has(event.keycode): operation = KEYS[event.keycode]
		if event.keycode == KEY_TAB and not world.records.is_empty():
			var ids: Array = world.records.keys()
			selected = ids[(ids.find(selected)+1)%ids.size()]
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		world.submit(operation,selected,arguments())
