extends Node
## Audio · the sound effects (GDD › Presentation and Platforms, Audio: telegraphs first, then
## stroke, splash and guy noises for the comedy).
##
## Keeps a pool of AudioStreamPlayers on the Sfx bus and plays the WAVs in assets/audio/ and
## assets/audio/hazards/ (tools/gen_audio.gd makes them) by name with play(). A hazard's
## telegraph that lasts (the motorboat's engine, the jet-ski's whine, the whitecaps' wind, the
## beast's rumble) runs as a loop on its own player: play_loop() starts one and hands back a
## handle, stop_loop() ends it; at most LOOP_CAP run at once (T26). Listens to RunState: a
## stroke landing plays the swoosh and that seat's guy's grunt (one pitch per guy), a fumble
## the plop, a jump the splash, a pickup the blip, a beer going overboard the clink, a guy
## knocked in the splash again, the beast's grab its chomp, and a guy saying a line his babble
## (RunState.spoke, T94). The buses are
## assets/audio/default_bus_layout.tres (Master → Sfx, Music for later). master_volume sets the
## Master bus and lives only here: the GDD leaves player settings open, so there is no settings
## file yet. Inert during the check, and safe without an audio device: on the dummy driver the
## players just play nothing. Reads and writes no player data.

const MASTER_BUS: StringName = &"Master"
const SFX_BUS: StringName = &"Sfx"
## Sounds that can play at once; a further play() takes the player started longest ago.
const POOL_SIZE: int = 8
## Loops that can run at once; a further play_loop() is refused (returns 0) until one stops.
const LOOP_CAP: int = 4
## Linear gain of the Master bus until player settings exist. ## PLACEHOLDER
const DEFAULT_MASTER_VOLUME: float = 0.8
## The stroke swoosh varies this much in pitch either way, so four paddles don't sound like one.
const STROKE_PITCH_SPREAD: float = 0.08
## A guy's babble varies this much in pitch either way, so his repeats don't sound identical (T94).
const TALK_PITCH_SPREAD: float = 0.06

const AUDIO_DIR: String = "res://assets/audio"
const HAZARD_DIR: String = "res://assets/audio/hazards"
## The sounds, each AUDIO_DIR/<name>.wav. Loaded at _ready rather than preloaded: the import
## pass instantiates autoloads before it has imported a new WAV, so a parse-time preload fails
## on a fresh clone's first import.
const SOUNDS: Array[StringName] = [
	&"stroke", &"fumble", &"splash", &"pickup", &"beer_over", &"cheer",
	&"guy_grunt_0", &"guy_grunt_1", &"guy_grunt_2", &"guy_grunt_3",
	&"guy_talk_0", &"guy_talk_1", &"guy_talk_2", &"guy_talk_3",
]
## The hazard telegraphs, each HAZARD_DIR/<name>.wav; engine, jetski, whitecaps and
## beast_rumble loop (the WAV carries the loop, which the importer reads).
const HAZARD_SOUNDS: Array[StringName] = [
	&"engine", &"jetski", &"geese_hiss", &"wind_rise", &"whitecaps", &"beast_rumble", &"beast_grab",
]
## Each seat's grunt, in Paddling.Seat order.
const GRUNTS: Array[StringName] = [&"guy_grunt_0", &"guy_grunt_1", &"guy_grunt_2", &"guy_grunt_3"]
## Each seat's babble, in Paddling.Seat order too: the voice of a guy who says a line (T94).
const TALKS: Array[StringName] = [&"guy_talk_0", &"guy_talk_1", &"guy_talk_2", &"guy_talk_3"]

## Linear 0..1 gain of the Master bus; assigning it applies it (set_master_volume).
var master_volume: float = DEFAULT_MASTER_VOLUME:
	set = set_master_volume

var _streams: Dictionary[StringName, AudioStream] = {}
var _pool: Array[AudioStreamPlayer] = []
## The pool player to take next when all are playing.
var _next: int = 0
## The loop players, and the handle each one is playing for (0 = free), by index.
var _loop_players: Array[AudioStreamPlayer] = []
var _loop_handles: Array[int] = []
## The handle play_loop() gives out next; counts up, so a stale handle never stops a new loop.
var _next_handle: int = 1


