class_name JetSki
extends RefCounted
## JetSki · loud from offscreen, then a jet-ski crosses the boat's path on a straight line at
## speed (GDD › Systems › Hazards, the Jet-ski idiot row).
##
## A plain rule class: it receives its LakeTuning and the trigger's position and never touches
## the scene tree or RunState. The event is placed like an object, but the placement is only a
## trigger; the event happens as the boat passes. It runs one state machine, advanced by step()
## with the boat's position and heading:
##   WAITING:  armed. When the boat comes within jetski_trigger_radius of the trigger the
##             warning starts;
##   WARNING:  jetski_warning seconds of noise from offscreen (the telegraph: the audio comes
##             with T26; the scene shows a stand-in marker on the side it will come from), the
##             jet-ski not yet on the water and nothing moving;
##   CROSSING: the jet-ski sets off from off-screen on the trigger's side of the lake, EDGE_MARGIN
##             beyond the lake's edge, and crosses on a straight line at jetski_speed: the line
##             across the lake through the aim point, jetski_lead ahead (toward the island) of
##             where the boat was the moment the crossing started, so a boat that keeps paddling
##             meets it and one that holds back lets it pass. Its position is `jetski`. The step
##             on which its path comes within jetski_hit_radius of the boat is the hit, at most
##             once per event: a shove of jetski_shove in its travel direction and a beer
##             overboard on the hull it came from, in the boat's frame. It carries on to the far
##             edge, hit or not;
##   SPENT:    over, once it has left by the far edge. One event per trigger.
## The direction is fixed per event by the trigger's side of the lake, the same rule as the
## motorboat's crossing (MotorboatWake): a trigger left of the lake's middle (x < 0) crosses
## rightward (+x) from the left edge, any other leftward (-x) from the right edge. No randomness:
## the same inputs give the same hit. The trigger and the jet-ski are in the same frame as the
## boat it is given (the scene uses global coordinates), with the island up-screen (negative y).

## What the event is doing.
enum State { WAITING, WARNING, CROSSING, SPENT }

## One hit: a beer overboard on `hull`, the side the jet-ski came from, and `shove` in pixels per
## second along its travel.
class Hit extends RefCounted:
	var hull: Rescue.Hull = Rescue.Hull.LEFT
	var shove: Vector2 = Vector2.ZERO


## Pixels beyond the lake's edge (lake_width / 2) the jet-ski starts from and leaves at: more
## than half the 640 px view plus the camera's lead, so it is off-screen even for a boat hugging
## that edge.
const EDGE_MARGIN: float = 360.0


var tuning: LakeTuning
## The placed point: the boat passing it sets the event off. Fixed.
var trigger: Vector2 = Vector2.ZERO
var state: State = State.WAITING
## Which way it crosses: +1 rightward (from the left edge), -1 leftward. Fixed per event.
var direction: float = 1.0
## Seconds left of the warning (WARNING); 0 otherwise.
var time_left: float = 0.0
## Where the jet-ski is while it crosses (the trigger before that); where it left the lake after.
var jetski: Vector2 = Vector2.ZERO
## The point it aims through: jetski_lead ahead of the boat when the crossing started.
var aim: Vector2 = Vector2.ZERO
## Whether this event's one hit has been given.
var hit_given: bool = false


func _init(lake_tuning: LakeTuning, trigger_position: Vector2) -> void:
	tuning = lake_tuning
	trigger = trigger_position
	reset()


## Armed again, nothing crossing. The direction is known from the trigger alone, so the scene
## can show the warning on the right side from the first warning frame.
func reset() -> void:
	state = State.WAITING
	direction = 1.0 if trigger.x < 0.0 else -1.0
	time_left = 0.0
	jetski = trigger
	aim = trigger
	hit_given = false


## Whether the boat is near enough to the trigger to set the event off.
func boat_near(boat_position: Vector2) -> bool:
	return trigger.distance_to(boat_position) <= tuning.jetski_trigger_radius


## The x the jet-ski sets off from: off-screen beyond the lake's edge on the trigger's side.
func start_x() -> float:
	return -(tuning.lake_width * 0.5 + EDGE_MARGIN) * direction


## The x it leaves by: off-screen beyond the far edge.
func end_x() -> float:
	return (tuning.lake_width * 0.5 + EDGE_MARGIN) * direction


## Its travel direction: straight across the lake.
func travel() -> Vector2:
	return Vector2(direction, 0.0)


## The hull the jet-ski comes from, in the boat's own frame.
func hull_hit(boat_rotation: float) -> Rescue.Hull:
	var from_jetski: Vector2 = (-travel()).rotated(-boat_rotation)
	return Rescue.Hull.LEFT if from_jetski.x < 0.0 else Rescue.Hull.RIGHT


## The hit for this heading: the hull it came from and a hard shove along its travel.
func make_hit(boat_rotation: float) -> Hit:
	var hit: Hit = Hit.new()
	hit.hull = hull_hit(boat_rotation)
	hit.shove = travel() * tuning.jetski_shove
	return hit


## Whether the jet-ski's path this step, from `from` to `to`, came within jetski_hit_radius of
## the boat (the segment, so a fast jet-ski can't step over it).
func passes_boat(from: Vector2, to: Vector2, boat_position: Vector2) -> bool:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(boat_position, from, to)
	return closest.distance_to(boat_position) <= tuning.jetski_hit_radius


## Advances the event by delta with the boat where it is; returns the hit the jet-ski lands this
## step, or null.
func step(delta: float, boat_position: Vector2, boat_rotation: float = 0.0) -> Hit:
	var hit: Hit = null
	match state:
		State.WAITING:
			if boat_near(boat_position):
				state = State.WARNING
				time_left = tuning.jetski_warning
		State.WARNING:
			time_left -= delta
			if time_left <= 0.0:
				state = State.CROSSING
				time_left = 0.0
				aim = boat_position + Vector2(0.0, -tuning.jetski_lead)
				jetski = Vector2(start_x(), aim.y)
		State.CROSSING:
			var from: Vector2 = jetski
			jetski.x += direction * tuning.jetski_speed * delta
			if (jetski.x - end_x()) * direction >= 0.0:
				jetski.x = end_x()
				state = State.SPENT
			if not hit_given and passes_boat(from, jetski, boat_position):
				hit_given = true
				hit = make_hit(boat_rotation)
		State.SPENT:
			pass
	return hit
