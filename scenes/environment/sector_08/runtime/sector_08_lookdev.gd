## Sector 08, the first diorama arena. Everything level-agnostic -- the approved framing, the
## follow rig, the world filter -- lives in DioramaArena; what stays here is what makes this
## district itself: its lights, its material calibration, its atmosphere anchors and its
## reactive access display.
##
## The same scene serves the game and the art pass. `lookdev_tools` gates the debug overlay, the
## static stand-in figure and the lateral sweep, so the arena the player sees is literally the
## one the look was approved on, not a copy that can drift from it.
class_name Sector08LookDev
extends DioramaArena

## Optional art comparison and bounded extension; zero/false preserve the original yard.
@export var restrained_presentation: bool = false
@export_range(0.0, 12.0, 1.0) var lateral_extension: float = 0.0
@export_range(0.0, 24.0, 1.0) var south_extension: float = 0.0

var parallax: Node
var access_display: Node3D
var cinematic_dust: Node3D
var player: CharacterBody3D
var play_mode: bool = false

var _art_surfaces: Array[Dictionary] = []
var _art_materials_prepared: bool = false
var _art_light_base_energy: Dictionary = {}

const CHARACTER_POSITIONS: Array[Vector3] = [
	Vector3(4.0, 0.05, 4.0),
	Vector3(0.0, 0.05, -2.0),
	Vector3(-4.0, 0.05, -8.0),
]

@onready var sector_runtime: Sector08Runtime = $Sector08Runtime
@onready var controller: ReactiveDistrictController = $ReactiveDistrictController
@onready var test_character: Node3D = $TestCharacter
@onready var character_sprite: Sprite3D = $TestCharacter/CharacterSprite
@onready var contact_shadow: MeshInstance3D = $TestCharacter/ContactShadow
@onready var key_light: DirectionalLight3D = $LookDevHelpers/KeyLight
@onready var fill_light: DirectionalLight3D = $LookDevHelpers/FillLight
@onready var motivated_lights: Node3D = $LookDevHelpers/MotivatedLights
@onready var spine_cyan_light: OmniLight3D = $LookDevHelpers/MotivatedLights/SpineCyan
@onready var industrial_amber_west: OmniLight3D = $LookDevHelpers/MotivatedLights/IndustrialAmberWest
@onready var industrial_amber_center: OmniLight3D = $LookDevHelpers/MotivatedLights/IndustrialAmberCenter
@onready var corruption_magenta_light: OmniLight3D = $LookDevHelpers/MotivatedLights/CorruptionMagenta
@onready var debug_layer: CanvasLayer = $DebugControls

var _depth_index: int = 1
var _status_label: Label
var _baseline_button: Button
var _visual_button: Button
var _auto_button: Button
var _calibrated_look: bool = true
var _slider_rows: Dictionary = {}


func _enter_tree() -> void:
	$Sector08Runtime.lateral_extension = lateral_extension
	$Sector08Runtime.south_extension = south_extension
	if (lateral_extension > 0.0 or south_extension > 0.0):
		$Sector08Runtime.billboard_enabled = false
	# More world travel, with the same perspective and sprite scale.
	if (lateral_extension > 0.0 or south_extension > 0.0):
		follow_limit = Vector2(40.0, 24.0)


func _ready() -> void:
	if south_extension > 0.0:
		var court := preload("res://scenes/environment/sector_08/modules/south_rain_court.tscn").instantiate()
		add_child(court)
		court.position = Vector3(0.0, 0.0, 14.0 + south_extension * 0.5)
		var containment := preload("res://scenes/environment/sector_08/modules/containment_court.gd").new()
		containment.name = "ContainmentCourt"
		add_child(containment)
	_initialise_diorama()
	_configure_environment()
	_configure_character()
	controller.set_materials(sector_runtime.get_reactive_materials())
	if lookdev_tools:
		_build_debug_ui()
	_set_calibrated_look(true)
	controller.reactive_state_changed.connect(_sync_art_lights)
	_set_character_depth(1)
	build_presentation()
	_apply_readable_vegetation()
	# Sector08Runtime owns the redistribution; it only needs the framing to judge it from.
	sector_runtime.composition_camera = gameplay_camera
	sector_runtime.composition_framing_distance = framing_distance
	parallax = preload("res://scenes/environment/sector_08/runtime/sector_08_parallax.gd").new()
	add_child(parallax)
	parallax.setup(self)
	access_display = preload("res://scenes/environment/sector_08/runtime/sector_08_access_display.gd").new()
	add_child(access_display)
	access_display.setup(self)
	cinematic_dust = preload("res://scenes/environment/sector_08/runtime/sector_08_cinematic_dust.gd").new()
	add_child(cinematic_dust)
	cinematic_dust.setup(self)
	build_camera_rig()
	camera_rig.ground_follow = (lateral_extension > 0.0 or south_extension > 0.0)
	# The rig folds the lookdev's lateral sweep in rather than fighting it for the transform.
	camera_rig.extra_offset = func() -> float: return parallax.offset
	parallax.rig = camera_rig
	activate_camera()
	if not lookdev_tools:
		# In game the arena has no stand-in figure and no debug overlay; the real players are
		# spawned by the host scene, which then calls follow().
		test_character.visible = false
		debug_layer.visible = false
		# The demo loop is a lookdev affordance: it drives waves and blackouts off a timer to show
		# the reactive district to a viewer. Left on in game it darkened the yard mid-fight on a
		# schedule nothing in the match could see coming. Gameplay will drive these states.
		controller.auto_demo = false
		call_deferred("_add_yard_polish")
	print("Sector08 arena ready. Keys: 1/2/3 depth, Space wave, X blackout/recovery, B baseline, A auto-demo.")


