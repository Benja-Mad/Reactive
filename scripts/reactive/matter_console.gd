## Runtime preparation and reference selection. Structured data only; world runs on host.
## Holds three routine slots, draws the operator's HUD and the editor, and projects the routine
## into the yard while it is being aimed: its final form, the vector it will push along, and
## the conduit it will open to the previous routine.
extends CanvasLayer
const Catalog = preload("res://scripts/matter/materials.gd")
const Meshes = preload("res://scripts/matter/matter_meshes.gd")
const Model = preload("res://scripts/reactive/routine_model.gd")
const Style = preload("res://scripts/reactive/console_style.gd")
const SAVE_PATH := "user://reactive_routine.cfg"
const REASONS := {"Requires movable matter": "Requiere materia móvil", "Cannot freeze this material": "Este material no se puede congelar",
	"Cannot heat this material": "Este material no se puede calentar", "Requires reshapeable matter": "Requiere materia moldeable",
	"No compatible attachment": "No hay recubrimiento compatible", "Target no longer exists": "La referencia ya no existe",
	"Out of reach": "Fuera de alcance", "Solid volume is occupied": "El volumen sólido está ocupado", "Already coated": "Ya tiene ese recubrimiento",
	"Requires breakable matter": "Requiere materia rompible", "Requires level ground": "Necesita suelo plano", "Construct limit reached": "Límite de constructos",
	"Choose another reference": "Elige otra referencia", "Conduit out of range": "Conducto fuera de alcance (14 m)",
	"Target belongs to another player": "Pertenece a otro operador", "Player unavailable": "Operador no disponible",
	"Operation already resolving": "Otra operación en curso", "Incompatible surface": "Superficie incompatible"}
const TOKENS := {"broken": "rotura", "hit": "impacto", "transformed": "cambio de fase", "pulsed": "pulso", "push": "impulsar",
	"command": "detonar", "freeze": "congelar", "heat": "calentar", "water": "agua", "ice": "hielo", "steam": "vapor"}

var world: Node
var runner: Node
var arena: Node
var selected: int = 0
var cursor := Vector3.ZERO
var direction := Vector3.FORWARD
var slots: Array = []
var current_slot: int = 0
var chain_tail: int = 0
var aiming: bool = false
var verdict: Dictionary = {}
var message: String = "Q despliega la rutina hacia el cursor · E la edita"
var message_ok: bool = true
var periodic: bool = false
## Screen point used instead of the mouse, for captures and scripted tests.
var pointer_override: Variant = null
## The editor. Named `panel` because tests and tools open it by that name.
var panel: Control
var hud: Control
var _root: Control
var _message_time: float = 0.0
var _deployed_at: float = -100.0
var _hologram: MeshInstance3D
var _hologram_material: ShaderMaterial
var _hologram_key: String = ""
var _marker: MeshInstance3D
var _marker_material: ShaderMaterial
var _arrow: MeshInstance3D
var _arrow_material: ShaderMaterial
var _chain_preview: MeshInstance3D

func _ready() -> void:
	world = get_parent().get_node("WorldMatter")
	runner = world.get_node("Programs")
	arena = get_parent().get_node("Arena")
	runner.feedback.connect(_result)
	world.operation_result.connect(_result)
	layer = 8
	_load()
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	hud = preload("res://scripts/reactive/console_hud.gd").new()
	hud.console = self
	_root.add_child(hud)
	panel = preload("res://scripts/reactive/routine_editor.gd").new()
	panel.console = self
	_root.add_child(panel)
	panel.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_build_previews()

func _layout() -> void:
	# Drawn at a 1080-line reference and scaled, so the instrument keeps its proportions.
	var view: Vector2 = get_viewport().get_visible_rect().size
	var ui_scale: float = clampf(view.y / 1080.0, 0.6, 2.0)
	_root.scale = Vector2.ONE * ui_scale
	_root.size = view / ui_scale
	hud.size = _root.size
	panel.place(_root.size)

