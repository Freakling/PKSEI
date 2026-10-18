class_name MotorboatWake
extends RefCounted
## MotorboatWake · a motorboat crosses ahead and trails a V of two wake fronts
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
##             the trigger (toward the island). Its position is `motorboat`. It trails two wake
##             fronts, the V a real boat leaves: each is a half-line that starts at the motorboat
##             (its apex) and runs backwards, one toward the shore (SHORE) and one toward the
##             island (ISLAND), at wake_angle degrees from the course. The V sweeps across the
##             lake with the motorboat;
##   ROLLING:  once it has crossed, the apex stays where it left the lake and both fronts keep
##             spreading outward along their normals (away from the course) at wake_speed, until
##             each has passed the trigger by wake_trigger_radius along its normal (far enough to
##             have swept any boat that set the event off);
##   SPENT:    over. One event per trigger.
## A front is a wave. When it crosses the boat (the boat's signed distance to it goes from the
## outside of the V to the inside, while the boat is behind the apex, so a boat ahead of the
## motorboat is never hit) that is a hit, at most one per event: head-on (the boat's heading
## within wake_head_on_angle of straight into or straight away from that front's normal) is
## nothing, and that front is used up all the same; otherwise a broadside hit on the high hull,
## the one facing the wave, with a shove of wake_shove sideways in the boat's frame away from the
## wave (toward the low hull) and wake_water of water aboard. A boat on the course behind the
## motorboat is reached by both fronts on the same step; the SHORE front is checked first.
## No randomness: the same inputs give the same hit. The motorboat, the fronts and the trigger
## are in the same frame as the boat it is given (the scene uses global coordinates), with the
## island up-screen (negative y) and the shore down-screen.

## What the event is doing.
enum State { WAITING, CROSSING, ROLLING, SPENT }

## The two wake fronts: the arm that runs toward the shore (down-screen) and the one toward the
## island (up-screen).
enum Front { SHORE, ISLAND }

## One broadside hit: a beer overboard on `hull`, the high side, `shove` in pixels per second,
## and `water` aboard that hull. `front` is the wave that landed it.
class Hit extends RefCounted:
	var hull: Rescue.Hull = Rescue.Hull.LEFT
	var shove: Vector2 = Vector2.ZERO
	var water: float = 0.0
	var front: Front = Front.SHORE


const FRONTS: Array[Front] = [Front.SHORE, Front.ISLAND]
## Slack (radians) on the head-on limit, so a heading exactly on it (straight at the island with
## wake_angle equal to wake_head_on_angle) is not decided by rounding.
const HEAD_ON_SLACK: float = 0.0001


var tuning: LakeTuning
## The placed point: the boat passing it sets the event off. Fixed.
var trigger: Vector2 = Vector2.ZERO
var state: State = State.WAITING
## Where the motorboat (the V's apex) is while it crosses; where it left the lake after that.
var motorboat: Vector2 = Vector2.ZERO
## Which way it crosses: +1 rightward (from the left edge), -1 leftward.
var direction: float = 1.0
## How far both fronts have spread outward from the apex along their normals while ROLLING.
var spread: float = 0.0
## Whether this event's one hit has been given.
var hit_given: bool = false
## The boat's signed distance to each front on the last step (positive: outside the V).
var _last_distance: Array[float] = [0.0, 0.0]
## Whether each front has already crossed the boat (a hit, or head-on).
var _crossed: Array[bool] = [false, false]
## Whether each front has spread past the trigger's reach and is over.
var _done: Array[bool] = [false, false]


func _init(lake_tuning: LakeTuning, trigger_position: Vector2) -> void:
	tuning = lake_tuning
	trigger = trigger_position
	reset()


## Armed again, nothing crossing.
func reset() -> void:
	state = State.WAITING
	motorboat = trigger
	direction = 1.0
	spread = 0.0
	hit_given = false
	_last_distance = [0.0, 0.0]
	_crossed = [false, false]
	_done = [false, false]


## Whether the boat is near enough to the trigger to set the event off.
func boat_near(boat_position: Vector2) -> bool:
	return trigger.distance_to(boat_position) <= tuning.wake_trigger_radius


## The y of the motorboat's course: wake_lead ahead of the trigger, toward the island.
func course_y() -> float:
	return trigger.y - tuning.wake_lead


## The lake's edge the motorboat sets off from: the one on the trigger's side.
func start_x() -> float:
	return -tuning.lake_width * 0.5 * direction


## The lake's edge it leaves by.
func end_x() -> float:
	return tuning.lake_width * 0.5 * direction


## The unit direction a front runs in from its apex: backwards (against the motorboat's travel)
## and outward, at wake_angle from the course.
func front_direction(front: Front) -> Vector2:
	var angle: float = deg_to_rad(tuning.wake_angle)
	var outward: float = 1.0 if front == Front.SHORE else -1.0
	return Vector2(-direction * cos(angle), outward * sin(angle))