func _process(_delta: float) -> void:
	_update_status()


func _add_yard_polish() -> void:
	var polish := preload("res://scenes/environment/sector_08/runtime/yard_polish.gd").new()
	polish.name = "YardPolish"
	add_child(polish)
	polish.setup(self)
	if restrained_presentation:
		polish.apply_restrained_presentation(self)
	var ground := preload("res://scenes/environment/sector_08/runtime/ground_surface_state.gd").new()
	ground.name = "GroundSurfaceState"
	add_child(ground)
	ground.setup(polish.water_materials, polish.rain_emitters)


func _unhandled_input(event: InputEvent) -> void:
	if not lookdev_tools:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key_event: InputEventKey = event as InputEventKey
		match key_event.keycode:
			KEY_P:
				set_play_mode(not play_mode)
			KEY_F11:
				pixel_presentation.set_diorama(not pixel_presentation.diorama_enabled)
			KEY_F6:
				pixel_presentation.set_mode(0)
			KEY_F7:
				pixel_presentation.set_mode(1)
			KEY_F9:
				pixel_presentation.set_dither(not pixel_presentation.dither_enabled)
			KEY_F10:
				pixel_presentation.set_quantization(not pixel_presentation.quantization_enabled)
			KEY_F8:
				pixel_presentation.set_mode(2)
			KEY_1:
				_set_character_depth(0)
			KEY_2:
				_set_character_depth(1)
			KEY_3:
				_set_character_depth(2)
			KEY_SPACE:
				controller.trigger_wave()
			KEY_X:
				if controller.blackout_amount > 0.5:
					controller.recover_power()
				else:
					controller.trigger_blackout()
			KEY_B:
				_toggle_baseline()
			KEY_V:
				_set_calibrated_look(not _calibrated_look)
			KEY_A:
				controller.auto_demo = not controller.auto_demo
			KEY_H:
				debug_layer.visible = not debug_layer.visible
			KEY_F:
				_capture_comparison()
			KEY_G:
				_capture_upper_center_diagnostic()
			KEY_J:
				_capture_upper_center_pair()
			KEY_L:
				_capture_value_visualization()


func _capture_value_visualization() -> void:
	await RenderingServer.frame_post_draw
	var directory: String = "res://scenes/environment/sector_08/runtime/comparisons"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var image: Image = get_viewport().get_texture().get_image()
	var size: Vector2i = image.get_size()
	for y: int in size.y:
		for x: int in size.x:
			var source: Color = image.get_pixel(x, y)
			var luminance: float = source.r * 0.2126 + source.g * 0.7152 + source.b * 0.0722
			image.set_pixel(x, y, Color(luminance, luminance, luminance, source.a))
	var error: Error = image.save_png("%s/cohesion_value.png" % directory)
	print("Cohesion value visualization: %s" % error_string(error))


