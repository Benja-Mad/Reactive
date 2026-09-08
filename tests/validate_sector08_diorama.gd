extends "res://tests/validate_sector08_pipeline.gd"
var mode: int = 0
func capture(label: String) -> void:
 if label == "normal":
  var args = OS.get_cmdline_user_args()
  mode = int(args[1]) if args.size()>1 else 1
  scene.pixel_presentation.set_mode(mode)
  scene.pixel_presentation.set_diorama(args.size()>2 and args[2]=="diorama")
  assert(not root.disable_3d)
  assert(scene.pixel_presentation.character == scene.character_sprite)
 if scene.pixel_presentation.diorama_enabled:
  var air = scene.pixel_presentation.atmosphere
  assert(air.visible)
  assert(air.beams.size() == 2)
  assert(air.shaft_materials.size() == 2)
  assert(not air.environment.volumetric_fog_temporal_reprojection_enabled)
  # Measured on total luminaire output, not on the primary emitter. The compound lamp is now
  # three sources spread across its 0.95 m aperture -- a single point origin made every shadow
  # shaft converge on one dot inside a fixture many times its size -- so the primary alone
  # carries a third of the beam and reading it directly understates the light by two thirds.
  if label == "blackout":
   for i in air.beams.size(): assert(air.beam_output(i) < 1.0)
  if label == "normal" or label == "recovered":
   for i in air.beams.size(): assert(air.beam_output(i) > 5.0)
 await super.capture(label)
 if label == "normal":
  for index in [0,2]:
   scene._set_character_depth(index)
   await super.capture("depth_"+str(index+1))
  scene._set_character_depth(1)
  FileAccess.open(output.path_join("presentation.json"),FileAccess.WRITE).store_string(JSON.stringify(scene.pixel_presentation.get_report(),"  "))

 if label == "recovered":
  var air = scene.pixel_presentation.atmosphere
  var was_enabled: bool = scene.pixel_presentation.diorama_enabled
  scene.pixel_presentation.set_diorama(false)
  assert(not air.visible)
  assert(is_equal_approx(air.yard.light_volumetric_fog_energy,air.original_yard_scattering))
  assert(air.environment.volumetric_fog_temporal_reprojection_enabled == air.original_reprojection)
  scene.pixel_presentation.set_diorama(was_enabled)
