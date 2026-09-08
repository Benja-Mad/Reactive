extends SceneTree
var scene: Node
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var args: PackedStringArray = OS.get_cmdline_user_args()
 var output: String = args[0]
 root.size = Vector2i(1920, 1080)
 scene = load("res://scenes/environment/sector_08/Sector08LookDev.tscn").instantiate()
 root.add_child(scene)
 scene.debug_layer.visible = false
 var controller: Node = scene.controller
 controller.auto_demo = false
 controller.set_process(false)
 controller.preset_normal()
 for i in 120: controller._process(1.0 / 60.0)
 controller.effect_time = 2.0
 controller._push_material_parameters()
 scene.pixel_presentation.set_mode(int(args[1]) if args.size() > 1 else 0)
 if args.size() > 2:
  scene.pixel_presentation.set_dither(args[2] == "dither")
  scene.pixel_presentation.set_quantization(args[2] == "quant")
 for i in 30: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output)
 var report: Dictionary = scene.sector_runtime.get_runtime_report()
 report["pixel"] = scene.pixel_presentation.get_report()
 report["root_size"] = str(root.size)
 report["texture_size"] = str(root.get_texture().get_size())
 report["visible_rect"] = str(root.get_visible_rect())
 report["camera_fov"] = scene.gameplay_camera.fov
 report["camera_position"] = str(scene.gameplay_camera.global_position)
 FileAccess.open(output + ".json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CAPTURED ",output," ",report)
 quit()
