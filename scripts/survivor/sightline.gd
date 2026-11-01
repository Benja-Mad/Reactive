## Keeps the local operator readable: scenery standing between the camera and the player fades out.
## Local presentation only; nothing here is replicated or touches collision.
extends Node
## Scenery whose top is below this height (floor, kerbs, low cover) never blocks the view.
const MIN_TOP: float = 2.2
## Single meshes this wide are the district's outer shell (backdrop, viaduct): they never fade.
## Instanced shells (the perimeter fence and walls) are judged piece by piece instead.
const MAX_SPAN: float = 50.0
## Past this span a box says little about a diagonal pipe or tray: test the real triangles.
const COARSE_SPAN: float = 4.0
## Radius of the sight corridor around the camera-to-player line, in metres.
const CORRIDOR: float = 1.6
const FADED: float = 0.82
var run: Node
var arena: Node3D
var _candidates: Array[Dictionary] = []
var _faded: Dictionary = {}
## Instanced pieces cannot fade alone, so a blocking piece is collapsed and later put back.
var _pieces: Array[Dictionary] = []
var _hidden: Dictionary = {}
var _check_in: float = 0.0
var _initial_collection_complete: bool = false

func _ready() -> void:
	# The arena finishes dressing itself on deferred calls; collect once that has settled.
	await get_tree().create_timer(0.6).timeout
	_collect(arena)
	_initial_collection_complete = true

func register_environment_extension(node: Node) -> void:
	# Early additions are covered by the initial arena scan; late preview additions
	# need their own scan. Never register the same early scenery twice.
	if _initial_collection_complete:
		_collect(node)

func _collect(node: Node) -> void:
	for child: Node in node.get_children():
		if child == arena.gameplay_camera: continue
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh != null:
			_collect_pieces(child as MultiMeshInstance3D)
		elif child is MeshInstance3D:
			var instance := child as GeometryInstance3D
			var box: AABB = instance.global_transform * instance.get_aabb()
			var span: float = maxf(box.size.x, box.size.z)
			if box.end.y >= MIN_TOP and box.size.length() > 0.01 and span < MAX_SPAN:
				var candidate: Dictionary = {"node": instance, "box": box.grow(CORRIDOR)}
				if span > COARSE_SPAN and instance is MeshInstance3D and (instance as MeshInstance3D).mesh != null:
					candidate["triangles"] = (instance as MeshInstance3D).mesh.generate_triangle_mesh()
				_candidates.append(candidate)
		_collect(child)

func _collect_pieces(holder: MultiMeshInstance3D) -> void:
	var multimesh: MultiMesh = holder.multimesh
	if multimesh.mesh == null or multimesh.transform_format != MultiMesh.TRANSFORM_3D: return
	var shape: AABB = multimesh.mesh.get_aabb()
	for index: int in multimesh.visible_instance_count if multimesh.visible_instance_count >= 0 else multimesh.instance_count:
		var placed: Transform3D = multimesh.get_instance_transform(index)
		var box: AABB = holder.global_transform * placed * shape
		if box.end.y >= MIN_TOP:
			_pieces.append({"holder": holder, "index": index, "placed": placed, "box": box.grow(CORRIDOR * 0.5)})

func _process(delta: float) -> void:
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = 0.08
		_refresh()
	for instance: GeometryInstance3D in _faded.keys():
		if not is_instance_valid(instance):
			_faded.erase(instance)
			continue
		var goal: float = FADED if _faded[instance] else 0.0
		instance.transparency = move_toward(instance.transparency, goal, delta * 5.0)
		if goal == 0.0 and instance.transparency == 0.0: _faded.erase(instance)

func _refresh() -> void:
	var player: Character = run.local_player()
	var camera: Camera3D = arena.gameplay_camera
	if player == null or camera == null: return
	var eye: Vector3 = camera.global_position
	# The body's origin is the capsule centre; the worker figure stands on the ground below it.
	var worker: Node3D = player.get_node_or_null("ShiftWorker")
	var feet: Vector3 = worker.global_position + Vector3.UP * 0.1 if worker != null else player.global_position - Vector3.UP * 0.9
	var head: Vector3 = feet + Vector3.UP * (float(worker.height) - 0.05 if worker != null and "height" in worker else 2.3)
	var side: Vector3 = camera.global_basis.x * CORRIDOR
	var targets: Array[Vector3] = [head, feet + Vector3.UP * 0.3, head + side, head - side, feet + side, feet - side]
	for instance: GeometryInstance3D in _faded.keys(): _faded[instance] = false
	for candidate: Dictionary in _candidates:
		var box: AABB = candidate["box"]
		if box.intersects_segment(eye, head) or box.intersects_segment(eye, feet):
			var instance: GeometryInstance3D = candidate["node"]
			if not is_instance_valid(instance) or not instance.is_visible_in_tree(): continue
			# Only what sits between the camera and the player: not the building behind them.
			if camera.global_basis.z.dot(eye - box.get_center()) > camera.global_basis.z.dot(eye - feet) + box.size.length() * 0.5: continue
			if candidate.has("triangles") and not _hits(candidate["triangles"], instance.global_transform.affine_inverse(), eye, targets): continue
			_faded[instance] = true
	var blocking: Dictionary = {}
	var depth: float = camera.global_basis.z.dot(eye - feet)
	for piece: Dictionary in _pieces:
		var box: AABB = piece["box"]
		if not (box.intersects_segment(eye, head) or box.intersects_segment(eye, feet)): continue
		if camera.global_basis.z.dot(eye - box.get_center()) > depth + box.size.length() * 0.5: continue
		blocking[piece] = true
		if not _hidden.has(piece):
			_hidden[piece] = true
			var placed: Transform3D = piece["placed"]
			(piece["holder"] as MultiMeshInstance3D).multimesh.set_instance_transform(piece["index"], Transform3D(placed.basis.scaled(Vector3.ONE * 0.0001), placed.origin))
	for piece: Dictionary in _hidden.keys():
		if blocking.has(piece): continue
		_hidden.erase(piece)
		if is_instance_valid(piece["holder"]):
			(piece["holder"] as MultiMeshInstance3D).multimesh.set_instance_transform(piece["index"], piece["placed"])

func _hits(triangles: TriangleMesh, to_local: Transform3D, eye: Vector3, targets: Array[Vector3]) -> bool:
	if triangles == null: return false
	var from: Vector3 = to_local * eye
	for target: Vector3 in targets:
		if not triangles.intersect_segment(from, to_local * target).is_empty(): return true
	return false
