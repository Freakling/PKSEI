class_name GeeseFlock
extends RefCounted
## GeeseFlock · a flock of angry geese guarding its goslings (GDD › Systems › Hazards, the Angry
## geese row).
##
## A plain rule class: it receives its LakeTuning and the nest's position and never touches the
## scene tree or RunState. The nest is an object, fixed where the lake placed it; the charge is
## the event. The flock runs one state machine, advanced by step() with the boat's position (and
## its rotation, for which hull a peck lands on):
##   NESTING:   at the nest. Once the cooldown (time_left) is over and the boat comes within
##              geese_radius of the nest, it starts HISSING;
##   HISSING:   the telegraph, geese_warning seconds (time_left) of hissing and raised wings; a
##              boat that leaves the radius calms them (back to NESTING with no cooldown), one
##              that stays gets the charge;
##   CHARGING:  for geese_attack_time seconds (time_left) the flock flies toward the boat at
##              geese_speed, and while within geese_peck_range of it pecks: the first peck the
##              moment it is in range, then one every geese_peck_interval seconds, each a beer
##              overboard on the hull nearest the flock in the boat's own frame;
##   RETURNING: back to the nest at geese_speed, then NESTING with geese_cooldown seconds before
##              it can hiss again.
## No randomness: the same inputs give the same pecks. The flock's position is in the same frame
## as the nest and the boat it is given (the scene uses global coordinates).

## What the flock is doing.
enum State { NESTING, HISSING, CHARGING, RETURNING }

## One peck: a beer overboard on this hull.
class Peck extends RefCounted:
	var hull: Rescue.Hull = Rescue.Hull.LEFT


var tuning: LakeTuning
## Where the goslings are: the flock's home, fixed.
var nest: Vector2 = Vector2.ZERO
var state: State = State.NESTING
## Where the geese are; the nest unless they are charging or returning.
var position: Vector2 = Vector2.ZERO
## Seconds left of the hiss, the charge, or the cooldown after returning; 0 otherwise.
var time_left: float = 0.0
## Seconds to the next peck while in range of the boat; 0 pecks at once, then the interval.
var _peck_timer: float = 0.0


func _init(lake_tuning: LakeTuning, nest_position: Vector2) -> void:
	tuning = lake_tuning
	nest = nest_position
	reset()


## Back on the nest, calm, ready to hiss.
func reset() -> void:
	state = State.NESTING
	position = nest
	time_left = 0.0
	_peck_timer = 0.0


## Whether the boat is near enough to the nest to set the geese off.
func boat_near(boat_position: Vector2) -> bool:
	return nest.distance_to(boat_position) <= tuning.geese_radius


## Whether the geese are close enough to the boat to peck it.
func in_peck_range(boat_position: Vector2) -> bool:
	return position.distance_to(boat_position) <= tuning.geese_peck_range


## The hull nearest the flock in the boat's own frame: left if the flock is on the boat's left.
func nearest_hull(boat_position: Vector2, boat_rotation: float) -> Rescue.Hull:
	var local: Vector2 = (position - boat_position).rotated(-boat_rotation)
	return Rescue.Hull.LEFT if local.x < 0.0 else Rescue.Hull.RIGHT


## Advances the flock by delta with the boat where it is; returns the pecks landed this step.
func step(delta: float, boat_position: Vector2, boat_rotation: float = 0.0) -> Array[Peck]:
	var pecks: Array[Peck] = []
	match state:
		State.NESTING:
			time_left = maxf(time_left - delta, 0.0)
			if time_left <= 0.0 and boat_near(boat_position):
				state = State.HISSING
				time_left = tuning.geese_warning
		State.HISSING:
			if not boat_near(boat_position):
				state = State.NESTING
				time_left = 0.0
			else:
				time_left = maxf(time_left - delta, 0.0)
				if time_left <= 0.0:
					state = State.CHARGING
					time_left = tuning.geese_attack_time
					_peck_timer = 0.0
		State.CHARGING:
			time_left = maxf(time_left - delta, 0.0)
			position = position.move_toward(boat_position, tuning.geese_speed * delta)
			if in_peck_range(boat_position):
				_peck_timer -= delta
				if _peck_timer <= 0.0:
					var peck: Peck = Peck.new()
					peck.hull = nearest_hull(boat_position, boat_rotation)
					pecks.append(peck)
					_peck_timer = tuning.geese_peck_interval
			else:
				_peck_timer = 0.0
			if time_left <= 0.0:
				state = State.RETURNING
				_peck_timer = 0.0
		State.RETURNING:
			position = position.move_toward(nest, tuning.geese_speed * delta)
			if position.is_equal_approx(nest):
				position = nest
				state = State.NESTING
				time_left = tuning.geese_cooldown
	return pecks
