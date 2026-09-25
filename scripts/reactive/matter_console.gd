## Runtime preparation and reference selection. Structured data only; world runs on host.
extends CanvasLayer
const OPS := ["", "raise", "freeze", "coat", "impact", "push"]
const NAMES := ["—", "Elevar", "Congelar", "Recubrir", "Impactar", "Impulsar"]
var world: Node
var runner: Node
var arena: Node
var selected: int = 0
var cursor := Vector3.ZERO
var direction := Vector3.FORWARD
var panel: PanelContainer
var steps: Array[OptionButton] = []
var trigger: OptionButton
var action: OptionButton
var status: Label
var hint: Label
var ghost: MeshInstance3D
var ghost_material: StandardMaterial3D
var draft := {"steps": ["raise","freeze","coat"], "trigger": "broken", "action": "push"}
var message: String = "Q despliega hacia el cursor · E prepara una rutina"
var aiming: bool = false
var auto_ability: CheckBox
const DISPLAY := {"water":"agua", "ice":"hielo", "broken":"rotura", "hit":"impacto", "transformed":"transformación", "push":"impulsar", "command":"detonar", "freeze":"congelar"}

func _ready() -> void:
	world = get_parent().get_node("WorldMatter")
	runner = world.get_node("Programs")
	arena = get_parent().get_node("Arena")
	runner.feedback.connect(_result)
	world.operation_result.connect(_result)
	layer = 8
	var save := ConfigFile.new()
	if save.load("user://reactive_routine.cfg") == OK:
		var stored: Variant = save.get_value("routine","draft",draft)
		if stored is Dictionary and runner.valid(stored): draft = stored
	panel = PanelContainer.new()
	panel.position = Vector2(24,144)
	panel.custom_minimum_size = Vector2(325,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.064,0.061,0.96)
	style.border_color = Color(0.49,0.39,0.23)
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	_text(column,"PREPARAR / RUTINA 01",18)
	auto_ability = CheckBox.new()
	auto_ability.text = "Disparo / curación periódica"
	auto_ability.toggled.connect(_toggle_ability)
	column.add_child(auto_ability)
	_text(column,"Q: crear agua en el cursor y ejecutar\nDirección: desde ti hacia el punto elegido",13)
	for index in 4:
		var row := HBoxContainer.new()
		column.add_child(row)
		_text(row,str(index+1)+"  ",14)
		var pick := OptionButton.new()
		for title: String in NAMES: pick.add_item(title)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.select(OPS.find(draft["steps"][index]) if index < draft["steps"].size() else 0)
		row.add_child(pick)
		steps.append(pick)
	_text(column,"DESPUÉS / REACCIONAR UNA VEZ",14)
	trigger = OptionButton.new()
	for title: String in ["Al romperse", "Al recibir daño", "Al transformarse"]: trigger.add_item(title)
	trigger.select(["broken","hit","transformed"].find(draft["trigger"]))
	column.add_child(trigger)
	action = OptionButton.new()
	for title: String in ["Impulsar hacia la dirección guardada", "Ordenar detonación del recubrimiento", "Congelar"]: action.add_item(title)
	action.select(["push","command","freeze"].find(draft["action"]))
	column.add_child(action)
	var bind_button := Button.new()
	bind_button.text = "Vincular reacción a la referencia seleccionada"
	bind_button.pressed.connect(func(): world.submit("react",selected,{"trigger":["broken","hit","transformed"][trigger.selected],"action":["push","command","freeze"][action.selected],"vector":direction.normalized()*14.0}))
	column.add_child(bind_button)
	var save_button := Button.new()
	save_button.text = "Guardar y volver al combate [E]"
	save_button.pressed.connect(_save)
	column.add_child(save_button)
	_text(column,"Los pasos incompatibles detienen la rutina.\nLa materia ya creada permanece.\nEl combate continúa mientras preparas.",12)
	panel.hide()
	status = Label.new()
	status.position = Vector2(24,24)
	status.add_theme_font_size_override("font_size",14)
	status.add_theme_color_override("font_color",Color(0.87,0.79,0.6))
	status.add_theme_color_override("font_shadow_color",Color.BLACK)
	status.add_theme_constant_override("shadow_offset_y",2)
	add_child(status)
	hint = Label.new()
	hint.position = Vector2(24,100)
	hint.add_theme_font_size_override("font_size",12)
	hint.text = "Q mantener / soltar: desplegar · E preparar · C seleccionar · R impactar · T detonar · 1/2/3/4 elevar/congelar/recubrir/impulsar"
	add_child(hint)
	ghost = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4,1.8,0.2)
	ghost.mesh = mesh
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = ghost_material
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child.call_deferred(ghost)
	ghost.hide()

func _text(parent: Node, value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)

func _save() -> void:
	var chosen: Array = []
	for pick: OptionButton in steps:
		if pick.selected > 0: chosen.append(OPS[pick.selected])
	draft = {"steps":chosen,"trigger":["broken","hit","transformed"][trigger.selected],"action":["push","command","freeze"][action.selected]}
	var save := ConfigFile.new()
	save.set_value("routine","draft",draft)
	var error: Error = save.save("user://reactive_routine.cfg")
	message = "Rutina guardada · Q para reutilizar" if error == OK else "Rutina lista · no se pudo guardar en disco"
	panel.hide()
	get_viewport().gui_release_focus()

