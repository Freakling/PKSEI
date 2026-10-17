extends HazardBase
## Cross-current stripe · a band of faster water that pushes the boat sideways while the boat is
## in it (GDD › Systems › Hazards, the Cross-current stripe row). An object placed like one: the
## lake puts this node where the plan put it, and the stripe is the CrossCurrent rule's rectangle
## from there toward the island across the whole lake. Visual/Band tints that stretch a slightly
## different blue and Visual/Arrows (a two-frame tile of an arrow and streaks moving the way the
## water runs, from assets/sprites/hazards/, T24, drawn by tools/gen_sprites.gd, repeated over the
## stripe) covers it, visible from spawn. Each physics frame the boat is inside, the rule's push
## goes to RunState.push(), which the boat moves by, the same sustained push as a gust. No rules
## and no randomness here; the tunables are the stripe_* fields on LakeTuning, which the lake
## sets as `tuning` before the node enters the tree.

const ARROW_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/current_arrow_0.png"),
	preload("res://assets/sprites/hazards/current_arrow_1.png"),
]
## Seconds each frame shows (cosmetic): slow enough to read at 1×.
const FRAME_PERIOD: float = 0.25
const BAND_COLOUR: Color = Color(0.3, 0.62, 0.92, 0.35)

@onready var _band: Polygon2D = $Visual/Band
@onready var _arrows: Sprite2D = $Visual/Arrows

var _stripe: CrossCurrent
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
## Seconds into the animation.
var _clock: float = 0.0


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_stripe = CrossCurrent.new(tuning, global_position)
	_boat = _find_boat()
	var half: float = _stripe.half_width()
	# The island-side edge in this node's frame: the trigger is the origin, the island is up.
	var top: float = _stripe.far_y() - _stripe.near_y()
	_band.color = BAND_COLOUR
	_band.polygon = PackedVector2Array([
		Vector2(-half, top), Vector2(half, top), Vector2(half, 0.0), Vector2(-half, 0.0),
	])
	# The tile repeats over the whole rectangle, centred on it; its arrow points right, so it
	# is flipped for a stripe that runs left.
	_arrows.region_rect = Rect2(0.0, 0.0, half * 2.0, -top)
	_arrows.position = Vector2(0.0, top * 0.5)
	_arrows.scale.x = _stripe.direction().x


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	if _stripe.inside(_boat.global_position):
		RunState.push(_stripe.push())
	_clock += delta
	_arrows.texture = ARROW_FRAMES[_frame_at(_clock, ARROW_FRAMES.size(), FRAME_PERIOD)]
