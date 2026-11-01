## Procedural geometry for programmable matter. Seeded by construct id, so every peer grows the
## same crystal from the same record. Collision never uses these: it stays the record's box.
extends RefCounted

## A wall of grown columns along local X, base at y = 0. COLOR.r carries a per-column random
## the ice shader uses to vary the growth ribs.
static func crystal_wall(size: Vector3, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var depth: float = maxf(size.z, 0.2) * 1.6
	# A compacted footing ties the columns into one wall.
	_prism(tool, Vector3(0, 0, 0), Vector2(size.x * 0.5 + 0.08, depth * 0.6), 0.34, 0.0, 10, 0.0, 0.5, rng)
	var columns: int = maxi(8, int(size.x / 0.24))
	for index: int in columns:
		var t: float = (float(index) + 0.5) / float(columns)
		var x: float = lerpf(-size.x * 0.5, size.x * 0.5, t) + rng.randf_range(-0.07, 0.07)
		# Taller toward the middle, ragged at both ends.
		var crown: float = 1.0 - pow(absf(t - 0.5) * 2.0, 3.0) * 0.35
		var height: float = size.y * crown * rng.randf_range(0.86, 1.06)
		var radius: float = rng.randf_range(0.17, 0.27)
		var lean: float = rng.randf_range(-0.09, 0.09)
		var tip: float = rng.randf_range(0.18, 0.42)
		_column(tool, Vector3(x, 0.0, rng.randf_range(-0.05, 0.05)), radius, depth * 0.5, height, tip, lean, rng.randf(), rng)
		# Secondary spurs between the main columns break the comb silhouette.
		if rng.randf() < 0.55:
			var spur_x: float = x + rng.randf_range(0.1, 0.2)
			_column(tool, Vector3(spur_x, 0.0, rng.randf_range(-0.08, 0.08)), radius * 0.55, depth * 0.35, height * rng.randf_range(0.35, 0.6), tip * 0.8, lean * 2.0 + rng.randf_range(-0.15, 0.15), rng.randf(), rng)
	tool.generate_normals()
	return tool.commit()

## A frozen puddle: an irregular slab with a bevelled crown and a few pressure ridges.
static func crystal_floe(size: Vector3, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 104729 + 7
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	_slab(tool, Vector2(size.x * 0.5, size.z * 0.5), maxf(size.y, 0.1), rng)
	for ridge: int in 3:
		var x: float = rng.randf_range(-size.x * 0.32, size.x * 0.32)
		var z: float = rng.randf_range(-size.z * 0.28, size.z * 0.28)
		_column(tool, Vector3(x, size.y * 0.6, z), rng.randf_range(0.08, 0.14), 0.1, rng.randf_range(0.12, 0.26), 0.08, rng.randf_range(-0.6, 0.6), rng.randf(), rng)
	tool.generate_normals()
	return tool.commit()

## One debris shard: a tapered, slightly twisted five-sided spike, centred on its origin.
static func shard(seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	_column(tool, Vector3(0, -0.22, 0), 0.11, 0.08, 0.32, 0.18, 0.1, rng.randf(), rng, 5)
	tool.generate_normals()
	return tool.commit()

static func _column(tool: SurfaceTool, base: Vector3, radius: float, depth_radius: float, height: float, tip: float, lean: float, tint: float, rng: RandomNumberGenerator, sides: int = 6) -> void:
	var ring_low: Array[Vector3] = []
	var ring_high: Array[Vector3] = []
	var twist: float = rng.randf() * TAU
	var shaft: float = maxf(height - tip, 0.05)
	var top_offset := Vector3(sin(lean) * shaft, 0.0, 0.0)
	for side: int in sides:
		var angle: float = twist + TAU * float(side) / float(sides)
		var wobble: float = rng.randf_range(0.82, 1.12)
		var offset := Vector3(cos(angle) * radius * wobble, 0.0, sin(angle) * minf(radius, depth_radius) * wobble)
		ring_low.append(base + offset)
		ring_high.append(base + offset * rng.randf_range(0.82, 0.95) + Vector3.UP * shaft * rng.randf_range(0.94, 1.0) + top_offset)
	var apex: Vector3 = base + Vector3.UP * height + top_offset * 1.15 + Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03))
	tool.set_color(Color(tint, 0, 0))
	for side: int in sides:
		var next: int = (side + 1) % sides
		_quad(tool, ring_low[side], ring_low[next], ring_high[next], ring_high[side])
		_tri(tool, ring_high[side], ring_high[next], apex)

static func _prism(tool: SurfaceTool, base: Vector3, half: Vector2, height: float, lean: float, sides: int, tint: float, taper: float, rng: RandomNumberGenerator) -> void:
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for side: int in sides:
		var angle: float = TAU * (float(side) + 0.5) / float(sides)
		var c: float = cos(angle)
		var s: float = sin(angle)
		# A squircle footprint, roughened.
		var x: float = signf(c) * pow(absf(c), 0.4) * half.x * rng.randf_range(0.95, 1.0)
		var z: float = signf(s) * pow(absf(s), 0.4) * half.y * rng.randf_range(0.85, 1.0)
		low.append(base + Vector3(x, 0.0, z))
		high.append(base + Vector3(x * lerpf(1.0, 0.92, taper), height, z * lerpf(1.0, 0.7, taper)))
	tool.set_color(Color(tint, 0, 0))
	for side: int in sides:
		var next: int = (side + 1) % sides
		_quad(tool, low[side], low[next], high[next], high[side])
	var centre: Vector3 = base + Vector3.UP * height
	for side: int in sides:
		_tri(tool, high[side], high[(side + 1) % sides], centre)

static func _slab(tool: SurfaceTool, half: Vector2, height: float, rng: RandomNumberGenerator) -> void:
	var count: int = 18
	var low: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var c: float = cos(angle)
		var s: float = sin(angle)
		var radius: float = rng.randf_range(0.86, 1.0)
		var x: float = signf(c) * pow(absf(c), 0.55) * half.x * radius
		var z: float = signf(s) * pow(absf(s), 0.55) * half.y * radius
		low.append(Vector3(x, 0.0, z))
		mid.append(Vector3(x * 0.93, height, z * 0.9))
	var crown := Vector3(rng.randf_range(-0.2, 0.2), height * 1.35, rng.randf_range(-0.2, 0.2))
	tool.set_color(Color(rng.randf(), 0, 0))
	for index: int in count:
		var next: int = (index + 1) % count
		_quad(tool, low[index], low[next], mid[next], mid[index])
		_tri(tool, mid[index], mid[next], crown)

static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Wound so the face points away from the shape's interior for the outward-facing rings above.
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(tool, a, b, c)
	_tri(tool, a, c, d)
