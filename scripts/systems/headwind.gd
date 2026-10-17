class_name Headwind
extends RefCounted
## Headwind · a stretch of whitecaps where a sustained headwind strengthens the current, so only
## strong strokes gain water (GDD › Systems › Hazards, the Harsh wind row).
##
## A plain rule class: it receives its LakeTuning and the trigger's position and never touches
## the scene tree or RunState. The event is placed like an object, but the placement marks a
## stretch, not a point: a rectangle across the whole lake (lake_width, centred on x = 0),
## headwind_length tall, starting at the trigger and reaching toward the island (up-screen,
## negative y). It has no state: the boat is inside the stretch or not, and inside the current's
## pull toward the shore is stronger by headwind_force pixels per second. The scene feeds that
## to RunState every step the boat is inside, so the boat drifts back faster than a weak stroke
## gains: a stamina-management test. No randomness. The trigger is in the same frame as the
## boat it is given (the scene uses global coordinates).

var tuning: LakeTuning
## The placed point: the stretch's shore-side edge, on the lake's centre line or off it. Fixed.
var trigger: Vector2 = Vector2.ZERO


func _init(lake_tuning: LakeTuning, trigger_position: Vector2) -> void:
	tuning = lake_tuning
	trigger = trigger_position


## The stretch's shore-side edge: the trigger's y.
func near_y() -> float:
	return trigger.y


## The stretch's island-side edge: headwind_length past the trigger, toward the island.
func far_y() -> float:
	return trigger.y - tuning.headwind_length


## Half the stretch's width: it spans the whole lake_width.
func half_width() -> float:
	return tuning.lake_width * 0.5


## Whether the boat is in the stretch (edges included).
func inside(boat_position: Vector2) -> bool:
	return (
		boat_position.y <= near_y() and boat_position.y >= far_y()
		and absf(boat_position.x) <= half_width()
	)


## Pixels per second the headwind adds to the current's pull for a boat here: headwind_force
## inside the stretch, nothing outside.
func extra_drift(boat_position: Vector2) -> float:
	return tuning.headwind_force if inside(boat_position) else 0.0
