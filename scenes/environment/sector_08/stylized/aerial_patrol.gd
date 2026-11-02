## Cosmetic surveillance pass: the comuna's security drone crosses the depot low enough to be
## seen, a small quadcopter with a cold white gimbal lamp. World-fixed route sampled once per
## pass, never tracks or damages the player. Inherits pause and is freed with the district.
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
## The visible fixture: the drone body flies with the lamp; it is parked out of sight between passes.
var drone: Node3D
var strobe: StandardMaterial3D
## Low enough that the drone stays inside the gameplay frame while it sweeps.
const ALTITUDE := 8.0
const PEAK_ENERGY := 40.0

func setup(owner_arena: Node3D) -> void:
	arena = owner_arena
	process_mode = Node.PROCESS_MODE_PAUSABLE
	lamp = SpotLight3D.new()
	lamp.name = "AirborneSearchlight"
	add_child(lamp)
	lamp.light_color = Color("e4ecf0")
	lamp.light_specular = 0.0
	lamp.light_volumetric_fog_energy = 0.0
	lamp.spot_range = 30.0
	lamp.spot_angle = 17.0
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
		surface.add_vertex(Vector3(cos(a)*2.2,sin(a)*2.2,-26))
		surface.set_uv(Vector2(1,1))
		surface.add_vertex(Vector3(cos(b)*2.2,sin(b)*2.2,-26))
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
	build_drone()

## A municipal quadcopter: dark body, four arms with rotor discs, a white anti-collision strobe
## on top and the gimbal lamp underneath. No signal colours; it is a thing, not an enemy.
func build_drone() -> void:
	drone = Node3D.new()
	drone.name = "SecurityDrone"
	add_child(drone)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color("2e3336")
	shell.roughness = 0.6
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("9aa1a3")
	trim.roughness = 0.7
	var rotor := StandardMaterial3D.new()
	rotor.albedo_color = Color(0.12, 0.13, 0.14, 0.35)
	rotor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rotor.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color("e4ecf0")
	lens.emission_enabled = true
	lens.emission = Color("e4ecf0")
	lens.emission_energy_multiplier = 4.0
	strobe = lens.duplicate()
	for part: Array in [["Body",Vector3(0,0,0),Vector3(0.62,0.2,0.9),shell],["Battery",Vector3(0,0.14,0.05),Vector3(0.4,0.1,0.5),trim],
			["ArmA",Vector3(0,0,0),Vector3(1.7,0.07,0.09),shell],["ArmB",Vector3(0,0,0),Vector3(0.09,0.07,1.7),shell]]:
		var mesh := MeshInstance3D.new()
		mesh.name = part[0]
		var box := BoxMesh.new()
		box.size = part[2]
		mesh.mesh = box
		mesh.position = part[1]
		mesh.material_override = part[3]
		if part[0].begins_with("Arm"): mesh.rotation.y = PI * 0.25
		drone.add_child(mesh)
	for corner: int in 4:
		var angle: float = PI * 0.25 + float(corner) * PI * 0.5
		var disc := MeshInstance3D.new()
		disc.name = "Rotor%d" % corner
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.22
		cylinder.bottom_radius = 0.22
		cylinder.height = 0.02
		cylinder.radial_segments = 12
		disc.mesh = cylinder
		disc.material_override = rotor
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(sin(angle), 0.08, cos(angle)) * Vector3(0.6, 1, 0.6) + Vector3(0, 0.08, 0)
		drone.add_child(disc)
	var gimbal := MeshInstance3D.new()
	gimbal.name = "GimbalLamp"
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	gimbal.mesh = sphere
	gimbal.material_override = lens
	gimbal.position = Vector3(0, -0.16, -0.2)
	gimbal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drone.add_child(gimbal)
	var beacon := MeshInstance3D.new()
	beacon.name = "Strobe"
	var dot := BoxMesh.new()
	dot.size = Vector3(0.08, 0.05, 0.08)
	beacon.mesh = dot
	beacon.material_override = strobe
	beacon.position = Vector3(0, 0.22, -0.1)
	drone.add_child(beacon)
	drone.hide()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		lamp.light_energy = 0.0
		shaft.hide()
		drone.hide()
		return
	elapsed += delta
	var phase := fmod(elapsed,PERIOD)-START
	if phase < 0.0 or phase > DURATION:
		in_pass = false
		lamp.light_energy = 0.0
		shaft.hide()
		drone.hide()
		return
	if not in_pass:
		var run: Node = arena.get_parent().get_node_or_null("SurvivorRun")
		var player: Node3D = run.local_player() if run != null else null
		route_origin = player.global_position if is_instance_valid(player) else Vector3(-7,0,-9)
		# Fly over what the camera is looking at when the pass starts, so the drone that carries
		# the lamp is in frame even where the rig has stopped following the player.
		var eye: Camera3D = arena.get("gameplay_camera")
		if eye != null and eye.is_inside_tree():
			var forward: Vector3 = -eye.global_basis.z
			if forward.y < -0.05: route_origin = eye.global_position + forward * (-eye.global_position.y / forward.y)
		route_origin.y = 0.0
		in_pass = true
	sample_pass(phase/DURATION,route_origin)

func sample_pass(progress: float, origin: Vector3) -> void:
	var t := clampf(progress,0.0,1.0)
	var aim := origin + Vector3(lerpf(-11.0,11.0,t),0,sin(t*PI)*3.0-1.5)
	# The drone crosses the depot west to east a little behind the player, so its body stays in
	# the upper half of the frame while the gimbal swings the lamp across the floor.
	var flight := origin + Vector3(lerpf(-12.0,11.0,t),ALTITUDE+sin(t*TAU*1.5)*0.25,2.0)
	lamp.global_position = flight + Vector3(0,-0.2,0)
	lamp.look_at(aim,Vector3.UP)
	lamp.light_energy = PEAK_ENERGY * smoothstep(0.0,0.13,t) * (1.0-smoothstep(0.82,1.0,t))
	drone.global_position = flight
	var heading := Vector3(23.0,0.0,0.0)
	drone.rotation = Vector3(-0.12,atan2(-heading.x,-heading.z),sin(t*TAU)*0.05)
	drone.visible = t > 0.0 and t < 1.0
	strobe.emission_energy_multiplier = 6.0 if fmod(t*DURATION,1.1) < 0.08 else 0.0

	shaft.scale.z = lamp.global_position.distance_to(aim)/26.0
	shaft.visible = lamp.light_energy > 0.0
	shaft_material.set_shader_parameter("strength",lamp.light_energy/PEAK_ENERGY)
