## Cosmetic surveillance pass. World-fixed route sampled once per pass, never
## tracks or damages the player. Inherits pause and is freed with the district.
extends Node3D
const PERIOD := 38.0
const START := 5.0
const DURATION := 9.0
var elapsed := 0.0
var route_origin := Vector3.ZERO
var in_pass := false
var lamp: SpotLight3D
var arena: Node3D
var shaft: MeshInstance3D
var shaft_material: ShaderMaterial

func setup(owner_arena: Node3D) -> void:
	arena = owner_arena
	process_mode = Node.PROCESS_MODE_PAUSABLE
	lamp = SpotLight3D.new()
	lamp.name = "AirborneSearchlight"
	add_child(lamp)
	lamp.light_color = Color("c9c3ee")
	lamp.light_specular = 0.0
	lamp.light_volumetric_fog_energy = 1.4
	lamp.spot_range = 44.0
	lamp.spot_angle = 15.0
	lamp.spot_attenuation = 0.8
	lamp.spot_angle_attenuation = 0.65
	lamp.light_size = 0.2
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.025
	# Octagonal aperture with a continuous shoulder, without concentric bands.
	# This is a filled light footprint, not a targeting ring or warning decal.
	var aperture := Image.create(64,64,false,Image.FORMAT_RGB8)
	for y: int in 64:
		for x: int in 64:
			var p := (Vector2(x,y)+Vector2.ONE*0.5-Vector2(32,32))/31.0
			var radius: float = maxf(maxf(absf(p.x),absf(p.y)),(absf(p.x)+absf(p.y))*0.7071)
			var value: float = 1.0-smoothstep(0.55,1.0,radius)
			aperture.set_pixel(x,y,Color(value,value,value))
	lamp.light_projector = ImageTexture.create_from_image(aperture)
	lamp.light_energy = 0.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for i: int in 8:
		var a := float(i)*TAU/8.0
		var b := float(i+1)*TAU/8.0
		surface.set_uv(Vector2(0.5,0))
		surface.add_vertex(Vector3.ZERO)
		surface.set_uv(Vector2(0,1))
		surface.add_vertex(Vector3(cos(a)*6.4,sin(a)*6.4,-26))
		surface.set_uv(Vector2(1,1))
		surface.add_vertex(Vector3(cos(b)*6.4,sin(b)*6.4,-26))
	surface.generate_normals()
	shaft = MeshInstance3D.new()
	shaft.name = "FacetedSearchlightShaft"
	shaft.mesh = surface.commit()
	shaft_material = ShaderMaterial.new()
	shaft_material.shader = preload("res://scenes/environment/sector_08/stylized/patrol_shaft.gdshader")
	shaft.material_override = shaft_material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(shaft)
	shaft.hide()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		lamp.light_energy = 0.0
		shaft.hide()
		return
	elapsed += delta
	var phase := fmod(elapsed,PERIOD)-START
	if phase < 0.0 or phase > DURATION:
		in_pass = false
		lamp.light_energy = 0.0
		shaft.hide()
		return
	if not in_pass:
		var run: Node = arena.get_parent().get_node_or_null("SurvivorRun")
		var player: Node3D = run.local_player() if run != null else null
		route_origin = player.global_position if is_instance_valid(player) else Vector3(-7,0,-9)
		route_origin.y = 0.0
		in_pass = true
	sample_pass(phase/DURATION,route_origin)

func sample_pass(progress: float, origin: Vector3) -> void:
	var t := clampf(progress,0.0,1.0)
	var aim := origin + Vector3(lerpf(-11.0,11.0,t),0,sin(t*PI)*3.0-1.5)
	# Near the study area the pass climbs the shelter instead of skating only
	# across the road. The same frozen route still applies for the whole event.
	if Vector2(origin.x-12.0,origin.z-16.0).length() < 15.0:
		aim = Vector3(12.0+lerpf(-9.0,9.0,t),1.0+sin(t*PI)*3.1,16.0+sin(t*PI)*0.8)
	lamp.global_position = origin + Vector3(lerpf(-15.0,13.0,t),23.0,-11.0)
	lamp.look_at(aim,Vector3.UP)
	lamp.light_energy = 180.0 * smoothstep(0.0,0.13,t) * (1.0-smoothstep(0.82,1.0,t))

	shaft.scale.z = lamp.global_position.distance_to(aim)/26.0
	shaft.visible = lamp.light_energy > 0.0
	shaft_material.set_shader_parameter("strength",lamp.light_energy/180.0)
