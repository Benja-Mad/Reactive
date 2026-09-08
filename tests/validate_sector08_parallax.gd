extends "res://tests/validate_sector08_diorama.gd"
func capture(label: String) -> void:
 if label in ["normal","recovered"]:
  assert(scene.access_display.display_state == "normal")
 if label == "blackout":
  assert(scene.access_display.glow.light_energy < 0.02)
 await super.capture(label)
 if label == "normal":
  var center: Transform3D = scene.parallax.center
  var projections: Dictionary = {}
  var points: Dictionary = {"foreground":Vector3(5.416686,3.45,9.222723),"gameplay":Vector3(0,0.05,-2),"architecture":Vector3(-5.415864,6.3,-24.32433),"skyline_offscreen_diagnostic_only":Vector3(1.222776,34,-45.58331)}
  for side in [-1,0,1]:
   scene.parallax.set_offset(float(side)*scene.parallax.EXTENT)
   assert(scene.gameplay_camera.global_basis.is_equal_approx(center.basis))
   assert(scene.gameplay_camera.fov == 30.0)
   var key: String = ["left","center","right"][side+1]
   projections[key] = {}
   for id in points:
    projections[key][id] = str(scene.gameplay_camera.unproject_position(points[id]))
   for i in 6: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join(key+".png"))
  scene.parallax.set_offset(0.0)
  assert(scene.gameplay_camera.global_transform.is_equal_approx(center))
  FileAccess.open(output.path_join("parallax.json"),FileAccess.WRITE).store_string(JSON.stringify({"extent_m":scene.parallax.EXTENT,"basis_preserved":true,"projections_logical":projections},"  "))

  var field: MeshInstance3D = scene.access_display.field
  assert(field.get_meta("cs_prog") == "barrier")
  assert(not field.visible and field.mesh != null)
  assert(field.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] != null)
  for state in ["alert","overload","corrupt"]:
   if state == "alert": scene.controller.preset_alert()
   elif state == "overload": scene.controller.preset_network_overload()
   else: scene.controller.preset_corrupted()
   settle(scene.controller,3.0)
   assert(scene.access_display.display_state == state)
   for i in 6: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join("display_"+state+".png"))
  scene.controller.preset_normal()
  settle(scene.controller,3.0)
