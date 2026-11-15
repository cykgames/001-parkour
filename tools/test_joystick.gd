extends Node
## Headless unit test: Joystick output math + driven input path + follow + release.
## The disc is MOUSE_FILTER_IGNORE; HUD drives press_at/drag_to/release_touch
## from _unhandled_input. This test exercises that API directly.
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

	# --- driven input path ---
	_joy = Joystick.new()
	_joy.size = Vector2(600, 480)
	_joy.home_center = Vector2(260, 250)
	add_child(_joy)
	_expect(_joy.mouse_filter == Control.MOUSE_FILTER_IGNORE, "disc is IGNORE (HUD routes touch)")

	# can_activate: generous zone OR 1.5x radius around the disc.
	_expect(_joy.can_activate(Vector2(100, 100)), "activate inside zone")
	_expect(_joy.can_activate(Vector2(590, 470)), "activate zone corner")
	_expect(_joy.can_activate(Vector2(260, 490)), "activate within 1.5R below disc (outside zone)")
	_expect(not _joy.can_activate(Vector2(260, 520)), "no activate beyond 1.5R outside zone")

	# press_at centers the disc under the finger.
	_joy.press_at(Vector2(260, 250), 0)
	_expect(_joy.active and _joy.touch_index() == 0, "press_at activates + tracks index")
	_expect(_joy.output == Vector2.ZERO, "center press = zero output")
	_expect(_joy.center().distance_to(Vector2(260, 250)) < 0.001, "disc centers under finger")

	# drag within knob travel: disc stays, output scales.
	_joy.drag_to(Vector2(368, 250))
	_expect(absf(_joy.output.x - 1.0) < 0.001 and absf(_joy.output.y) < 0.001, "drag right -> x=1")
	_expect(_joy.center().distance_to(Vector2(260, 250)) < 0.001, "disc stays within travel")
	_joy.drag_to(Vector2(260, 142))
	_expect(absf(_joy.output.y + 1.0) < 0.001, "drag up -> y=-1")
	_joy.drag_to(Vector2(260, 250))
	_expect(_joy.output == Vector2.ZERO, "back to center = zero")

	# FOLLOW: finger outruns the knob -> whole disc slides after it, output
	# keeps full magnitude (the "steering never drops" fix).
	_joy.drag_to(Vector2(600, 250))
	_expect(absf(_joy.output.x - 1.0) < 0.001, "follow: far right still x=1")
	_expect(_joy.center().distance_to(Vector2(492, 250)) < 0.001, "follow: disc moved after finger")
	_joy.drag_to(Vector2(900, 250))
	_expect(absf(_joy.output.x - 1.0) < 0.001, "follow: even farther still x=1")
	_expect(_joy.center().distance_to(Vector2(792, 250)) < 0.001, "follow: disc keeps tracking")

	# release zeroes output and clears the tracked index.
	_joy.release_touch()
	_expect(not _joy.active and _joy.output == Vector2.ZERO and _joy.touch_index() == -1, "release zeroes output")

	# force_release (used on pause) clears a held stick.
	_joy.press_at(Vector2(100, 100), 0)
	_joy.drag_to(Vector2(208, 100))
	_expect(_joy.active and absf(_joy.output.x - 1.0) < 0.001, "re-grab after release")
	_joy.force_release()
	_expect(not _joy.active and _joy.output == Vector2.ZERO, "force_release")

	# --- JumpButton enlarged circular hit area (1.5x graphic radius) ---
	var jb := JumpButton.new()
	jb.size = Vector2(330, 330)  # drawn disc radius 165; effective 247.5
	_expect(jb._has_point(Vector2(165, 165)), "jump center hit")
	_expect(jb._has_point(Vector2(165, -35)), "jump 200px above center hit (<247.5, outside graphic)")
	_expect(jb._has_point(Vector2(-75, 165)), "jump 240px left hit (<247.5, outside rect)")
	_expect(not jb._has_point(Vector2(165, -95)), "jump 260px above miss (>247.5)")
	_expect(not jb._has_point(Vector2(415, 165)), "jump 250px right miss (>247.5)")

	if _fails == 0:
		print("JOYSTICK_TEST_PASS")
	else:
		print("JOYSTICK_TEST_FAIL count=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)
