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
 scene.pixel_presentation.set_mode(1)
 scene.parallax.set_offset(-1.2)
 var basis: Basis = scene.gameplay_camera.global_basis
 var air: Node3D = scene.pixel_presentation.atmosphere
 var light_transforms: Array = air.beams.map(func(b): return b.global_transform)
 for i in 30: await process_frame
 var overlay := CanvasLayer.new()
 root.add_child(overlay)
 var label := Label.new()
 overlay.add_child(label)
 label.position = Vector2(20,20)
 label.add_theme_font_size_override("font_size",22)
 for frame in 240:
  var offset: float
  if frame < 30: offset = -1.2
  elif frame < 105: offset = lerpf(-1.2,0.0,smoothstep(0,1,float(frame-30)/74.0))
  elif frame < 135: offset = 0.0
  elif frame < 210: offset = lerpf(0.0,1.2,smoothstep(0,1,float(frame-135)/74.0))
  else: offset = 1.2
  scene.parallax.set_offset(offset)
  label.text = "LEFT > CENTER > RIGHT | %.2f m | P30 fixed / SOFT" % offset
  assert(scene.gameplay_camera.global_basis.is_equal_approx(basis))
  for i in air.beams.size(): assert(air.beams[i].global_transform.is_equal_approx(light_transforms[i]))
  await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_jpg(out.path_join("%04d.jpg" % frame),0.97) == OK)
 scene.parallax.set_offset(0.0)
 print("PARALLAX MOTION PASS: 240 frames / 30 fps, basis and world light transforms fixed")
 quit()
