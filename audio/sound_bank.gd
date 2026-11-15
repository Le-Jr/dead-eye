class_name SoundBank
extends Resource
## Maps sound keys to lists of audio files; one is picked at random each time.
## Entries set here in the inspector win over the generated manifests, so any
## synthesised sound can be swapped for a recording without touching code.

@export var sounds: Dictionary = {}
@export var music: Dictionary = {}

var _streams := {}


func load_manifests() -> void:
	_merge("res://audio/sfx/manifest.json", sounds)
	_merge("res://audio/music/manifest.json", music)


func has_sound(key: StringName) -> bool:
	return not (sounds.get(String(key), []) as Array).is_empty()


func pick(key: StringName) -> AudioStream:
	var choices: Array = sounds.get(String(key), [])
	if choices.is_empty():
		return null
	return stream(choices.pick_random())


## Loads (once) and returns the stream at `path`.
func stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream
	return _streams[path]


func _merge(path: String, into: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for key: String in parsed:
			if not into.has(key):
				into[key] = parsed[key]
