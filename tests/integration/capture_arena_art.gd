extends Node
var scene: Node
var arena: Node
var local: Character
var out: String
var report := {}
func _ready() -> void: call_deferred("run")
func wait_frames(n: int) -> void:
 for i in n: await get_tree().physics_frame
func capture(id: String) -> void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join(id+".png"))
func measure(character: Character) -> Dictionary:
 var sprite: AnimatedSprite3D = character.animated_sprite_3d
 var texture: Texture2D = sprite.sprite_frames.get_frame_texture("Idle",0)
 var atlas := texture as AtlasTexture
 var im: Image = atlas.atlas.get_image() if atlas != null else texture.get_image()
 if im.is_compressed(): im.decompress()
 if atlas != null: im=im.get_region(Rect2i(atlas.region))
 var bounds: Rect2i = im.get_used_rect()
 for y in im.get_height():
  for x in im.get_width():
   if im.get_pixel(x,y).a < 0.5: im.set_pixel(x,y,Color(0,0,0,0))
 bounds = im.get_used_rect()
 var bottom := Vector3(0, -(bounds.end.y-texture.get_height()*0.5)*sprite.pixel_size,0)
 var top := Vector3(0, -(bounds.position.y-texture.get_height()*0.5)*sprite.pixel_size,0)
 var a: Vector3 = sprite.global_transform*bottom
 var b: Vector3 = sprite.global_transform*top
 var camera: Camera3D = arena.gameplay_camera
 var window_scale: float = float(get_window().size.y)/get_viewport().get_visible_rect().size.y
 var shape: CollisionShape3D = character.get_node("CollisionShape3D")
 return {"name":str(character.name),"opaque_bounds":str(bounds),"sprite_scale":str(sprite.scale),"sprite_position":str(sprite.position),"canvas_height_screen_px":absf(camera.unproject_position(sprite.global_transform*Vector3(0,-texture.get_height()*0.5*sprite.pixel_size,0)).y-camera.unproject_position(sprite.global_transform*Vector3(0,texture.get_height()*0.5*sprite.pixel_size,0)).y)*window_scale,"height_screen_px":absf(camera.unproject_position(a).y-camera.unproject_position(b).y)*window_scale,"visual_feet_world":str(a),"collision_radius":shape.shape.radius,"collision_height":shape.shape.height,"body_scale":str(character.scale),"label_position":str(character.label_3d.position)}
