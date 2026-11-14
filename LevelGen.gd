extends Node3D
## Procedural voxel course, 3 themed levels. Forward = -Z.
## Static terrain: one StaticBody3D + chunked ArrayMesh (vertex colors).
## Moving platforms: AnimatableBody3D (sync_to_physics). Coins: Area3D.
## Physics-relevant geometry keeps MVP jump range (4.64m) valid: static gaps <= 4.0m.

const VOXEL := 1.0
const CHUNK := 16.0
const TOP_Y := 0.0
const THICK := 1.0
const MOVER_GAP := 6.5
const MOVER_SIZE := 3.0

const LEVELS := [
	{
		"name": "GRASSLAND", "width": 4.0, "strip_len": 30.0,
		"gaps": [2.0, 2.5, 3.0, 3.2, 3.5, 3.5], "movers": [], "obstacles": 2, "par": 50.0,
		"grass": Color(0.35, 0.75, 0.25), "dirt": Color(0.45, 0.30, 0.15),
		"stone": Color(0.55, 0.55, 0.58), "mover_col": Color(0.7, 0.5, 0.2),
		"sky_top": Color(0.30, 0.55, 0.95), "sky_horizon": Color(0.65, 0.78, 0.92),
		"sun": Color(1.0, 0.96, 0.85), "sun_rot": Vector3(-50, -30, 0),
	},
	{
		"name": "CANYON", "width": 4.0, "strip_len": 30.0,
		"gaps": [2.5, 3.0, 3.5, 3.8, 4.0, 4.0], "movers": [2, 4], "obstacles": 4, "par": 58.0,
		"grass": Color(0.85, 0.62, 0.32), "dirt": Color(0.60, 0.38, 0.18),
		"stone": Color(0.70, 0.45, 0.28), "mover_col": Color(0.45, 0.30, 0.55),
		"sky_top": Color(0.85, 0.45, 0.25), "sky_horizon": Color(0.95, 0.72, 0.45),
		"sun": Color(1.0, 0.80, 0.55), "sun_rot": Vector3(-35, -45, 0),
	},
	{
		"name": "FROST", "width": 3.0, "strip_len": 28.0,
		"gaps": [3.0, 3.5, 3.8, 4.0, 4.0, 4.0], "movers": [1, 3, 5], "obstacles": 0, "par": 62.0,
		"grass": Color(0.78, 0.88, 0.98), "dirt": Color(0.45, 0.55, 0.70),
		"stone": Color(0.60, 0.70, 0.82), "mover_col": Color(0.30, 0.65, 0.80),
		"sky_top": Color(0.10, 0.14, 0.30), "sky_horizon": Color(0.35, 0.45, 0.65),
		"sun": Color(0.75, 0.85, 1.0), "sun_rot": Vector3(-60, 20, 0),
	},
]

var cfg: Dictionary
var spawn_point := Vector3(0, 2, 8)
var goal_z := 0.0
var checkpoints: Array[Vector3] = []
var movers: Array = []
var coin_total := 0
var time := 0.0

var _strips: Array = []
var _gapinfo: Array = []
var _obstacle_positions: Array = []
var _terrain_body: StaticBody3D
var _col_grass: Color
var _col_dirt: Color

signal finished(final_time: float)
signal coin_taken(pos: Vector3)


func _ready() -> void:
	cfg = LEVELS[clampi(Game.level_index, 0, LEVELS.size() - 1)]
	_col_grass = cfg["grass"]
	_col_dirt = cfg["dirt"]
	var boxes := _build_layout()
	_build_collision(boxes)
	_build_chunk_meshes(boxes)
	_build_obstacles()
	_build_movers()
	_build_coins()
	_build_finish_gate()
	_build_light()


func _box(x: float, zmin: float, w: float, length: float, gold: bool) -> Dictionary:
	return {"min": Vector3(x, TOP_Y - THICK, zmin), "size": Vector3(w, THICK, length), "gold": gold}


