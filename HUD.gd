extends CanvasLayer
## HUD: timer + falls + touch buttons (left/right/jump) + win/fail labels.

var time := 0.0
var falls := 0
var running := true

@onready var time_label: Label = $TopBar/TimeLabel
@onready var fall_label: Label = $TopBar/FallLabel
@onready var msg_label: Label = $MsgLabel
@onready var player: CharacterBody3D = get_parent().get_node("Player")


func _ready() -> void:
	($TouchLeft as Button).button_down.connect(_on_left_down)
	($TouchLeft as Button).button_up.connect(_on_left_up)
	($TouchRight as Button).button_down.connect(_on_right_down)
	($TouchRight as Button).button_up.connect(_on_right_up)
	($TouchJump as Button).button_down.connect(_on_jump_down)
	($TouchJump as Button).button_up.connect(_on_jump_up)
	get_parent().get_node("LevelGen").finished.connect(_on_finished)


var _tick := 0

func _process(delta: float) -> void:
	_tick += 1
	if DisplayServer.get_name() == "headless" and _tick % 600 == 0:
		_report()
	if running:
		time += delta
		time_label.text = "TIME %05.1f" % time


func get_time() -> float:
	return time


func add_fall() -> void:
	falls += 1
	fall_label.text = "FALLS %d" % falls


func _on_left_down() -> void:
	player.input_left = true


func _on_left_up() -> void:
	player.input_left = false


func _on_right_down() -> void:
	player.input_right = true


func _on_right_up() -> void:
	player.input_right = false


func _on_jump_down() -> void:
	Input.action_press("jump")


func _on_jump_up() -> void:
	Input.action_release("jump")


func _report() -> void:
	print("HUDREPORT time=", time, " falls=", falls, " pos=", player.position, " running=", running)

func _on_finished(final_time: float) -> void:
	running = false
	player.win()
	msg_label.text = "FINISH! %05.1fs  FALLS %d" % [final_time, falls]
	msg_label.visible = true
