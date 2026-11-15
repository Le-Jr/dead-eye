extends Node
## Local high scores and progress, stored as JSON in user://.
## One record per challenge id: best score, stars, play count, and whatever
## extra stats the mode put in its result.

signal record_changed(challenge_id: StringName)

const VERSION := 1

## Tests point this somewhere else so they never touch the real save.
var path := "user://save.json"

var _data := {"version": VERSION, "challenges": {}}


func _ready() -> void:
	load_save()


## The stored record for a challenge, or an empty Dictionary.
func get_record(challenge_id: StringName) -> Dictionary:
	return _data.challenges.get(String(challenge_id), {})


func get_stars(challenge_id: StringName) -> int:
	return int(get_record(challenge_id).get("stars", 0))


## Stores a finished run. `result` must contain "score" and may contain
## "stars" plus any other stats. Returns true if it is a new best.
func submit(challenge_id: StringName, result: Dictionary, lower_is_better := false) -> bool:
	var key := String(challenge_id)
	var record: Dictionary = _data.challenges.get(key, {})
	var plays := int(record.get("plays", 0)) + 1
	var best_stars := maxi(int(record.get("stars", 0)), int(result.get("stars", 0)))
	var score := float(result.get("score", 0))
	var is_best := not record.has("score")
	if not is_best:
		var old := float(record.score)
		is_best = score < old if lower_is_better else score > old
	if is_best:
		record = result.duplicate()
		record["date"] = Time.get_datetime_string_from_system(false, true)
	record["plays"] = plays
	record["stars"] = best_stars
	_data.challenges[key] = record
	save()
	record_changed.emit(challenge_id)
	return is_best


func clear() -> void:
	_data = {"version": VERSION, "challenges": {}}
	save()


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(_data, "\t"))


func load_save() -> void:
	_data = {"version": VERSION, "challenges": {}}
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("challenges") is Dictionary:
		_data.challenges = parsed.challenges
	else:
		push_warning("SaveSystem: %s is not a valid save; starting fresh" % path)