func run() -> void:
 out=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(out)
 get_window().size=Vector2i(1920,1080)
 Game.instance.players=[Statics.PlayerData.new(multiplayer.get_unique_id(),"Local",0,Statics.Role.SUPPORT),Statics.PlayerData.new(multiplayer.get_unique_id()+1,"Remote",1,Statics.Role.DAMAGE)]
 scene=load("res://scenes/main_scene.tscn").instantiate()
 add_child(scene)
 await wait_frames(60)
 arena=scene.get_node("Arena")
 local=scene.get_node("Players").get_child(0)
 local.programming_block.get_node("CodeBlock").release_focus()
 arena.controller.auto_demo=false
 arena.controller.set_process(false)
 arena.controller.preset_normal()
 for i in 180: arena.controller._process(1.0/60.0)
 await wait_frames(90)
 report["initial_mode"]=arena.pixel_presentation.mode
 arena.pixel_presentation.set_mode(1)
 report["players"]=[]
 for player in scene.get_node("Players").get_children(): report.players.append(measure(player))
 report["camera"]=arena.get_framing_report()
 report["collision"]=arena.sector_runtime.collision.stats
 report["runtime"]=arena.sector_runtime.get_runtime_report()
 assert(arena.gameplay_camera.current and not arena.lookdev_tools)
 assert(arena.gameplay_camera.fov==30.0)
 var material_ids: Array = arena.sector_runtime.get_reactive_materials().map(func(m): return m.get_instance_id())
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/environment/sector_08/reactive_manifest.json"))
 for i in manifest.propagation.route.size():
  assert(int(arena.sector_runtime.imported_environment.get_node("CS_REACTIVE/OWNER_"+str(manifest.propagation.route[i])).get_meta("cs_route_index"))==i)
 var spawn_clear: int = 0
 var query := PhysicsShapeQueryParameters3D.new()
 var probe := SphereShape3D.new()
 probe.radius=0.6
 query.shape=probe
 for i in 16:
  var point: Vector3 = arena.find_clear_spawn(float(i)*TAU/16.0,8.0)
  query.transform=Transform3D(Basis(),point+Vector3.UP*0.9)
  if arena.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): spawn_clear+=1
 report["clear_spawn_probes"]=spawn_clear
 assert(spawn_clear==16)
 for player in scene.get_node("Players").get_children():
  assert(not player.camera_3d.current and not player.use_own_camera)
  assert(player.scale.is_equal_approx(Vector3.ONE))
 report["follow_initial"]=arena.camera_rig.get_report()
 await capture("normal")
 FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 if OS.get_cmdline_user_args().size()>1 and OS.get_cmdline_user_args()[1]=="motion":
  await motion()
  get_tree().quit()
  return
 RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
 var walls=[];var cpus=[];var draws=[];var gpu=[]
 var last=Time.get_ticks_usec()
 for i in 120:
  await get_tree().process_frame
  var now=Time.get_ticks_usec()
  walls.append((now-last)/1000.0);last=now
  cpus.append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 walls.sort();cpus.sort();draws.sort();gpu.sort()
 report["performance"]={"frame_ms_p50":walls[60],"frame_ms_p95":walls[114],"cpu_ms_p50":cpus[60],"draw_calls":draws[60],"gpu_ms":gpu[60]}
 for state in ["wave","blackout","recovered"]:
  if state=="wave": arena.controller.trigger_wave()
  elif state=="blackout": arena.controller.trigger_blackout()
  else: arena.controller.recover_power()
  for i in (36 if state=="wave" else 180): arena.controller._process(1.0/60.0)
  await wait_frames(6)
  await capture(state)
  if state=="wave": assert(arena.controller.wave_intensity>0.8)
  elif state=="blackout": assert(arena.controller.blackout_amount>0.99)
  else: assert(arena.controller.blackout_amount<0.001)
  assert(arena.sector_runtime.get_reactive_materials().map(func(m): return m.get_instance_id())==material_ids)
 FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("INTEGRATED ART CAPTURE ",JSON.stringify(report))
 get_tree().quit()

func motion() -> void:
 var frames: String = out.path_join("frames")
 DirAccess.make_dir_recursive_absolute(frames)
 var start: Vector3 = local.global_position
 var camera_start: Vector3 = arena.gameplay_camera.global_position
 var positions: Array = []
 var light_transforms: Array = arena.pixel_presentation.atmosphere.beams.map(func(light): return light.global_transform)
 for frame in 360:
  if frame==0: Input.action_press("move_up")
  if frame==60:
   Input.action_release("move_up")
   Input.action_press("move_right")
  if frame==240:
   Input.action_release("move_right")
   arena.controller.trigger_wave()
  if frame==280: arena.controller.trigger_blackout()
  if frame==320: arena.controller.recover_power()
  arena.controller._process(1.0/30.0)
  await get_tree().process_frame
  assert(arena.gameplay_camera.global_basis.is_equal_approx(arena.approved_transform.basis))
  for i in light_transforms.size(): assert(arena.pixel_presentation.atmosphere.beams[i].global_transform.is_equal_approx(light_transforms[i]))
  if frame%30==0: positions.append({"frame":frame,"player":str(local.global_position),"rig":arena.camera_rig.get_report()})
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_jpg(frames.path_join("%04d.jpg" % frame),0.95)
 Input.action_release("move_up")
 Input.action_release("move_right")
 var displacement: float = arena.gameplay_camera.global_position.distance_to(camera_start)
 assert(displacement>0.25,"Actual input must trigger camera follow")
 report["motion"]={"camera_translation_m":displacement,"player_displacement_m":local.global_position.distance_to(start),"samples":positions,"basis_preserved":true,"world_lights_preserved":true,"input_actions_only":true}
 FileAccess.open(out.path_join("motion.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("REAL GAMEPLAY MOTION PASS ",JSON.stringify(report.motion))
