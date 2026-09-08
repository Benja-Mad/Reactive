## World presentation before transparent sprites: native depth and native UI remain available.
extends Node
enum Mode { CLEAN, SOFT, MEDIUM }
const LABELS: Array[String] = ["CLEAN", "SOFT PIXEL", "MEDIUM PIXEL"]
const SCALES: Array[float] = [1.0, 2.0/3.0, 0.5]
var atmosphere: Node3D
var mode: int = 0
var dither_enabled := false
var quantization_enabled := false
var diorama_enabled := false
var source_camera: Camera3D
var source_viewport: Viewport
var presentation_material: ShaderMaterial
var quad: MeshInstance3D
var character: Sprite3D
var original_alpha_cut: int
var _managed: Array[Sprite3D] = []

func setup(camera: Camera3D) -> void:
 source_camera = camera
 source_viewport = camera.get_viewport()
 character = get_parent().character_sprite
 original_alpha_cut = character.alpha_cut
 _managed = [character]
 quad = MeshInstance3D.new()
 var mesh := QuadMesh.new()
 mesh.size = Vector2(2,2)
 quad.mesh = mesh
 quad.extra_cull_margin = 16384.0
 quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 presentation_material = ShaderMaterial.new()
 presentation_material.shader = preload("res://scenes/environment/sector_08/runtime/sector_08_world_pixel.gdshader")
 presentation_material.render_priority = -128
 quad.material_override = presentation_material
 source_camera.add_child(quad)
 quad.position.z = -1.0
 source_viewport.size_changed.connect(_update_effects)
 atmosphere = preload("res://scenes/environment/sector_08/runtime/sector_08_atmosphere.gd").new()
 get_parent().add_child(atmosphere)
 atmosphere.setup(get_parent())
 set_diorama(true)
## Any transparent world sprite that must draw after the world filter, at full resolution.
func register_sprite(sprite: Sprite3D) -> void:
 if sprite != null and sprite not in _managed:
  _managed.append(sprite)
  _update_effects()
func set_mode(value: int) -> void:
 mode = clampi(value,0,2)
 _update_effects()
func set_dither(value: bool) -> void:
 dither_enabled = value
 _update_effects()
func set_quantization(value: bool) -> void:
 quantization_enabled = value
 _update_effects()
func set_diorama(value: bool) -> void:
 diorama_enabled = value
 atmosphere.set_enabled(value)
 _update_effects()
func _focus_distance() -> float:
 var owner_arena: Node = get_parent()
 return float(owner_arena.framing_distance) if owner_arena != null and "framing_distance" in owner_arena else 85.8
func _native_size() -> Vector2:
 return Vector2((source_viewport as Window).size) if source_viewport is Window else source_viewport.get_visible_rect().size
func _update_effects() -> void:
 if quad == null: return
 quad.visible = mode != 0 or diorama_enabled
 # Transparent sprite draws after the world filter, with the original full-resolution depth buffer.
 for sprite: Sprite3D in _managed:
  sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if quad.visible else original_alpha_cut
 presentation_material.set_shader_parameter("pixel_grid",_native_size()*SCALES[mode])
 presentation_material.set_shader_parameter("pixel_enabled",mode!=0)
 presentation_material.set_shader_parameter("diorama_enabled",diorama_enabled)
 # The in-focus band follows the framing distance, so a level (or a framing trial) that composes
 # from somewhere other than 85.8 m keeps its gameplay plane sharp instead of inheriting P30's.
 presentation_material.set_shader_parameter("focus_distance",_focus_distance())
 presentation_material.set_shader_parameter("subtle_dither",dither_enabled and mode!=0)
 presentation_material.set_shader_parameter("subtle_quantization",quantization_enabled and mode!=0)
func get_report() -> Dictionary:
 return {"mode":LABELS[mode],"internal_resolution":_native_size(),"world_sample_grid":_native_size()*SCALES[mode],"native_character":true,"diorama":diorama_enabled,"dither":dither_enabled,"quantization":quantization_enabled,"filter":"world screen sampling before transparent sprite","msaa":source_viewport.msaa_3d}
