extends CharacterBody3D
## Player: auto-run forward (-Z), analog joystick strafe + jump.
## Physics constants are MVP-validated (jump range 4.64m) -- do not retune.
## Block character + procedural run/jump animation + squash&stretch built in code.

const SPEED := 6.0
const STRAFE := 4.5
const GRAVITY := 22.0
const JUMP_VELOCITY := 8.5
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const KILL_Y := -12.0

signal jumped
signal landed
signal fell

## Analog stick input from the HUD joystick. x = strafe (-1..1), consumed
## below. y is already plumbed end-to-end and RESERVED for a future
## forward/back axis (e.g. speed bias); auto-run owns forward speed today.
var input_dir := Vector2.ZERO
var started := false
var autopilot := false
var _coyote := 0.0
var _buffer := 0.0
var _dead := false
var _last_checkpoint := Vector3(0, 2, 8)
var _ap_dir := 0.0
var _ap_brake := false
var _avoid_lane := 0.0
var _avoid_until_z := -1e20
var _last_dir := 0.0
var _squash := 0.0
var _anim_t := 0.0

@onready var level: Node3D = get_parent().get_node("LevelGen")
@onready var hud: CanvasLayer = get_parent().get_node("HUD")

var _visual: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _dust: CPUParticles3D


func _ready() -> void:
	add_to_group("player")
	autopilot = DisplayServer.get_name() == "headless"
	started = autopilot
	_build_visual()
	_build_dust()


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	return mi


func _build_visual() -> void:
	var skin := Color(0.90, 0.72, 0.50)
	var shirt := Color(0.25, 0.50, 0.85)
	var pants := Color(0.20, 0.22, 0.40)
	var hair := Color(0.35, 0.24, 0.14)
	var shoe := Color(0.15, 0.15, 0.18)
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.position = Vector3(0, -0.7, 0)
	add_child(_visual)
	# Legs (pivot at hip y=0.5)
	_leg_l = Node3D.new(); _leg_l.position = Vector3(-0.14, 0.5, 0); _visual.add_child(_leg_l)
	_leg_l.add_child(_box(Vector3(0.22, 0.5, 0.24), pants, Vector3(0, -0.25, 0)))
	_leg_l.add_child(_box(Vector3(0.24, 0.12, 0.30), shoe, Vector3(0, -0.46, -0.03)))
	_leg_r = Node3D.new(); _leg_r.position = Vector3(0.14, 0.5, 0); _visual.add_child(_leg_r)
	_leg_r.add_child(_box(Vector3(0.22, 0.5, 0.24), pants, Vector3(0, -0.25, 0)))
	_leg_r.add_child(_box(Vector3(0.24, 0.12, 0.30), shoe, Vector3(0, -0.46, -0.03)))
	# Torso
	_visual.add_child(_box(Vector3(0.56, 0.60, 0.32), shirt, Vector3(0, 0.80, 0)))
	# Arms (pivot at shoulder y=1.05)
	_arm_l = Node3D.new(); _arm_l.position = Vector3(-0.37, 1.05, 0); _visual.add_child(_arm_l)
	_arm_l.add_child(_box(Vector3(0.18, 0.50, 0.20), shirt, Vector3(0, -0.25, 0)))
	_arm_l.add_child(_box(Vector3(0.18, 0.12, 0.20), skin, Vector3(0, -0.52, 0)))
	_arm_r = Node3D.new(); _arm_r.position = Vector3(0.37, 1.05, 0); _visual.add_child(_arm_r)
	_arm_r.add_child(_box(Vector3(0.18, 0.50, 0.20), shirt, Vector3(0, -0.25, 0)))
	_arm_r.add_child(_box(Vector3(0.18, 0.12, 0.20), skin, Vector3(0, -0.52, 0)))
	# Head + hair + face (faces -Z)
	_visual.add_child(_box(Vector3(0.46, 0.46, 0.46), skin, Vector3(0, 1.33, 0)))
	_visual.add_child(_box(Vector3(0.48, 0.14, 0.48), hair, Vector3(0, 1.52, 0)))
	# Full hair back panel: from the chase cam the bare skin back of the head
	# read as a featureless face (looked like the runner faced backwards).
	_visual.add_child(_box(Vector3(0.48, 0.36, 0.10), hair, Vector3(0, 1.38, 0.20)))
	_visual.add_child(_box(Vector3(0.09, 0.09, 0.02), Color(0.12, 0.12, 0.2), Vector3(-0.10, 1.36, -0.235)))
	_visual.add_child(_box(Vector3(0.09, 0.09, 0.02), Color(0.12, 0.12, 0.2), Vector3(0.10, 1.36, -0.235)))


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.position = Vector3(0, -0.65, 0)
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 14
	_dust.lifetime = 0.45
	_dust.explosiveness = 1.0
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 180.0
	_dust.initial_velocity_min = 1.2
	_dust.initial_velocity_max = 2.6
	_dust.gravity = Vector3(0, -3, 0)
	_dust.scale_amount_min = 0.08
	_dust.scale_amount_max = 0.16
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.12)
	_dust.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.30)
	mat.vertex_color_use_as_albedo = false
	_dust.material_override = mat
	add_child(_dust)


