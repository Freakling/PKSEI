extends "res://tools/test_case.gd"
## T16, T88 · Motorboat wake: the boat passing a wake trigger (within wake_trigger_radius) sends a
## motorboat across the lake wake_lead ahead at wake_boat_speed, trailing a V of two wake fronts,
## one either side of its course at wake_angle, which keep spreading outward at wake_speed once it
## is across. A front crossing the boat (behind the motorboat) is a hit, at most one per event:
## head-on to that front's normal does nothing; a broadside boat takes one hit: a beer overboard
## on the high hull (the one facing the wave), a shove of wake_shove sideways away from the wave
## and wake_water aboard that hull, which its guy bails at BoatTuning.bail_rate while his seat
## gives no strokes (GDD › Systems › Hazards, the Motorboat wake row). One event per trigger; same
## inputs, same hit.
##
## The tick is 1/64 s and the speeds and distances are multiples of it, so the motorboat moves
## exactly 10 px per tick and crosses the 640 px lake in 64 ticks, and the fronts spread 1 px per
## tick. The fronts' slopes are not round numbers, so the tests check what a hit is rather than
## the arithmetic of the line, and name the ticks only where the geometry is exact.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 64.0
const RADIUS: float = 100.0
const LEAD: float = 64.0
const BOAT_SPEED: float = 640.0
const LAKE_WIDTH: float = 640.0
const SPEED: float = 64.0
const SHOVE: float = 50.0
const WATER: float = 3.0
const ANGLE: float = 30.0
const HEAD_ON: float = 30.0
const BAIL_RATE: float = 2.0
const HULL_RADIUS: float = 34.0
const RAM_SHOVE: float = 40.0
## Left of the lake's middle, so the motorboat sets off from the left edge and crosses rightward.
const TRIGGER: Vector2 = Vector2(-100.0, -1000.0)
const COURSE_Y: float = -1064.0
## Inside the radius, 60 px to the right of the trigger, on its y: 64 px shore-side of the course.
const NEAR: Vector2 = Vector2(-40.0, -1000.0)
## On the course itself (87.7 px from the trigger), and 26 px island-side of it (98.5 px from it).
const ON_COURSE: Vector2 = Vector2(-40.0, -1064.0)
const ISLAND_SIDE: Vector2 = Vector2(-60.0, -1090.0)
const FAR: Vector2 = Vector2(-100.0, -800.0)
## The tick the event starts and the tick the motorboat is across (64 ticks of 10 px).
const START_TICK: int = 1
const ROLL_TICK: int = START_TICK + 64
## The tick the motorboat's apex reaches ON_COURSE's x: both fronts cross a boat there together.
const ON_COURSE_TICK: int = 29
## The tick the SHORE front crosses NEAR (the apex is 110.8 px past it, so on the 41st step).
const NEAR_HIT_TICK: int = 41
const BROADSIDE: float = PI / 2.0

var tuning: LakeTuning
var wake: MotorboatWake
var last_hit: MotorboatWake.Hit


func before_each() -> void:
	tuning = LakeTuning.new()
	tuning.lake_width = LAKE_WIDTH
	tuning.wake_trigger_radius = RADIUS
	tuning.wake_boat_speed = BOAT_SPEED
	tuning.wake_lead = LEAD
	tuning.wake_speed = SPEED
	tuning.wake_angle = ANGLE
	tuning.wake_head_on_angle = HEAD_ON
	tuning.wake_shove = SHOVE
	tuning.wake_water = WATER
	tuning.wake_hull_radius = HULL_RADIUS
	tuning.wake_ram_shove = RAM_SHOVE
	wake = MotorboatWake.new(tuning, TRIGGER)
	last_hit = null


## Steps the event for some ticks with the boat still; returns the ticks (1-based) that hit, and
## keeps the last hit in last_hit.
func run(ticks: int, boat: Vector2, rotation: float = 0.0) -> Array[int]:
	var hits: Array[int] = []
	for tick: int in ticks:
		var hit: MotorboatWake.Hit = wake.step(TICK, boat, rotation)
		if hit != null:
			hits.append(tick + 1)
			last_hit = hit
	return hits


## The boat rotation that points the boat along `heading`.
func rotation_of(heading: Vector2) -> float:
	return Vector2.UP.angle_to(heading)


