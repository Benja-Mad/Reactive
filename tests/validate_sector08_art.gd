extends "res://tests/validate_sector08_pipeline.gd"

var art_report: Dictionary = {}
var variant_ids: Array = []
## The lit-state energy this run actually used, so the blackout and recovery guards are
## expressed as a fraction of it. An absolute threshold here was pinned to a 32.0 lamp and had
## 3% of headroom, so retuning the luminaire broke the test rather than reporting a regression.
var lit_yard_energy: float = 0.0

func capture(label: String) -> void:
 var yard: SpotLight3D = scene.motivated_lights.get_node("YardStreetlight")
 if label == "normal": lit_yard_energy = yard.light_energy
 var expected_anchor := Vector3(4.0537, 6.55, 10.76307)
 assert(yard.global_position.distance_to(expected_anchor) < 0.001)
 # Was `not yard.shadow_enabled`. An unshadowed 48-degree cone at 2.5 volumetric fog energy
 # poured straight through the fence, the gantry and the character and read as a directionless
 # haze wash rather than a beam. The lamp is now a shadowed 34-degree luminaire, so the guard
 # is inverted: it must keep its shadows and must not widen back into a wash.
 assert(yard.shadow_enabled)
 assert(yard.spot_angle < 40.0)
 assert(scene.motivated_lights.get_child_count() == 5)
 if label == "normal":
  assert(yard.light_energy > 31.9)
  assert(lit_yard_energy > 31.9)
  var unique: Dictionary = {}
  for entry: Dictionary in scene._art_surfaces:
   var mesh: MeshInstance3D = entry.mesh
   var original := mesh.mesh.surface_get_material(0) as StandardMaterial3D
   var variant := entry.material as StandardMaterial3D
   assert(mesh.material_override == null)
   assert(mesh.get_active_material(0) == variant)
   assert(variant.albedo_texture == original.albedo_texture)
   assert(variant.roughness_texture == original.roughness_texture)
   assert(variant.normal_texture == original.normal_texture)
   assert(variant.roughness == original.roughness)
   assert(variant.metallic == original.metallic)
   assert(variant.uv1_scale == original.uv1_scale)
   assert(variant.uv2_scale == original.uv2_scale)
   for prop: Dictionary in original.get_property_list():
    var property_name: String = str(prop.name)
    if property_name.begins_with("uv") or property_name.contains("texture"):
     assert(variant.get(property_name) == original.get(property_name))
   unique[variant.get_instance_id()] = true
  variant_ids = unique.keys()
  art_report["surfaces"] = []
  for entry: Dictionary in scene._art_surfaces:
   art_report["surfaces"].append({"node":str(entry.mesh.get_path()),"material":entry.material.resource_name,"albedo_multiplier":str(entry.material.albedo_color),"emission_energy":entry.material.emission_energy_multiplier})
  art_report["surface_variants"] = variant_ids.size()
  art_report["affected_surfaces"] = scene._art_surfaces.size()
 elif label == "blackout":
  assert(yard.light_energy < lit_yard_energy * 0.05)
  assert(scene.spine_cyan_light.light_energy < 0.7)
 elif label == "recovered":
  assert(yard.light_energy > lit_yard_energy * 0.95)
  for entry: Dictionary in scene._art_surfaces:
   assert(variant_ids.has(entry.material.get_instance_id()))
 await super.capture(label)
 art_report[label] = {
  "yard_energy": yard.light_energy,
  "spine_energy": scene.spine_cyan_light.light_energy,
  "render_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
  # This Metal build returns an unsigned underflow for texture memory: expose availability.
  "texture_memory_bytes": _texture_memory(),
  "texture_memory_available": _texture_memory() != null,
  "buffer_memory_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
  "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
 }
 if label == "normal":
  # The comparison toggles must restore originals and reuse variants, not compound gains.
  for i in 3:
   scene._set_calibrated_look(false)
   for entry: Dictionary in scene._art_surfaces:
    assert(entry.mesh.get_surface_override_material(0) == entry.original)
   scene._set_calibrated_look(true)
   assert(scene.motivated_lights.get_child_count() == 5)
   for entry: Dictionary in scene._art_surfaces:
    assert(variant_ids.has(entry.mesh.get_active_material(0).get_instance_id()))
 elif label == "recovered":
  art_report["pass"] = true
  art_report["toggle_cycles"] = 3
  FileAccess.open(output.path_join("art_validation.json"), FileAccess.WRITE).store_string(JSON.stringify(art_report, "  "))

func _texture_memory() -> Variant:
 var value: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
 return value if value >= 0.0 and value < 1.0e12 else null
