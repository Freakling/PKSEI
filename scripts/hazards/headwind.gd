extends HazardBase
## Headwind · a stretch of whitecaps where a sustained headwind strengthens the current, so only
## strong strokes gain water (GDD › Systems › Hazards, the Harsh wind row). An event placed like
## an object: the lake puts this node where the plan put it, and the stretch is the Headwind
## rule's rectangle from there toward the island across the whole lake. Visual/Band tints it and
## Visual/Whitecaps (a two-frame whitecap tile from assets/sprites/hazards/, T24, drawn by
## tools/gen_sprites.gd, repeated over the stretch) covers it, so the stretch is seen long before
## the boat reaches it. Each physics frame the boat is inside, the rule's extra drift goes to
## RunState.set_extra_drift(), so the current pulls harder for that step. No rules and no
## randomness here; the tunables are the headwind_* fields on LakeTuning, which the lake sets as
## `tuning` before the node enters the tree.

const WHITECAP_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/whitecap_0.png"),
	preload("res://assets/sprites/hazards/whitecap_1.png"),
]
## Seconds each frame shows (cosmetic): slow enough to read at 1×.
const FRAME_PERIOD: float = 0.25

@onready var _band: Polygon2D = $Visual/Band
@onready var _whitecaps: Sprite2D = $Visual/Whitecaps

var _wind: Headwind
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
## Seconds into the animation.
var _clock: float = 0.0
## Whether the boat was inside the stretch on the last step, to catch it entering and leaving
## for the sound.
var _was_inside: bool = false


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_wind = Headwind.new(tuning, global_position)
	_boat = _find_boat()
	var half: float = _wind.half_width()
	# The island-side edge in this node's frame: the trigger is the origin, the island is up.
	var top: float = _wind.far_y() - _wind.near_y()
	_band.polygon = PackedVector2Array([
		Vector2(-half, top), Vector2(half, top), Vector2(half, 0.0), Vector2(-half, 0.0),
	])
	# The tile repeats over the whole rectangle, centred on it.
	_whitecaps.region_rect = Rect2(0.0, 0.0, half * 2.0, -top)
	_whitecaps.position = Vector2(0.0, top * 0.5)


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var extra: float = _wind.extra_drift(_boat.global_position)
	if extra > 0.0:
		RunState.set_extra_drift(extra)
	_sound_state()
	_clock += delta
	_whitecaps.texture = WHITECAP_FRAMES[_frame_at(_clock, WHITECAP_FRAMES.size(), FRAME_PERIOD)]


## Sound and the call-out (T26, T56): the whitecaps' wind loops while the boat is inside the
## stretch, from the step it enters to the step it leaves, and on entering a guy calls it out:
## the stretch is lake-wide, so it comes from no hull in particular.
func _sound_state() -> void:
	var inside: bool = _wind.inside(_boat.global_position)
	if inside == _was_inside:
		return
	_was_inside = inside
	if inside:
		_start_loop(&"whitecaps")
		RunState.telegraph(&"headwind", Rescue.NOBODY)
	else:
		_stop_loop()
