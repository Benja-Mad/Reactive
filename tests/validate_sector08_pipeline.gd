extends SceneTree
var scene: Node
var output: String
var report: Dictionary = {}
func _initialize() -> void:
 call_deferred("run")
func capture(label: String) -> void:
 for i in 6: await process_frame
 await RenderingServer.frame_post_draw
 var error: Error = root.get_texture().get_image().save_png(output.path_join(label + ".png"))
 assert(error == OK)
 if label == "normal":
  var frame: Image = root.get_texture().get_image()
  frame.get_region(Rect2i(930, 70, 950, 550)).save_png(output.path_join("right_cluster.png"))
  frame.get_region(Rect2i(560, 240, 660, 290)).save_png(output.path_join("spine_vents.png"))
func settle(controller: Node, seconds: float) -> void:
 for i in int(seconds * 60.0): controller._process(1.0 / 60.0)
 controller.effect_time = 2.0
 controller._push_material_parameters()
func run() -> void:
 var args: PackedStringArray = OS.get_cmdline_user_args()
 output = args[0]
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(1920, 1080)
 scene = load("res://scenes/environment/sector_08/Sector08LookDev.tscn").instantiate()
 root.add_child(scene)
 scene.debug_layer.visible = false
 var controller: Node = scene.controller
 var runtime: Node = scene.sector_runtime
 controller.auto_demo = false
 controller.set_process(false)
 controller.preset_normal()
 settle(controller, 3.0)
 assert(is_equal_approx(scene.gameplay_camera.fov, 30.0))
 assert(scene.gameplay_camera.keep_aspect == Camera3D.KEEP_WIDTH)
 assert(scene.gameplay_camera.global_position.distance_to(Vector3(42.61959, 49.05, 58.86708)) < 0.001)
 var old_tests: Node = load("res://tests/test_sector08_runtime.gd").new()
 old_tests.test_sector_lookdev_resources_load()
 old_tests.test_imported_extras_and_vertex_channels_are_auditable()
 old_tests.free()
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/environment/sector_08/reactive_manifest.json")) as Dictionary
 var route: Array = manifest["propagation"]["route"]
 for i in route.size():
  var owner: Node = runtime.imported_environment.get_node("CS_REACTIVE/OWNER_" + str(route[i]))
  assert(int(owner.get_meta("cs_route_index")) == i)
 var materials: Array = runtime.get_reactive_materials()
 var material_ids: Array = materials.map(func(m: Material) -> int: return m.get_instance_id())
 var baseline_report: Dictionary = runtime.get_runtime_report()
 if args.size() < 2 or args[1] != "baseline":
  assert(int(baseline_report.get("authored_pbr_meshes", 0)) >= 2500)
  assert(baseline_report["calibrated_overrides"] < 500)
  for candidate: Node in runtime.imported_environment.find_children("*", "MeshInstance3D", true, false):
   var mesh_instance: MeshInstance3D = candidate as MeshInstance3D
   if mesh_instance.mesh == null: continue
   var material: Material = mesh_instance.mesh.surface_get_material(0)
   if runtime._is_authored_pbr(material):
    assert(mesh_instance.material_override == null)
    assert(mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2] != null)
 await capture("normal")
 controller.trigger_wave()
 settle(controller, 0.6)
 assert(controller.wave_intensity > 0.8)
 await capture("wave")
 controller.set_signal_target("wave_intensity", 0.0)
 controller.trigger_blackout()
 settle(controller, 3.0)
 assert(controller.blackout_amount > 0.99)
 assert(controller.power < 0.3)
 var uniform_checks: int = 0
 for material: ShaderMaterial in materials:
  if material.get_shader_parameter(&"cs_blackout") != null:
   assert(float(material.get_shader_parameter(&"cs_blackout")) > 0.99)
   uniform_checks += 1
 assert(uniform_checks >= 4)
 await capture("blackout")
 controller.recover_power()
 settle(controller, 3.0)
 assert(controller.blackout_amount < 0.001)
 assert(controller.power > 0.89)
 await capture("recovered")
 assert(materials.map(func(m: Material) -> int: return m.get_instance_id()) == material_ids)
 assert(runtime.get_runtime_report() == baseline_report)
 for i in 3:
  scene._set_character_depth(i)
  assert(scene.test_character.position.is_equal_approx(scene.CHARACTER_POSITIONS[i]))
 scene._set_character_depth(1)
 controller.preset_normal()
 settle(controller, 3.0)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
 for i in 60: await process_frame
 var gpu: Array[float] = []
 var cpu: Array[float] = []
 var draws: Array[float] = []
 var wall: Array[float] = []
 var last_tick: int = Time.get_ticks_usec()
 for i in 120:
  await process_frame
  var tick: int = Time.get_ticks_usec()
  wall.append(float(tick - last_tick) / 1000.0)
  last_tick = tick
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
  cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 gpu.sort(); cpu.sort(); draws.sort(); wall.sort()
 report = {"pass": true, "runtime": baseline_report, "reactive_uniform_checks": uniform_checks, "camera_preserved": true, "depth_positions_checked": 3, "material_instances_stable": true, "frame_wall_ms_p50": wall[60], "frame_wall_ms_p95": wall[114], "gpu_timing_available": gpu[60] > 0.0, "gpu_ms_p50": gpu[60], "gpu_ms_p95": gpu[114], "render_cpu_ms_p50": cpu[60], "draw_calls_p50": draws[60], "renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name()}
 FileAccess.open(output.path_join("runtime_validation.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
 print("SECTOR08 PIPELINE PASS ", JSON.stringify(report))
 # Free the scene before quitting: quit() alone leaves GPUParticles3D holding their generated
 # shader, which the engine then reports as an unfreed RID and buries real errors in noise.
 root.remove_child(scene)
 scene.free()
 await process_frame
 quit()
