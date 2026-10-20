class_name Splash
extends CanvasLayer
## Splash · the first screen (GDD › Presentation and Platforms, Splash; design/ui/splash.md): the
## crew in their catamaran on the lake with the island behind, the title, a blinking prompt, and a
## chiptune loop. Main (scenes/main.tscn) holds it over the lake, which is why it shows once per
## launch: nothing reloads main.tscn, so a reset or the win's "go again" never brings it back.
##
## While it is up the tree is paused (the splash itself runs always), so the lake, the boat and the
## touch pads get no input and no time; the boat polls its keys in a physics step that doesn't run.
## Any key, mouse button, pad button or touch after INPUT_GUARD (so the key that launched the page
## doesn't skip it) starts the fade, and the event is marked handled. The fade takes FADE_TIME: the
## screen and the music fade out together, then the splash unpauses the tree and frees itself.
## Everything runs in _process so it is the same with frames as in a test that calls _process.
##
## The music is the exported `music` stream, played on the Music bus. To swap in the human's mp3:
## put it in res://assets/audio/music/, set its import "Loop" on, and point the Splash node's
## `music` at it in scenes/splash.tscn. A stream that doesn't loop by itself is restarted when it
## finishes. The placeholder is assets/audio/music/splash_theme.wav, made by tools/gen_audio.gd.
## The backdrop is drawn from the game's sprites; only the boat bobs, for show.

## Seconds after the splash appears before an input counts.
const INPUT_GUARD: float = 0.5
## Seconds the screen and the music take to fade out.
const FADE_TIME: float = 1.0
## The music's gain at the end of the fade (linear), a silence you can't hear.
const SILENT: float = 0.001
## The prompt's blink: seconds per cycle and its dimmest alpha.
const BLINK_PERIOD: float = 1.4
const BLINK_DIM: float = 0.25
## The boat's bob (cosmetic): its size in pixels and radians, and its speed in radians a second.
const BOB_AMPLITUDE: float = 3.0
const BOB_SPEED: float = 2.0
const ROCK_AMPLITUDE: float = 0.04
const ROCK_SPEED: float = 1.3
## The boat heads this far round from straight up (radians, clockwise), toward the island.
const BOAT_HEADING: float = 0.3
## Each guy sways a little on his seat: radians and speed, a different phase per seat.
const SWAY_AMPLITUDE: float = 0.1
const SWAY_SPEED: float = 2.1
## Where the boat and the island sit, as fractions of the backdrop.
const BOAT_AT: Vector2 = Vector2(0.5, 0.62)
const ISLAND_AT: Vector2 = Vector2(0.82, 0.26)

@export var music: AudioStream

@onready var _root: Control = %Root
@onready var _backdrop: Control = %Backdrop
@onready var _island: Node2D = %Island
@onready var _boat: Node2D = %Boat
@onready var _prompt: Label = %Prompt
@onready var _music: AudioStreamPlayer = %Music

var _age: float = 0.0
var _fade_elapsed: float = 0.0
var _fading: bool = false
var _done: bool = false
var _holds_pause: bool = false
var _boat_home: Vector2 = Vector2.ZERO


func _ready() -> void:
	_prompt.text = prompt_text(DisplayServer.is_touchscreen_available())
	_backdrop.resized.connect(_layout)
	_layout()
	_music.stream = music
	_music.finished.connect(_on_music_finished)
	_music.play()
	# Nothing reaches the lake until the splash is gone.
	get_tree().paused = true
	_holds_pause = true


func _exit_tree() -> void:
	# However it goes (a freed scene, a test), the tree is not left paused by a splash that is gone.
	if _holds_pause and get_tree() != null:
		get_tree().paused = false
	_holds_pause = false


func _process(delta: float) -> void:
	_age += delta
	_animate()
	if _fading:
		_fade_elapsed += delta
		var left: float = 1.0 - clampf(_fade_elapsed / FADE_TIME, 0.0, 1.0)
		_root.modulate.a = left
		_music.volume_db = linear_to_db(maxf(left, SILENT))
		if left <= 0.0:
			dismiss_now()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if is_start_event(event):
		if _age >= INPUT_GUARD and not _fading:
			start_fade()
		# Held back while it is guarded or fading too: nothing gets past the splash.
		get_viewport().set_input_as_handled()


## "Tap to start" on a touchscreen, "Press any key" otherwise.
static func prompt_text(touch: bool) -> String:
	return "Tap to start" if touch else "Press any key"


## Whether `event` is one that starts the game: a key press (not a repeat), a mouse button, a pad
## button or a touch going down.
static func is_start_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.is_pressed() and not event.is_echo()
	return (event is InputEventMouseButton or event is InputEventJoypadButton
			or event is InputEventScreenTouch) and event.is_pressed()


## Whether the fade has started.
func is_fading() -> bool:
	return _fading


## Starts the fade out; the splash frees itself when it is done.
func start_fade() -> void:
	_fading = true


## Ends the splash now: no fade, the music stops, the tree runs and the splash is freed. The
## fade's end calls it, and so does the autoplay adapter, which starts its runs on the lake.
func dismiss_now() -> void:
	if _done:
		return
	_done = true
	_music.stop()
	if _holds_pause:
		get_tree().paused = false
		_holds_pause = false
	queue_free()


## The boat and the island go where the backdrop's size puts them.
func _layout() -> void:
	_boat_home = (_backdrop.size * BOAT_AT).round()
	_island.position = (_backdrop.size * ISLAND_AT).round()
	_boat.position = _boat_home


## The boat bobs and rocks, each guy sways, and the prompt blinks.
func _animate() -> void:
	_boat.position = _boat_home + Vector2(0.0, sin(_age * BOB_SPEED) * BOB_AMPLITUDE).round()
	_boat.rotation = BOAT_HEADING + sin(_age * ROCK_SPEED) * ROCK_AMPLITUDE
	for seat: int in RunState.GUY_COUNT:
		var guy: Node2D = _boat.get_node_or_null("Guy%d" % seat) as Node2D
		if guy != null:
			guy.rotation = sin(_age * SWAY_SPEED + seat * 1.7) * SWAY_AMPLITUDE
	_prompt.modulate.a = lerpf(BLINK_DIM, 1.0, 0.5 + 0.5 * cos(TAU * _age / BLINK_PERIOD))


## A stream that doesn't loop by itself (an mp3 without Loop on) starts over.
func _on_music_finished() -> void:
	if not _done:
		_music.play()