## A front's normal for a rightward crossing, worked out here from the angle alone.
func normal_of(front: MotorboatWake.Front) -> Vector2:
	var outward: float = 1.0 if front == MotorboatWake.Front.SHORE else -1.0
	return Vector2(sin(deg_to_rad(ANGLE)), outward * cos(deg_to_rad(ANGLE)))


## A front's direction from its apex for a rightward crossing: backwards and outward.
func direction_of(front: MotorboatWake.Front) -> Vector2:
	var outward: float = 1.0 if front == MotorboatWake.Front.SHORE else -1.0
	return Vector2(-cos(deg_to_rad(ANGLE)), outward * sin(deg_to_rad(ANGLE)))


## What every hit has: the shove is wake_shove sideways in the boat's frame, away from the wave
## (along the front's normal, not against it), on the hull facing the wave, with wake_water.
func expect_broadside_hit(hit: MotorboatWake.Hit, boat_rotation: float, normal: Vector2) -> void:
	var heading: Vector2 = Vector2.UP.rotated(boat_rotation)
	var right: Vector2 = Vector2.RIGHT.rotated(boat_rotation)
	expect_near(hit.shove.length(), SHOVE, 0.0001, "wake_shove")
	expect_near(hit.shove.dot(heading), 0.0, 0.0001, "sideways in the boat's frame")
	expect(hit.shove.dot(normal) > 0.0, "away from the wave")
	var wave_from_left: bool = (-normal).dot(right) < 0.0
	expect_eq(hit.hull, Rescue.Hull.LEFT if wave_from_left else Rescue.Hull.RIGHT, "the hull facing the wave is high")
	expect_near(hit.water, WATER, 0.0001, "wake_water comes aboard")


func test_nothing_happens_outside_the_radius() -> void:
	var hits: Array[int] = run(400, FAR, BROADSIDE)
	expect_eq(wake.state, MotorboatWake.State.WAITING, "still armed")
	expect_eq(hits.size(), 0, "no hit")
	expect_false(wake.hit_given, "no hit given")


func test_the_boat_inside_the_radius_sets_the_motorboat_off() -> void:
	run(START_TICK, NEAR)
	expect_eq(wake.state, MotorboatWake.State.CROSSING, "the motorboat sets off")
	expect_eq(wake.direction, 1.0, "from the left edge, the trigger's side, rightward")
	expect_eq(wake.motorboat, Vector2(-320.0, COURSE_Y), "at the lake's left edge, wake_lead ahead of the trigger")


func test_a_trigger_right_of_the_middle_sends_it_leftward() -> void:
	tuning.wake_trigger_radius = 400.0
	var mirrored: MotorboatWake = MotorboatWake.new(tuning, Vector2(100.0, -1000.0))
	mirrored.step(TICK, Vector2(40.0, -1000.0))
	expect_eq(mirrored.state, MotorboatWake.State.CROSSING, "set off")
	expect_eq(mirrored.direction, -1.0, "leftward")
	expect_eq(mirrored.motorboat, Vector2(320.0, COURSE_Y), "from the right edge")
	for tick: int in 64:
		mirrored.step(TICK, Vector2(40.0, -1000.0))
	expect_eq(mirrored.state, MotorboatWake.State.ROLLING, "across after 64 ticks")
	expect_eq(mirrored.motorboat, Vector2(-320.0, COURSE_Y), "it left by the left edge")


