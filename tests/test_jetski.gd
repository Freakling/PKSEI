extends "res://tools/test_case.gd"
## T21 · Jet-ski idiot: the boat passing a jet-ski trigger (within jetski_trigger_radius) starts
## a warning of jetski_warning seconds in which nothing moves, then the jet-ski sets off from
## off-screen on the trigger's side of the lake (JetSki.EDGE_MARGIN beyond the edge) and crosses
## on a straight line at jetski_speed through the point jetski_lead ahead of where the boat was
## when the crossing started, until it leaves by the far edge. A boat its path passes within
## jetski_hit_radius of takes one hit: a shove of jetski_shove along the jet-ski's travel and a
## beer overboard on the hull it came from, in the boat's frame (GDD › Systems › Hazards, the
## Jet-ski idiot row). One event per trigger; same inputs, same hit.
## T52 · The course is a diagonal from the lake's edge: it starts level with the trigger, runs
## through the aim point, and carries on past the far edge (the straight line from the start
## through the aim), so the boat's own y moves the course's slope.
##
## The tick is 1/64 s and the speed is a multiple of it, so each move is 10 px along the course
## (the course's x and y steps are not whole numbers, so positions are compared with tolerance).
## The trigger's line is level with the trigger; the aim is 64 px above the boat, which sits at
## ON_LINE, so the course climbs 64 px over 640 px: a slope of -0.1.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 64.0
const RADIUS: float = 100.0
const WARNING: float = 1.0
const SPEED: float = 640.0
const LAKE_WIDTH: float = 640.0
const LEAD: float = 64.0
const HIT_RADIUS: float = 16.0
const SHOVE: float = 200.0
## Where the jet-ski sets off and leaves: the lake's edge plus the margin.
const EDGE: float = LAKE_WIDTH * 0.5 + JetSki.EDGE_MARGIN
## Left of the lake's middle, so the jet-ski sets off from the left edge and crosses rightward.
const TRIGGER: Vector2 = Vector2(-100.0, -1000.0)
## Inside the radius, 60 px to the right of the trigger, on its y.
const NEAR: Vector2 = Vector2(-40.0, -1000.0)
const FAR: Vector2 = Vector2(-100.0, -800.0)
## Where the jet-ski sets off: the left edge plus the margin, level with the trigger.
const START: Vector2 = Vector2(-680.0, -1000.0)
## The aim: LEAD ahead of NEAR. A boat sitting on it is on the course.
const ON_LINE: Vector2 = Vector2(-40.0, -1064.0)
## Where the course leaves by the right edge: the line from START through ON_LINE at x = EDGE.
const FAR_END: Vector2 = Vector2(680.0, -1136.0)
## The tick the warning starts, the tick the crossing starts, the tick the jet-ski's path first
## comes within HIT_RADIUS of ON_LINE (move 63: 630 px along the course, 13 px short of the boat;
## move 62 is 23 px short), and the tick it leaves by the far edge (137 moves: x gains 9.95 px a
## move, and 136 moves leave it 7 px short of the edge).
const START_TICK: int = 1
const CROSS_TICK: int = START_TICK + 64
const HIT_TICK: int = CROSS_TICK + 63
const END_TICK: int = CROSS_TICK + 137

var tuning: LakeTuning
var jetski: JetSki
var last_hit: JetSki.Hit
## Ticks stepped so far, so hits can be named across several run() calls.
var _tick: int = 0


func before_each() -> void:
	tuning = LakeTuning.new()
	tuning.lake_width = LAKE_WIDTH
	tuning.jetski_trigger_radius = RADIUS
	tuning.jetski_warning = WARNING
	tuning.jetski_speed = SPEED
	tuning.jetski_lead = LEAD
	tuning.jetski_hit_radius = HIT_RADIUS
	tuning.jetski_shove = SHOVE
	jetski = JetSki.new(tuning, TRIGGER)
	last_hit = null
	_tick = 0


## Steps the event for some ticks with the boat still; returns the ticks (1-based, counted from
## the first run() call) that hit, and keeps the last hit in last_hit.
func run(ticks: int, boat: Vector2, rotation: float = 0.0) -> Array[int]:
	var hits: Array[int] = []
	for tick: int in ticks:
		_tick += 1
		var hit: JetSki.Hit = jetski.step(TICK, boat, rotation)
		if hit != null:
			hits.append(_tick)
			last_hit = hit
	return hits


## The unit direction of the course: from START through ON_LINE.
func course_direction() -> Vector2:
	return (ON_LINE - START).normalized()


## How far a point is off the course's line, signed (zero on the line).
func off_line(point: Vector2) -> float:
	var along: Vector2 = point - START
	var direction: Vector2 = course_direction()
	return along.x * direction.y - along.y * direction.x


