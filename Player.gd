extends CharacterBody3D
## Player: auto-run forward (-Z), touch left/right + jump.
## Tune ONE group at a time: GRAVITY / JUMP_VELOCITY / COYOTE_TIME.

const SPEED := 6.0
const STRAFE := 4.5
const GRAVITY := 22.0
const JUMP_VELOCITY := 8.5
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const KILL_Y := -12.0

var input_left := false
var input_right := false
var _coyote := 0.0
var _buffer := 0.0
var _dead := false
var autopilot := false

@onready var level: Node3D = get_parent().get_node("LevelGen")
@onready var hud: CanvasLayer = get_parent().get_node("HUD")


func _ready() -> void:
	add_to_group("player")
	autopilot = DisplayServer.get_name() == "headless"


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_coyote -= delta
	else:
		_coyote = COYOTE_TIME
	# Autopilot (headless validate): jump when no floor 0.3m ahead
	if autopilot and is_on_floor():
		var sp := get_world_3d().direct_space_state
		var fr := Vector3(position.x, position.y - 0.5, position.z - 0.3)
		var to := Vector3(position.x, position.y - 3.0, position.z - 0.3)
		if sp.intersect_ray(PhysicsRayQueryParameters3D.create(fr, to)).is_empty():
			_buffer = JUMP_BUFFER

	# Jump buffer
	_buffer -= delta
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
	# Auto-run forward, strafe from touch/keys
	velocity.z = -SPEED
	var dir := 0.0
	if Input.is_action_pressed("move_left") or input_left:
		dir -= 1.0
	if Input.is_action_pressed("move_right") or input_right:
		dir += 1.0
	velocity.x = dir * STRAFE
	move_and_slide()
	# Clamp lateral inside course
	position.x = clampf(position.x, -8.0, 8.0)
	# Fell off
	if position.y < KILL_Y:
		respawn()


func respawn() -> void:
	var cp: Vector3 = level.nearest_checkpoint(position)
	position = cp
	velocity = Vector3.ZERO
	hud.add_fall()


func die() -> void:
	_dead = true
	velocity = Vector3.ZERO


func win() -> void:
	_dead = true
	velocity = Vector3.ZERO