func test_each_front_is_a_line_from_the_motorboat_back_at_wake_angle() -> void:
	run(20, NEAR)
	expect_eq(wake.state, MotorboatWake.State.CROSSING, "crossing")
	expect_eq(wake.motorboat, Vector2(-130.0, COURSE_Y), "10 px per tick along the course")
	for front: MotorboatWake.Front in MotorboatWake.FRONTS:
		var along: Vector2 = wake.front_direction(front)
		expect_eq(wake.front_point(front), wake.motorboat, "the front starts at the motorboat")
		expect_near(absf(rad_to_deg(along.angle_to(Vector2.LEFT))), ANGLE, 0.0001, "wake_angle from the course, back along it")
		expect(along.x < 0.0, "extending behind the motorboat")
		expect_near(along.distance_to(direction_of(front)), 0.0, 0.0001, "the SHORE arm runs down-screen, the ISLAND arm up")
		expect_near(wake.front_normal(front).dot(along), 0.0, 0.0001, "the normal is perpendicular to the front")
		expect_near(wake.front_normal(front).distance_to(normal_of(front)), 0.0, 0.0001, "and points away from the course")
		expect_near(wake.front_distance(front, wake.motorboat + along * 70.0), 0.0, 0.0001, "points behind the apex are on the line")
		expect(wake.in_extent(front, wake.motorboat + along * 70.0), "behind the apex is the front")
		expect_false(wake.in_extent(front, wake.motorboat - along * 70.0), "ahead of the apex is not")
	run(10, NEAR)
	expect_eq(wake.motorboat, Vector2(-30.0, COURSE_Y), "the V moves on with the motorboat")
	expect_eq(wake.front_point(MotorboatWake.Front.SHORE), wake.motorboat, "the SHORE front follows it")
	expect_eq(wake.front_point(MotorboatWake.Front.ISLAND), wake.motorboat, "the ISLAND front follows it")


func test_a_leftward_crossing_mirrors_the_v() -> void:
	var mirrored: MotorboatWake = MotorboatWake.new(tuning, Vector2(100.0, -1000.0))
	for tick: int in 20:
		mirrored.step(TICK, Vector2(40.0, -1000.0))
	for front: MotorboatWake.Front in MotorboatWake.FRONTS:
		var along: Vector2 = mirrored.front_direction(front)
		expect(along.x > 0.0, "extending behind a leftward motorboat, to the right")
		expect_near(along.x, -direction_of(front).x, 0.0001, "mirrored across the course")
		expect_near(along.y, direction_of(front).y, 0.0001, "the same side of the course")
		expect_near(mirrored.front_normal(front).x, -normal_of(front).x, 0.0001, "the normal mirrors too")


func test_after_the_crossing_both_fronts_keep_spreading_at_wake_speed() -> void:
	tuning.wake_trigger_radius = 400.0
	run(ROLL_TICK, NEAR)
	expect_eq(wake.state, MotorboatWake.State.ROLLING, "across: the fronts keep spreading")
	expect_eq(wake.motorboat, Vector2(320.0, COURSE_Y), "the apex stays where it left the lake")
	var before: Dictionary = {}
	for front: MotorboatWake.Front in MotorboatWake.FRONTS:
		before[front] = wake.front_point(front)
		expect_near(before[front].distance_to(wake.motorboat), 0.0, 0.0001, "they start on the apex")
	run(1, NEAR)
	for front: MotorboatWake.Front in MotorboatWake.FRONTS:
		var moved: Vector2 = wake.front_point(front) - before[front]
		expect_near(moved.distance_to(wake.front_normal(front) * SPEED * TICK), 0.0, 0.0001, "1 px per tick along the normal, away from the course")
	# The ISLAND front is over first (its normal leads away from the trigger); the SHORE front goes on.
	var island_end: float = wake.end_spread(MotorboatWake.Front.ISLAND)
	var shore_end: float = wake.end_spread(MotorboatWake.Front.SHORE)
	expect(island_end > 0.0 and island_end < shore_end, "the two fronts end at different spreads")
	run(int(ceilf(island_end)) + 5, NEAR)
	expect_eq(wake.state, MotorboatWake.State.ROLLING, "still rolling while the SHORE front is not over")
	var island_stopped: Vector2 = wake.front_point(MotorboatWake.Front.ISLAND)
	var shore_moving: Vector2 = wake.front_point(MotorboatWake.Front.SHORE)
	run(1, NEAR)
	expect_eq(wake.front_point(MotorboatWake.Front.ISLAND), island_stopped, "the ISLAND front stops once past the trigger")
	expect(wake.front_point(MotorboatWake.Front.SHORE) != shore_moving, "the SHORE front spreads on")
	run(400, NEAR)
	expect_eq(wake.state, MotorboatWake.State.SPENT, "spent once both are past the trigger by the radius")
	for front: MotorboatWake.Front in MotorboatWake.FRONTS:
		var past: float = (wake.front_point(front) - TRIGGER).dot(wake.front_normal(front))
		expect_near(past, 400.0, 0.0001, "each stops a trigger radius past the trigger, along its normal")


