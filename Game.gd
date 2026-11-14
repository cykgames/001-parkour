extends Node
## Autoload singleton: level index, best records (user://), headless flag.

const SAVE_PATH := "user://parkour_save.json"
const LEVEL_COUNT := 3

var level_index := 0
var headless := false
var records := {}


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	load_records()


func load_records() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		records = data


func best_for(idx: int) -> Dictionary:
	var r = records.get(str(idx), {})
	return r if r is Dictionary else {}


## Returns true if this result improved the stored record.
func save_level_result(idx: int, time: float, stars: int, coins: int) -> bool:
	var key := str(idx)
	var prev := best_for(idx)
	var improved := false
	if prev.is_empty() or time < float(prev.get("time", 1e9)):
		records[key] = {"time": time, "stars": stars, "coins": coins}
		improved = true
	elif stars > int(prev.get("stars", 0)):
		prev["stars"] = stars
		records[key] = prev
		improved = true
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(records))
	return improved
