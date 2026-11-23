@tool
extends Node3D
## Blender-authored modules, exported through MCP. Deterministic local scenery only.
const FRONTAGES: Array[PackedScene] = [
	preload("res://scenes/environment/night_district/models/noodle_corner.glb"),
	preload("res://scenes/environment/night_district/models/circuit_repair.glb"),
	preload("res://scenes/environment/night_district/models/lumen_clinic.glb"),
	preload("res://scenes/environment/night_district/models/onda_arcade.glb"),
]
const PROPS: Array[PackedScene] = [
	preload("res://scenes/environment/night_district/models/bench.glb"),
	preload("res://scenes/environment/night_district/models/planter.glb"),
	preload("res://scenes/environment/night_district/models/terminal.glb"),
	preload("res://scenes/environment/night_district/models/service_van.glb"),
]
const MARKET := preload("res://scenes/environment/night_district/models/lonja.glb")
const SOUNDING_WORKS := preload("res://scenes/environment/night_district/models/sounding_works.glb")
const NET_LOFT := preload("res://scenes/environment/night_district/models/net_loft.glb")
const SALT_WILLOW := preload("res://scenes/environment/night_district/models/salt_willow.glb")
const NET_WINCH := preload("res://scenes/environment/night_district/models/net_winch.glb")
const LANDING := preload("res://scenes/environment/night_district/models/tidal_landing.glb")
const CONTACT_SHADOW: Shader = preload("res://scenes/environment/night_district/contact_shadow.gdshader")
const CYAN := Color("69bfc1")
const AMBER := Color("e9b375")
const METAL := Color("253540")
var _materials: Dictionary = {}

func _ready() -> void:
	_build()

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	_materials[key] = material
	return material

