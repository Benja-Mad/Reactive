## A continuous transit apron and inhabited perimeter. All massing stays beyond the
## existing side boundaries; paving is a visual skin, not another physics floor.
extends "res://scenes/environment/sector_08/stylized/service_architecture.gd"
const PAINT = preload("res://scenes/environment/sector_08/stylized/painted_surface.gdshader")

func flat_paint(hex: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINT
	m.set_shader_parameter("paint", Color(hex))
	m.set_shader_parameter("pavement", true)
	m.set_shader_parameter("south_pavement", true)
	return m

func paving(id: String, points: PackedVector2Array, hex: String, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	for i: int in indices:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(points[i].x, height, points[i].y))
	var mesh := MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = surface.commit()
	mesh.material_override = flat_paint(hex)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func setup_district(lo: Vector2, hi: Vector2) -> void:
	# One continuous surface. Road, boarding strip and joints are colours in
	# the same material, never intersecting planes laid over rotated paving.
	var clip := PackedVector2Array([lo, Vector2(hi.x,lo.y), hi, Vector2(lo.x,hi.y)])
	var paving_basis := Basis(Vector3.UP,deg_to_rad(34.38))
	var points := PackedVector2Array()
	for p: Vector2 in [Vector2(-100,-5),Vector2(100,-5),Vector2(100,100),Vector2(-100,100)]:
		var world: Vector3 = Vector3(12,0,16) + paving_basis * Vector3(p.x,0,p.y)
		points.append(Vector2(world.x,world.z))
	for polygon: PackedVector2Array in Geometry2D.intersect_polygons(points,clip):
		paving("SouthDistrictPavement",polygon,"696a63",0.018)
	# Lateral service buildings face the district; their staggered upper floors
	# frame a continuation of the street without occluding the southern court.
	for side: float in [-1,1]:
		var boundary: float = hi.x if side > 0 else -lo.x
		var block := anchor("TransitReturnEast" if side > 0 else "TransitReturnWest",Vector3(side*(boundary+5.0),0,-6 if side > 0 else 8),0)
		var wall := material("4a4f4e" if side > 0 else "524f4a",0.03)
		var trim := material("6b6e69",0.03)
		var recess := material("212628",0.015)
		box(block,Vector3(0,3.4,0),Vector3(8,6.8,11),wall)
		# Recessed loading doorway and a deep cantilever, readable without lettering.
		box(block,Vector3(0,1.65,5.52),Vector3(4.4,3.3,0.08),recess)
		box(block,Vector3(0,3.55,5.95),Vector3(5.6,0.24,1.3),trim)
		for x: float in [-2.4,2.4]:
			box(block,Vector3(x,1.65,5.62),Vector3(0.24,3.3,0.3),trim)
		# A bare tube under the loading canopy; the old orange and violet spots are gone.
		fixture(block,Vector3(0,3.36,6.10),"cfe6d2",0.5,1.2)
		# Upper gallery and roof services share large, deliberate pixel-scale shapes.
		box(block,Vector3(0,4.5,5.72),Vector3(7.5,0.22,0.65),trim)
		for x: float in [-2.7,-0.9,0.9,2.7]:
			box(block,Vector3(x,5.3,5.54),Vector3(1.2,1.0,0.07),recess)
			box(block,Vector3(x,5.35,5.59),Vector3(0.9,0.55,0.04),material("bfcdbf" if x < 0 else "b89a70",0.25))
		box(block,Vector3(0,6.85,0),Vector3(8.4,0.25,11.4),trim)
		box(block,Vector3(side*0.9,7.5,-1),Vector3(3.4,1.2,3.0),wall)
		# A higher, inset second volume makes a layered silhouette, not a block pile.
		var upper := anchor("TransitUpperEast" if side > 0 else "TransitUpperWest",Vector3(side*(boundary+10.5),0,-19 if side > 0 else -5),0)
		box(upper,Vector3(0,6.4,0),Vector3(8,12.8,9),material("3a4244",0.03))
		box(upper,Vector3(0,12.9,0),Vector3(8.3,0.2,9.3),material("50585a",0.03))
		for y: float in [7.4,9.3,11.2]:
			box(upper,Vector3(0,y,4.52),Vector3(6.2,0.65,0.05),material("c9a76f" if y < 9.0 else "2a2f31",0.2 if y < 9.0 else 0.0))