func _toggle_ability(enabled: bool) -> void:
	var player: Character = world._player(multiplayer.get_unique_id())
	if player == null: return
	player.programming_block.code_block.text = ("heal()" if player is Support else "fire()") if enabled else ""

func _result(result: Dictionary) -> void:
	message = result.get("message","Operación aplicada") if result["ok"] else "Interrumpido · " + result.get("reason","")
	var reasons := {"Requires movable matter":"Requiere materia móvil", "Cannot freeze this material":"Este material no se puede congelar", "Requires reshapeable matter":"Requiere materia moldeable", "No compatible attachment":"No hay recubrimiento compatible", "Target no longer exists":"La referencia ya no existe", "Out of reach":"Fuera de alcance", "Solid volume is occupied":"El volumen sólido está ocupado", "Already coated":"Ya tiene ese recubrimiento", "Requires breakable matter":"Requiere materia rompible"}
	for source: String in reasons: message = message.replace(source,reasons[source])
	for token: String in DISPLAY: message = message.replace(token,DISPLAY[token])
	if result["ok"] and result.has("id"): selected = result["id"]

func _process(_delta: float) -> void:
	if not visible or not ghost.is_inside_tree(): return
	panel.position.y = clampf(get_viewport().get_visible_rect().size.y-780.0,96.0,144.0)
	var player: Node3D = world._player(multiplayer.get_unique_id())
	if player == null: return
	var camera: Camera3D = arena.gameplay_camera
	var point: Variant = Plane(Vector3.UP,0.07).intersects_ray(camera.project_ray_origin(get_viewport().get_mouse_position()),camera.project_ray_normal(get_viewport().get_mouse_position()))
	if point != null and not panel.visible:
		cursor = point
		direction = cursor-player.global_position
		direction.y = 0.0
	if direction.length() < 0.1: direction = Vector3.FORWARD
	var verdict: Dictionary = world.preview(multiplayer.get_unique_id(),"create",0,{"point":cursor})
	ghost.visible = aiming and not panel.visible
	ghost.mesh.size = Vector3(4,1.8,0.2) if "raise" in draft["steps"] else Vector3(4,0.12,3)
	ghost.position = cursor+Vector3.UP*ghost.mesh.size.y*0.5
	var axis: Vector3 = direction.cross(Vector3.UP)
	ghost.rotation.y = -atan2(axis.z,axis.x) if "raise" in draft["steps"] else 0.0
	ghost_material.albedo_color = Color(0.8,0.72,0.46,0.25) if verdict["ok"] else Color(0.85,0.25,0.12,0.3)
	var record: Dictionary = world.records.get(selected,{})
	if not aiming and not record.is_empty():
		ghost.visible = true
		ghost.mesh.size = Vector3(record["size"].x+0.25,0.025,maxf(record["size"].z,0.45)+0.2)
		ghost.position = record["position"]+Vector3.UP*0.04
		ghost.rotation.y = record["yaw"]
		ghost_material.albedo_color = Color(0.85,0.66,0.32,0.2)
	var state: String = "sin referencia" if record.is_empty() else "#%d · %s · %d integridad%s" % [selected,DISPLAY.get(record["material"],record["material"]),record["integrity"]," · ARMADO" if record.has("reaction") else ""]
	status.text = ("Crear · " + ("suelo compatible" if verdict["ok"] else verdict.get("reason",""))) if aiming else "RUTINA 01   /   INTEGRIDAD %d
%s
%s" % [player.health,state,message]
	hint.position.y = get_viewport().get_visible_rect().size.y-30.0

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if not event is InputEventKey or event.echo: return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is TextEdit or focus is LineEdit: return
	if event.keycode == KEY_E and event.pressed:
		if panel.visible: _save()
		else:
			aiming = false
			panel.show()
		get_viewport().set_input_as_handled()
		return
	if panel.visible: return
	if event.keycode == KEY_Q:
		var was_aiming: bool = aiming
		aiming = event.pressed
		if not event.pressed and was_aiming: runner.submit(draft,cursor,direction)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed: return
	if event.keycode == KEY_C:
		selected = 0
		var distance: float = 6.0
		for record: Dictionary in world.records.values():
			var separation: float = record["position"].distance_to(cursor)
			if record["owner"] == multiplayer.get_unique_id() and separation < distance:
				distance = separation
				selected = record["id"]
	if event.keycode == KEY_R: world.submit("impact",selected)
	if event.keycode == KEY_T: world.submit("command",selected,{"command":"detonate"})
	if event.keycode == KEY_DELETE: world.submit("remove",selected)
	if event.keycode == KEY_1: world.submit("raise",selected,{"vector":direction.cross(Vector3.UP)})
	if event.keycode == KEY_2: world.submit("freeze",selected)
	if event.keycode == KEY_3: world.submit("coat",selected)
	if event.keycode == KEY_4: world.submit("push",selected,{"vector":direction.normalized()*14})