## Two points within a hundredth of a pixel: the course's steps are not exact in float32.
func expect_point(actual: Vector2, expected: Vector2, message: String) -> void:
	expect_near(actual.distance_to(expected), 0.0, 0.01, message)


func test_nothing_happens_outside_the_radius() -> void:
	var hits: Array[int] = run(400, FAR)
	expect_eq(jetski.state, JetSki.State.WAITING, "still armed")
	expect_eq(hits.size(), 0, "no hit")
	expect_eq(jetski.jetski, TRIGGER, "nothing on the water")


func test_the_warning_lasts_jetski_warning_with_no_movement() -> void:
	run(START_TICK, NEAR)
	expect_eq(jetski.state, JetSki.State.WARNING, "inside the radius: the warning starts")
	expect_eq(jetski.direction, 1.0, "it will come from the left, the trigger's side")
	expect_near(jetski.time_left, WARNING, 0.0001, "jetski_warning to go")
	run(CROSS_TICK - START_TICK - 1, NEAR)
	expect_eq(jetski.state, JetSki.State.WARNING, "still the warning one tick short")
	expect_eq(jetski.jetski, TRIGGER, "nothing has moved")
	expect_near(jetski.time_left, TICK, 0.0001, "one tick to go")
	run(1, NEAR)
	expect_eq(jetski.state, JetSki.State.CROSSING, "then the jet-ski sets off")
	expect_near(jetski.time_left, 0.0, 0.0001, "the warning is over")
	expect_eq(jetski.aim, ON_LINE, "aimed jetski_lead ahead of the boat")
	expect_eq(jetski.jetski, START, "from off-screen beyond the left edge, level with the trigger")
	expect_eq(jetski.course, course_direction(), "on the course through the aimed point")


func test_the_crossing_is_a_straight_line_at_jetski_speed_through_the_aimed_point() -> void:
	run(CROSS_TICK, NEAR)
	var previous: Vector2 = jetski.jetski
	for move: int in 65:
		run(1, NEAR)
		expect_near(previous.distance_to(jetski.jetski), SPEED * TICK, 0.0001, "jetski_speed along the course, move %d" % (move + 1))
		expect_near(off_line(jetski.jetski), 0.0, 0.01, "on the line from the edge through the aim, move %d" % (move + 1))
		previous = jetski.jetski
	expect(jetski.jetski.x > ON_LINE.x, "past the aimed point after 65 moves")
	expect(jetski.jetski.y < TRIGGER.y - 50.0, "a diagonal: well up the lake by the aim, not level with the trigger")
	run(136 - 65, NEAR)
	expect_eq(jetski.state, JetSki.State.CROSSING, "still crossing one move short of the far edge")
	expect(jetski.jetski.x < EDGE, "not yet off the far edge")
	run(1, NEAR)
	expect_eq(jetski.state, JetSki.State.SPENT, "spent once it has left by the far edge")
	expect_point(jetski.jetski, FAR_END, "it carried on along the course to the far edge")


func test_a_trigger_right_of_the_middle_sends_it_leftward() -> void:
	var mirrored: JetSki = JetSki.new(tuning, Vector2(100.0, -1000.0))
	var boat: Vector2 = Vector2(40.0, -1000.0)
	for tick: int in CROSS_TICK:
		mirrored.step(TICK, boat)
	expect_eq(mirrored.state, JetSki.State.CROSSING, "set off")
	expect_eq(mirrored.direction, -1.0, "leftward")
	expect_eq(mirrored.jetski, Vector2(EDGE, -1000.0), "from beyond the right edge, level with the trigger")
	for tick: int in END_TICK - CROSS_TICK:
		mirrored.step(TICK, boat)
	expect_eq(mirrored.state, JetSki.State.SPENT, "across after 137 moves")
	expect_point(mirrored.jetski, Vector2(-EDGE, -1136.0), "it left beyond the left edge, up the lake")


func test_a_boat_on_the_line_gets_one_hit_shoved_along_the_travel_on_the_hull_it_came_from() -> void:
	run(CROSS_TICK, NEAR)
	var hits: Array[int] = run(END_TICK - CROSS_TICK, ON_LINE, 0.0)
	expect_eq(hits, [HIT_TICK] as Array[int], "one hit, the tick the jet-ski's path reaches the boat")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "facing the island, it came from the left hull")
	expect_eq(last_hit.shove, course_direction() * SHOVE, "shoved along its course by jetski_shove")
	expect(last_hit.shove.y < -1.0, "up the lake along the course, not sideways")
	expect_eq(jetski.state, JetSki.State.SPENT, "it carries on to the far edge")
	expect(jetski.hit_given, "the hit is used up")