func _capture_upper_center_pair() -> void:
	var previous_auto_demo: bool = controller.auto_demo
	controller.auto_demo = false
	sector_runtime.set_upper_center_repair_enabled(false)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var directory: String = "res://scenes/environment/sector_08/runtime/comparisons"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var before_image: Image = get_viewport().get_texture().get_image()
	var before_error: Error = before_image.save_png("%s/upper_center_before.png" % directory)
	sector_runtime.set_upper_center_repair_enabled(true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var after_image: Image = get_viewport().get_texture().get_image()
	var after_error: Error = after_image.save_png("%s/upper_center_after.png" % directory)
	controller.auto_demo = previous_auto_demo
	print("Upper-center matched pair: before=%s after=%s" % [error_string(before_error), error_string(after_error)])


func _capture_upper_center_diagnostic() -> void:
	var target_names: Array[StringName] = [&"Skyline_Block_019", &"Skyline_Block_037"]
	var highlighted: Array[Dictionary] = []
	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(1.0, 0.015, 0.28)
	marker_material.emission_enabled = true
	marker_material.emission = Color(1.0, 0.015, 0.28)
	marker_material.emission_energy_multiplier = 1.8
	for candidate: Node in sector_runtime.imported_environment.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = candidate as MeshInstance3D
		if mesh_instance != null and mesh_instance.name in target_names:
			highlighted.append({"mesh": mesh_instance, "material": mesh_instance.material_override})
			mesh_instance.material_override = marker_material
	await RenderingServer.frame_post_draw
	var directory: String = "res://scenes/environment/sector_08/runtime/comparisons"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png("%s/upper_center_identified_meshes.png" % directory)
	for entry: Dictionary in highlighted:
		var mesh_instance: MeshInstance3D = entry["mesh"] as MeshInstance3D
		mesh_instance.material_override = entry["material"] as Material
	print("Upper-center diagnostic highlighted %d meshes: %s" % [highlighted.size(), error_string(error)])


func _capture_comparison() -> void:
	var directory: String = "res://scenes/environment/sector_08/runtime/comparisons"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var mode_name: String = "raw_import" if not sector_runtime.is_enhanced() else ("calibrated" if _calibrated_look else "enhanced_baseline")
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png("%s/%s.png" % [directory, mode_name])
	print("Sector08 comparison capture %s: %s" % [mode_name, error_string(error)])


func _configure_environment() -> void:
	_apply_art_materials(false)
	var environment: Environment = runtime_environment.environment
	if environment == null:
		environment = Environment.new()
		runtime_environment.environment = environment
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.003, 0.008, 0.018)
	sky_material.sky_horizon_color = Color(0.035, 0.075, 0.11)
	sky_material.ground_horizon_color = Color(0.018, 0.038, 0.052)
	sky_material.ground_bottom_color = Color(0.002, 0.004, 0.008)
	sky_material.sky_curve = 0.12
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.background_energy_multiplier = 0.22
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.09, 0.13, 0.18)
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.08
	environment.glow_enabled = true
	environment.glow_intensity = 0.58
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 1.25
	environment.glow_hdr_scale = 1.35
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.025, 0.07, 0.095)
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0038
	environment.fog_height = 1.5
	environment.fog_height_density = 0.035
	environment.fog_aerial_perspective = 0.28
	environment.ssao_enabled = true
	environment.ssao_radius = 1.8
	environment.ssao_intensity = 1.05
	environment.ssao_power = 1.35
	environment.ssao_detail = 0.55
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.012
	environment.volumetric_fog_albedo = Color(0.25, 0.38, 0.46)
	environment.volumetric_fog_emission = Color(0.006, 0.016, 0.025)
	environment.volumetric_fog_emission_energy = 0.4
	environment.volumetric_fog_length = 130.0
	environment.volumetric_fog_detail_spread = 2.2
	environment.volumetric_fog_ambient_inject = 0.18
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.96
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.92
	key_light.light_color = Color(0.62, 0.72, 0.82)
	key_light.light_energy = 0.52
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 120.0
	key_light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	fill_light.light_color = Color(0.48, 0.18, 0.34)
	fill_light.light_energy = 0.16
	spine_cyan_light.light_energy = 1.35
	spine_cyan_light.omni_range = 14.0
	industrial_amber_west.light_energy = 1.4
	industrial_amber_west.omni_range = 10.5
	industrial_amber_center.light_energy = 1.2
	industrial_amber_center.omni_range = 9.0
	corruption_magenta_light.light_energy = 0.42
	corruption_magenta_light.omni_range = 8.0
	if is_instance_valid(motivated_lights):
		motivated_lights.visible = false


func _configure_calibrated_environment() -> void:
	var environment: Environment = runtime_environment.environment
	if environment == null:
		environment = Environment.new()
		runtime_environment.environment = environment
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.002, 0.004, 0.009)
	sky_material.sky_horizon_color = Color(0.022, 0.03, 0.04)
	sky_material.ground_horizon_color = Color(0.016, 0.019, 0.022)
	sky_material.ground_bottom_color = Color(0.001, 0.002, 0.004)
	sky_material.sky_curve = 0.16
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.background_energy_multiplier = 0.18
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.12, 0.145, 0.17)
	environment.ambient_light_energy = 0.54
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.32
	environment.glow_bloom = 0.006
	environment.glow_hdr_threshold = 1.48
	environment.glow_hdr_scale = 1.08
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.024, 0.032, 0.04)
	environment.fog_light_energy = 0.42
	environment.fog_density = 0.0027
	environment.fog_height = 0.5
	environment.fog_height_density = 0.016
	environment.fog_aerial_perspective = 0.2
	environment.ssao_enabled = true
	environment.ssao_radius = 1.05
	environment.ssao_intensity = 0.4
	environment.ssao_power = 1.0
	environment.ssao_detail = 0.38
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0052
	environment.volumetric_fog_albedo = Color(0.32, 0.35, 0.38)
	environment.volumetric_fog_emission = Color(0.003, 0.004, 0.006)
	environment.volumetric_fog_emission_energy = 0.22
	environment.volumetric_fog_length = 145.0
	environment.volumetric_fog_detail_spread = 2.5
	environment.volumetric_fog_ambient_inject = 0.15
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.02
	environment.adjustment_saturation = 0.94
	key_light.light_color = Color(0.74, 0.79, 0.86)
	key_light.light_energy = 0.68
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 120.0
	key_light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	fill_light.light_color = Color(0.2, 0.29, 0.42)
	fill_light.light_energy = 0.1
	spine_cyan_light.light_energy = 0.95
	spine_cyan_light.light_specular = 0.42
	spine_cyan_light.light_volumetric_fog_energy = 0.22
	spine_cyan_light.omni_range = 18.0
	industrial_amber_west.light_energy = 0.9
	industrial_amber_west.light_specular = 0.34
	industrial_amber_west.omni_range = 13.0
	industrial_amber_center.light_energy = 0.78
	industrial_amber_center.light_specular = 0.32
	industrial_amber_center.omni_range = 11.5
	corruption_magenta_light.light_energy = 0.26
	corruption_magenta_light.light_specular = 0.28
	corruption_magenta_light.omni_range = 9.0
	motivated_lights.visible = true
	if sector_runtime.authored_pbr_mesh_count > 0:
		_configure_authored_pbr_lighting()


