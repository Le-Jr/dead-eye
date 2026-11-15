extends Node
## Plays the score. Each cue is three stems that start together and loop on
## the same sample, so they can be mixed live:
##   0 rhythm (always on)   1 melody   2 intensity
## `layers` holds the wanted level of each stem, 0..1. Gallery drives them
## from the combo, Free Range from style; modes may also call set_layer().

const LEVEL_DB := -7.0
const FADE_SPEED := 1.6  # layer units per second

var stems: Array[AudioStreamPlayer] = []
var current := ""
var layers: Array[float] = [1.0, 1.0, 1.0]

var _gains: Array[float] = []
var _retiring: Array[AudioStreamPlayer] = []
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.style_changed.connect(_on_style_changed)


## Crossfades to `cue`. Playing the cue that is already on does nothing.
func play(cue: String) -> void:
	if cue == current:
		return
	current = cue
	_retiring.append_array(stems)
	stems = []
	_gains = []
	match cue:
		"gallery": layers = [1.0, 0.35, 0.0]
		"town": layers = [1.0, 1.0, 0.3]
		"quick_draw": layers = [1.0, 1.0, 0.25]
		_: layers = [1.0, 1.0, 1.0]
	for path: String in AudioManager.bank.music.get(cue, []):
		var stream := AudioManager.bank.stream(path)
		if stream == null:
			continue
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = "Music"
		p.volume_db = -60.0
		add_child(p)
		stems.append(p)
		_gains.append(0.0)
	if not _silent:
		for p in stems:
			p.play()


## Sets how loud one stem should be, 0..1. It fades there.
func set_layer(index: int, amount: float) -> void:
	if index >= 0 and index < layers.size():
		layers[index] = clampf(amount, 0.0, 1.0)


## A one-shot musical phrase over whatever is playing.
func sting(cue: String) -> void:
	var paths: Array = AudioManager.bank.music.get(cue, [])
	if paths.is_empty() or _silent or AudioManager.quitting:
		return
	var p := AudioStreamPlayer.new()
	p.stream = AudioManager.bank.stream(paths[0])
	p.bus = "Music"
	p.volume_db = -3.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func stop() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
	stems.clear()
	_gains.clear()
	_retiring.clear()
	current = ""


func _process(delta: float) -> void:
	for i in stems.size():
		_gains[i] = move_toward(_gains[i], layers[i] if i < layers.size() else 1.0, delta * FADE_SPEED)
		stems[i].volume_db = LEVEL_DB + linear_to_db(maxf(_gains[i], 0.001))
	for i in range(_retiring.size() - 1, -1, -1):
		var old := _retiring[i]
		old.volume_db -= delta * 45.0
		if old.volume_db <= -60.0:
			old.queue_free()
			_retiring.remove_at(i)


func _on_combo_changed(combo: int, multiplier: float) -> void:
	if current == "gallery":
		# The tune comes in as a chain builds; the band joins with the multiplier.
		layers[1] = 0.35 + 0.65 * clampf(combo / 4.0, 0.0, 1.0)
		layers[2] = clampf(multiplier - 1.0, 0.0, 1.0)


func _on_style_changed(style: float) -> void:
	if current == "town":
		layers[2] = 0.3 + 0.7 * clampf(style - 1.0, 0.0, 1.0)
