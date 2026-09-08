## Ground redistribution A/B: identical camera, identical lighting, placement is the only variable.
##
## Presentation is pinned to Astra's canonical still configuration -- CLEAN (mode 0) with the
## diorama atmosphere ON -- so these frames are directly comparable with
## authored/sector08/parallax_pass_20260907/final_clean/. Do not leave the diorama at its
## default: validate_sector08_diorama.gd only enables it when its third CLI argument is the
## literal "diorama", and a run without it silently drops the fog pockets, the light shafts
## and the maintenance floodlight geometry.
extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var out: String = OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(out)
 root.size = Vector2i(1920,1080)
 var scene: Node = load("res://scenes/environment/sector_08/Sector08LookDev.tscn").instantiate()
 root.add_child(scene)
 scene.debug_layer.visible = false
 scene.controller.auto_demo = false
 scene.controller.set_process(false)
 scene.controller.preset_normal()
 scene.controller.set_signal_target("wave_intensity",0.0)
 for i in 180: scene.controller._process(1.0/60.0)
 scene.pixel_presentation.set_mode(0)
 scene.pixel_presentation.set_diorama(true)
 for i in 30: await process_frame
 var stats: Dictionary = scene.sector_runtime.ground_dressing.stats
 print("GROUND DRESSING ", JSON.stringify(stats))
 FileAccess.open(out.path_join("ground_stats.json"),FileAccess.WRITE).store_string(JSON.stringify(stats,"  "))
 for pair in [["before",false],["after",true]]:
  scene.sector_runtime.ground_dressing.set_enabled(bool(pair[1]))
  for i in 8: await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(out.path_join(str(pair[0])+".png")) == OK)
 # Perf and P30 integrity are read on the shipped (after) state.
 assert(scene.gameplay_camera.fov == 30.0)
 assert(scene.pixel_presentation.diorama_enabled)
 var air: Node3D = scene.pixel_presentation.atmosphere
 assert(air.visible and air.beams.size() == 2 and air.shaft_materials.size() == 2)
 var draw_calls: float = 0.0
 for i in 40:
  await process_frame
  draw_calls += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
 print("GROUND AFTER draw_calls_avg=%.1f" % (draw_calls/40.0))
 print("GROUND CAPTURE PASS")
 quit()