func _set_calibrated_look(enabled: bool) -> void:
	_calibrated_look = enabled
	sector_runtime.set_calibrated(enabled)
	if not sector_runtime.is_enhanced():
		_configure_environment()
		return
	if enabled:
		_configure_calibrated_environment()
	else:
		_configure_environment()


func _configure_character() -> void:
	character_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	character_sprite.shaded = false
	character_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	character_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	character_sprite.pixel_size = 0.014
	_ground_character_frame(2.2)
	contact_shadow.scale = Vector3(1.4, 1.0, 1.25)
	character_sprite.render_priority = 2
	contact_shadow.position.y = 0.035


func _set_character_depth(index: int) -> void:
	_depth_index = clampi(index, 0, CHARACTER_POSITIONS.size() - 1)
	test_character.position = CHARACTER_POSITIONS[_depth_index]


func _build_debug_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ReactivePanel"
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(390.0, 0.0)
	debug_layer.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 14)
	margin.add_theme_constant_override(&"margin_right", 14)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 5)
	margin.add_child(content)
	var title: Label = Label.new()
	title.text = "SECTOR 08 · RUNTIME LOOK-DEV"
	title.add_theme_font_size_override(&"font_size", 18)
	title.add_theme_color_override(&"font_color", Color(0.3, 0.88, 1.0))
	content.add_child(title)
	_status_label = Label.new()
	_status_label.text = "Initializing imported district…"
	content.add_child(_status_label)
	var signal_names: Array[String] = ["network_load", "alert_level", "corruption", "power", "electric_activity", "wave_intensity", "wave_dir_x", "wave_dir_y", "wave_speed", "blackout_amount"]
	for signal_name: String in signal_names:
		_add_slider_row(content, signal_name)
	var preset_row: HBoxContainer = HBoxContainer.new()
	content.add_child(preset_row)
	_add_button(preset_row, "NORMAL", controller.preset_normal)
	_add_button(preset_row, "ALERT", controller.preset_alert)
	_add_button(preset_row, "OVERLOAD", controller.preset_network_overload)
	_add_button(preset_row, "CORRUPT", controller.preset_corrupted)
	var effect_row: HBoxContainer = HBoxContainer.new()
	content.add_child(effect_row)
	_add_button(effect_row, "WAVE", controller.trigger_wave)
	_add_button(effect_row, "BLACKOUT", controller.trigger_blackout)
	_add_button(effect_row, "RECOVER", controller.recover_power)
	_auto_button = _add_button(effect_row, "AUTO", _toggle_auto)
	var view_row: HBoxContainer = HBoxContainer.new()
	content.add_child(view_row)
	_add_button(view_row, "NEAR [1]", func() -> void: _set_character_depth(0))
	_add_button(view_row, "CENTER [2]", func() -> void: _set_character_depth(1))
	_add_button(view_row, "FAR [3]", func() -> void: _set_character_depth(2))
	_baseline_button = _add_button(view_row, "BASELINE [B]", _toggle_baseline)
	var pixel_row := HBoxContainer.new()
	content.add_child(pixel_row)
	_add_button(pixel_row, "CLEAN [F6]", func() -> void: pixel_presentation.set_mode(0))
	_add_button(pixel_row, "SOFT [F7]", func() -> void: pixel_presentation.set_mode(1))
	_add_button(pixel_row, "MEDIUM [F8]", func() -> void: pixel_presentation.set_mode(2))
	_add_button(pixel_row, "DIORAMA [F11]", func() -> void: pixel_presentation.set_diorama(not pixel_presentation.diorama_enabled))
	var compare_row: HBoxContainer = HBoxContainer.new()
	content.add_child(compare_row)
	_visual_button = _add_button(compare_row, "CALIBRATED [V]", func() -> void: _set_calibrated_look(not _calibrated_look))
	var compare_label: Label = Label.new()
	compare_label.text = "A: enhanced baseline · B: calibrated · C: raw import"
	compare_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compare_row.add_child(compare_label)
	var help: Label = Label.new()
	help.text = "Auto: wave → blackout → recovery (18 s) · H hides UI"
	help.modulate = Color(0.64, 0.72, 0.78)
	content.add_child(help)