func test_the_hull_is_the_side_it_came_from_in_the_boats_frame() -> void:
	run(CROSS_TICK, NEAR)
	run(END_TICK - CROSS_TICK, ON_LINE, PI)
	expect_eq(last_hit.hull, Rescue.Hull.RIGHT, "facing the shore, the right hull faces the left edge")
	expect_eq(last_hit.shove, course_direction() * SHOVE, "the shove is still the jet-ski's travel, not the boat's side")
	jetski.reset()
	run(CROSS_TICK, NEAR)
	run(END_TICK - CROSS_TICK, ON_LINE, -PI / 4.0)
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "slanted left: the left hull still faces it")
	var mirrored: JetSki = JetSki.new(tuning, Vector2(100.0, -1000.0))
	var hit: JetSki.Hit = null
	for tick: int in END_TICK:
		var boat: Vector2 = Vector2(40.0, -1000.0) if tick < CROSS_TICK else Vector2(40.0, -1064.0)
		var this_hit: JetSki.Hit = mirrored.step(TICK, boat, 0.0)
		if this_hit != null:
			hit = this_hit
	expect(hit != null, "the leftward jet-ski hits too")
	expect_eq(hit.hull, Rescue.Hull.RIGHT, "from the right edge: the right hull")
	expect(hit.shove.x < 0.0, "shoved leftward")
	expect_near(hit.shove.length(), SHOVE, 0.0001, "by jetski_shove")


func test_a_boat_well_off_the_line_gets_none() -> void:
	var hits: Array[int] = run(END_TICK, NEAR)
	expect_eq(hits.size(), 0, "the jet-ski passes jetski_lead ahead of a boat that holds back")
	expect_eq(jetski.state, JetSki.State.SPENT, "spent all the same")
	expect_false(jetski.hit_given, "no hit given")
	jetski.reset()
	run(CROSS_TICK, NEAR)
	hits = run(END_TICK - CROSS_TICK, Vector2(ON_LINE.x, ON_LINE.y - HIT_RADIUS - 1.0))
	expect_eq(hits.size(), 0, "just outside jetski_hit_radius of the course: nothing")


func test_a_fast_jetski_cannot_step_over_the_boat() -> void:
	run(CROSS_TICK, NEAR)
	var hit: JetSki.Hit = jetski.step(1.5, ON_LINE, 0.0)
	expect(hit != null, "one move of 960 px passes right over the boat and still hits")
	expect_eq(jetski.jetski, START + course_direction() * 960.0, "it is past the boat now")


func test_one_event_per_trigger() -> void:
	run(CROSS_TICK, NEAR)
	var first: Array[int] = run(HIT_TICK - CROSS_TICK, ON_LINE)
	expect_eq(first.size(), 1, "hit")
	# The boat gets ahead of the jet-ski along its course and meets it again: no second hit.
	var again: Array[int] = run(END_TICK - HIT_TICK, Vector2(200.0, -1088.0))
	expect_eq(again.size(), 0, "the jet-ski never hits twice")
	expect_eq(jetski.state, JetSki.State.SPENT, "spent")
	var later: Array[int] = run(400, ON_LINE)
	expect_eq(later.size(), 0, "a spent trigger does nothing more")
	expect_eq(jetski.state, JetSki.State.SPENT, "and stays spent")


func test_the_hit_applied_to_run_state_shoves_the_boat_and_knocks_a_beer_over() -> void:
	run(CROSS_TICK, NEAR)
	run(END_TICK - CROSS_TICK, ON_LINE, 0.0)
	var hit: JetSki.Hit = last_hit
	expect(hit != null, "hit")
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.paddling = Paddling.new(BoatTuning.new())
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	# What scripts/hazards/jetski.gd does with a hit.
	state.shove(hit.shove)
	var seat: int = state.beer_overboard(hit.hull, ON_LINE)
	expect_eq(state.take_shove(), hit.shove, "the boat takes the hard shove along the jet-ski's course")
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy's beer went over: he winds up")
	expect(state.rescue.winding_up(seat), "winding up to jump")
	state.free()


func test_same_inputs_same_hit() -> void:
	var other: JetSki = JetSki.new(tuning, TRIGGER)
	var mine: Array[int] = []
	var theirs: Array[int] = []
	for tick: int in 400:
		var boat: Vector2 = NEAR + Vector2(30.0 * sin(tick * 0.05), -1.0 * tick)
		var rotation: float = 0.3 * sin(tick * 0.02)
		var hit: JetSki.Hit = jetski.step(TICK, boat, rotation)
		if hit != null:
			mine.append(tick * 2 + int(hit.hull))
		var their_hit: JetSki.Hit = other.step(TICK, boat, rotation)
		if their_hit != null:
			theirs.append(tick * 2 + int(their_hit.hull))
		expect_eq(jetski.state, other.state, "same state at tick %d" % tick)
		expect_eq(jetski.jetski, other.jetski, "same jet-ski at tick %d" % tick)
	expect_eq(mine.size(), 1, "the boat paddling on into the line got hit once")
	expect_eq(mine, theirs, "the same hit on the same hull")
