## Physical information panel inside the existing programmable yard gate.
## Imported geometry, metadata, UVs and route nodes remain untouched.
extends Node3D
var field: MeshInstance3D
var display_material: StandardMaterial3D
var glow: OmniLight3D
var textures: Dictionary = {}
var display_state := ""
func setup(owner_scene: Node) -> void:
 field = owner_scene.sector_runtime.imported_environment.get_node("CS_REACTIVE/OWNER_YARD/YARD_programmable/Barrier_Field")
 global_transform = field.global_transform
 # Replace only the ambiguous preview bars. Keep the original node/mesh for audits and rollback.
 field.visible = false
 var steel := StandardMaterial3D.new()
 steel.albedo_color = Color(0.075,0.09,0.095)
 steel.metallic = 0.72
 steel.roughness = 0.46
 _box("DisplayHousing",Vector3(3.95,1.10,0.20),Vector3(0,0.72,0.07),steel)
 for x in [-2.04,2.04]:
  _box("PostClamp",Vector3(0.18,0.18,0.30),Vector3(x,0.72,0.04),steel)
 _box("PowerConduit",Vector3(0.045,0.62,0.045),Vector3(1.95,0.34,-0.16),steel)
 display_material = StandardMaterial3D.new()
 display_material.albedo_color = Color(0.30,0.30,0.30)
 display_material.roughness = 0.32
 display_material.emission_enabled = true
 display_material.emission = Color.WHITE
 display_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
 display_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 for state in ["normal","alert","overload","corrupt"]:
  textures[state] = load("res://scenes/environment/sector_08/runtime/signage/"+state+".png")
 var screen := MeshInstance3D.new()
 screen.name = "AccessDisplay"
 var mesh := QuadMesh.new()
 mesh.size = Vector2(3.76,0.96)
 screen.mesh = mesh
 screen.material_override = display_material
 add_child(screen)
 screen.position = Vector3(0,0.72,0.177)
 glow = OmniLight3D.new()
 glow.name = "DisplaySpill"
 glow.light_color = Color(0.26,0.60,0.67)
 glow.omni_range = 2.5
 glow.light_specular = 0.3
 glow.light_volumetric_fog_energy = 0.0
 glow.shadow_enabled = true
 add_child(glow)
 glow.position = Vector3(0,0.80,0.45)
 owner_scene.controller.reactive_state_changed.connect(_sync)
 _sync(owner_scene.controller.get_values())
func _box(id: String,size: Vector3,pos: Vector3,material: Material) -> void:
 var instance := MeshInstance3D.new()
 instance.name = id
 var mesh := BoxMesh.new()
 mesh.size = size
 instance.mesh = mesh
 instance.material_override = material
 add_child(instance)
 instance.position = pos
func _sync(values: Dictionary) -> void:
 var state := "normal"
 if float(values.get("corruption",0.0)) > 0.65: state = "corrupt"
 elif float(values.get("network_load",0.0)) > 0.85: state = "overload"
 elif float(values.get("alert_level",0.0)) > 0.60: state = "alert"
 if state != display_state:
  display_state = state
  display_material.albedo_texture = textures[state]
  display_material.emission_texture = textures[state]
 var supply: float = clampf(float(values.get("power",0.92))/0.92,0.0,1.1)*(1.0-0.9*clampf(float(values.get("blackout_amount",0.0)),0.0,1.0))
 display_material.emission_energy_multiplier = 1.15*supply
 glow.light_energy = 0.45*supply
 glow.light_color = Color(0.90,0.48,0.15) if state == "alert" else Color(0.57,0.23,0.33) if state == "corrupt" else Color(0.26,0.60,0.67)