func _build_previews() -> void:
	_hologram = MeshInstance3D.new()
	_hologram_material = ShaderMaterial.new()
	_hologram_material.shader = preload("res://scripts/reactive/hologram.gdshader")
	_hologram.material_override = _hologram_material
	_hologram.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker = _ground_quad()
	_marker_material = _marker.material_override
	_arrow = _ground_quad()
	_arrow_material = _arrow.material_override
	_arrow_material.set_shader_parameter("chevrons", true)
	_chain_preview = MeshInstance3D.new()
	_chain_preview.mesh = ImmediateMesh.new()
	var conduit := ShaderMaterial.new()
	conduit.shader = preload("res://scripts/matter/conduit.gdshader")
	conduit.set_shader_parameter("color", Color(1.0, 0.72, 0.38, 0.6))
	_chain_preview.material_override = conduit
	_chain_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node: Node3D in [_hologram, _marker, _arrow, _chain_preview]:
		node.visible = false
		get_parent().add_child.call_deferred(node)

func _ground_quad() -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	quad.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/reactive/ground_marker.gdshader")
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return quad

# --- Routine slots ------------------------------------------------------------------------------

func _load() -> void:
	slots = Model.DEFAULT_SLOTS.duplicate(true)
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) != OK: return
	var stored: Variant = save.get_value("routine", "slots", [])
	if stored is Array:
		for i: int in mini(stored.size(), slots.size()):
			if stored[i] is Dictionary and runner.valid(stored[i]): slots[i] = stored[i]
	else:
		# The single routine an earlier build saved becomes the first slot.
		var legacy: Variant = save.get_value("routine", "draft", null)
		if legacy is Dictionary and runner.valid(legacy): slots[0] = legacy
	current_slot = clampi(int(save.get_value("routine", "current", 0)), 0, slots.size() - 1)

func save() -> void:
	var file := ConfigFile.new()
	file.set_value("routine", "slots", slots)
	file.set_value("routine", "current", current_slot)
	if file.save(SAVE_PATH) != OK: _say("Rutinas listas · no se pudieron guardar en disco", false)

func current_draft() -> Dictionary:
	return slots[current_slot]

func select_slot(index: int) -> void:
	current_slot = wrapi(index, 0, slots.size())
	_hologram_key = ""
	_say("Rutina %02d · %s" % [current_slot + 1, Model.name_of(current_draft())], true)

func close_editor() -> void:
	panel.hide()
	save()
	_say("Rutina guardada · Q para desplegar", true)

func bind_reaction() -> void:
	var draft: Dictionary = current_draft()
	world.submit("react", selected, {"trigger": draft["trigger"], "action": draft["action"], "vector": direction.normalized() * 14.0})

## How charged the deploy is, 0..1, from the host's six-second spacing as this client saw it.
func charge() -> float:
	return clampf((Time.get_ticks_msec() * 0.001 - _deployed_at) / 6.0, 0.0, 1.0)

func local_player() -> Node3D:
	return world._player(multiplayer.get_unique_id())

func selected_record() -> Dictionary:
	return world.records.get(selected, {})

func message_age() -> float:
	return Time.get_ticks_msec() * 0.001 - _message_time

func translate(text: String) -> String:
	for source: String in REASONS: text = text.replace(source, REASONS[source])
	for token: String in TOKENS: text = text.replace(token, TOKENS[token])
	return text

func _say(text: String, ok: bool) -> void:
	message = text
	message_ok = ok
	_message_time = Time.get_ticks_msec() * 0.001

func _result(result: Dictionary) -> void:
	if result["ok"]:
		_say(translate(result.get("message", "Operación aplicada")), true)
		if result.get("message", "") == "Rutina iniciada":
			_deployed_at = Time.get_ticks_msec() * 0.001
			chain_tail = result["id"]
		if result.has("id"): selected = result["id"]
	else:
		_say("Interrumpido · " + translate(result.get("reason", "")), false)

