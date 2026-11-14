extends CanvasLayer
## HUD: timer/coins/falls/level, touch buttons, start/pause/finish panels,
## star rating, best record, red fall flash. All UI built in code.

signal run_started

var time := 0.0
var falls := 0
var coins := 0
var running := false
var started := false
var finished := false
var paused := false
var _is_last := false
var _coin_total := 0
var _tick := 0

var _level_label: Label
var _time_label: Label
var _coin_label: Label
var _fall_label: Label
var _msg_label: Label
var _star_label: Label
var _best_label: Label
var _center_button: Button
var _restart_button: Button
var _pause_button: Button
var _pause_panel: ColorRect
var _flash: ColorRect

@onready var player: CharacterBody3D = get_parent().get_node("Player")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	msg_label_set("TAP TO START")
	_center_button.text = "START"
	_center_button.visible = true
	if DisplayServer.get_name() == "headless":
		start_run()


func _mk_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _mk_button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.16)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(1, 1, 1, 0.34)
	sbp.set_corner_radius_all(14)
	sbp.set_content_margin_all(10)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover", sbp)
	return b


func _centered(ctrl: Control, top: float, bottom: float, half_w: float = 320.0) -> void:
	ctrl.set_anchors_preset(Control.PRESET_CENTER)
	ctrl.offset_left = -half_w
	ctrl.offset_right = half_w
	ctrl.offset_top = top
	ctrl.offset_bottom = bottom


func _build_ui() -> void:
	# Top bar background + labels
	var topbg := ColorRect.new()
	topbg.color = Color(0, 0, 0, 0.35)
	topbg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topbg.offset_bottom = 58.0
	topbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(topbg)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18.0
	bar.offset_right = -18.0
	bar.offset_top = 8.0
	bar.offset_bottom = 54.0
	bar.add_theme_constant_override("separation", 26)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	_level_label = _mk_label("L1", 28)
	_time_label = _mk_label("TIME 000.0", 30)
	_coin_label = _mk_label("COIN 0/0", 30)
	_fall_label = _mk_label("FALLS 0", 30)
	bar.add_child(_level_label)
	bar.add_child(_time_label)
	bar.add_child(_coin_label)
	bar.add_child(_fall_label)
	_pause_button = _mk_button("II", 26)
	_pause_button.custom_minimum_size = Vector2(56, 44)
	_pause_button.pressed.connect(toggle_pause)
	bar.add_child(_pause_button)

	# Center message / stars / best / buttons
	_msg_label = _mk_label("", 52)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centered(_msg_label, -170, -100)
	add_child(_msg_label)
	_star_label = _mk_label("", 62)
	_star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_centered(_star_label, -85, -10)
	_star_label.visible = false
	add_child(_star_label)
	_best_label = _mk_label("", 28)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centered(_best_label, 0, 40)
	_best_label.visible = false
	add_child(_best_label)
	_center_button = _mk_button("START", 46)
	_centered(_center_button, 60, 140, 240)
	_center_button.pressed.connect(_on_center_pressed)
	add_child(_center_button)
	_restart_button = _mk_button("RESTART", 30)
	_centered(_restart_button, 160, 212, 160)
	_restart_button.pressed.connect(_on_restart_pressed)
	_restart_button.visible = false
	add_child(_restart_button)

	# Touch controls (bottom corners)
	var tl := _mk_button("L", 60)
	tl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tl.offset_left = 40; tl.offset_right = 190
	tl.offset_top = -160; tl.offset_bottom = -30
	tl.button_down.connect(_on_left_down); tl.button_up.connect(_on_left_up)
	add_child(tl)
	var tr := _mk_button("R", 60)
	tr.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tr.offset_left = 210; tr.offset_right = 360
	tr.offset_top = -160; tr.offset_bottom = -30
	tr.button_down.connect(_on_right_down); tr.button_up.connect(_on_right_up)
	add_child(tr)
	var tj := _mk_button("J", 60)
	tj.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tj.offset_left = -230; tj.offset_right = -40
	tj.offset_top = -160; tj.offset_bottom = -30
	tj.button_down.connect(_on_jump_down); tj.button_up.connect(_on_jump_up)
	add_child(tj)

	# Red fall flash (full screen, ignored by mouse)
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.1, 0.1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# Pause panel
	_pause_panel = ColorRect.new()
	_pause_panel.color = Color(0, 0, 0, 0.6)
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	add_child(_pause_panel)
	var pv := VBoxContainer.new()
	pv.set_anchors_preset(Control.PRESET_CENTER)
	pv.offset_left = -160; pv.offset_right = 160
	pv.offset_top = -120; pv.offset_bottom = 120
	pv.add_theme_constant_override("separation", 18)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_panel.add_child(pv)
	var pl := _mk_label("PAUSED", 48)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pl)
	var resume := _mk_button("RESUME", 36)
	resume.pressed.connect(toggle_pause)
	pv.add_child(resume)
	var prestart := _mk_button("RESTART", 32)
	prestart.pressed.connect(_on_restart_pressed)
	pv.add_child(prestart)


