extends Node3D
## LevelGen: procedural Minecraft-style voxel course.
## One StaticBody3D, one ArrayMesh per 16m chunk, surface faces only.
## Course: start pad + 8 strips (35m) + 7 gaps (2.0m -> 4.5m) + finish.
## Forward = -Z. Total ~300m, ~60s at 6 m/s.

const VOXEL := 1.0
const CHUNK := 16.0
const WIDTH := 4.0
const STRIP_LEN := 35.0
const GAPS := [2.0, 2.5, 3.0, 3.5, 3.8, 4.0, 4.0]
const TOP_Y := 0.0
const THICK := 1.0
const KILL_Y := -12.0

const COL_GRASS := Color(0.35, 0.75, 0.25)
const COL_DIRT := Color(0.45, 0.30, 0.15)
const COL_GOLD := Color(1.0, 0.8, 0.2)

var spawn_point := Vector3(0, 2, 8)
var goal_z := 0.0
var checkpoints: Array[Vector3] = []

signal finished(final_time: float)


func _ready() -> void:
	var boxes := _build_layout()
	_build_collision(boxes)
	_build_chunk_meshes(boxes)
	_build_finish_gate()
	_build_light()


func _build_layout() -> Array:
	# Each box: {min: Vector3, size: Vector3, gold: bool}
	var boxes: Array = []
	var z := 10.0 # start pad front edge
	# Start pad 6x6
	boxes.append({"min": Vector3(-3, TOP_Y - THICK, z - 6.0), "size": Vector3(6, THICK, 6), "gold": false})
	checkpoints.append(Vector3(0, TOP_Y + 1.5, z - 3.0))
	z -= 6.0
	for i in range(GAPS.size() + 1):
		var length := STRIP_LEN
		var w := WIDTH
		var gold := false
		if i == GAPS.size():
			length = 10.0 # finish pad
			w = 6.0
			gold = true
		var z_end := z - length
		boxes.append({"min": Vector3(-w / 2.0, TOP_Y - THICK, z_end), "size": Vector3(w, THICK, length), "gold": gold})
		checkpoints.append(Vector3(0, TOP_Y + 1.5, z - 2.0))
		z = z_end
		if i < GAPS.size():
			z -= float(GAPS[i])
	goal_z = z + 5.0
	return boxes


func _build_collision(boxes: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	add_child(body)
	for b in boxes:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b["size"]
		col.shape = shape
		col.position = b["min"] + b["size"] / 2.0
		body.add_child(col)


func _build_chunk_meshes(boxes: Array) -> void:
	# Bucket top-face quads per chunk; sides only on box borders.
	var chunk_quads := {}
	for b in boxes:
		var mn: Vector3 = b["min"]
		var sz: Vector3 = b["size"]
		var gold: bool = b["gold"]
		var nx := int(sz.x / VOXEL)
		var nz := int(sz.z / VOXEL)
		for ix in range(nx):
			for iz in range(nz):
				var x0 := mn.x + ix * VOXEL
				var z0 := mn.z + iz * VOXEL
				var key := _chunk_key(x0, z0)
				if not chunk_quads.has(key):
					chunk_quads[key] = []
				(chunk_quads[key] as Array).append({"x0": x0, "z0": z0, "gold": gold})
		# Border sides for this box (4 skirts)
		var key0 := _chunk_key(mn.x, mn.z)
		if not chunk_quads.has(key0):
			chunk_quads[key0] = []
		(chunk_quads[key0] as Array).append({"side": true, "box_min": mn, "box_size": sz, "gold": gold})
	for key in chunk_quads:
		_build_single_mesh(key, chunk_quads[key])


func _chunk_key(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / CHUNK)), int(floor(z / CHUNK)))


func _build_single_mesh(key: Vector2i, quads: Array) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for q in quads:
		if q.has("side"):
			_emit_sides(verts, normals, colors, q["box_min"], q["box_size"], q["gold"])
		else:
			_emit_top(verts, normals, colors, q["x0"], q["z0"], q["gold"])
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Chunk_%d_%d" % [key.x, key.y]
	mi.mesh = mesh
	add_child(mi)


func _emit_top(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, x0: float, z0: float, gold: bool) -> void:
	var y := TOP_Y
	var c := COL_GOLD if gold else COL_GRASS
	var a := Vector3(x0, y, z0)
	var b := Vector3(x0 + VOXEL, y, z0)
	var cc := Vector3(x0 + VOXEL, y, z0 + VOXEL)
	var d := Vector3(x0, y, z0 + VOXEL)
	var n := Vector3.UP
	# Two triangles, CCW from above
	verts.append_array([a, b, cc, a, cc, d])
	for i in range(6):
		normals.append(n)
		colors.append(c)


func _emit_sides(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, mn: Vector3, sz: Vector3, gold: bool) -> void:
	var c := COL_GOLD if gold else COL_DIRT
	var y0 := mn.y
	var y1 := mn.y + sz.z * 0.0 + THICK # top of slab
	y1 = TOP_Y
	var x0 := mn.x
	var x1 := mn.x + sz.x
	var z0 := mn.z
	var z1 := mn.z + sz.z
	# 4 skirts, outward normals
	_quads(verts, normals, colors, [Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1)], Vector3.LEFT, c)
	_quads(verts, normals, colors, [Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, c)
	_quads(verts, normals, colors, [Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1)], Vector3.BACK, c)
	_quads(verts, normals, colors, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], Vector3.FORWARD, c)


func _quads(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, corners: Array, n: Vector3, c: Color) -> void:
	verts.append_array([corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])
	for i in range(6):
		normals.append(n)
		colors.append(c)


func _build_finish_gate() -> void:
	var area := Area3D.new()
	area.name = "GoalArea"
	area.position = Vector3(0, TOP_Y + 1.5, goal_z)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 3, 1)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(_on_goal_entered)
	add_child(area)
	# Two gold pillars so the finish is visible
	for px in [-3.0, 3.0]:
		var pillar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 4.0, 0.6)
		pillar.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COL_GOLD
		pillar.material_override = mat
		pillar.position = Vector3(px, TOP_Y + 2.0, goal_z)
		add_child(pillar)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.name = "Env"
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.6, 1.0)
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.3)
	sky.sky_material = sky_mat
	sky_mat.ground_horizon_color = Color(0.6, 0.7, 0.8)
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	add_child(env)


func _on_goal_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		finished.emit(_race_time())


func _race_time() -> float:
	var hud := get_node_or_null("../HUD")
	if hud != null and hud.has_method("get_time"):
		return hud.get_time()
	return 0.0


func nearest_checkpoint(pos: Vector3) -> Vector3:
	# Course runs toward -Z. Passed checkpoints have LARGER z than player.
	var best: Vector3 = spawn_point
	var best_z := -1e20
	for c in checkpoints:
		if c.z > pos.z + 1.0:
			continue # not reached yet
		if c.z > best_z:
			best_z = c.z
			best = c
	return best
