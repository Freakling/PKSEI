class_name CrossCurrent
extends RefCounted
## CrossCurrent · a stripe of faster water that pushes the boat sideways while the boat is in it
## (GDD › Systems › Hazards, the Cross-current stripe row).
##
## A plain rule class: it receives its LakeTuning and the trigger's position and never touches
## the scene tree or RunState. The event is placed like an object, but the placement marks a
## stretch, not a point: a rectangle across the whole lake (lake_width, centred on x = 0),
## stripe_length tall, starting at the trigger and reaching toward the island (up-screen,
## negative y). It has no state: the boat is inside the stripe or not. Its direction is sideways
## only, fixed by the placed point's side of the lake middle: a trigger left of the middle
## (x < 0) pushes the boat rightward (+x), any other leftward (-x), the same rule as the gust.
## The push is stripe_force pixels per second in that direction. No randomness. The trigger is in
## the same frame as the boat it is given (the scene uses global coordinates).

var tuning: LakeTuning
## The placed point: the stripe's shore-side edge, on the lake's centre line or off it. Fixed.
var trigger: Vector2 = Vector2.ZERO


func _init(lake_tuning: LakeTuning, trigger_position: Vector2) -> void:
	tuning = lake_tuning
	trigger = trigger_position


## The stripe's shore-side edge: the trigger's y.
func near_y() -> float:
	return trigger.y


## The stripe's island-side edge: stripe_length past the trigger, toward the island.
func far_y() -> float:
	return trigger.y - tuning.stripe_length


## Half the stripe's width: it spans the whole lake_width.
func half_width() -> float:
	return tuning.lake_width * 0.5


## Whether the boat is in the stripe (edges included).
func inside(boat_position: Vector2) -> bool:
	return (
		boat_position.y <= near_y() and boat_position.y >= far_y()
		and absf(boat_position.x) <= half_width()
	)


## The unit direction of the push: sideways only, +x when the trigger is left of the lake's
## middle, -x otherwise.
func direction() -> Vector2:
	return Vector2(1.0 if trigger.x < 0.0 else -1.0, 0.0)


## Pixels per second the stripe pushes the boat while it is inside: stripe_force in the stripe's
## direction.
func push() -> Vector2:
	return direction() * tuning.stripe_force
