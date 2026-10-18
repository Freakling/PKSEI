class_name Paddling
extends RefCounted
## Paddling · turns stroke events into the boat's thrust, turn and drift
## (GDD › Systems › Catamaran and paddling, GDD › Core Loop › Moment to moment).
##
## A plain rule class: it receives its BoatTuning and never touches the scene tree or RunState.
## Seats equal RunState's Guy.seat (0 left front, 1 left back, 2 right front, 3 right back).
## Directions: thrust is forward, toward the island (along RunState.progress); turn is a signed
## yaw impulse, positive to the right (clockwise from above); drift is the distance the current
## pulls the boat back toward the shore in one step.

## Seat numbers, equal to RunState.Guy.seat.
enum Seat { LEFT_FRONT = 0, LEFT_BACK = 1, RIGHT_FRONT = 2, RIGHT_BACK = 3 }


## One released stroke: who paddled, for how long his key was held, and whether he paddled
## backwards (his reverse key, or seeing double flipping a key, GDD › Drunkenness): the forward stroke
## mirrored, its thrust reverse_thrust_fraction of the forward one and its turn the same, both
## negated (GDD › Systems › Catamaran and paddling).
class Stroke extends RefCounted:
	var seat: int = Seat.LEFT_FRONT
	var hold_time: float = 0.0
	var backwards: bool = false

	func _init(stroke_seat: int, stroke_hold_time: float, stroke_backwards: bool = false) -> void:
		seat = stroke_seat
		hold_time = stroke_hold_time
		backwards = stroke_backwards


## What one timestep does to the boat.
class Motion extends RefCounted:
	## Forward impulse from this step's strokes.
	var thrust: float = 0.0
	## Yaw impulse: positive turns right (clockwise from above), negative turns left.
	var turn: float = 0.0
	## Distance the current pulled the boat back toward the shore this step.
	var drift_to_shore: float = 0.0


var tuning: BoatTuning


func _init(boat_tuning: BoatTuning) -> void:
	tuning = boat_tuning


## Power of a stroke: stroke_force_min for a tap, stroke_force_max once the key was held for
## charge_time, linear in between and capped at both ends.
func stroke_force(hold_time: float) -> float:
	if tuning.charge_time <= 0.0:
		return tuning.stroke_force_max
	var charge: float = clampf(hold_time / tuning.charge_time, 0.0, 1.0)
	return lerpf(tuning.stroke_force_min, tuning.stroke_force_max, charge)


## Yaw impulse of one stroke. A left-side stroke turns the boat right (positive) and a
## right-side stroke left, like an outboard at the stern. Back seats steer with
## steer_share_back and front seats with steer_share_front of turn_torque, scaled by the
## stroke's power, so a harder stroke also turns more.
func stroke_turn(seat: int, hold_time: float) -> float:
	return seat_side(seat) * steer_share(seat) * tuning.turn_torque * stroke_force(hold_time)


## Forward impulse of one stroke: its power, or for a backwards one reverse_thrust_fraction of
## that, negated.
func stroke_thrust(hold_time: float, backwards: bool) -> float:
	var force: float = stroke_force(hold_time)
	return -force * tuning.reverse_thrust_fraction if backwards else force


## Sums the strokes released this step, a backwards one with its thrust by stroke_thrust and
## its turn reversed, and the current's pull over `delta` seconds.
func step(strokes: Array[Stroke], delta: float) -> Motion:
	var motion: Motion = Motion.new()
	for stroke: Stroke in strokes:
		motion.thrust += stroke_thrust(stroke.hold_time, stroke.backwards)
		var direction: float = -1.0 if stroke.backwards else 1.0
		motion.turn += direction * stroke_turn(stroke.seat, stroke.hold_time)
	motion.drift_to_shore = tuning.current_speed * delta
	return motion


## Share of turn_torque this seat steers with: back seats are the rudder, front seats the engine.
func steer_share(seat: int) -> float:
	return tuning.steer_share_back if is_back_seat(seat) else tuning.steer_share_front


## +1 for the left hull (its strokes turn the boat right), -1 for the right hull.
static func seat_side(seat: int) -> float:
	return 1.0 if seat == Seat.LEFT_FRONT or seat == Seat.LEFT_BACK else -1.0


static func is_back_seat(seat: int) -> bool:
	return seat == Seat.LEFT_BACK or seat == Seat.RIGHT_BACK