## The unit normal of a front: perpendicular to it, pointing away from the course (toward the
## shore for SHORE, toward the island for ISLAND). The wave travels along it.
func front_normal(front: Front) -> Vector2:
	var angle: float = deg_to_rad(tuning.wake_angle)
	var outward: float = 1.0 if front == Front.SHORE else -1.0
	return Vector2(direction * sin(angle), outward * cos(angle))


## How far a front has spread from the apex: nothing while the motorboat crosses, wake_speed
## after, stopping where the front is over.
func front_spread(front: Front) -> float:
	return minf(spread, end_spread(front))


## The spread at which a front has passed the trigger by wake_trigger_radius along its normal
## (never negative: a front that is already past it is over once the motorboat has crossed).
func end_spread(front: Front) -> float:
	var parked: Vector2 = Vector2(end_x(), course_y())
	var past: float = (parked - trigger).dot(front_normal(front))
	return maxf(0.0, tuning.wake_trigger_radius - past)


## A point on the front: its apex, moved out along the normal by the spread.
func front_point(front: Front) -> Vector2:
	return motorboat + front_normal(front) * front_spread(front)


## The point's signed distance to the front's line: positive outside the V (the side the wave is
## coming from), negative inside.
func front_distance(front: Front, point: Vector2) -> float:
	return (point - front_point(front)).dot(front_normal(front))


## Whether the point is behind the apex, where the front exists (it is a half-line).
func in_extent(front: Front, point: Vector2) -> bool:
	return (point - front_point(front)).dot(front_direction(front)) >= 0.0


## Whether this heading takes a wave travelling along `normal` head-on: within wake_head_on_angle
## of straight into it or straight away from it.
func is_head_on(boat_rotation: float, normal: Vector2) -> bool:
	var heading: Vector2 = Vector2.UP.rotated(boat_rotation)
	var angle: float = absf(heading.angle_to(normal))
	var limit: float = deg_to_rad(tuning.wake_head_on_angle) + HEAD_ON_SLACK
	return angle <= limit or angle >= PI - limit


## The high hull: the one facing the wave, in the boat's own frame.
func high_hull(boat_rotation: float, normal: Vector2) -> Rescue.Hull:
	var from_wave: Vector2 = (-normal).rotated(-boat_rotation)
	return Rescue.Hull.LEFT if from_wave.x < 0.0 else Rescue.Hull.RIGHT


## The broadside hit of a front with this normal: the high hull, a sideways shove toward the low
## hull and the water.
func make_hit(boat_rotation: float, normal: Vector2) -> Hit:
	var hit: Hit = Hit.new()
	hit.hull = high_hull(boat_rotation, normal)
	var right: Vector2 = Vector2.RIGHT.rotated(boat_rotation)
	hit.shove = (right if hit.hull == Rescue.Hull.LEFT else -right) * tuning.wake_shove
	hit.water = tuning.wake_water
	return hit


## Advances the event by delta with the boat where it is; returns the hit a front lands this
## step, or null.
func step(delta: float, boat_position: Vector2, boat_rotation: float = 0.0) -> Hit:
	var hit: Hit = null
	match state:
		State.WAITING:
			if boat_near(boat_position):
				state = State.CROSSING
				direction = 1.0 if trigger.x < 0.0 else -1.0
				motorboat = Vector2(start_x(), course_y())
				for front: Front in FRONTS:
					_last_distance[front] = front_distance(front, boat_position)
		State.CROSSING:
			motorboat.x += direction * tuning.wake_boat_speed * delta
			if (motorboat.x - end_x()) * direction >= 0.0:
				motorboat.x = end_x()
				state = State.ROLLING
			hit = _cross_fronts(boat_position, boat_rotation)
			if state == State.ROLLING:
				_retire_fronts()
		State.ROLLING:
			spread += tuning.wake_speed * delta
			hit = _cross_fronts(boat_position, boat_rotation)
			_retire_fronts()
		State.SPENT:
			pass
	return hit


## The fronts that crossed the boat on this step: the first one to do so (SHORE first on a tie)
## is the hit, unless it is head-on or the event's hit has been given.
func _cross_fronts(boat_position: Vector2, boat_rotation: float) -> Hit:
	var hit: Hit = null
	for front: Front in FRONTS:
		var distance: float = front_distance(front, boat_position)
		var crossing: bool = _last_distance[front] > 0.0 and distance <= 0.0
		_last_distance[front] = distance
		if not crossing or _crossed[front] or _done[front] or not in_extent(front, boat_position):
			continue
		_crossed[front] = true
		if hit_given:
			continue
		var normal: Vector2 = front_normal(front)
		if is_head_on(boat_rotation, normal):
			continue
		hit_given = true
		hit = make_hit(boat_rotation, normal)
		hit.front = front
	return hit


## Marks the fronts that have spread past the trigger's reach, and ends the event when both have.
func _retire_fronts() -> void:
	for front: Front in FRONTS:
		if spread >= end_spread(front):
			_done[front] = true
	if _done[Front.SHORE] and _done[Front.ISLAND]:
		state = State.SPENT