func test_a_boat_on_the_course_is_hit_once_by_the_first_front_to_reach_it() -> void:
	var rotation: float = rotation_of(direction_of(MotorboatWake.Front.SHORE))
	var hits: Array[int] = run(200, ON_COURSE, rotation)
	expect_eq(hits, [ON_COURSE_TICK] as Array[int], "one hit, the tick the apex passes it")
	expect_eq(last_hit.front, MotorboatWake.Front.SHORE, "both reach it together; the SHORE front is first")
	expect_broadside_hit(last_hit, rotation, normal_of(MotorboatWake.Front.SHORE))
	expect(wake.hit_given, "used up")


func test_a_boat_island_side_of_the_course_is_hit_by_the_island_front() -> void:
	var rotation: float = rotation_of(direction_of(MotorboatWake.Front.ISLAND))
	var hits: Array[int] = run(200, ISLAND_SIDE, rotation)
	expect_eq(hits.size(), 1, "one hit")
	expect_eq(last_hit.front, MotorboatWake.Front.ISLAND, "the arm toward the island reaches it")
	expect_broadside_hit(last_hit, rotation, normal_of(MotorboatWake.Front.ISLAND))


func test_a_boat_shore_side_of_the_course_is_hit_by_the_shore_front_as_the_v_sweeps_by() -> void:
	var hits: Array[int] = run(200, NEAR, BROADSIDE)
	expect_eq(hits, [NEAR_HIT_TICK] as Array[int], "one hit, when the arm trailing back from the apex reaches it")
	expect(NEAR_HIT_TICK < ROLL_TICK, "while the motorboat is still crossing")
	expect_eq(last_hit.front, MotorboatWake.Front.SHORE, "the SHORE front")
	expect_eq(wake.state, MotorboatWake.State.SPENT, "and the wake runs its course")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "facing right, the left hull faces the wave")
	expect_broadside_hit(last_hit, BROADSIDE, normal_of(MotorboatWake.Front.SHORE))
	wake.reset()
	hits = run(200, NEAR, -BROADSIDE)
	expect_eq(hits, [NEAR_HIT_TICK] as Array[int], "one hit again")
	expect_eq(last_hit.hull, Rescue.Hull.RIGHT, "facing left, the right hull faces the wave")
	expect_broadside_hit(last_hit, -BROADSIDE, normal_of(MotorboatWake.Front.SHORE))


func test_a_boat_the_motorboat_has_already_left_behind_is_hit_by_the_spreading_front() -> void:
	# Far enough from the apex's exit that the arm only reaches it after the crossing is over.
	tuning.wake_trigger_radius = 400.0
	var boat: Vector2 = Vector2(250.0, -1000.0)
	run(1, NEAR)
	var hits: Array[int] = run(400, boat, BROADSIDE)
	expect_eq(hits.size(), 1, "one hit")
	expect_eq(wake.motorboat, Vector2(320.0, COURSE_Y), "after the motorboat has crossed")
	expect_eq(last_hit.front, MotorboatWake.Front.SHORE, "the SHORE front, spreading")
	expect(hits[0] > ROLL_TICK - START_TICK, "later than the crossing")


func test_a_slanted_boat_is_shoved_along_its_own_side() -> void:
	var hits: Array[int] = run(200, NEAR, PI / 4.0)
	expect_eq(hits.size(), 1, "45 degrees is broadside to a front")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "the left hull faces the wave")
	var side: Vector2 = Vector2.RIGHT.rotated(PI / 4.0) * SHOVE
	expect_near(last_hit.shove.x, side.x, 0.0001, "shoved along the boat's right")
	expect_near(last_hit.shove.y, side.y, 0.0001, "toward the low hull")


