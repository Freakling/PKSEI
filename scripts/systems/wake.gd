class_name MotorboatWake
extends RefCounted
## MotorboatWake · a motorboat crosses ahead and its wake rolls back at the boat
## (GDD › Systems › Hazards, the Motorboat wake row).
##
## A plain rule class: it receives its LakeTuning and the trigger's position and never touches
## the scene tree or RunState. The event is placed like an object, but the placement is only a
## trigger; the event happens as the boat passes. It runs one state machine, advanced by step()
## with the boat's position and heading:
##   WAITING:  armed. When the boat comes within wake_trigger_radius of the trigger the motorboat
##             sets off;
##   CROSSING: the motorboat crosses the lake, from the lake's edge on the trigger's side to the
##             other edge, at wake_boat_speed along the course: the line wake_lead pixels ahead of
##             the trigger (toward the island). Its position is `motorboat`;
##   ROLLING:  once it has crossed, the wave front, a line parallel to the course at `front_y`,
##             rolls toward the shore at wake_speed until it has passed the trigger by
##             wake_trigger_radius (far enough to reach any boat that set it off). The step on
##             which the front crosses the boat is the hit, at most once per event:
##             head-on (the boat's heading within wake_head_on_angle of straight into or straight
##             away from the wave) is nothing; otherwise a broadside hit on the high hull, the one
##             facing the wave, with a shove of wake_shove sideways in the boat's frame away from
##             the wave (toward the low hull) and wake_water of water aboard;
##   SPENT:    over. One event per trigger.
## No randomness: the same inputs give the same hit. The motorboat, the front and the trigger
## are in the same frame as the boat it is given (the scene uses global coordinates), with the
## island up-screen (negative y) and the shore down-screen.

## What the event is doing.
enum State { WAITING, CROSSING, ROLLING, SPENT }

## One broadside hit: a beer overboard on `hull`, the high side, `shove` in pixels per second,
## and `water` aboard that hull.
class Hit extends RefCounted:
	var hull: Rescue.Hull = Rescue.Hull.LEFT
	var shove: Vector2 = Vector2.ZERO
	var water: float = 0.0


## The wave's travel direction: toward the shore, down-screen.
const TRAVEL: Vector2 = Vector2.DOWN


var tuning: LakeTuning
## The placed point: the boat passing it sets the event off. Fixed.
var trigger: Vector2 = Vector2.ZERO
var state: State = State.WAITING
## Where the motorboat is while it crosses; where it left the lake after that.
var motorboat: Vector2 = Vector2.ZERO
## Which way it crosses: +1 rightward (from the left edge), -1 leftward.
var direction: float = 1.0
## The wave front's y while it rolls (the line y = front_y across the whole lake).
var front_y: float = 0.0
## Whether this event's one hit has been given.
var hit_given: bool = false
## Whether the boat was still ahead of the front (shore-side of it) on the last step.
var _boat_ahead: bool = false


func _init(lake_tuning: LakeTuning, trigger_position: Vector2) -> void:
	tuning = lake_tuning
	trigger = trigger_position
	reset()


## Armed again, nothing crossing.
func reset() -> void:
	state = State.WAITING
	motorboat = trigger
	direction = 1.0
	front_y = course_y()
	hit_given = false
	_boat_ahead = false


## Whether the boat is near enough to the trigger to set the event off.
func boat_near(boat_position: Vector2) -> bool:
	return trigger.distance_to(boat_position) <= tuning.wake_trigger_radius


## The y of the motorboat's course: wake_lead ahead of the trigger, toward the island.
func course_y() -> float:
	return trigger.y - tuning.wake_lead


## Where the front stops: past the trigger by the trigger radius, so it reaches any boat that
## set the event off from there.
func front_end_y() -> float:
	return trigger.y + tuning.wake_trigger_radius


## The lake's edge the motorboat sets off from: the one on the trigger's side.
func start_x() -> float:
	return -tuning.lake_width * 0.5 * direction


## The lake's edge it leaves by.
func end_x() -> float:
	return tuning.lake_width * 0.5 * direction


## Whether this heading takes the wave head-on: within wake_head_on_angle of straight into it
## (facing the island) or straight away from it.
func is_head_on(boat_rotation: float) -> bool:
	var heading: Vector2 = Vector2.UP.rotated(boat_rotation)
	var angle: float = absf(heading.angle_to(TRAVEL))
	var limit: float = deg_to_rad(tuning.wake_head_on_angle)
	return angle <= limit or angle >= PI - limit


## The high hull: the one facing the wave, in the boat's own frame.
func high_hull(boat_rotation: float) -> Rescue.Hull:
	var from_wave: Vector2 = (-TRAVEL).rotated(-boat_rotation)
	return Rescue.Hull.LEFT if from_wave.x < 0.0 else Rescue.Hull.RIGHT


## The broadside hit for this heading: the high hull, a sideways shove toward the low hull and
## the water.
func make_hit(boat_rotation: float) -> Hit:
	var hit: Hit = Hit.new()
	hit.hull = high_hull(boat_rotation)
	var right: Vector2 = Vector2.RIGHT.rotated(boat_rotation)
	hit.shove = (right if hit.hull == Rescue.Hull.LEFT else -right) * tuning.wake_shove
	hit.water = tuning.wake_water
	return hit


## Advances the event by delta with the boat where it is; returns the hit the front lands this
## step, or null.
func step(delta: float, boat_position: Vector2, boat_rotation: float = 0.0) -> Hit:
	var hit: Hit = null
	match state:
		State.WAITING:
			if boat_near(boat_position):
				state = State.CROSSING
				direction = 1.0 if trigger.x < 0.0 else -1.0
				motorboat = Vector2(start_x(), course_y())
		State.CROSSING:
			motorboat.x += direction * tuning.wake_boat_speed * delta
			if (motorboat.x - end_x()) * direction >= 0.0:
				motorboat.x = end_x()
				state = State.ROLLING
				front_y = course_y()
				_boat_ahead = boat_position.y > front_y
		State.ROLLING:
			front_y = minf(front_y + tuning.wake_speed * delta, front_end_y())
			var ahead: bool = boat_position.y > front_y
			if _boat_ahead and not ahead and not hit_given:
				hit_given = true
				if not is_head_on(boat_rotation):
					hit = make_hit(boat_rotation)
			_boat_ahead = ahead
			if front_y >= front_end_y():
				state = State.SPENT
		State.SPENT:
			pass
	return hit