func _ready() -> void:
	if Engine.has_meta("godot_director_check"):
		return
	_load(AUDIO_DIR, SOUNDS)
	_load(HAZARD_DIR, HAZARD_SOUNDS)
	for i: int in POOL_SIZE:
		_pool.append(_new_player())
	for i: int in LOOP_CAP:
		_loop_players.append(_new_player())
		_loop_handles.append(0)
	set_master_volume(master_volume)
	RunState.stroke_landed.connect(_on_stroke_landed)
	RunState.stroke_fumbled.connect(_on_stroke_fumbled)
	RunState.guy_jumped.connect(_on_guy_jumped)
	RunState.guy_picked_up.connect(_on_guy_picked_up)
	RunState.beer_overboard_started.connect(_on_beer_overboard_started)
	RunState.guy_fell_in.connect(_on_guy_fell_in)
	RunState.guy_grabbed.connect(_on_guy_grabbed)
	RunState.spoke.connect(_on_spoke)


## Plays the sound called `sound_name` (one of SOUNDS or HAZARD_SOUNDS) once at `pitch_scale`.
## An unknown name is a warning; before _ready, and during the check, nothing plays.
func play(sound_name: StringName, pitch_scale: float = 1.0) -> void:
	if _pool.is_empty() or not _known(sound_name):
		return
	var player: AudioStreamPlayer = _free_player()
	player.stream = _streams[sound_name]
	player.pitch_scale = pitch_scale
	player.play()


## Starts the sound called `sound_name` on a loop player of its own and returns the handle to
## stop it with, or 0 when it couldn't start: an unknown name (a warning), LOOP_CAP loops
## already running, or before _ready and during the check. The sound must be a loop (the WAV
## carries it); a one-shot would just play once and hold its player until stop_loop().
func play_loop(sound_name: StringName) -> int:
	if _loop_players.is_empty() or not _known(sound_name):
		return 0
	var index: int = _loop_handles.find(0)
	if index < 0:
		return 0
	var handle: int = _next_handle
	_next_handle += 1
	_loop_handles[index] = handle
	var player: AudioStreamPlayer = _loop_players[index]
	player.stream = _streams[sound_name]
	player.pitch_scale = 1.0
	player.play()
	return handle


## Stops the loop started with `handle` and frees its player. A handle that is 0 or already
## stopped does nothing, so a caller can stop without checking.
func stop_loop(handle: int) -> void:
	if handle == 0:
		return
	var index: int = _loop_handles.find(handle)
	if index < 0:
		return
	_loop_players[index].stop()
	_loop_handles[index] = 0


## Sets the Master bus to `linear` (0..1, clamped) and remembers it in master_volume.
func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	var bus: int = AudioServer.get_bus_index(MASTER_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


## Loads each of `names` from `dir`/<name>.wav into _streams; a missing one is an error.
func _load(dir: String, names: Array[StringName]) -> void:
	for sound_name: StringName in names:
		var stream: AudioStream = load(dir.path_join(sound_name + ".wav")) as AudioStream
		if stream == null:
			push_error("Audio: %s.wav is missing; run tools/gen_audio.gd" % sound_name)
			continue
		_streams[sound_name] = stream


## Whether `sound_name` was loaded; warns when not.
func _known(sound_name: StringName) -> bool:
	if _streams.has(sound_name):
		return true
	push_warning("Audio: no sound called %s" % sound_name)
	return false


## A player on the Sfx bus, added under this node.
func _new_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = SFX_BUS
	add_child(player)
	return player


## A pool player that isn't playing, else the one taken longest ago (round robin).
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


## A guy knocked in (the pee antic's shove) splashes like a jumper: the same splash.
func _on_guy_fell_in(_seat: int) -> void:
	play(&"splash")


func _on_guy_grabbed(_seat: int) -> void:
	play(&"beast_grab")


## A guy says a line (T94): his babble, at a little pitch spread. A seat outside the guys (-1,
## nobody) says nothing.
func _on_spoke(seat: int, _kind: StringName) -> void:
	if seat < 0 or seat >= TALKS.size():
		return
	play(TALKS[seat], randf_range(1.0 - TALK_PITCH_SPREAD, 1.0 + TALK_PITCH_SPREAD))
