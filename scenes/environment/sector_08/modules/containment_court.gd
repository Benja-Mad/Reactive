## Fixed handmade placement; repeated pressure ribs are construction detail, not random rooms.
## Bases and low partitions have matching collision; openings remain walkable.
extends Node3D
var ceramic: ShaderMaterial
var iron: StandardMaterial3D
var brass: StandardMaterial3D
var clay: StandardMaterial3D

func _ready() -> void:
	ceramic = ShaderMaterial.new()
	ceramic.shader = preload("res://scenes/environment/sector_08/modules/ceramic.gdshader")
	iron = _material(Color(0.065,0.085,0.08),0.8)
	brass = _material(Color(0.38,0.25,0.105),0.65)
	clay = _material(Color(0.24,0.14,0.095),0.95)
	# A broken sequence of gates marks two traversable service routes. Silhouette first.
	_gate(Vector3(-15,0,5),-0.24,1.0)
	_gate(Vector3(-15,0,11),-0.24,0.86)
	_gate(Vector3(12,0,16),0.6,1.15)
	# Staggered partitions: cover with flanking gaps, not a sealed corridor.
	_partition(Vector3(-6,0,9),-0.25,4.5)
	_partition(Vector3(5,0,13),0.40,5.2)
	_partition(Vector3(-1,0,22),-0.12,3.6)
	# Dry ceramic service islands, inset at floor level, leave broad circulation between them.
	for centre: Vector3 in [Vector3(-15,0,8),Vector3(12,0,17)]:
		for x in 5:
			for z in 7:
				var offset := Vector3((x-2)*1.3,0.08,(z-3)*1.05)
				_box(self,centre+offset,Vector3(1.25,0.045,1),ceramic if (x+z)%4 else clay)
	# Service stacks anchor the rear of the south district; lower foreground stays open.
	for index in 3:
		var root := Node3D.new()
		root.position = Vector3(21+index*2.5,0,6+index*0.7)
		add_child(root)
		_box(root,Vector3(0,1.5,0),Vector3(1.7,3,1.8),iron,true)
		for rib in 5:
			_box(root,Vector3(0,0.45+rib*0.58,0),Vector3(2.0,0.22,2.1),ceramic)
		_box(root,Vector3(0.0,1.5,1.07),Vector3(0.13,2.5,0.08),brass)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

func _box(parent: Node3D, centre: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = centre
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		visual.add_child(body)
	return visual

func _gate(origin: Vector3, yaw: float, size: float) -> void:
	var root := Node3D.new()
	root.position = origin
	root.rotation.y = yaw
	root.scale = Vector3.ONE*size
	add_child(root)
	for side: float in [-1.0,1.0]:
		_box(root,Vector3(side*2.65,0.65,0),Vector3(1.1,1.3,1.7),clay,true)
		_box(root,Vector3(side*2.65,2.0,0),Vector3(0.45,3.0,0.85),iron,true)
		for rib in 5:
			var plate: MeshInstance3D = _box(root,Vector3(side*(2.7-rib*0.05),1.5+rib*0.53,0),Vector3(0.9,0.3,1.35),ceramic)
			plate.rotation.z = side*0.12
		var shoulder := _box(root,Vector3(side*1.9,4.15,0),Vector3(1.8,0.55,1.25),ceramic)
		shoulder.rotation.z = side*0.48
		_box(root,Vector3(side*2.7,1.1,0.87),Vector3(0.7,0.14,0.08),brass)
	# Open crown with a physical tension bar, not a floating decorative rune.
	_box(root,Vector3(0,4.55,0),Vector3(2.7,0.16,0.3),iron)
	_box(root,Vector3(-0.5,4.55,0),Vector3(0.2,0.4,0.65),brass)

func _partition(origin: Vector3, yaw: float, length: float) -> void:
	var root := Node3D.new()
	root.position = origin
	root.rotation.y = yaw
	add_child(root)
	_box(root,Vector3(0,0.7,0),Vector3(length,1.4,0.6),iron,true)
	for index in 7:
		var x: float = (index-3)*length/7.0
		var plate := _box(root,Vector3(x,0.75,0),Vector3(length/7.0-0.055,1.45,0.78),ceramic)
		plate.rotation.z = 0.025*sin(float(index)*2.4)
	_box(root,Vector3(0,0.36,0.41),Vector3(length,0.09,0.08),brass)
