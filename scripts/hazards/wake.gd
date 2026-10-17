extends HazardBase
## Wake · a motorboat crosses ahead and its wake rolls back at the boat (GDD › Systems › Hazards,
## the Motorboat wake row). An event: the lake places this node where the plan put it, but the
## placement is only the trigger and nothing shows there. When the boat comes near, the motorboat
## (Visual/Motorboat: the motorboat sprite with its two-frame spray trail astern) crosses the
## lake ahead of it at the MotorboatWake rule's position, and once it is across the wave front
## (Visual/Front/Crest: a two-frame rolling crest tile repeated across the lake) rolls toward
## the shore at the rule's front_y, so the boat is seen before the wave. The frames are in
## assets/sprites/hazards/ (T24, drawn by tools/gen_sprites.gd). The rule decides everything;
## this script steps it each physics frame with the boat's position and heading, and applies
## its one hit through RunState: beer_overboard() on the high hull, shove() and water_aboard()
## on that hull. No rules and no randomness here; the tunables are the wake_* fields on
## LakeTuning, which the lake sets as `tuning` before the node enters the tree.

const SPRAY_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/motorboat_spray_0.png"),
	preload("res://assets/sprites/hazards/motorboat_spray_1.png"),
]
const CREST_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/wake_crest_0.png"),
	preload("res://assets/sprites/hazards/wake_crest_1.png"),
]
## Seconds each frame shows (cosmetic): slow enough to read at 1×.
const FRAME_PERIOD: float = 0.2
## The crest tile's height in pixels: the repeated region is one tile tall.
const CREST_HEIGHT: float = 8.0

@onready var _motorboat: Node2D = $Visual/Motorboat
@onready var _spray: Sprite2D = $Visual/Motorboat/Spray
@onready var _front: Node2D = $Visual/Front
@onready var _crest: Sprite2D = $Visual/Front/Crest

var _wake: MotorboatWake
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
## Seconds into the animation.
var _clock: float = 0.0
## The rule's state on the last step, to catch its changes for the sound.
var _last_state: MotorboatWake.State = MotorboatWake.State.WAITING


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_wake = MotorboatWake.new(tuning, global_position)
	_boat = _find_boat()
	_crest.region_rect = Rect2(0.0, 0.0, tuning.lake_width, CREST_HEIGHT)
	_motorboat.visible = false
	_front.visible = false


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var hit: MotorboatWake.Hit = _wake.step(delta, _boat.global_position, _boat.global_rotation)
	if hit != null:
		RunState.beer_overboard(hit.hull, _boat.global_position)
		RunState.shove(hit.shove)
		RunState.water_aboard(hit.hull, hit.water)
	_sound_state()
	_show_state(delta)


## Sound and the call-out (T26, T56): the motorboat's engine loops from the moment it sets out
## (CROSSING, before its wave is anywhere near) until the wave is spent, and the guy on the side
## it sets out from calls it out.
func _sound_state() -> void:
	var state: MotorboatWake.State = _wake.state
	if state == _last_state:
		return
	_last_state = state
	if state == MotorboatWake.State.CROSSING:
		_start_loop(&"engine")
		_telegraph(&"wake", _wake.motorboat)
	elif state == MotorboatWake.State.SPENT:
		_stop_loop()


## Visual only: the motorboat shows while it crosses, turned the way it goes (the sprite is
## drawn pointing up) with its spray dancing; the front while it rolls, its crest rolling.
func _show_state(delta: float) -> void:
	_clock += delta
	var frame: int = _frame_at(_clock, 2, FRAME_PERIOD)
	_motorboat.visible = _wake.state == MotorboatWake.State.CROSSING
	_motorboat.position = to_local(_wake.motorboat)
	_motorboat.rotation = Vector2(_wake.direction, 0.0).angle() + PI * 0.5
	_spray.texture = SPRAY_FRAMES[frame]
	_front.visible = _wake.state == MotorboatWake.State.ROLLING
	_front.position = to_local(Vector2(0.0, _wake.front_y))
	_crest.texture = CREST_FRAMES[frame]
