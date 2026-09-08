## Facade-scale advertising screen along the lower edge of the frame.
##
## Two jobs. Compositionally it closes the bottom of the shot with a surface instead of more
## pavement, which is what sells the yard as somewhere elevated: you read the top of a screen on
## a block below rather than ground running to the frame edge. Lighting-wise it is a broad
## magenta source under a scene of cyan and sodium, throwing colour up onto the near railing and
## the yard lip, which is a hue the district otherwise only has in the corruption light.
##
## It is world geometry, so it parallaxes correctly and stays put while the player walks. Its
## placement is derived once from the approved framing, because "covers the bottom band of the
## P30 frame" is a screen-space requirement that would be guesswork to hand-place in metres.
extends Node3D

## Where the top edge of the screen should land in the frame, as a fraction of frame height.
const TOP_EDGE_UV := 0.878
## Distance from the camera along that ray. Nearer than the pavement the bottom edge otherwise
## shows (65-75 m) and nearer than the cable tray (75 m), so it reads as the closest thing there.
const DISTANCE := 58.0
const WIDTH := 96.0
const HEIGHT := 34.0
## Depth of the parapet cap. Without it the screen is a floating rectangle rather than the top of
## a structure that continues below the frame.
const CAP_DEPTH := 1.1

var screen: MeshInstance3D
var material: ShaderMaterial
var spill: OmniLight3D
var placement: Dictionary = {}


func setup(camera: Camera3D) -> void:
	var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
	var sample := Vector2(viewport.x * 0.5, viewport.y * TOP_EDGE_UV)
	var origin: Vector3 = camera.project_ray_origin(sample)
	var direction: Vector3 = camera.project_ray_normal(sample)
	var top_centre: Vector3 = origin + direction * DISTANCE

	# Vertical panel facing the camera on the horizontal plane, so it stays a believable facade
	# rather than a plate tilted to chase the lens.
	var facing: Vector3 = -Vector3(direction.x, 0.0, direction.z).normalized()
	var right: Vector3 = Vector3.UP.cross(facing).normalized()

	global_position = top_centre
	global_basis = Basis(right, Vector3.UP, facing)

	material = ShaderMaterial.new()
	material.shader = preload("res://scenes/environment/sector_08/runtime/sector_08_billboard.gdshader")
	material.resource_name = "CS_facade_screen"
	# Deliberately dim for an emissive of this size: it fills a tenth of the frame, so anything
	# near full brightness reads as the subject of the shot instead of as depth behind the yard.
	material.set_shader_parameter("brightness", 0.34)
	material.set_shader_parameter("screen_tint", Vector3(0.40, 0.13, 0.60))
	material.set_shader_parameter("accent_tint", Vector3(0.78, 0.24, 0.62))
	material.set_shader_parameter("panel_rows", 19.0)
	material.set_shader_parameter("panel_columns", 21.0)

	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	screen = MeshInstance3D.new()
	screen.name = "FacadeScreen"
	screen.mesh = quad
	screen.material_override = material
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)
	# Hangs below its top edge, which is the only part inside the frame.
	screen.position = Vector3(0.0, -HEIGHT * 0.5, 0.0)

	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color(0.045, 0.05, 0.062)
	cap_material.roughness = 0.62
	cap_material.metallic = 0.35
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(WIDTH, 0.42, CAP_DEPTH)
	var cap := MeshInstance3D.new()
	cap.name = "ParapetCap"
	cap.mesh = cap_mesh
	cap.material_override = cap_material
	add_child(cap)
	cap.position = Vector3(0.0, 0.21, -CAP_DEPTH * 0.35)

	# Bounce back into the yard. Deliberately weak: the board is a rim and a hue, not a key.
	spill = OmniLight3D.new()
	spill.name = "FacadeScreenSpill"
	spill.light_color = Color(0.72, 0.30, 0.92)
	spill.light_energy = 2.9
	spill.omni_range = 17.0
	spill.omni_attenuation = 1.9
	spill.light_specular = 0.25
	spill.light_volumetric_fog_energy = 0.18
	spill.shadow_enabled = false
	add_child(spill)
	spill.position = Vector3(0.0, 2.4, 5.0)

	placement = {
		"top_centre": str(top_centre.snappedf(0.01)),
		"distance_m": DISTANCE,
		"top_edge_uv": TOP_EDGE_UV,
		"size_m": str(Vector2(WIDTH, HEIGHT)),
		"spill_energy": spill.light_energy,
		"brightness": 0.34,
	}


## Same supply curve as every other emitter in the district, plus corruption driving the panel
## break-up, so the board is part of the reactive world rather than set dressing bolted on top.
func sync_state(values: Dictionary) -> void:
	if material == null:
		return
	var supply: float = clampf(float(values.get("power", 0.92)) / 0.92, 0.0, 1.1)
	supply *= 1.0 - 0.9 * clampf(float(values.get("blackout_amount", 0.0)), 0.0, 1.0)
	material.set_shader_parameter("supply", supply)
	material.set_shader_parameter("corruption", clampf(float(values.get("corruption", 0.0)), 0.0, 1.0))
	spill.light_energy = 2.9 * supply


func get_report() -> Dictionary:
	var report: Dictionary = placement.duplicate()
	report["supply"] = material.get_shader_parameter("supply")
	report["spill_energy_now"] = snappedf(spill.light_energy, 0.01)
	return report
