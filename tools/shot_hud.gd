extends Node
## Rendered UI proof: instances the REAL Main scene and drives the joystick via
## the driven API (press_at/drag_to -- the disc is MOUSE_FILTER_IGNORE, HUD owns
## touch routing). Captures idle / normal-deflection / WIDE-drag / released
## frames to build/hud_joy_*.png. The WIDE frame proves the anchored fix: the
## finger goes far beyond the zone but the disc stays near home (lean <=
## MAX_DRIFT) while the knob pins at the rim and output stays full magnitude.
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
		joy.press_at(Vector2(190, 250), 0)  # home -> activates + auto-starts
		joy.drag_to(Vector2(290, 220))      # normal deflection within reach
	if _f == 40:
		_snap("build/hud_joy_active.png")
	if _f == 45:
		# WIDE: finger far right, well beyond the 600px zone. Disc must stay
		# near home (lean caps at MAX_DRIFT), knob pinned right, output x=1.
		joy.drag_to(Vector2(760, 250))
	if _f == 60:
		_snap("build/hud_joy_wide.png")
		print("WIDE center=", joy.center(), " home=", joy.home_center,
			" drift=", snappedf(joy.center().distance_to(joy.home_center), 0.1),
			" MAX_DRIFT=", Joystick.MAX_DRIFT, " output=", joy.output)
	if _f == 75:
		joy.force_release()
	if _f == 100:
		_snap("build/hud_joy_released.png")
		print("HUD_SHOTS_DONE")
		get_tree().quit(0)


func _snap(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