func test_a_boat_heading_into_a_front_takes_no_hit_and_a_broadside_one_does() -> void:
	var normal: Vector2 = normal_of(MotorboatWake.Front.SHORE)
	var head_on: Dictionary = {
		"straight into the front": rotation_of(normal),
		"straight away from it": rotation_of(-normal),
		"inside wake_head_on_angle, one side": rotation_of(normal.rotated(deg_to_rad(HEAD_ON - 1.0))),
		"inside wake_head_on_angle, the other": rotation_of(normal.rotated(deg_to_rad(-HEAD_ON + 1.0))),
		"inside it, backing away": rotation_of((-normal).rotated(deg_to_rad(HEAD_ON - 1.0))),
	}
	for label: String in head_on:
		wake.reset()
		var hits: Array[int] = run(200, NEAR, head_on[label])
		expect_eq(hits.size(), 0, "%s: nothing" % label)
		expect_false(wake.hit_given, "%s: the event's hit is not used up" % label)
	var broadside: Dictionary = {
		"across the front": rotation_of(direction_of(MotorboatWake.Front.SHORE)),
		"just outside wake_head_on_angle": rotation_of(normal.rotated(deg_to_rad(HEAD_ON + 1.0))),
		"just outside it, backing away": rotation_of((-normal).rotated(deg_to_rad(-HEAD_ON - 1.0))),
	}
	for label: String in broadside:
		wake.reset()
		var hits: Array[int] = run(200, NEAR, broadside[label])
		expect_eq(hits.size(), 1, "%s: a hit" % label)


func test_a_head_on_crossing_of_one_front_leaves_the_other_to_hit() -> void:
	# On the course both fronts reach the boat together. Facing along the SHORE front's normal is
	# head-on to it, but 60 degrees off the ISLAND front's axis, which is broadside: the boat
	# crossing the V at an angle is hit by the arm it crosses broadside.
	var rotation: float = rotation_of(normal_of(MotorboatWake.Front.SHORE))
	var hits: Array[int] = run(200, ON_COURSE, rotation)
	expect_eq(hits, [ON_COURSE_TICK] as Array[int], "hit by the front it is not head-on to")
	expect_eq(last_hit.front, MotorboatWake.Front.ISLAND, "the ISLAND front")
	wake.reset()
	var straight_up: Array[int] = run(200, ON_COURSE, 0.0)
	expect_eq(straight_up.size(), 0, "straight at the island is within the angle of both fronts: crosses the V untouched")


func test_a_boat_ahead_of_the_motorboat_is_never_hit() -> void:
	tuning.wake_trigger_radius = 400.0
	var rotation: float = rotation_of(direction_of(MotorboatWake.Front.SHORE))
	run(1, NEAR, rotation)
	var hits: int = 0
	for tick: int in 400:
		var boat: Vector2 = wake.motorboat + Vector2(40.0 * wake.direction, 0.0)
		if wake.step(TICK, boat, rotation) != null:
			hits += 1
	expect_eq(hits, 0, "a boat kept ahead of the apex is never reached by the arms behind it")
	expect_eq(wake.state, MotorboatWake.State.SPENT, "the wake runs its course")
	expect_false(wake.hit_given, "nothing used up")


func test_one_event_per_trigger() -> void:
	tuning.wake_trigger_radius = 400.0
	var hits: Array[int] = run(NEAR_HIT_TICK, NEAR, BROADSIDE)
	expect_eq(hits, [NEAR_HIT_TICK] as Array[int], "hit")
	expect(wake.hit_given, "used up")
	# The boat is carried to the island side, where the other front sweeps over it: no second hit.
	var again: Array[int] = run(400, Vector2(-40.0, -1140.0), BROADSIDE)
	expect_eq(again.size(), 0, "the wake never hits twice")
	expect_eq(wake.state, MotorboatWake.State.SPENT, "spent")
	var later: Array[int] = run(400, NEAR, BROADSIDE)
	expect_eq(later.size(), 0, "a spent trigger does nothing more")
	expect_eq(wake.state, MotorboatWake.State.SPENT, "and stays spent")
	# Without the first hit that same boat on the island side is hit by the ISLAND front.
	var fresh: MotorboatWake = MotorboatWake.new(tuning, TRIGGER)
	var fresh_hits: int = 0
	fresh.step(TICK, NEAR, BROADSIDE)
	for tick: int in 400:
		if fresh.step(TICK, Vector2(-40.0, -1140.0), BROADSIDE) != null:
			fresh_hits += 1
	expect_eq(fresh_hits, 1, "the island-side boat is there to be hit")


