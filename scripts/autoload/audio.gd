extends Node
## Audio · the sound effects (GDD › Presentation and Platforms, Audio: stroke, splash and guy
## noises for the comedy; the hazard telegraph sounds are T26's).
##
## Keeps a pool of AudioStreamPlayers on the Sfx bus and plays the WAVs in assets/audio/
## (tools/gen_audio.gd makes them) by name with play(). Listens to RunState: a stroke landing
## plays the swoosh and that seat's guy's grunt (one pitch per guy), a fumble the plop, a jump
## the splash, a pickup the blip and a beer going overboard the clink. The buses are
## assets/audio/default_bus_layout.tres (Master → Sfx, Music for later). master_volume sets the
## Master bus and lives only here: the GDD leaves player settings open, so there is no settings
## file yet. Inert during the check, and safe without an audio device: on the dummy driver the
## players just play nothing. Reads and writes no player data.

const MASTER_BUS: StringName = &"Master"
const SFX_BUS: StringName = &"Sfx"
## Sounds that can play at once; a further play() takes the player started longest ago.
const POOL_SIZE: int = 8
## Linear gain of the Master bus until player settings exist. ## PLACEHOLDER
const DEFAULT_MASTER_VOLUME: float = 0.8
## The stroke swoosh varies this much in pitch either way, so four paddles don't sound like one.
const STROKE_PITCH_SPREAD: float = 0.08

const AUDIO_DIR: String = "res://assets/audio"
## The sounds, each AUDIO_DIR/<name>.wav. Loaded at _ready rather than preloaded: the import
## pass instantiates autoloads before it has imported a new WAV, so a parse-time preload fails
## on a fresh clone's first import.
const SOUNDS: Array[StringName] = [
	&"stroke", &"fumble", &"splash", &"pickup", &"beer_over",
	&"guy_grunt_0", &"guy_grunt_1", &"guy_grunt_2", &"guy_grunt_3",
]
## Each seat's grunt, in Paddling.Seat order.
const GRUNTS: Array[StringName] = [&"guy_grunt_0", &"guy_grunt_1", &"guy_grunt_2", &"guy_grunt_3"]

## Linear 0..1 gain of the Master bus; assigning it applies it (set_master_volume).
var master_volume: float = DEFAULT_MASTER_VOLUME:
	set = set_master_volume

var _streams: Dictionary[StringName, AudioStream] = {}
var _pool: Array[AudioStreamPlayer] = []
## The pool player to take next when all are playing.
var _next: int = 0


func _ready() -> void:
	if Engine.has_meta("godot_director_check"):
		return
	for sound_name: StringName in SOUNDS:
		var stream: AudioStream = load(AUDIO_DIR.path_join(sound_name + ".wav")) as AudioStream
		if stream == null:
			push_error("Audio: %s.wav is missing; run tools/gen_audio.gd" % sound_name)
			continue
		_streams[sound_name] = stream
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_pool.append(player)
	set_master_volume(master_volume)
	RunState.stroke_landed.connect(_on_stroke_landed)
	RunState.stroke_fumbled.connect(_on_stroke_fumbled)
	RunState.guy_jumped.connect(_on_guy_jumped)
	RunState.guy_picked_up.connect(_on_guy_picked_up)
	RunState.beer_overboard_started.connect(_on_beer_overboard_started)


## Plays the sound called `sound_name` (one of SOUNDS) once at `pitch_scale`. An unknown name
## is a warning; before _ready, and during the check, nothing plays.
func play(sound_name: StringName, pitch_scale: float = 1.0) -> void:
	if _pool.is_empty():
		return
	if not _streams.has(sound_name):
		push_warning("Audio: no sound called %s" % sound_name)
		return
	var player: AudioStreamPlayer = _free_player()
	player.stream = _streams[sound_name]
	player.pitch_scale = pitch_scale
	player.play()


## Sets the Master bus to `linear` (0..1, clamped) and remembers it in master_volume.
func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	var bus: int = AudioServer.get_bus_index(MASTER_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


## A player that isn't playing, else the one taken longest ago (round robin).
func _free_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _pool:
		if not player.playing:
			return player
	var oldest: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	return oldest


func _on_stroke_landed(seat: int) -> void:
	play(&"stroke", randf_range(1.0 - STROKE_PITCH_SPREAD, 1.0 + STROKE_PITCH_SPREAD))
	play(GRUNTS[seat])


func _on_stroke_fumbled(_seat: int) -> void:
	play(&"fumble")


func _on_guy_jumped(_seat: int) -> void:
	play(&"splash")


func _on_guy_picked_up(_seat: int) -> void:
	play(&"pickup")


func _on_beer_overboard_started(_hull: int) -> void:
	play(&"beer_over")
