extends HazardBase
## Gust · ripples race across the water a second ahead, then the wind shoves the boat sideways
## for a few seconds (GDD › Systems › Hazards, the Wind gust row). An event: the lake places this
## node where the plan put it, but the placement is only the trigger and nothing shows there.
## When the boat comes near, ripples (Visual/Ripples: thin light streaks on a fixed pattern over
## a field around the trigger) race across the water in the wind's direction for the warning,
## and lean over while the gust blows. The WindGust rule decides everything; this script steps
## it each physics frame with the boat's position and hands the push it returns to
## RunState.push(), which the boat moves by. No rules and no randomness here; the tunables are
## the gust_* fields on LakeTuning, which the lake sets as `tuning` before the node enters the tree.

## The ripples (cosmetic): how many streaks, their size and colour, how fast they race in
## pixels per second, how far they lean while the gust blows (radians), and the stride in
## pixels between one streak's starting place and the next's, so the pattern scatters.
const RIPPLE_COUNT: int = 24
const RIPPLE_LENGTH: float = 18.0
const RIPPLE_THICKNESS: float = 2.0
const RIPPLE_COLOUR: Color = Color(0.8, 0.9, 1.0, 0.9)
const RIPPLE_SPEED: float = 260.0
const RIPPLE_LEAN: float = 0.35
const RIPPLE_STRIDE: float = 97.0
## The field the ripples race over, each way from the trigger, as a share of gust_trigger_radius.
const FIELD_SCALE: float = 1.5

@onready var _ripples: Node2D = $Visual/Ripples

var _gust: WindGust
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
var _streaks: Array[Polygon2D] = []
## Half the field's size in pixels.
var _half_field: float = 0.0
## How far the ripples have raced, wrapped over the field's width.
var _travel: float = 0.0


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_gust = WindGust.new(tuning, global_position)
	_boat = _find_boat()
	_half_field = tuning.gust_trigger_radius * FIELD_SCALE
	for index: int in RIPPLE_COUNT:
		var streak: Polygon2D = _rect("Streak%d" % index, RIPPLE_LENGTH, RIPPLE_THICKNESS, RIPPLE_COLOUR)
		_ripples.add_child(streak)
		_streaks.append(streak)
	_ripples.visible = false


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var push: Vector2 = _gust.step(delta, _boat.global_position)
	if push != Vector2.ZERO:
		RunState.push(push)
	_show_state(delta)


## Visual only: the ripples show from the warning to the end of the push, racing the way the
## wind blows, and lean over while it blows.
func _show_state(delta: float) -> void:
	var racing: bool = _gust.state == WindGust.State.WARNING or _gust.state == WindGust.State.BLOWING
	_ripples.visible = racing
	if not racing:
		return
	var width: float = _half_field * 2.0
	_travel = fmod(_travel + RIPPLE_SPEED * delta, width)
	var lean: float = RIPPLE_LEAN * _gust.direction if _gust.state == WindGust.State.BLOWING else 0.0
	for index: int in _streaks.size():
		# A fixed pattern: each streak on its own row, starting a different way across the field.
		var start: float = fmod(index * RIPPLE_STRIDE, width)
		var across: float = fmod(start + _travel, width) - _half_field
		var row: float = (index + 0.5) / RIPPLE_COUNT * width - _half_field
		_streaks[index].position = Vector2(across * _gust.direction, row)
		_streaks[index].rotation = lean
