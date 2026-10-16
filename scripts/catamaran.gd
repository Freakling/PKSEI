extends CharacterBody2D
## Catamaran · the boat scene (GDD › Systems › Catamaran and paddling, GDD › Presentation and
## Platforms).
##
## Reads the four stroke keys, calls RunState.stroke() on each release and RunState.step() every
## physics frame, and moves by the Motion it gets back: thrust along its facing, turn as yaw, and
## the current's drift down-screen toward the shore (the island is up-screen). Damping stands in
## for the water; the scales and damping are BoatTuning's, read through RunState.paddling. The guys' squares under `Visual` show the break telegraph from RunState's
## Stamina state: a flashing marker during the warning, dimmed on the break. No rules live here.

## One input action per seat, in Paddling.Seat order (Q, A, I, K).
const ACTIONS: Array[StringName] = [
	&"stroke_left_front", &"stroke_left_back", &"stroke_right_front", &"stroke_right_back",
]
## The guys' squares under Visual, in Paddling.Seat order.
const GUY_PATHS: Array[String] = [
	"Visual/LeftFront", "Visual/LeftBack", "Visual/RightFront", "Visual/RightBack",
]
const BREAK_DIM: Color = Color(0.4, 0.4, 0.4, 1.0)
## Seconds per flash of the break warning marker (cosmetic).
const WARNING_FLASH_PERIOD: float = 0.3

## Speed from strokes, kept apart from `velocity` so a shore collision never feeds the current
## back into it.
var _stroke_velocity: Vector2 = Vector2.ZERO
var _yaw_rate: float = 0.0
var _hold_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flash_clock: float = 0.0
var _guys: Array[Polygon2D] = []
var _warnings: Array[Node2D] = []


func _ready() -> void:
	for path: String in GUY_PATHS:
		var guy: Polygon2D = get_node(path) as Polygon2D
		_guys.append(guy)
		_warnings.append(guy.get_node("Warning") as Node2D)


func _physics_process(delta: float) -> void:
	_read_keys(delta)
	var tuning: BoatTuning = RunState.paddling.tuning
	var motion: Paddling.Motion = RunState.step(delta)
	_stroke_velocity += Vector2.UP.rotated(rotation) * motion.thrust * tuning.thrust_scale
	_yaw_rate += motion.turn * tuning.turn_scale
	_stroke_velocity *= exp(-tuning.linear_damping * delta)
	_yaw_rate *= exp(-tuning.angular_damping * delta)
	rotation += _yaw_rate * delta
	# The drift goes through velocity so the shore collision stops it.
	velocity = _stroke_velocity + Vector2.DOWN * motion.drift_to_shore / delta
	move_and_slide()
	_show_telegraphs(delta)


## Hold to charge, release to stroke: the hold time goes to RunState with the seat.
func _read_keys(delta: float) -> void:
	for seat: int in ACTIONS.size():
		var action: StringName = ACTIONS[seat]
		if Input.is_action_just_pressed(action):
			_hold_times[seat] = 0.0
		if Input.is_action_pressed(action):
			_hold_times[seat] += delta
		if Input.is_action_just_released(action):
			RunState.stroke(seat, _hold_times[seat])
			_hold_times[seat] = 0.0


## Visual only: a swimmer's square is hidden, a warned guy's marker flashes, a guy on a break is dim.
func _show_telegraphs(delta: float) -> void:
	_flash_clock = fmod(_flash_clock + delta, WARNING_FLASH_PERIOD)
	for seat: int in _guys.size():
		var state: Stamina.State = RunState.stamina.state_of(seat)
		_guys[seat].visible = RunState.guys[seat].aboard
		_guys[seat].modulate = BREAK_DIM if state == Stamina.State.BREAK else Color.WHITE
		_warnings[seat].visible = state == Stamina.State.WARNING and _flash_clock < WARNING_FLASH_PERIOD * 0.5
