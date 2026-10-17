class_name WindGust
extends RefCounted
## WindGust · ripples race across the water a second ahead, then a gust shoves the boat sideways
## for a few seconds (GDD › Systems › Hazards, the Wind gust row).
##
## A plain rule class: it receives its LakeTuning and the trigger's position and never touches
## the scene tree or RunState. The event is placed like an object, but the placement is only a
## trigger; the gust happens as the boat passes. It runs one state machine, advanced by step()
## with the boat's position:
##   WAITING: armed. When the boat comes within gust_trigger_radius of the trigger the ripples
##            start;
##   WARNING: ripples race across the water for gust_warning seconds (the telegraph), no push;
##   BLOWING: the boat is pushed sideways across the lake at gust_shove pixels per second for
##            gust_time seconds, whether or not it stays near the trigger. The push compounds
##            with the current: the boat moves by both;
##   SPENT:   over. One event per trigger.
## The wind's direction is fixed per event by the trigger's side of the lake, the same rule as
## the motorboat's crossing (MotorboatWake): a trigger left of the lake's middle (x < 0) blows
## the boat rightward (+x), any other leftward (-x). No randomness: the same inputs give the
## same push. The trigger is in the same frame as the boat it is given (the scene uses global
## coordinates), with the island up-screen (negative y).

## What the event is doing.
enum State { WAITING, WARNING, BLOWING, SPENT }


var tuning: LakeTuning
## The placed point: the boat passing it sets the gust off. Fixed.
var trigger: Vector2 = Vector2.ZERO
var state: State = State.WAITING
## Which way the wind blows the boat: +1 rightward, -1 leftward. Fixed per event.
var direction: float = 1.0
## Seconds left of the warning (WARNING) or of the push (BLOWING); 0 otherwise.
var time_left: float = 0.0


func _init(lake_tuning: LakeTuning, trigger_position: Vector2) -> void:
	tuning = lake_tuning
	trigger = trigger_position
	reset()


## Armed again, nothing blowing. The direction is known from the trigger alone, so the scene can
## show the ripples racing the right way from the first warning frame.
func reset() -> void:
	state = State.WAITING
	direction = 1.0 if trigger.x < 0.0 else -1.0
	time_left = 0.0


## Whether the boat is near enough to the trigger to set the gust off.
func boat_near(boat_position: Vector2) -> bool:
	return trigger.distance_to(boat_position) <= tuning.gust_trigger_radius


## The push while the gust blows: gust_shove pixels per second sideways, across the lake, in
## the wind's direction.
func push_velocity() -> Vector2:
	return Vector2(direction * tuning.gust_shove, 0.0)


## Advances the event by delta with the boat where it is; returns the push to apply this step
## (pixels per second), zero unless the gust is blowing.
func step(delta: float, boat_position: Vector2) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	match state:
		State.WAITING:
			if boat_near(boat_position):
				state = State.WARNING
				time_left = tuning.gust_warning
		State.WARNING:
			time_left -= delta
			if time_left <= 0.0:
				state = State.BLOWING
				time_left = tuning.gust_time
		State.BLOWING:
			push = push_velocity()
			time_left -= delta
			if time_left <= 0.0:
				state = State.SPENT
				time_left = 0.0
		State.SPENT:
			pass
	return push
