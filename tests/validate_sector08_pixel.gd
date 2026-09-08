extends "res://tests/validate_sector08_art.gd"

var pixel_report: Dictionary = {}
var checked_mode: int = 0

func capture(label: String) -> void:
 if label == "normal":
  var args := OS.get_cmdline_user_args()
  checked_mode = int(args[1]) if args.size() > 1 else 0
  scene.pixel_presentation.set_mode(checked_mode)
  assert(scene.pixel_presentation._native_size() == Vector2(1920,1080))
  assert(not root.disable_3d)
  if checked_mode > 0:
   assert(scene.character_sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED)
   assert(scene.pixel_presentation.presentation_material.render_priority < scene.character_sprite.render_priority)
  pixel_report["presentation"] = scene.pixel_presentation.get_report()
  pixel_report["character_scale"] = str(scene.character_sprite.scale)
  pixel_report["character_position"] = str(scene.character_sprite.position)
 await super.capture(label)
 if label == "normal":
  for depth in [0,2]:
   scene._set_character_depth(depth)
   await _save("normal_depth_" + str(depth + 1))
  scene._set_character_depth(1)
  scene.debug_layer.visible = true
  await _save("native_ui")
  scene.debug_layer.visible = false
 elif label == "recovered":
  await _benchmark_pixel()
  # Clean must bypass the presentation entirely after any sequence of toggles.
  var original_transform: Transform3D = scene.gameplay_camera.global_transform
  for mode in [0,1,2,0,checked_mode]:
   scene.pixel_presentation.set_mode(mode)
   assert(scene.gameplay_camera.global_transform.is_equal_approx(original_transform))
   assert(not root.disable_3d)
  pixel_report["pass"] = true
  FileAccess.open(output.path_join("pixel_validation.json"), FileAccess.WRITE).store_string(JSON.stringify(pixel_report,"  "))

func _save(label: String) -> void:
 for i in 8: await process_frame
 await RenderingServer.frame_post_draw
 var im: Image = root.get_texture().get_image()
 assert(im.get_size() == Vector2i(1920,1080))
 assert(im.save_png(output.path_join(label + ".png")) == OK)

func _benchmark_pixel() -> void:
 scene.controller.preset_normal()
 settle(scene.controller,3.0)
 var views: Array[Viewport] = [root]
 for view: Viewport in views:
  RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
 for i in 60: await process_frame
 var cpu: Array[float] = []
 var wall: Array[float] = []
 var draws: Array[float] = []
 var gpu: Array[float] = []
 var last: int = Time.get_ticks_usec()
 for i in 180:
  await process_frame
  var now: int = Time.get_ticks_usec()
  wall.append(float(now-last)/1000.0)
  last = now
  var cpu_total: float = 0.0
  var gpu_total: float = 0.0
  for view: Viewport in views:
   cpu_total += RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
   gpu_total += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
  cpu.append(cpu_total)
  gpu.append(gpu_total)
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 cpu.sort();wall.sort();draws.sort();gpu.sort()
 pixel_report["performance"] = {"samples":180,"frame_ms_p50":wall[90],"frame_ms_p95":wall[171],"cpu_render_all_active_viewports_ms_p50":cpu[90],"draw_calls_p50":draws[90],"gpu_available":gpu[90]>0.0,"gpu_ms_p50":gpu[90] if gpu[90]>0.0 else null,"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