func _toggle_periodic() -> void:
	var player: Character = local_player() as Character
	if player == null: return
	periodic = not periodic
	player.programming_block.code_block.text = ("heal()" if player is Support else "fire()") if periodic else ""
	_say("Programa periódico " + ("activo · " + player.programming_block.code_block.text if periodic else "detenido"), true)

# --- Per frame -----------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not visible or not _hologram.is_inside_tree():
		return
	var player: Node3D = local_player()
	if player == null: return
	var camera: Camera3D = arena.gameplay_camera
	var mouse: Vector2 = pointer_override if pointer_override is Vector2 else get_viewport().get_mouse_position()
	var point: Variant = Plane(Vector3.UP, 0.07).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if point != null and not panel.visible:
		cursor = point
		direction = cursor - player.global_position
		direction.y = 0.0
	if direction.length() < 0.1: direction = Vector3.FORWARD
	verdict = world.preview(multiplayer.get_unique_id(), "create", 0, {"point": cursor})
	_update_hologram()
	_update_marker()

func _update_hologram() -> void:
	var draft: Dictionary = current_draft()
	var projecting: bool = aiming and not panel.visible
	_hologram.visible = projecting
	_arrow.visible = projecting
	if not projecting:
		_chain_preview.visible = false
		return
	var state: Dictionary = Model.simulate(draft)["state"]
	var key: String = state["material"] + "/" + state["shape"]
	if key != _hologram_key:
		_hologram_key = key
		_hologram.scale = Vector3.ONE
		match key:
			"water/orb", "ice/orb":
				var orb := SphereMesh.new()
				orb.radius = Catalog.ORB_SIZE.x * 0.5
				orb.height = Catalog.ORB_SIZE.y
				_hologram.mesh = orb
			"ice/wall": _hologram.mesh = Meshes.crystal_wall(Vector3(4, 1.8, 0.2), 1)
			"ice/patch": _hologram.mesh = Meshes.crystal_floe(Catalog.PATCH_SIZE, 1)
			"steam/cloud":
				var sphere := SphereMesh.new()
				_hologram.mesh = sphere
				_hologram.scale = Catalog.STEAM_SIZE
			"water/wall":
				var curtain := BoxMesh.new()
				curtain.size = Vector3(4, 1.8, 0.2)
				_hologram.mesh = curtain
			_:
				var slab := BoxMesh.new()
				slab.size = Vector3(4, 0.12, 3)
				_hologram.mesh = slab
	var primed: bool = verdict.get("ok", false) and charge() >= 1.0
	var color: Color = Style.SODIUM if primed else Style.FAULT
	_hologram_material.set_shader_parameter("color", color)
	var raised: bool = "raise" in draft["steps"]
	var axis: Vector3 = direction.cross(Vector3.UP)
	var lift: float = 0.0
	if state["shape"] == "orb": lift = Catalog.HOLD_HEIGHT + Catalog.ORB_SIZE.y * 0.5
	elif key == "water/wall": lift = 0.9
	elif key == "steam/cloud": lift = Catalog.STEAM_SIZE.y * 0.5
	elif key == "water/patch": lift = 0.06
	_hologram.global_position = cursor + Vector3.UP * lift
	_hologram.rotation = Vector3(0, -atan2(axis.z, axis.x) if raised else 0.0, 0)
	# The saved vector: where a push reaction will throw what remains.
	var flat: Vector3 = direction.normalized()
	_arrow.global_position = cursor + flat * 3.2 + Vector3.UP * 0.05
	_arrow.rotation = Vector3(0, -atan2(flat.z, flat.x), 0)
	_arrow.scale = Vector3(3.0, 1, 1.0)
	_arrow_material.set_shader_parameter("extent", Vector2(3.0, 1.0))
	_arrow_material.set_shader_parameter("color", color)
	_arrow_material.set_shader_parameter("strength", 0.8 if draft["action"] == "push" else 0.35)
	_draw_chain_preview(draft)