func test_the_hit_applied_to_run_state_knocks_a_beer_over_shoves_and_sets_the_guy_bailing() -> void:
	run(NEAR_HIT_TICK, NEAR, BROADSIDE)
	var hit: MotorboatWake.Hit = last_hit
	expect(hit != null, "hit")
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	var boat_tuning: BoatTuning = BoatTuning.new()
	boat_tuning.bail_rate = BAIL_RATE
	state.paddling = Paddling.new(boat_tuning)
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	# What scripts/hazards/wake.gd does with a hit.
	var seat: int = state.beer_overboard(hit.hull, NEAR)
	state.shove(hit.shove)
	state.water_aboard(hit.hull, hit.water)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy's beer went over: he winds up")
	expect(state.rescue.winding_up(seat), "winding up to jump")
	expect_eq(state.take_shove(), hit.shove, "the boat takes the shove")
	expect_near(state.water_of(Rescue.Hull.LEFT), WATER, 0.0001, "wake_water aboard the high hull")
	expect_eq(state.bailer_of(Rescue.Hull.LEFT), Paddling.Seat.LEFT_FRONT, "the guy on that side bails")
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	expect_near(state.step(TICK, NEAR).thrust, 0.0, 0.0001, "his seat gives no strokes")
	state.stroke(Paddling.Seat.RIGHT_FRONT, 10.0)
	expect(state.step(TICK, NEAR).thrust > 0.0, "the other hull still paddles")
	state.step(0.5, NEAR)
	expect_near(state.water_of(Rescue.Hull.LEFT), WATER - BAIL_RATE * (0.5 + 2.0 * TICK), 0.0001, "bailed at bail_rate per second")
	state.free()


var last_ram: MotorboatWake.Hit
var wave_hits: Array[int] = []


## Steps for some ticks with the boat still; returns the ticks (1-based) that gave a ram and keeps
## the last in last_ram. The wave's hits go to wave_hits.
func run_rams(ticks: int, boat: Vector2, rotation: float = 0.0) -> Array[int]:
	var rams: Array[int] = []
	wave_hits = []
	for tick: int in ticks:
		var hit: MotorboatWake.Hit = wake.step(TICK, boat, rotation)
		if hit != null:
			wave_hits.append(tick + 1)
		var ram: MotorboatWake.Hit = wake.take_ram()
		if ram != null:
			rams.append(tick + 1)
			last_ram = ram
	return rams


func test_a_boat_on_the_motorboats_course_is_rammed_once() -> void:
	var rams: Array[int] = run_rams(200, ON_COURSE, 0.0)
	expect_eq(rams.size(), 1, "exactly one ram in the whole event")
	expect(rams[0] < ON_COURSE_TICK, "the first step the motorboat is within wake_hull_radius, before it is alongside")
	expect(last_ram.ram, "marked as the ram")
	expect(wake.rammed, "used up")
	expect_eq(last_ram.hull, Rescue.Hull.LEFT, "the motorboat comes from the boat's left: the left hull")
	expect_eq(last_ram.shove, Vector2(RAM_SHOVE, 0.0), "wake_ram_shove along the motorboat's travel, rightward")
	expect_near(last_ram.water, 0.0, 0.0001, "no water from a ram")


func test_the_ram_hull_is_the_side_the_motorboat_is_on_in_the_boats_frame() -> void:
	run_rams(200, ON_COURSE, PI)
	expect_eq(last_ram.hull, Rescue.Hull.RIGHT, "the boat turned round: the motorboat is on its right")
	wake.reset()
	run_rams(200, ON_COURSE, 0.0)
	expect_eq(last_ram.hull, Rescue.Hull.LEFT, "facing up it comes from the left")
	wake.motorboat = Vector2(-40.0, -1030.0)
	expect_eq(wake.ram_hull(Vector2(-10.0, -1030.0), 0.0), Rescue.Hull.LEFT, "the motorboat left of the boat")
	expect_eq(wake.ram_hull(Vector2(-70.0, -1030.0), 0.0), Rescue.Hull.RIGHT, "the motorboat right of the boat")