func msg_label_set(text: String) -> void:
	_msg_label.text = text
	_msg_label.visible = true


func set_level_info(lname: String, coin_total: int) -> void:
	_coin_total = coin_total
	_level_label.text = "L%d %s" % [Game.level_index + 1, lname]
	_coin_label.text = "COIN 0/%d" % coin_total


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
	if running:
		time += delta
		_time_label.text = "TIME %05.1f" % time
	_tick += 1
	if DisplayServer.get_name() == "headless" and _tick % 600 == 0:
		print("HUDREPORT level=", Game.level_index, " time=", snappedf(time, 0.1), " falls=", falls, " coins=", coins, " pos=", player.position)


func get_time() -> float:
	return time


func add_fall() -> void:
	falls += 1
	_fall_label.text = "FALLS %d" % falls


func add_coin() -> void:
	coins += 1
	_coin_label.text = "COIN %d/%d" % [coins, _coin_total]


func flash_red() -> void:
	_flash.color = Color(1, 0.1, 0.1, 0.45)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.4)


func start_run() -> void:
	if started:
		return
	started = true
	running = true
	player.started = true
	_msg_label.visible = false
	_center_button.visible = false
	run_started.emit()


func toggle_pause() -> void:
	if not started or finished:
		return
	paused = not paused
	get_tree().paused = paused
	_pause_panel.visible = paused
	running = not paused


func show_finish(stars: int, t: float, pcoins: int, pfalls: int, best: Dictionary, is_last: bool, improved: bool) -> void:
	finished = true
	running = false
	_is_last = is_last
	msg_label_set("LEVEL CLEAR!")
	_star_label.text = "*".repeat(stars) + "-".repeat(3 - stars)
	_star_label.visible = true
	var bt := ""
	if improved:
		bt = "NEW RECORD!  "
	if not best.is_empty():
		bt += "BEST %05.1fs" % float(best.get("time", 0.0))
	_best_label.text = bt
	_best_label.visible = true
	_center_button.text = "PLAY AGAIN" if is_last else "NEXT LEVEL"
	_center_button.visible = true
	_restart_button.visible = true


func _on_center_pressed() -> void:
	if finished:
		if _is_last:
			Game.level_index = 0
		else:
			Game.level_index += 1
		_reload()
	elif not started:
		start_run()


func _on_restart_pressed() -> void:
	_reload()


func _reload() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_left_down() -> void:
	if not started:
		start_run()
	player.input_left = true


func _on_left_up() -> void:
	player.input_left = false


func _on_right_down() -> void:
	if not started:
		start_run()
	player.input_right = true


func _on_right_up() -> void:
	player.input_right = false


func _on_jump_down() -> void:
	if not started:
		start_run()
	Input.action_press("jump")


func _on_jump_up() -> void:
	Input.action_release("jump")