func _build_layout() -> Array:
	var boxes: Array = []
	var w: float = cfg["width"]
	var sl: float = cfg["strip_len"]
	var gaps: Array = cfg["gaps"]
	var mover_idx: Array = cfg["movers"]
	var z := 10.0
	# Start pad 6x6
	boxes.append(_box(-3.0, z - 6.0, 6.0, 6.0, false))
	checkpoints.append(Vector3(0, TOP_Y + 1.5, z - 3.0))
	_strips.append({"z0": z, "z1": z - 6.0, "w": 6.0, "start": true})
	z -= 6.0
	for i in range(gaps.size() + 1):
		var length := sl
		var bw := w
		var gold := false
		if i == gaps.size():
			length = 10.0
			bw = 6.0
			gold = true
		var z_end := z - length
		boxes.append(_box(-bw / 2.0, z_end, bw, length, gold))
		checkpoints.append(Vector3(0, TOP_Y + 1.5, z - 2.0))
		_strips.append({"z0": z, "z1": z_end, "w": bw, "idx": i, "finish": gold})
		z = z_end
		if i < gaps.size():
			var is_mover: bool = mover_idx.has(i)
			var g: float = MOVER_GAP if is_mover else float(gaps[i])
			_gapinfo.append({"z_edge": z, "gap": g, "mover": is_mover, "i": i})
			z -= g
	goal_z = z + 5.0
	return boxes


func _build_collision(boxes: Array) -> void:
	_terrain_body = StaticBody3D.new()
	_terrain_body.name = "TerrainBody"
	add_child(_terrain_body)
	for b in boxes:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b["size"]
		col.shape = shape
		col.position = b["min"] + b["size"] / 2.0
		_terrain_body.add_child(col)


func _build_chunk_meshes(boxes: Array) -> void:
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
	var c := Color(1.0, 0.8, 0.2) if gold else _col_grass
	var a := Vector3(x0, y, z0)
	var b := Vector3(x0 + VOXEL, y, z0)
	var cc := Vector3(x0 + VOXEL, y, z0 + VOXEL)
	var d := Vector3(x0, y, z0 + VOXEL)
	var n := Vector3.UP
	verts.append_array([a, b, cc, a, cc, d])
	for i in range(6):
		normals.append(n)
		colors.append(c)


func _emit_sides(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, mn: Vector3, sz: Vector3, gold: bool) -> void:
	var c := Color(1.0, 0.8, 0.2) if gold else _col_dirt
	var y0 := mn.y
	var y1 := TOP_Y
	var x0 := mn.x
	var x1 := mn.x + sz.x
	var z0 := mn.z
	var z1 := mn.z + sz.z
	_quads(verts, normals, colors, [Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1)], Vector3.LEFT, c)
	_quads(verts, normals, colors, [Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, c)
	_quads(verts, normals, colors, [Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1)], Vector3.BACK, c)
	_quads(verts, normals, colors, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], Vector3.FORWARD, c)


func _quads(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, corners: Array, n: Vector3, c: Color) -> void:
	verts.append_array([corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])
	for i in range(6):
		normals.append(n)
		colors.append(c)


func _build_obstacles() -> void:
	var count: int = cfg["obstacles"]
	if count <= 0:
		return
	var eligible: Array = []
	for s in _strips:
		if s.get("start", false) or s.get("finish", false):
			continue
		if float(s["w"]) >= 4.0:
			eligible.append(s)
	var n := mini(count, eligible.size())
	for k in range(n):
		var s: Dictionary = eligible[k]
		var oz := (float(s["z0"]) + float(s["z1"])) / 2.0
		var pos := Vector3(0, TOP_Y + 0.5, oz)
		_obstacle_positions.append(pos)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1, 1, 1)
		col.shape = sh
		col.position = pos
		_terrain_body.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 1, 1)
		mi.mesh = bm
		mi.position = pos
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cfg["stone"]
		mat.roughness = 0.95
		mi.material_override = mat
		add_child(mi)


