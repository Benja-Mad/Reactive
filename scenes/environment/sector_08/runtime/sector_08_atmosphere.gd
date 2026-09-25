## Local scattering volumes and fixture-anchored beams, owned by the optional Diorama mode.
extends Node3D
var lookdev: Node
var beams: Array[SpotLight3D] = []
var base_energies: Array[float] = []
var yard: SpotLight3D
var original_yard_scattering: float
var environment: Environment
var original_reprojection: bool
var shaft_materials: Array[ShaderMaterial] = []
var fixture_lens: StandardMaterial3D
## Extra emitters spread across the floodlight aperture. The housing is 0.95 m wide, but a single
## SpotLight3D is a point, so every shadow shaft converged on one dot inside a fixture many times
## its size. Three sources across the aperture make the beam issue from a band instead.
var aperture_lights: Array[SpotLight3D] = []
var aperture_base_energies: Array[float] = []
func setup(owner_scene: Node) -> void:
 lookdev = owner_scene
 environment = lookdev.runtime_environment.environment
 original_reprojection = environment.volumetric_fog_temporal_reprojection_enabled
 yard = lookdev.motivated_lights.get_node("YardStreetlight")
 original_yard_scattering = yard.light_volumetric_fog_energy
 # Wall pockets: keep the central combat area free of a uniform fog blanket.
 _volume("SpineAir",Vector3(-18,10,-13),Vector3(16,23,13),0.055)
 _volume("PerimeterAir",Vector3(0,8,-20),Vector3(35,18,10),0.040)
 _volume("StreetlightAir",Vector3(4,3,8),Vector3(13,8,13),0.018)
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/environment/sector_08/arena_manifest.json"))
 for anchor: Dictionary in manifest.get("lights",[]):
  var id: String = anchor.get("name","")
  if id not in ["spine_node_2","compound_lamp"]: continue
  var p: Array = anchor["position"]
  var pos := Vector3(p[0],p[2],-p[1])
  var cyan: bool = id == "spine_node_2"
  _beam(id,pos,pos+Vector3(11,-18,13) if cyan else pos+Vector3(6,-4.3,12),Color(0.30,0.70,0.86) if cyan else Color(1.0,0.72,0.38),8.0 if cyan else 9.0,29.0 if cyan else 17.0,11.0 if cyan else 18.0)
 lookdev.controller.reactive_state_changed.connect(_sync)
 set_enabled(false)
func _volume(id: String,pos: Vector3,extent: Vector3,density: float) -> void:
 var volume := FogVolume.new()
 volume.name = id
 volume.size = extent
 var material := FogMaterial.new()
 material.density = density
 material.albedo = Color(0.64,0.72,0.78)
 material.edge_fade = 2.0
 volume.material = material
 add_child(volume)
 volume.position = pos
func _beam(id: String,pos: Vector3,target: Vector3,color: Color,energy: float,reach: float,angle: float) -> void:
 var light := SpotLight3D.new()
 light.name = id + "_shaft"
 light.light_color = color
 light.light_energy = energy
 light.light_volumetric_fog_energy = 2.0
 light.light_specular = 0.25
 light.spot_range = reach
 light.spot_angle = angle
 light.spot_angle_attenuation = 0.55
 light.spot_attenuation = 0.7
 light.shadow_enabled = true
 light.shadow_bias = 0.01
 light.shadow_normal_bias = 0.02
 add_child(light)
 light.position = pos
 light.look_at(target,Vector3.UP)
 var primary_energy: float = energy
 if id == "compound_lamp":
  _add_maintenance_fixture(light)
  primary_energy = _spread_aperture(light, energy)
 _add_shaft(light, target, color, id == "spine_node_2")
 beams.append(light)
 base_energies.append(primary_energy)
func set_enabled(enabled: bool) -> void:
 visible = enabled
 # P30 is fixed: temporal fog jitter caused visible crawling even with static lights.
 environment.volumetric_fog_temporal_reprojection_enabled = false if enabled else original_reprojection
 # 2.5 through a 48-degree unshadowed cone was the "strange" streetlight god ray. The cone is
 # now 31 degrees and shadowed, so a lower scattering value reads as a beam rather than a wash.
 yard.light_volumetric_fog_energy = 1.35 if enabled else original_yard_scattering
 _sync(lookdev.controller.get_values())
## Total emitted energy for a beam, primary plus any satellites spread across its aperture.
## The compound lamp is three sources sharing one luminaire, so reading only the primary
## understates its output by two thirds.
func beam_output(index: int) -> float:
 var total: float = beams[index].light_energy
 var prefix: String = beams[index].name + "_aperture"
 for satellite: SpotLight3D in aperture_lights:
  if str(satellite.name).begins_with(prefix):
   total += satellite.light_energy
 return total