func _physics_process(delta: float) -> void:
	if _dead or not started:
		return
	var was_on_floor := is_on_floor()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_coyote -= delta
	else:
		_coyote = COYOTE_TIME
	# Autopilot (headless validation)
	_ap_dir = 0.0
	_ap_brake = false
	if autopilot:
		_autopilot_think()
	# Jump buffer
	_buffer -= delta
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_squash = -0.25
		jumped.emit()
	# Auto-run forward, analog strafe from joystick/keys/autopilot
	velocity.z = 0.0 if _ap_brake else -SPEED
	var dir := clampf(input_dir.x, -1.0, 1.0)
	if Input.is_action_pressed("move_left"):
		dir -= 1.0
	if Input.is_action_pressed("move_right"):
		dir += 1.0
	dir = clampf(dir, -1.0, 1.0)
	if autopilot:
		dir = _ap_dir
		if not is_on_floor():
			dir = 0.0
	velocity.x = dir * STRAFE
	_last_dir = dir
	move_and_slide()
	position.x = clampf(position.x, -8.0, 8.0)
	# Track the last checkpoint actually reached while grounded, so a fall
	# respawns behind the player (not skipped forward by fall drift).
	if is_on_floor():
		_last_checkpoint = level.checkpoint_behind(position)
	# Landing detection
	if is_on_floor() and not was_on_floor:
		_squash = 0.35
		if _dust:
			_dust.restart()
		landed.emit()
	# Fell off
	if position.y < KILL_Y:
		respawn()


func _ray(sp: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return sp.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


func _autopilot_think() -> void:
	if not is_on_floor():
		return
	var sp := get_world_3d().direct_space_state
	var chest_y := position.y + 0.2
	# 1. Obstacle avoidance: commit to a lane until fully past the obstacle.
	if position.z < _avoid_until_z:
		_avoid_until_z = -1e20
		_avoid_lane = 0.0
	if _avoid_until_z > -1e19:
		_ap_dir = clampf(_avoid_lane - position.x, -1.0, 1.0)
		return
	var hit := _ray(sp, Vector3(position.x, chest_y, position.z - 0.2), Vector3(position.x, chest_y, position.z - 2.0))
	if not hit.is_empty():
		var lf := _ray(sp, Vector3(position.x - 1.1, chest_y, position.z - 0.2), Vector3(position.x - 1.1, chest_y, position.z - 2.0)).is_empty()
		var rf := _ray(sp, Vector3(position.x + 1.1, chest_y, position.z - 0.2), Vector3(position.x + 1.1, chest_y, position.z - 2.0)).is_empty()
		if rf:
			_avoid_lane = 1.1
		elif lf:
			_avoid_lane = -1.1
		else:
			_avoid_lane = 0.0
		_avoid_until_z = hit.position.z - 2.0
		_ap_dir = clampf(_avoid_lane - position.x, -1.0, 1.0)
		return
	# Drift back to center lane when path is clear.
	if absf(position.x) > 0.3:
		_ap_dir = -signf(position.x) * 0.6
	# 2. Gap / moving-platform logic.
	var fr := Vector3(position.x, position.y - 0.5, position.z - 0.3)
	var to := Vector3(position.x, position.y - 3.0, position.z - 0.3)
	if not _ray(sp, fr, to).is_empty():
		return # floor ahead, keep running
	var on_mover := _mover_under()
	if not on_mover.is_empty():
		# Riding a mover: brake, align to center lane, jump when mover near x=0.
		_ap_brake = true
		var mx: float = on_mover["body"].global_position.x
		var tx := clampf(0.0, mx - 1.1, mx + 1.1)
		_ap_dir = clampf(tx - position.x, -1.0, 1.0)
		if absf(mx) < 0.3 and absf(position.x) < 0.4:
			_buffer = JUMP_BUFFER
		return
	var next_mover = level.mover_ahead(position)
	if next_mover != null:
		# Static edge -> jump onto mover; track predicted landing x.
		_ap_brake = true
		var t_land := 2.0 * JUMP_VELOCITY / GRAVITY
		var px: float = next_mover["amp"] * sin(TAU * (level.time + t_land) / next_mover["period"] + next_mover["phase"])
		if absf(px) <= 1.5:
			_ap_dir = clampf(px - position.x, -1.0, 1.0)
			if absf(position.x - px) < 0.3:
				_buffer = JUMP_BUFFER
	else:
		_buffer = JUMP_BUFFER


func _mover_under() -> Dictionary:
	for m in level.movers:
		var mp: Vector3 = m["body"].global_position
		if absf(position.x - mp.x) < 1.7 and absf(position.z - mp.z) < 1.7 and position.y > -1.0 and position.y < 2.5:
			return m
	return {}


func _process(delta: float) -> void:
	if _visual == null:
		return
	_anim_t += delta
	var active := started and not _dead
	if is_on_floor() and active:
		var swing := sin(_anim_t * 13.0) * 0.75
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_arm_l.rotation.x = -swing * 0.8
		_arm_r.rotation.x = swing * 0.8
	elif not is_on_floor():
		_leg_l.rotation.x = 0.5
		_leg_r.rotation.x = -0.3
		_arm_l.rotation.x = -0.9
		_arm_r.rotation.x = -0.9
	else:
		_leg_l.rotation.x = 0.0
		_leg_r.rotation.x = 0.0
		_arm_l.rotation.x = 0.0
		_arm_r.rotation.x = 0.0
	_visual.rotation.z = lerpf(_visual.rotation.z, -_last_dir * 0.08, 0.2)
	# Squash & stretch spring back to rest.
	if absf(_squash) > 0.001:
		_squash = move_toward(_squash, 0.0, delta * 5.0)
		_visual.scale = Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.5)
	else:
		_visual.scale = Vector3.ONE


func respawn() -> void:
	var cp: Vector3 = _last_checkpoint
	position = cp
	velocity = Vector3.ZERO
	fell.emit()
	hud.add_fall()


func die() -> void:
	_dead = true
	velocity = Vector3.ZERO


func win() -> void:
	_dead = true
	velocity = Vector3.ZERO