func _add_slider_row(parent: VBoxContainer, signal_name: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = signal_name
	label.custom_minimum_size.x = 142.0
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.custom_minimum_size.x = 170.0
	slider.min_value = -1.0 if signal_name in ["wave_dir_x", "wave_dir_y"] else (0.01 if signal_name == "wave_speed" else 0.0)
	slider.max_value = 1.0
	slider.step = 0.01
	if signal_name == "wave_speed":
		slider.value = controller.wave_speed
	elif signal_name == "wave_dir_x":
		slider.value = controller.wave_direction.x
	elif signal_name == "wave_dir_y":
		slider.value = controller.wave_direction.y
	else:
		slider.value = float(controller.get_values().get(signal_name, 0.0))
	slider.value_changed.connect(func(value: float) -> void:
		if signal_name == "wave_speed":
			controller.set_wave_speed(value)
			controller.auto_demo = false
		elif signal_name == "wave_dir_x":
			controller.set_wave_direction(Vector2(value, controller.wave_direction.y))
			controller.auto_demo = false
		elif signal_name == "wave_dir_y":
			controller.set_wave_direction(Vector2(controller.wave_direction.x, value))
			controller.auto_demo = false
		else:
			controller.set_signal_target(signal_name, value)
	)
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.custom_minimum_size.x = 48.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_slider_rows[signal_name] = {"slider": slider, "value": value_label}


func _add_button(parent: HBoxContainer, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _toggle_baseline() -> void:
	sector_runtime.set_enhanced(not sector_runtime.is_enhanced())
	if sector_runtime.is_enhanced():
		_set_calibrated_look(_calibrated_look)
	else:
		_configure_environment()


func _toggle_auto() -> void:
	controller.auto_demo = not controller.auto_demo


func _update_status() -> void:
	if _status_label == null:
		return
	var values: Dictionary = controller.get_values()
	var look_name: String = "RAW IMPORT" if not sector_runtime.is_enhanced() else ("CALIBRATED" if _calibrated_look else "ENHANCED BASELINE")
	_status_label.text = "%s · %s depth · %.1f s" % [look_name, ["NEAR", "CENTER", "FAR"][_depth_index], controller.effect_time]
	if pixel_presentation != null:
		_status_label.text += "\n%s [F6–F8] · Diorama:%s [F11]" % [pixel_presentation.LABELS[pixel_presentation.mode], "ON" if pixel_presentation.diorama_enabled else "OFF"]
		_status_label.text += " · Dither:%s [F9] · Quant:%s [F10]" % ["ON" if pixel_presentation.dither_enabled else "OFF", "ON" if pixel_presentation.quantization_enabled else "OFF"]
	for signal_name_value: Variant in _slider_rows.keys():
		var signal_name: String = str(signal_name_value)
		var row: Dictionary = _slider_rows[signal_name]
		var slider: HSlider = row["slider"] as HSlider
		var value_label: Label = row["value"] as Label
		var current_value: float
		if signal_name == "wave_speed":
			current_value = controller.wave_speed
		elif signal_name == "wave_dir_x":
			current_value = controller.wave_direction.x
		elif signal_name == "wave_dir_y":
			current_value = controller.wave_direction.y
		else:
			current_value = float(values.get(signal_name, 0.0))
		if not slider.has_focus():
			slider.set_value_no_signal(current_value)
		value_label.text = "%.2f" % current_value
	_baseline_button.text = "ENHANCED [B]" if not sector_runtime.is_enhanced() else "RAW [B]"
	_visual_button.text = "BASELINE A [V]" if _calibrated_look else "CALIBRATED B [V]"
	_auto_button.button_pressed = controller.auto_demo


## Authored standing positions in the yard, reused as player spawns in game.
func get_spawn_positions() -> Array[Vector3]:
	return [Vector3(-3.0, 0.4, -2.0), Vector3(3.0, 0.4, -2.0), Vector3(0.0, 0.4, -5.2)]


## Play mode swaps the static lookdev figure for a walkable one and lets the camera follow it.
## P30 is untouched: the rig only translates, exactly as the lateral parallax does.
func set_play_mode(enabled: bool) -> void:
	play_mode = enabled
	if enabled and player == null:
		player = preload("res://scenes/environment/sector_08/runtime/sector_08_player.gd").new()
		player.name = "Sector08Player"
		add_child(player)
		player.setup(gameplay_camera, character_sprite)
		# Drop in from just above the slab: a capsule that spawns already intersecting the
		# floor box settles inside it instead of on top.
		player.global_position = CHARACTER_POSITIONS[1] + Vector3.UP * 1.2
		pixel_presentation.register_sprite(player.sprite)
		camera_rig.set_target(player)
	if player != null:
		player.visible = enabled
		player.set_physics_process(enabled)
	test_character.visible = not enabled
	camera_rig.set_enabled(enabled)
	if not enabled:
		parallax.set_offset(parallax.offset)


func _configure_authored_pbr_lighting() -> void:
	# P30 art pass: quiet global fill, cyan landmark and localized warm circulation.
	# The approved export, camera and reactive shader bindings remain authoritative.
	var environment: Environment = runtime_environment.environment
	# A 0.95 uniform ambient was lighting every surface the same regardless of orientation, which
	# is what made the scene read flat: the planes all landed within 0.12 luma of each other.
	# Drop the fill and put the energy back into directional and motivated light instead, so
	# faces turned away from a source actually go dark and the depth planes separate.
	environment.ambient_light_color = Color(0.20, 0.29, 0.40)
	environment.ambient_light_energy = 0.38
	key_light.light_color = Color(0.62, 0.74, 0.95)
	key_light.light_energy = 2.05
	key_light.light_angular_distance = 1.6
	key_light.light_specular = 0.6
	# Cool counter-fill from the opposite side keeps shadow faces readable without lifting
	# everything the way ambient did, and puts a cold edge against the warm sodium pools.
	fill_light.light_color = Color(0.30, 0.45, 0.72)
	fill_light.light_energy = 0.55
	# Screen-space bounce gives the sodium and cyan pools some local colour spill. Contact
	# occlusion is strengthened so props sit on the ground instead of floating on flat fill.
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.85
	environment.ssil_radius = 3.2
	environment.ssao_intensity = 2.6
	environment.ssao_power = 2.2
	environment.ssao_light_affect = 0.15
	# Haze is the other half of plane separation: distance should cost contrast, not just detail.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.10, 0.16, 0.24)
	environment.fog_density = 0.0042
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.95
	environment.glow_strength = 1.15
	environment.glow_bloom = 0.25
	environment.glow_hdr_threshold = 0.72
	environment.glow_hdr_scale = 2.4
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	spine_cyan_light.light_color = Color(0.24, 0.78, 0.95).linear_to_srgb()
	industrial_amber_west.light_color = Color(1.0, 0.62, 0.28).linear_to_srgb()
	industrial_amber_center.light_color = Color(1.0, 0.60, 0.26).linear_to_srgb()
	spine_cyan_light.light_energy = 22.0
	spine_cyan_light.omni_attenuation = 0.7
	# Left at the approved 0.42. Identified, not changed: this omni's specular on the wet slab at
	# about (-9.7, 0, -5.3) is the saturated white blob on the pavement. It is a 22-energy point
	# source standing in for a volumetric landmark, and the slab is authored PBR whose own
	# roughness map reads as wet, so the glint clips and the glow spreads it into a ball. Zeroing
	# this one light's specular takes that region's peak from 255 to 77 -- the same as zeroing
	# every light in the scene -- and a sweep found no non-zero value that survives: 0.02 still
	# clips. So the only lever is 0.0, and that is an art call on approved lighting, not a fix.
	industrial_amber_west.light_energy = 5.0
	industrial_amber_center.light_energy = 12.0
	industrial_amber_center.omni_range = 17.0
	industrial_amber_center.omni_attenuation = 0.7
	# The district's third colour was unreachable rather than dim: a 9 m sphere floating 10.6 m up
	# at the far edge, which unprojects to the very top row of the frame and never touches the
	# ground -- raising its energy to six moved the image by nothing. Brought down to bay height
	# and given the reach to spill onto the slabs, so magenta is a colour the yard actually has.
	corruption_magenta_light.light_energy = 4.2
	corruption_magenta_light.omni_range = 19.0
	corruption_magenta_light.omni_attenuation = 1.3
	# Coordinates come from Blender's actual fixture anchors (x, z, -y in Godot).
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/environment/sector_08/arena_manifest.json")) as Dictionary
	var fixtures: Dictionary = {"spine_node_0": spine_cyan_light, "streetlight_0": industrial_amber_west, "compound_lamp": industrial_amber_center, "break_bay_corrupt": corruption_magenta_light}
	for anchor: Dictionary in manifest.get("lights", []):
		var anchor_name: String = str(anchor.get("name", ""))
		if fixtures.has(anchor_name):
			var position_values: Array = anchor["position"]
			var light: OmniLight3D = fixtures[anchor_name] as OmniLight3D
			light.global_position = Vector3(float(position_values[0]), float(position_values[2]), -float(position_values[1]))
	# Keep the corruption fixture's authored plan position, drop it to where a break bay would
	# actually leak light from.
	corruption_magenta_light.global_position.y = 3.4

	# Central pool at the existing streetlight, anchored in the authored manifest.
	var yard_light := motivated_lights.get_node_or_null("YardStreetlight") as SpotLight3D
	if yard_light == null:
		yard_light = SpotLight3D.new()
		yard_light.name = "YardStreetlight"
		motivated_lights.add_child(yard_light)
	yard_light.light_color = Color(1.0, 0.76, 0.48)
	# Turning shadows on cost the gameplay plane light, because the gantry and cable tray now
	# occlude the lamp. Pay that back with intensity, not with ambient: the point is that the
	# character stands in a motivated pool, not that everything is lifted.
	yard_light.light_energy = 38.0
	yard_light.light_specular = 0.55
	yard_light.spot_range = 14.0
	# Was a 48-degree cone with no shadows and 2.5 fog energy: a wide unshadowed volume that
	# poured straight through the fence, the gantry and the character and read as a haze wash
	# with no visible source. Narrowed to a real luminaire cone and given shadows, so the shaft
	# is occluded by the geometry it passes and actually looks like it comes from the lamp.
	yard_light.spot_angle = 38.0
	yard_light.spot_angle_attenuation = 1.1
	yard_light.spot_attenuation = 0.8
	yard_light.shadow_enabled = true
	yard_light.shadow_bias = 0.02
	yard_light.shadow_normal_bias = 0.03
	for anchor: Dictionary in manifest.get("lights", []):
		if anchor.get("name") == "streetlight_1":
			var p: Array = anchor["position"]
			yard_light.global_position = Vector3(p[0], p[2], -p[1])
	# Streetlight_Lamp_001 is a real lamp head at this anchor, but the light was aimed at the
	# yard centre 13 m away: only 26 degrees below horizontal, which is a floodlight, not a
	# streetlight. The pool came out as a long stretched smear offset from the visible fixture
	# and read as a stain on the pavement rather than as light from that lamp. Aim it down, the
	# way the fixture actually points, so the pool sits under its own source.
	yard_light.look_at(yard_light.global_position + Vector3(-0.28, -1.0, -0.34), Vector3.UP)

	# Not repaired here: the `east_shed` mass holds the right edge of the frame at 0.29 of the
	# luminance of the authored architecture beside it, and reads as a featureless black shape.
	# Its material is authored PBR, so it is deliberately outside the calibrated shading path and
	# the `cs_architecture_fill` that keeps the skyline masses off black never reaches it. A dim
	# omni in the lot behind it was tried and measured: at 45 energy it moved that patch by 0.01,
	# because the faces in frame point away from anywhere a motivated source could stand. Fixing
	# it means either extending the calibrated fill to authored-PBR backdrop masses or re-aiming
	# a directional, both of which change the approved lighting rather than patch one building.
	_art_light_base_energy = {
		spine_cyan_light: 22.0,
		industrial_amber_west: 5.0,
		industrial_amber_center: 12.0,
		corruption_magenta_light: 4.2,
		yard_light: 38.0,
	}
	_sync_art_lights(controller.get_values())
	_apply_art_materials(true)


func _sync_art_lights(values: Dictionary) -> void:
	if not _calibrated_look or not sector_runtime.is_enhanced():
		return
	# Follow the existing controller transition; keep ambient/moonlight as emergency visibility.
	var supply: float = clampf(float(values.get("power", 0.92)) / 0.92, 0.0, 1.1)
	supply *= 1.0 - 0.9 * clampf(float(values.get("blackout_amount", 0.0)), 0.0, 1.0)
	for light: Light3D in _art_light_base_energy:
		light.light_energy = float(_art_light_base_energy[light]) * supply
	# Magenta is the corruption state's colour, so it should answer to corruption rather than sit
	# at one level forever. It keeps a floor, so the hue is present in the palette at rest, and
	# surges when the district is actually corrupted.
	var corruption: float = clampf(float(values.get("corruption", 0.0)), 0.0, 1.0)
	corruption_magenta_light.light_energy = float(_art_light_base_energy[corruption_magenta_light]) * supply * (0.6 + 1.9 * corruption)
	if sector_runtime.particles != null:
		sector_runtime.particles.sync_power(supply)
	if sector_runtime.billboard != null:
		sector_runtime.billboard.sync_state(values)


func _apply_art_materials(enabled: bool) -> void:
	# Exact audited nodes/materials only. Shared variants retain the authored atlas and UV settings.
	if enabled and not _art_materials_prepared:
		_art_materials_prepared = true
		var variants: Dictionary = {}
		for mesh: MeshInstance3D in sector_runtime.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null or mesh.mesh.get_surface_count() != 1:
				continue
			var source := mesh.get_active_material(0) as StandardMaterial3D
			if source == null or mesh.material_override != null:
				continue
			var factor := Color.WHITE
			var emission_scale: float = 1.0
			if mesh.name == &"north_block_ServiceBand":
				factor = Color(0.55, 0.55, 0.55)
				emission_scale = 0.32
			elif str(mesh.name).begins_with("Yard_Slab") and source.resource_name.begins_with("CS_concrete_pale_PLAY_w1.62"):
				factor = Color(0.55, 0.55, 0.55)
			elif str(mesh.name).begins_with("Ground_Patch"):
				factor = Color(0.62, 0.62, 0.62)
			else:
				continue
			var variant_key: String = "%s:%s:%s" % [source.get_instance_id(), factor, emission_scale]
			if not variants.has(variant_key):
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_color *= factor
				material.emission_energy_multiplier *= emission_scale
				variants[variant_key] = material
			_art_surfaces.append({"mesh": mesh, "original": mesh.get_surface_override_material(0), "material": variants[variant_key]})
	for entry: Dictionary in _art_surfaces:
		(entry.mesh as MeshInstance3D).set_surface_override_material(0, entry.material if enabled else entry.original)


func _ground_character_frame(height_m: float) -> void:
	# Ignore nearly transparent padding at the same cutoff as the Sprite3D.
	var atlas := character_sprite.texture as AtlasTexture
	var frame: Image = atlas.atlas.get_image() if atlas != null else character_sprite.texture.get_image()
	if frame.is_compressed():
		var error: Error = frame.decompress()
		if error != OK:
			push_error("Cannot inspect character frame: " + error_string(error))
			return
	if atlas != null:
		frame = frame.get_region(Rect2i(atlas.region))
	var left: int = frame.get_width()
	var top: int = frame.get_height()
	var right: int = -1
	var bottom: int = -1
	for y: int in frame.get_height():
		for x: int in frame.get_width():
			if frame.get_pixel(x, y).a >= character_sprite.alpha_scissor_threshold:
				left = mini(left, x)
				right = maxi(right, x)
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if bottom < top:
		return
	var foot_left: int = frame.get_width()
	var foot_right: int = -1
	for x: int in frame.get_width():
		if frame.get_pixel(x, bottom).a >= character_sprite.alpha_scissor_threshold:
			foot_left = mini(foot_left, x)
			foot_right = maxi(foot_right, x)
	var metres_per_pixel: float = height_m / float(bottom - top + 1)
	character_sprite.scale = Vector3.ONE * metres_per_pixel / character_sprite.pixel_size
	var foot_x: float = (float(foot_left + foot_right) + 1.0) * 0.5
	var offset_right: float = (float(frame.get_width()) * 0.5 - foot_x) * metres_per_pixel
	var offset_up: float = (float(bottom + 1) - float(frame.get_height()) * 0.5) * metres_per_pixel
	# Full billboard: offset along camera up/right so the foot lands at TestCharacter's origin.
	character_sprite.position = gameplay_camera.global_basis.x * offset_right + gameplay_camera.global_basis.y * offset_up


func _apply_readable_vegetation() -> void:
	# Authored foliage is baked PBR, so the legacy calibrated foliage shader is not active here.
	# Share one tinted copy per source material, retaining atlas, normal and ORM response.
	var variants: Dictionary = {}
	for node: Node in sector_runtime.imported_environment.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not ("weed" in str(mesh.name).to_lower()):
			continue
		var source := mesh.get_active_material(0) as StandardMaterial3D
		if source == null or not "foliage" in source.resource_name.to_lower():
			continue
		if not variants.has(source):
			var material := source.duplicate() as StandardMaterial3D
			material.resource_name = source.resource_name + "_readable"
			material.albedo_color = Color(2.5, 2.5, 2.0, 1.0)
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.backlight_enabled = true
			material.backlight = Color(0.035, 0.044, 0.018)
			variants[source] = material
		mesh.set_surface_override_material(0, variants[source])


## Fit only real-player visuals to the approved arena framing. Never resize their bodies.
func configure_player_presentation(character: Character) -> void:
	var sprite: AnimatedSprite3D = character.animated_sprite_3d
	if sprite.has_meta("sector08_visual_fitted"):
		return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture("Idle",0)
	var atlas := texture as AtlasTexture
	var image: Image = atlas.atlas.get_image() if atlas != null else texture.get_image()
	if image.is_compressed() and image.decompress() != OK:
		push_error("Cannot inspect real-player sprite for grounding")
		return
	if atlas != null:
		image = image.get_region(Rect2i(atlas.region))
	var top: int = image.get_height()
	var bottom: int = -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a >= 0.5:
				top = mini(top,y)
				bottom = maxi(bottom,y)
	if bottom < top:
		return
	var body_shape: CollisionShape3D = character.get_node("CollisionShape3D")
	var floor_local: float = body_shape.position.y - (body_shape.shape as CapsuleShape3D).height*0.5
	# Atlas canvas includes transparent padding. Anchor the opaque boot edge, not its centre.
	sprite.scale *= 1.4
	var metres_per_pixel: float = sprite.pixel_size*sprite.scale.y
	sprite.position.y = floor_local + (float(bottom+1)-image.get_height()*0.5)*metres_per_pixel + 0.01
	character.label_3d.position.y = floor_local + float(bottom-top+1)*metres_per_pixel + 0.20
	sprite.set_meta("sector08_visual_fitted",true)
	character.add_child(preload("res://scenes/characters/combat_presentation.gd").new())
