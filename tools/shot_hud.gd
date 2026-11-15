extends Node
## Rendered UI proof: instances the REAL Main scene, captures idle /
## deflected / released joystick frames to build/hud_joy_*.png.
## Run (windowed): Godot... --path . --resolution 1280x720 res://tools/shot_hud.tscn

var _main: Node
var _f := 0


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().size = Vector2i(1280, 720)
	_main = load("res://Main.tscn").instantiate()
	add_child(_main)


func _process(_d: float) -> void:
	_f += 1
	var joy: Joystick = _main.get_node("HUD")._joy
	if _f == 20:
		_snap("build/hud_joy_idle.png")
	if _f == 25:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.pressed = true
		down.position = Vector2(190, 250)
		joy._gui_input(down)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = Vector2(290, 220)
		joy._gui_input(drag)
	if _f == 40:
		_snap("build/hud_joy_active.png")
	if _f == 55:
		joy.force_release()
	if _f == 80:
		_snap("build/hud_joy_released.png")
		print("HUD_SHOTS_DONE")
		get_tree().quit(0)


func _snap(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