func test_a_leftward_motorboat_shoves_leftward() -> void:
	tuning.wake_trigger_radius = 400.0
	wake = MotorboatWake.new(tuning, Vector2(100.0, -1000.0))
	var rams: Array[int] = run_rams(200, Vector2(40.0, COURSE_Y), 0.0)
	expect_eq(rams.size(), 1, "one ram")
	expect_eq(last_ram.shove, Vector2(-RAM_SHOVE, 0.0), "along its course, leftward")
	expect_eq(last_ram.hull, Rescue.Hull.RIGHT, "it comes from the boat's right")


func test_a_boat_out_of_the_motorboats_reach_is_not_rammed() -> void:
	expect_eq(run_rams(200, NEAR, BROADSIDE).size(), 0, "64 px off the course: no ram")
	wake.reset()
	expect_eq(run_rams(200, FAR, 0.0).size(), 0, "far from the trigger: the event never starts")
	wake.reset()
	expect_eq(run_rams(200, Vector2(-40.0, COURSE_Y + HULL_RADIUS + 1.0), 0.0).size(), 0, "just past wake_hull_radius of the course")
	wake.reset()
	expect_eq(run_rams(200, Vector2(-40.0, COURSE_Y + HULL_RADIUS - 1.0), 0.0).size(), 1, "just inside it")


func test_the_ram_is_apart_from_the_waves_one_hit() -> void:
	var rotation: float = rotation_of(direction_of(MotorboatWake.Front.SHORE))
	var rams: Array[int] = run_rams(200, ON_COURSE, rotation)
	expect_eq(rams.size(), 1, "the ram")
	expect_eq(wave_hits, [ON_COURSE_TICK] as Array[int], "and the wave's hit, apart, on its own tick")
	expect(wake.hit_given and wake.rammed, "each used up on its own")
	wake.reset()
	rams = run_rams(200, NEAR, BROADSIDE)
	expect_eq(rams.size(), 0, "a wave hit without a ram")
	expect_eq(wave_hits.size(), 1, "the wave still hits")
	wake.reset()
	rams = run_rams(200, ON_COURSE, 0.0)
	expect_eq(rams.size(), 1, "a ram")
	expect_eq(wave_hits.size(), 0, "head-on to both fronts: no wave hit")
	expect_false(wake.hit_given, "the wave's hit is not used up by the ram")


func test_a_rolling_wake_has_no_hull_to_ram_with() -> void:
	tuning.wake_trigger_radius = 400.0
	run(ROLL_TICK, NEAR)
	expect_eq(wake.state, MotorboatWake.State.ROLLING, "across")
	var rams: Array[int] = run_rams(200, Vector2(320.0, COURSE_Y), 0.0)
	expect_eq(rams.size(), 0, "a boat at the parked apex is not rammed")


func test_the_ram_applied_to_run_state_knocks_a_beer_over_and_shoves() -> void:
	run_rams(200, ON_COURSE, 0.0)
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	# What scripts/hazards/wake.gd does with a ram.
	var seat: int = state.beer_overboard(last_ram.hull, ON_COURSE)
	state.shove(last_ram.shove)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy's beer went over")
	expect_eq(state.take_shove(), Vector2(RAM_SHOVE, 0.0), "the boat is shoved along the course")
	state.free()


func test_same_inputs_same_hit() -> void:
	var other: MotorboatWake = MotorboatWake.new(tuning, TRIGGER)
	var mine: Array[int] = []
	var theirs: Array[int] = []
	for tick: int in 800:
		var boat: Vector2 = NEAR + Vector2(30.0 * sin(tick * 0.05), -0.5 * tick)
		var rotation: float = BROADSIDE + 0.3 * sin(tick * 0.02)
		var hit: MotorboatWake.Hit = wake.step(TICK, boat, rotation)
		if hit != null:
			mine.append(tick * 2 + int(hit.hull))
		var their_hit: MotorboatWake.Hit = other.step(TICK, boat, rotation)
		if their_hit != null:
			theirs.append(tick * 2 + int(their_hit.hull))
		expect_eq(wake.state, other.state, "same state at tick %d" % tick)
		expect_eq(wake.motorboat, other.motorboat, "same motorboat at tick %d" % tick)
		for front: MotorboatWake.Front in MotorboatWake.FRONTS:
			expect_eq(wake.front_point(front), other.front_point(front), "same front at tick %d" % tick)
	expect_eq(mine.size(), 1, "the moving boat got hit once")
	expect_eq(mine, theirs, "the same hit on the same hull")
