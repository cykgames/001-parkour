extends Node
## Rendered finish-screen proof: instances the REAL Main scene, calls
## show_finish() with a 3-star result, captures landscape 1280x720 and
## portrait 1080x2340 frames to build/hud_finish_*.png.
## Run (windowed): Godot... --path . res://tools/shot_finish.tscn

var _main: Node
var _f := 0


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	get_window().size = Vector2i(1280, 720)
	_main = load("res://Main.tscn").instantiate()
	add_child(_main)


func _process(_d: float) -> void:
	_f += 1
	var hud := _main.get_node("HUD")
	if _f == 20:
		hud.show_finish(3, 34.3, 25, 0, {"time": 34.3}, false, true)
	if _f == 40:
		_snap("build/hud_finish_landscape.png")
	if _f == 45:
		get_window().size = Vector2i(1080, 2340)
	if _f == 80:
		_snap("build/hud_finish_portrait.png")
		print("FINISH_SHOTS_DONE")
		get_tree().quit(0)


func _snap(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