func _build_movers() -> void:
	for g in _gapinfo:
		if not g["mover"]:
			continue
		var ze: float = g["z_edge"]
		var body := AnimatableBody3D.new()
		body.name = "Mover_%d" % int(g["i"])
		body.sync_to_physics = true
		body.position = Vector3(0, TOP_Y - THICK / 2.0, ze - 4.0)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(MOVER_SIZE, THICK, MOVER_SIZE)
		col.shape = sh
		body.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(MOVER_SIZE, THICK, MOVER_SIZE)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cfg["mover_col"]
		mat.roughness = 0.7
		mi.material_override = mat
		body.add_child(mi)
		add_child(body)
		movers.append({"body": body, "amp": 2.0, "period": 3.5, "phase": float(g["i"]) * 1.3, "z": ze - 4.0})
		# A coin riding on the platform.
		_spawn_coin(body, Vector3(0, THICK / 2.0 + 1.0, 0))


func _obstacle_near(z: float) -> bool:
	for p in _obstacle_positions:
		if absf(p.z - z) < 2.5:
			return true
	return false


func _build_coins() -> void:
	for s in _strips:
		if s.get("start", false):
			continue
		var z0: float = s["z0"]
		var z1: float = s["z1"]
		var zz := z0 - 4.0
		while zz > z1 + 2.0:
			var cx := 0.0
			if _obstacle_near(zz):
				cx = 1.2
			_spawn_coin(self, Vector3(cx, TOP_Y + 1.0, zz))
			zz -= 7.0


func _spawn_coin(parent: Node3D, lpos: Vector3) -> void:
	var coin := Area3D.new()
	coin.set_script(load("res://Coin.gd"))
	coin.position = lpos
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.55
	col.shape = sh
	coin.add_child(col)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.35
	cm.height = 0.08
	cm.radial_segments = 16
	mi.mesh = cm
	mi.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.42, 0.05)
	mat.metallic = 0.6
	mat.roughness = 0.3
	mi.material_override = mat
	coin.add_child(mi)
	coin.collected.connect(_on_coin_collected)
	parent.add_child(coin)
	coin_total += 1


func _on_coin_collected(pos: Vector3) -> void:
	coin_taken.emit(pos)


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
	for px in [-3.0, 3.0]:
		var pillar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 4.0, 0.6)
		pillar.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.3, 0.05)
		pillar.material_override = mat
		pillar.position = Vector3(px, TOP_Y + 2.0, goal_z)
		add_child(pillar)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = cfg["sun_rot"]
	sun.light_color = cfg["sun"]
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.name = "Env"
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = cfg["sky_top"]
	sky_mat.ground_horizon_color = cfg["sky_horizon"]
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.28)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = cfg["sky_horizon"]
	e.fog_density = 0.006
	env.environment = e
	add_child(env)


func _physics_process(delta: float) -> void:
	time += delta
	for m in movers:
		m["body"].position.x = m["amp"] * sin(TAU * time / m["period"] + m["phase"])


func _on_goal_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		finished.emit(_race_time())


func _race_time() -> float:
	var hud := get_node_or_null("../HUD")
	if hud != null and hud.has_method("get_time"):
		return hud.get_time()
	return 0.0


func mover_ahead(pos: Vector3) -> Variant:
	for m in movers:
		var mz: float = m["z"]
		if mz < pos.z and pos.z - mz < 9.0:
			return m
	return null


## Nearest checkpoint at/behind the player (last one reached). Forward = -Z,
## so "behind" means c.z >= pos.z; pick the smallest such z (most advanced).
func checkpoint_behind(pos: Vector3) -> Vector3:
	var best: Vector3 = spawn_point
	var best_z := 1e20
	for c in checkpoints:
		if c.z >= pos.z and c.z < best_z:
			best_z = c.z
			best = c
	return best


func nearest_checkpoint(pos: Vector3) -> Vector3:
	var best: Vector3 = spawn_point
	var best_z := -1e20
	for c in checkpoints:
		if c.z > pos.z + 1.0:
			continue
		if c.z > best_z:
			best_z = c.z
			best = c
	return best
