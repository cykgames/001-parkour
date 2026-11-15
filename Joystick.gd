class_name Joystick
extends Control
## Floating virtual joystick disc. Touch anywhere inside the zone: the disc
## re-centers under the finger, drag to steer, release to spring back.
## Output is a FULL Vector2 (-1..1 per axis, radial deadzone):
##   x = strafe (consumed by Player.input_dir.x today)
##   y = reserved for a future forward/back axis (not consumed yet)
## so the same pad can later become a 4-way stick without input rework.

signal activated
signal released

const RADIUS := 165.0
const KNOB_RADIUS := 72.0
const KNOB_MAX := 108.0
const DEADZONE := 0.12

var output := Vector2.ZERO
var active := false
var home_center := Vector2(190, 250)
var _center := Vector2(190, 250)
var _knob := Vector2.ZERO
var _touch := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = home_center


## Pure mapping knob-offset -> normalized output (radial deadzone + rescale).
static func compute_output(d: Vector2) -> Vector2:
	var mag := d.length() / KNOB_MAX
	if mag <= DEADZONE:
		return Vector2.ZERO
	var m := clampf((mag - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	return d.normalized() * m


func force_release() -> void:
	if _touch != -1 or active:
		_release()


func _release() -> void:
	_touch = -1
	active = false
	output = Vector2.ZERO
	released.emit()
	queue_redraw()


func _clamp_center(p: Vector2) -> Vector2:
	var pad := RADIUS + 6.0
	return Vector2(
		clampf(p.x, pad, maxf(pad, size.x - pad)),
		clampf(p.y, pad, maxf(pad, size.y - pad)))


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch == -1:
			_touch = touch.index
			active = true
			_center = _clamp_center(touch.position)
			_knob = Vector2.ZERO
			output = Vector2.ZERO
			activated.emit()
			queue_redraw()
			accept_event()
		elif not touch.pressed and touch.index == _touch:
			_release()
			accept_event()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _touch:
		var d := drag.position - _center
		if d.length() > KNOB_MAX:
			d = d.normalized() * KNOB_MAX
		_knob = d
		output = compute_output(d)
		queue_redraw()
		accept_event()


func _process(delta: float) -> void:
	if active:
		return
	var moved := false
	if _knob.length() > 0.5:
		_knob = _knob.move_toward(Vector2.ZERO, delta * 900.0)
		moved = true
	elif _knob != Vector2.ZERO:
		_knob = Vector2.ZERO
		moved = true
	if _center.distance_to(home_center) > 0.5:
		_center = _center.move_toward(home_center, delta * 1200.0)
		moved = true
	elif _center != home_center:
		_center = home_center
		moved = true
	if moved:
		queue_redraw()


func _arrow(c: Vector2, dir: Vector2, col: Color) -> void:
	var tip := c + dir * (RADIUS - 26.0)
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		tip,
		tip - dir * 22.0 + side * 16.0,
		tip - dir * 22.0 - side * 16.0,
	])
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var c := _center
	var base_a := 0.82 if active else 0.55
	var rim_a := 0.9 if active else 0.45
	# Deep navy disc + light rim (matches HUD v2 dark buttons).
	draw_circle(c, RADIUS, Color(0.07, 0.10, 0.16, base_a))
	draw_arc(c, RADIUS - 2.0, 0.0, TAU, 64, Color(0.85, 0.92, 1.0, rim_a), 4.0, true)
	# Travel guide ring.
	draw_arc(c, KNOB_MAX, 0.0, TAU, 48, Color(1, 1, 1, 0.10), 2.0, true)
	# Axis hints: E/W bright (strafe live now), N/S dim (future axes).
	_arrow(c, Vector2.RIGHT, Color(1, 1, 1, 0.85))
	_arrow(c, Vector2.LEFT, Color(1, 1, 1, 0.85))
	_arrow(c, Vector2.UP, Color(1, 1, 1, 0.28))
	_arrow(c, Vector2.DOWN, Color(1, 1, 1, 0.28))
	# Knob: electric blue while held, slate at rest.
	var kc := c + _knob
	var knob_col := Color(0.10, 0.34, 0.72, 0.95) if active else Color(0.16, 0.22, 0.34, 0.90)
	var knob_rim := 0.85 if active else 0.50
	draw_circle(kc, KNOB_RADIUS, knob_col)
	draw_arc(kc, KNOB_RADIUS - 2.0, 0.0, TAU, 48, Color(1, 1, 1, knob_rim), 3.0, true)
	draw_circle(kc - Vector2(18, 20), 14.0, Color(1, 1, 1, 0.18))
