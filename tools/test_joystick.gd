extends Node
## Headless unit test: Joystick output math + touch event path + release.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/test_joystick.tscn

var _fails := 0
var _joy: Joystick


func _expect(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("JOY_FAIL: ", what)


func _ready() -> void:
	# --- pure output math ---
	_expect(Joystick.compute_output(Vector2.ZERO) == Vector2.ZERO, "zero input")
	_expect(Joystick.compute_output(Vector2(10, 0)) == Vector2.ZERO, "deadzone 10px")
	_expect(Joystick.compute_output(Vector2(108, 0)).distance_to(Vector2(1, 0)) < 0.001, "full right")
	_expect(Joystick.compute_output(Vector2(-108, 0)).distance_to(Vector2(-1, 0)) < 0.001, "full left")
	_expect(Joystick.compute_output(Vector2(0, -108)).distance_to(Vector2(0, -1)) < 0.001, "y axis wired (future forward/back)")
	_expect(Joystick.compute_output(Vector2(300, 0)).distance_to(Vector2(1, 0)) < 0.001, "overtravel clamped")
	var diag := Joystick.compute_output(Vector2(54, 54))
	_expect(absf(diag.x - diag.y) < 0.001 and diag.length() > 0.6 and diag.length() < 0.75, "diagonal rescale")
	var prev := 0.0
	for i in range(0, 109, 3):
		var m := Joystick.compute_output(Vector2(i, 0)).x
		_expect(m >= prev - 0.0001, "monotonic at %d" % i)
		prev = m

	# --- event path ---
	_joy = Joystick.new()
	_joy.size = Vector2(600, 480)
	_joy.home_center = Vector2(260, 250)
	add_child(_joy)

	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = Vector2(260, 250)
	_joy._gui_input(down)
	_expect(_joy.active, "touch activates")
	_expect(_joy.output == Vector2.ZERO, "center press = zero output")

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(368, 250)
	_joy._gui_input(drag)
	_expect(absf(_joy.output.x - 1.0) < 0.001 and absf(_joy.output.y) < 0.001, "drag right -> x=1")

	drag.position = Vector2(260, 142)
	_joy._gui_input(drag)
	_expect(absf(_joy.output.y + 1.0) < 0.001, "drag up -> y=-1")

	# second finger must not steal the stick
	var down2 := InputEventScreenTouch.new()
	down2.index = 1
	down2.pressed = true
	down2.position = Vector2(50, 50)
	_joy._gui_input(down2)
	_expect(_joy.active and absf(_joy.output.y + 1.0) < 0.001, "second finger ignored")

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = Vector2(260, 142)
	_joy._gui_input(up)
	_expect(not _joy.active and _joy.output == Vector2.ZERO, "release zeroes output")

	# floating re-center clamps disc inside the zone
	down.position = Vector2(10, 10)
	_joy._gui_input(down)
	_expect(_joy._center.distance_to(Vector2(171, 171)) < 0.001, "floating center clamped")
	_joy.force_release()
	_expect(not _joy.active and _joy.output == Vector2.ZERO, "force_release")

	if _fails == 0:
		print("JOYSTICK_TEST_PASS")
	else:
		print("JOYSTICK_TEST_FAIL count=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)