func _draw_chain_preview(draft: Dictionary) -> void:
	var tail: Node3D = world.views.get(chain_tail)
	_chain_preview.visible = draft.get("chain", false) and tail != null and is_instance_valid(tail)
	if not _chain_preview.visible: return
	var a: Vector3 = tail.anchor()
	var b: Vector3 = cursor + Vector3.UP * 0.6
	var in_range: bool = tail.global_position.distance_to(cursor) <= Catalog.LINK_RANGE
	var material := _chain_preview.material_override as ShaderMaterial
	material.set_shader_parameter("color", Style.SODIUM if in_range else Style.FAULT)
	material.set_shader_parameter("length", a.distance_to(b))
	var camera := get_viewport().get_camera_3d()
	var geometry := _chain_preview.mesh as ImmediateMesh
	geometry.clear_surfaces()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var lift: float = 0.35 + a.distance_to(b) * 0.07
	for i: int in 25:
		var t: float = float(i) / 24.0
		var p: Vector3 = a.lerp(b, t) + Vector3.UP * sin(PI * t) * lift
		var tangent: Vector3 = (b - a).normalized() + Vector3.UP * cos(PI * t) * lift * PI / maxf(a.distance_to(b), 0.1)
		var side: Vector3 = tangent.cross(camera.global_position - p).normalized() * 0.04
		geometry.surface_set_uv(Vector2(t, 0.0))
		geometry.surface_add_vertex(p - side)
		geometry.surface_set_uv(Vector2(t, 1.0))
		geometry.surface_add_vertex(p + side)
	geometry.surface_end()

func _update_marker() -> void:
	var record: Dictionary = selected_record()
	_marker.visible = not record.is_empty() and not aiming
	if not _marker.visible: return
	var footprint := Vector2(record["size"].x + 1.3, maxf(record["size"].z, 0.4) + 1.7)
	_marker.global_position = record["position"] + Vector3.UP * 0.04
	_marker.rotation = Vector3(0, record["yaw"], 0)
	_marker.scale = Vector3(footprint.x, 1, footprint.y)
	_marker_material.set_shader_parameter("extent", footprint)
	_marker_material.set_shader_parameter("color", Style.SODIUM)

# --- Input ---------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if not event is InputEventKey or event.echo: return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is TextEdit or focus is LineEdit: return
	if event.keycode == KEY_E and event.pressed:
		if panel.visible: close_editor()
		else:
			aiming = false
			panel.show()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_TAB and event.pressed:
		select_slot(current_slot + (-1 if event.shift_pressed else 1))
		get_viewport().set_input_as_handled()
		return
	if panel.visible: return
	if event.keycode == KEY_Q:
		var was_aiming: bool = aiming
		aiming = event.pressed
		if not event.pressed and was_aiming: runner.submit(current_draft(), cursor, direction)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed: return
	match event.keycode:
		KEY_C:
			selected = _nearest_own(cursor, 6.0, 0)
		KEY_L:
			var other: int = _nearest_own(cursor, 6.0, selected)
			if selected == 0 or other == 0: _say("Conducto · selecciona una referencia y apunta a otra tuya", false)
			else: world.submit("link", selected, {"to": other})
		KEY_P: _toggle_periodic()
		KEY_R: world.submit("impact", selected)
		KEY_T: world.submit("command", selected, {"command": "detonate"})
		KEY_DELETE, KEY_BACKSPACE: world.submit("remove", selected)
		KEY_1: world.submit("raise", selected, {"vector": direction.cross(Vector3.UP)})
		KEY_2: world.submit("freeze", selected)
		KEY_3: world.submit("coat", selected)
		KEY_4: world.submit("push", selected, {"vector": direction.normalized() * 14})

func _nearest_own(point: Vector3, radius: float, exclude: int) -> int:
	var best: int = 0
	var distance: float = radius
	for record: Dictionary in world.records.values():
		if record["owner"] != multiplayer.get_unique_id() or record["id"] == exclude: continue
		var separation: float = record["position"].distance_to(point)
		if separation < distance:
			distance = separation
			best = record["id"]
	return best
