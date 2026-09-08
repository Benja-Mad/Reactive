extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var args := OS.get_cmdline_user_args()
 var out: String = args[0]
 DirAccess.make_dir_recursive_absolute(out)
 root.size = Vector2i(1920,1080)
 var scene: Node = load("res://scenes/environment/sector_08/Sector08LookDev.tscn").instantiate()
 root.add_child(scene)
 scene.debug_layer.visible = false
 var controller: Node = scene.controller
 controller.auto_demo = false
 controller.set_process(false)
 controller.preset_normal()
 for i in 180: controller._process(1.0/60.0)
 scene.pixel_presentation.set_mode(int(args[1]))
 if args.size() > 2:
  scene.pixel_presentation.set_dither(args[2] == "dither")
  scene.pixel_presentation.set_diorama(args[2] == "diorama")
 for i in 30: await process_frame
 var camera_transform: Transform3D = scene.gameplay_camera.global_transform
 controller.trigger_wave()
 for frame in 240:
  if frame == 90:
   controller.set_signal_target("wave_intensity",0.0)
   controller.trigger_blackout()
  if frame == 150: controller.recover_power()
  var segment: int = frame / 60
  var indices: Array[int] = [0,1,2,1,0]
  scene.test_character.position = scene.CHARACTER_POSITIONS[indices[segment]].lerp(scene.CHARACTER_POSITIONS[indices[segment+1]], float(frame % 60)/60.0)
  controller._process(1.0/30.0)
  await process_frame
  await RenderingServer.frame_post_draw
  var im: Image = root.get_texture().get_image()
  assert(im.get_size() == Vector2i(1920,1080))
  assert(im.save_jpg(out.path_join("%04d.jpg" % frame),0.97) == OK)
  assert(scene.gameplay_camera.global_transform.is_equal_approx(camera_transform))
 print("MOTION PASS mode=",args[1]," frames=240 fps=30 camera unchanged")
 quit()