func _sync(values: Dictionary) -> void:
 var supply: float = clampf(float(values.get("power",0.92))/0.92,0.0,1.1)*(1.0-0.9*clampf(float(values.get("blackout_amount",0.0)),0.0,1.0))
 if fixture_lens != null: fixture_lens.emission_energy_multiplier = 3.0*supply
 for i in beams.size():
  beams[i].light_energy = base_energies[i]*supply
  shaft_materials[i].set_shader_parameter("strength",0.085*supply)
 for i in aperture_lights.size():
  aperture_lights[i].light_energy = aperture_base_energies[i]*supply

## Two satellites either side of the primary, sharing its aim. Each carries a third of the beam
## energy, and the primary is reduced to match, so total output is unchanged - only the origin
## of the shadow shafts is spread across the real aperture width.
func _spread_aperture(light: SpotLight3D, energy: float) -> float:
 var share: float = energy/3.0
 light.light_energy = share
 for offset in [-0.29, 0.29]:
  var satellite := SpotLight3D.new()
  satellite.name = "%s_aperture%s" % [light.name, "L" if offset < 0.0 else "R"]
  satellite.light_color = light.light_color
  satellite.light_energy = share
  satellite.light_volumetric_fog_energy = light.light_volumetric_fog_energy
  satellite.light_specular = light.light_specular
  satellite.spot_range = light.spot_range
  satellite.spot_angle = light.spot_angle
  satellite.spot_angle_attenuation = light.spot_angle_attenuation
  satellite.spot_attenuation = light.spot_attenuation
  satellite.shadow_enabled = true
  satellite.shadow_bias = light.shadow_bias
  satellite.shadow_normal_bias = light.shadow_normal_bias
  add_child(satellite)
  satellite.global_transform = light.global_transform
  satellite.position += light.global_basis.x*offset
  aperture_lights.append(satellite)
  aperture_base_energies.append(share)
 return share

func _add_shaft(light: SpotLight3D,target: Vector3,color: Color,cyan: bool) -> void:
 var origin: Vector3 = light.global_position
 var axis: Vector3 = target-origin
 var side: Vector3 = axis.normalized().cross((lookdev.gameplay_camera.global_position-(origin+target)*0.5).normalized()).normalized()
 var width: float = 4.2 if cyan else 2.8
 var mesh := ArrayMesh.new()
 var vertices := PackedVector3Array([origin-side*width,origin+side*width,target-side*width,target+side*width])
 var uv := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)])
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,1,3,2])
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var instance := MeshInstance3D.new()
 instance.name = light.name + "_stable_rays"
 # Warm fixtures use shadowed volumetric scattering, not three painted rays.
 instance.visible = cyan
 instance.mesh = mesh
 instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material := ShaderMaterial.new()
 material.shader=preload("res://scenes/environment/sector_08/runtime/sector_08_light_shafts.gdshader")
 material.set_shader_parameter("shaft_color",color)
 material.render_priority=0
 instance.material_override=material
 add_child(instance)
 shaft_materials.append(material)

# The manifest lamp anchor lacked a physical emitter. Bolt it to the existing gantry leg.
func _add_maintenance_fixture(light: SpotLight3D) -> void:
 var steel := StandardMaterial3D.new()
 steel.albedo_color = Color(0.11,0.12,0.12)
 steel.metallic = 0.75
 steel.roughness = 0.48
 var body := MeshInstance3D.new()
 body.name = "MaintenanceFloodlightHousing"
 var box := BoxMesh.new()
 box.size = Vector3(0.95,0.42,0.32)
 body.mesh = box
 body.material_override = steel
 add_child(body)
 body.global_transform = light.global_transform
 body.position += light.basis.z*0.20
 fixture_lens = StandardMaterial3D.new()
 fixture_lens.albedo_color = Color(0.65,0.44,0.19)
 fixture_lens.emission_enabled = true
 fixture_lens.emission = Color(1.0,0.68,0.30)
 fixture_lens.roughness = 0.25
 var lens := MeshInstance3D.new()
 lens.name = "MaintenanceFloodlightLens"
 var face := BoxMesh.new()
 face.size = Vector3(0.77,0.24,0.012)
 lens.mesh = face
 lens.material_override = fixture_lens
 lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(lens)
 lens.global_transform = light.global_transform
 lens.position += light.basis.z*0.032
 var start := Vector3(-3.116008,4.6,-23.01287)
 var finish: Vector3 = body.position
 var arm := MeshInstance3D.new()
 arm.name = "MaintenanceFloodlightGantryBracket"
 var arm_mesh := BoxMesh.new()
 arm_mesh.size = Vector3(0.09,0.12,start.distance_to(finish))
 arm.mesh = arm_mesh
 arm.material_override = steel
 add_child(arm)
 arm.position = (start+finish)*0.5
 arm.look_at(finish,Vector3.UP)
