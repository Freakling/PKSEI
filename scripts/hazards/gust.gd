extends HazardBase
## Gust · ripples race across the water a second ahead, then the wind shoves the boat sideways
## for a few seconds (GDD › Systems › Hazards, the Wind gust row). An event: the lake places this
## node where the plan put it, but the placement is only the trigger and nothing shows there.
## When the boat comes near, ripples (Visual/Ripples: sprites on a fixed pattern over a field
## around the trigger, the three-frame ripple arc from assets/sprites/hazards/, T24, drawn by
## tools/gen_sprites.gd) race across the water in the wind's direction for the warning, and
## turn into leaning streaks (the streak sprite) while the gust blows. The WindGust rule decides
## everything; this script steps it each physics frame with the boat's position and hands the
## push it returns to RunState.push(), which the boat moves by. No rules and no randomness here;
## the tunables are the gust_* fields on LakeTuning, which the lake sets as `tuning` before the
## node enters the tree.

const RIPPLE_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/gust_ripple_0.png"),
	preload("res://assets/sprites/hazards/gust_ripple_1.png"),
	preload("res://assets/sprites/hazards/gust_ripple_2.png"),
]
const STREAK: Texture2D = preload("res://assets/sprites/hazards/gust_streak.png")
## Seconds each ripple frame shows (cosmetic): slow enough to read at 1×.
const FRAME_PERIOD: float = 0.15
## The ripples (cosmetic): how many, how fast they race in pixels per second, how far the
## streaks lean while the gust blows (radians), and the stride in pixels between one ripple's
## starting place and the next's, so the pattern scatters.
const RIPPLE_COUNT: int = 24
const RIPPLE_SPEED: float = 260.0
const RIPPLE_LEAN: float = 0.35
const RIPPLE_STRIDE: float = 97.0
## The field the ripples race over, each way from the trigger, as a share of gust_trigger_radius.
const FIELD_SCALE: float = 1.5

@onready var _ripples: Node2D = $Visual/Ripples

var _gust: WindGust
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
var _sprites: Array[Sprite2D] = []
## Half the field's size in pixels.
var _half_field: float = 0.0
## How far the ripples have raced, wrapped over the field's width.
var _travel: float = 0.0
## Seconds into the animation.
var _clock: float = 0.0
## The rule's state on the last step, to catch the warning's start for the sound.
var _last_state: WindGust.State = WindGust.State.WAITING


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_gust = WindGust.new(tuning, global_position)
	_boat = _find_boat()
	_half_field = tuning.gust_trigger_radius * FIELD_SCALE
	for index: int in RIPPLE_COUNT:
		var ripple: Sprite2D = Sprite2D.new()
		ripple.name = "Ripple%d" % index
		ripple.texture = RIPPLE_FRAMES[0]
		_ripples.add_child(ripple)
		_sprites.append(ripple)
	_ripples.visible = false


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var push: Vector2 = _gust.step(delta, _boat.global_position)
	if push != Vector2.ZERO:
		RunState.push(push)
	_sound_state()
	_show_state(delta)


## Sound only (T26): the wind rises as the warning starts, before the gust blows.
func _sound_state() -> void:
	var state: WindGust.State = _gust.state
	if state == _last_state:
		return
	_last_state = state
	if state == WindGust.State.WARNING:
		Audio.play(&"wind_rise")


## Visual only: the ripples show from the warning to the end of the push, racing the way the
## wind blows (the arcs are drawn convex to the right and flipped for a leftward wind), and
## become leaning streaks while it blows.
func _show_state(delta: float) -> void:
	var blowing: bool = _gust.state == WindGust.State.BLOWING
	var racing: bool = _gust.state == WindGust.State.WARNING or blowing
	_ripples.visible = racing
	if not racing:
		return
	_clock += delta
	var width: float = _half_field * 2.0
	_travel = fmod(_travel + RIPPLE_SPEED * delta, width)
	var texture: Texture2D = STREAK if blowing else RIPPLE_FRAMES[_frame_at(_clock, RIPPLE_FRAMES.size(), FRAME_PERIOD)]
	var lean: float = RIPPLE_LEAN * _gust.direction if blowing else 0.0
	for index: int in _sprites.size():
		# A fixed pattern: each ripple on its own row, starting a different way across the field.
		var start: float = fmod(index * RIPPLE_STRIDE, width)
		var across: float = fmod(start + _travel, width) - _half_field
		var row: float = (index + 0.5) / RIPPLE_COUNT * width - _half_field
		var sprite: Sprite2D = _sprites[index]
		sprite.position = Vector2(across * _gust.direction, row)
		sprite.rotation = lean
		sprite.scale.x = _gust.direction
		sprite.texture = texture