func _box(pos: Vector3, extent: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = extent
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = _material(color, glow)
	add_child(item)
	item.position = pos
	return item

func _solid(pos: Vector3, extent: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "ArchitectureCollision"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.position = pos

func _light(pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	add_child(light)
	light.position = pos

func _contact_shadow(pos: Vector3, width: float, depth: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width * 1.15, depth * 1.6)
	var shadow := MeshInstance3D.new()
	shadow.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = CONTACT_SHADOW
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	shadow.position = pos + Vector3(0, 0.018, -depth * 0.25)

func _prop(kind: int, pos: Vector3, width: float, depth: float, height: float) -> void:
	var model := PROPS[kind].instantiate() as Node3D
	add_child(model)
	model.position = pos
	_solid(pos + Vector3(0, height * 0.5, 0), Vector3(width, height, depth))
	_contact_shadow(pos, width, depth)
	if kind == 1 or kind == 2:
		_light(pos + Vector3(0, 0.7, 0.4), CYAN, 0.55, 3.0)

func _frontage(x: float, kind: int) -> void:
	var model := FRONTAGES[kind].instantiate() as Node3D
	add_child(model)
	model.position = Vector3(x, 0, -16.6)
	# Box matches the building shell; shop fixtures have separate ground collisions.
	_solid(Vector3(x, 4.0, -16.8), Vector3(8.8, 8.0, 5.4))
	if kind == 0:
		_solid(Vector3(x - 1.5, 0.78, -13.5), Vector3(4.95, 1.56, 1.15))
		for offset: float in [-3.25, -1.5, 0.25]:
			_solid(Vector3(x + offset, 0.4, -12.9), Vector3(0.58, 0.8, 0.58))
	elif kind == 3:
		var cabinets := preload("res://scenes/environment/night_district/models/ghost_wave.glb").instantiate() as Node3D
		model.add_child(cabinets)
		for offset: float in [-0.85, 0.7, 2.25]:
			_solid(Vector3(x + offset, 0.9, -13.5), Vector3(0.95, 1.8, 1.0))
	var glow: Color = [AMBER, CYAN, Color("9acbb3"), Color("b77bac")][kind]
	_light(Vector3(x, 2.2, -12.7), glow, 1.7, 5.5)

func _lamp(pos: Vector3) -> void:
	_box(pos + Vector3(0, 1.6, 0), Vector3(0.075, 3.2, 0.09), METAL)
	_box(pos + Vector3(-0.4, 3.2, 0), Vector3(0.9, 0.09, 0.18), Color("42535a"))
	_box(pos + Vector3(-0.4, 3.14, 0), Vector3(0.72, 0.035, 0.14), AMBER, 1.4)
	_solid(pos + Vector3(0, 1.6, 0), Vector3(0.09, 3.2, 0.1))
	_light(pos + Vector3(-0.4, 2.9, 0.2), AMBER, 1.2, 5.5)

func _cold_chain() -> void:
	var station := preload("res://scenes/environment/night_district/models/brine_station.glb").instantiate() as Node3D
	add_child(station)
	station.position = Vector3(5.7, 0, -8.5)
	station.rotation.y = -0.14
	_solid(station.position + Vector3.UP * 1.35, Vector3(4.0, 2.7, 1.64))
	_contact_shadow(station.position, 4.15, 1.6)
	_light(station.position + Vector3(-0.65, 1.55, 0.40), Color("72ffe2"), 1.3, 3.1)
	var ray := station.find_child("Specimen", true, false) as Node3D
	if ray and not Engine.is_editor_hint():
		var drift := ray.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var rest := ray.position
		drift.tween_property(ray, "position", rest + Vector3(0.09, 0.13, 0.0), 1.7)
		drift.tween_property(ray, "position", rest, 1.7)
	for location: Vector3 in [Vector3(-5.8, 0, -8.3), Vector3(16.3, 0, 9.0)]:
		var cargo := preload("res://scenes/environment/night_district/models/graft_freight.glb").instantiate() as Node3D
		add_child(cargo)
		cargo.position = location
		_solid(location + Vector3.UP * 0.65, Vector3(2.65, 1.3, 1.62))
		_contact_shadow(location, 2.65, 1.62)
	var conduit := preload("res://scenes/environment/night_district/models/tidal_conduit.glb").instantiate() as Node3D
	add_child(conduit)
	conduit.position = Vector3(-2.3, 0.0, 6.9)
	conduit.rotation.y = -0.08
	var deck := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(23.5, 14.0)
	var stencil := StandardMaterial3D.new()
	stencil.albedo_texture = preload("res://scenes/environment/night_district/berth_stencils.png")
	stencil.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stencil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material = stencil
	deck.mesh = plane
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(deck)
	deck.position = Vector3(1.8, 0.018, -1.6)


# Printed enamel, corrugated paint and paper share one district print sheet.
func _printed_panel(pos: Vector3, size: Vector2, crop: Rect2) -> void:
	var panel := Sprite3D.new()
	panel.texture = preload("res://scenes/environment/night_district/quayside_prints.png")
	panel.region_enabled = true
	panel.region_rect = crop
	panel.pixel_size = 1.0
	panel.scale = Vector3(size.x / crop.size.x, size.y / crop.size.y, 1.0)
	panel.shaded = true
	panel.transparent = false
	panel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	panel.position = pos


func _willow(pos: Vector3, facing: float, size: float) -> void:
	var tree := SALT_WILLOW.instantiate() as Node3D
	add_child(tree)
	tree.position = pos
	tree.rotation.y = facing
	tree.scale = Vector3.ONE * size
	_solid(pos + Vector3.UP * size * 0.37, Vector3(1.6, 0.74, 1.6) * size)
	_contact_shadow(pos, 1.88 * size, 1.6 * size)


func _bell_yard() -> void:
	var yard := preload("res://scenes/environment/night_district/models/bell_yard.glb").instantiate() as Node3D
	add_child(yard)
	yard.position = Vector3(31.5, 0, -16.6)
	_solid(yard.position + Vector3(0, 2.25, -0.35), Vector3(8.9, 4.50, 5.9))
	_solid(yard.position + Vector3(-1.6, 1.8, 3.62), Vector3(1.55, 3.6, 1.48))
	_solid(yard.position + Vector3(1.5, 1.25, 3.62), Vector3(1.96, 2.5, 1.95))
	_contact_shadow(yard.position + Vector3(1.5, 0, 3.62), 2.2, 1.95)
	_light(yard.position + Vector3(1.5, 2.8, 4.82), AMBER, 1.2, 4.0)
	if Engine.is_editor_hint():
		return
	var valve := AudioStreamPlayer3D.new()
	valve.stream = preload("res://scenes/environment/night_district/pressure_valve.wav")
	valve.volume_db = -13.0
	valve.unit_size = 9.0
	valve.max_distance = 52.0
	yard.add_child(valve)
	valve.position = Vector3(.45, 2.09, 3.89)
	var steam := Sprite3D.new()
	steam.texture = preload("res://materials/combat/pressure_release.png")
	steam.hframes = 9
	steam.pixel_size = .033
	steam.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	steam.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	steam.modulate = Color(.78, .87, .82, .63)
	steam.hide()
	valve.add_child(steam)
	steam.position = Vector3(-.72, .41, .10)
	var cycle := valve.create_tween().set_loops()
	cycle.tween_interval(3.8)
	cycle.tween_callback(valve.play)
	cycle.tween_interval(.12)
	cycle.tween_callback(steam.show)
	cycle.tween_method(func(frame: int): steam.frame = frame, 0, 8, .67)
	cycle.tween_callback(steam.hide)


func _build() -> void:
	_cold_chain()
	_bell_yard()
	# The auction hall occupies the double-width central berth.
	for bay in [[-32, 1], [-23, 0], [13.5, 3], [22.5, 2]]:
		_frontage(bay[0], bay[1])
	var market := MARKET.instantiate() as Node3D
	add_child(market)
	market.position.z = -15.95
	market.add_child(SOUNDING_WORKS.instantiate())
	_printed_panel(Vector3(1.0, 4.75, -13.80), Vector2(3.79, 2.85), Rect2(0, 208, 256, 160))
	_printed_panel(Vector3(24.95, 5.58, -13.41), Vector2(2.50, 3.86), Rect2(256, 208, 160, 248))
	var loft := NET_LOFT.instantiate() as Node3D
	add_child(loft)
	loft.position = Vector3(-14.0, 0, -16.6)
	_printed_panel(Vector3(-14, 3.20, -14.15), Vector2(8.69, 6.26), Rect2(416, 0, 416, 304))
	_printed_panel(Vector3(-13.37, 1.72, -13.79), Vector2(5.66, 3.13), Rect2(0, 0, 416, 208))
	_solid(Vector3(-14.0, 3.2, -16.77), Vector3(8.7, 6.4, 5.2))
	for upright: float in [-17.82, -11.21]:
		_solid(Vector3(upright, 2.8, -13.27), Vector3(0.20, 5.6, 0.20))
	_light(Vector3(-4.8, 3.2, -12.8), Color("4edac9"), 2.4, 6.4)
	_light(Vector3(2.6, 3.3, -12.9), Color("d2a66e"), 1.35, 5.0)
	_solid(Vector3(-1.8, 2.8, -17.4), Vector3(12.8, 5.6, 5.4))
	_solid(Vector3(6, 2.1, -16.6), Vector3(3.75, 4.2, 4.3))
	for stall: int in 4:
		var x := -6.6 + stall * 2.68
		_solid(Vector3(x, 0.54, -13.8), Vector3(2.48, 1.08, 1.05))
		_light(Vector3(x, 1.8, -13.35), Color("ffab69"), 2.1, 4.3)
	for post: float in [-7.94, -2.05, 3.94]:
		_solid(Vector3(post, 1.25, -12.61), Vector3(0.09, 2.5, 0.09))
	_willow(Vector3(-9.3, 0, -10.6), -0.25, 1.05)
	_prop(2, Vector3(10.1, 0, -12.7), 0.8, 0.65, 2.15)
	_willow(Vector3(19.1, 0, -12.0), 1.2, 0.84)
	_prop(3, Vector3(-22, 0, -5.6), 4.1, 1.8, 2.0)
	var rack := NET_WINCH.instantiate() as Node3D
	add_child(rack)
	rack.position = Vector3(-22, 0, -5.6)
	_printed_panel(Vector3(-23.05, 1.36, -4.70), Vector2(1.45, 0.77), Rect2(416, 304, 144, 72))
	_prop(3, Vector3(24, 0, 5.6), 4.1, 1.8, 2.0)
	for x: float in [-25, -15, 5, 25]:
		_lamp(Vector3(x + 3.8, 0, -11.7))
	_prop(0, Vector3(-24, 0, 15.4), 2.5, 0.8, 0.6)
	_willow(Vector3(-27.1, 0, 16.1), 2.7, 1.18)
	_prop(0, Vector3(7.8, 0, 16.5), 2.5, 0.8, 0.6)
	_prop(1, Vector3(27.5, 0, 15.9), 2.6, 0.85, 0.58)
	var landing := LANDING.instantiate() as Node3D
	add_child(landing)
	landing.position = Vector3(0.0, 0, 18.3)
	landing.rotation.y = PI
	if not Engine.is_editor_hint():
		var buoy := landing.find_child("SoundingFloat", true, false) as Node3D
		var swell := buoy.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var waterline := buoy.position.y
		swell.tween_property(buoy, "position:y", waterline + 0.085, 1.65)
		swell.parallel().tween_property(buoy, "rotation:z", 0.035, 1.65)
		swell.tween_property(buoy, "position:y", waterline, 1.95)
		swell.parallel().tween_property(buoy, "rotation:z", 0.0, 1.95)
	for z: float in [-9.6, 9.6]:
		_box(Vector3(0, 0.035, z), Vector3(80, 0.07, 0.16), Color("596367"))
		_box(Vector3(0, 0.045, z + signf(z) * 0.14), Vector3(80, 0.025, 0.035), CYAN, 0.2)
	for section: float in [-19.2, 19.2]:
		_box(Vector3(section, 0.38, 18.5), Vector3(35.6, 0.76, 0.24), METAL)
		_box(Vector3(section, 0.78, 18.5), Vector3(35.6, 0.06, 0.3), Color("647b80"))
	# Closed chain across the landing keeps the arena boundary visible.
	_box(Vector3(0, 0.71, 18.5), Vector3(2.82, 0.10, 0.10), Color("bb9255"))
	_solid(Vector3(0, 0.38, 18.5), Vector3(74, 0.76, 0.24))
	for x: float in [-36, 36]:
		_box(Vector3(x, 0.5, 1), Vector3(0.28, 1, 35), METAL)
		_solid(Vector3(x, 0.5, 1), Vector3(0.28, 1, 35))
	for x: float in [-28, -20, -12, -4, 4, 12, 20, 28]:
		_box(Vector3(x, 0.048, -9.1), Vector3(1.1, 0.018, 0.34), Color("16242c"))
		for i: int in 8:
			_box(Vector3(x - 0.48 + i * 0.135, 0.061, -9.1), Vector3(0.035, 0.015, 0.3), Color("46535a"))
