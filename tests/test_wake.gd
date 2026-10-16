extends "res://tools/test_case.gd"
## T16 · Motorboat wake: the boat passing a wake trigger (within wake_trigger_radius) sends a
## motorboat across the lake wake_lead ahead at wake_boat_speed, and once it is across a wave
## front rolls toward the shore at wake_speed. The front crossing a head-on boat does nothing; a
## broadside boat takes one hit: a beer overboard on the high hull (the one facing the wave), a
## shove of wake_shove sideways away from the wave and wake_water aboard that hull, which its guy
## bails at BoatTuning.bail_rate while his seat gives no strokes (GDD › Systems › Hazards, the
## Motorboat wake row). One event per trigger; same inputs, same hit.
##
## The tick is 1/64 s and the speeds and distances are multiples of it, so every sum is exact:
## the motorboat moves 10 px per tick and crosses the 640 px lake in 64 ticks, the front rolls
## 1 px per tick, and the ticks can be named.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 64.0
const RADIUS: float = 100.0
const LEAD: float = 64.0
const BOAT_SPEED: float = 640.0
const LAKE_WIDTH: float = 640.0
const SPEED: float = 64.0
const SHOVE: float = 50.0
const WATER: float = 3.0
const HEAD_ON: float = 30.0
const BAIL_RATE: float = 2.0
## Left of the lake's middle, so the motorboat sets off from the left edge and crosses rightward.
const TRIGGER: Vector2 = Vector2(-100.0, -1000.0)
const COURSE_Y: float = -1064.0
## Inside the radius, 60 px to the right of the trigger, on its y.
const NEAR: Vector2 = Vector2(-40.0, -1000.0)
const FAR: Vector2 = Vector2(-100.0, -800.0)
## The tick the event starts, the tick the motorboat is across and the front starts rolling, the
## tick the front reaches NEAR's y and the tick it stops (TRIGGER.y + RADIUS).
const START_TICK: int = 1
const ROLL_TICK: int = START_TICK + 64
const HIT_TICK: int = ROLL_TICK + 64
const END_TICK: int = ROLL_TICK + 164
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
	tuning.wake_head_on_angle = HEAD_ON
	tuning.wake_shove = SHOVE
	tuning.wake_water = WATER
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
	var mirrored: MotorboatWake = MotorboatWake.new(tuning, Vector2(100.0, -1000.0))
	mirrored.step(TICK, Vector2(40.0, -1000.0))
	expect_eq(mirrored.state, MotorboatWake.State.CROSSING, "set off")
	expect_eq(mirrored.direction, -1.0, "leftward")
	expect_eq(mirrored.motorboat, Vector2(320.0, COURSE_Y), "from the right edge")
	for tick: int in 64:
		mirrored.step(TICK, Vector2(40.0, -1000.0))
	expect_eq(mirrored.state, MotorboatWake.State.ROLLING, "across after 64 ticks")
	expect_eq(mirrored.motorboat, Vector2(-320.0, COURSE_Y), "it left by the left edge")


func test_the_motorboat_crosses_then_the_front_rolls_at_wake_speed() -> void:
	run(ROLL_TICK - 1, NEAR)
	expect_eq(wake.state, MotorboatWake.State.CROSSING, "still crossing one tick short")
	expect_eq(wake.motorboat, Vector2(310.0, COURSE_Y), "10 px per tick along the course")
	run(1, NEAR)
	expect_eq(wake.state, MotorboatWake.State.ROLLING, "across: the front rolls")
	expect_eq(wake.motorboat, Vector2(320.0, COURSE_Y), "it left by the right edge")
	expect_near(wake.front_y, COURSE_Y, 0.0001, "the front starts on the course")
	run(1, NEAR)
	expect_near(wake.front_y, COURSE_Y + 1.0, 0.0001, "1 px per tick toward the shore")
	run(END_TICK - ROLL_TICK - 2, NEAR)
	expect_eq(wake.state, MotorboatWake.State.ROLLING, "still rolling one tick short of the end")
	expect_near(wake.front_y, TRIGGER.y + RADIUS - 1.0, 0.0001, "almost at the end")
	run(1, NEAR)
	expect_eq(wake.state, MotorboatWake.State.SPENT, "spent once the front has passed the trigger by the radius")
	expect_near(wake.front_y, TRIGGER.y + RADIUS, 0.0001, "the front stops there")


func test_a_head_on_boat_gets_no_hit() -> void:
	var facing_the_wave: Array[int] = run(END_TICK, NEAR, 0.0)
	expect_eq(facing_the_wave.size(), 0, "straight into the wave: nothing")
	expect_eq(wake.state, MotorboatWake.State.SPENT, "the event still runs its course")
	expect(wake.hit_given, "the crossing is used up all the same")
	wake.reset()
	var facing_away: Array[int] = run(END_TICK, NEAR, PI)
	expect_eq(facing_away.size(), 0, "straight away from the wave: nothing")
	wake.reset()
	var within_the_angle: Array[int] = run(END_TICK, NEAR, deg_to_rad(HEAD_ON - 1.0))
	expect_eq(within_the_angle.size(), 0, "inside wake_head_on_angle: nothing")


func test_a_broadside_boat_gets_one_hit_on_the_high_hull() -> void:
	var hits: Array[int] = run(END_TICK, NEAR, BROADSIDE)
	expect_eq(hits, [HIT_TICK] as Array[int], "one hit, the tick the front reaches the boat")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "facing right, the left hull faces the wave")
	expect_near(last_hit.shove.x, 0.0, 0.0001, "the shove is sideways in the boat's frame")
	expect_near(last_hit.shove.y, SHOVE, 0.0001, "toward the shore: away from the wave, by wake_shove")
	expect_near(last_hit.water, WATER, 0.0001, "wake_water comes aboard")
	wake.reset()
	hits = run(END_TICK, NEAR, -BROADSIDE)
	expect_eq(hits, [HIT_TICK] as Array[int], "one hit again")
	expect_eq(last_hit.hull, Rescue.Hull.RIGHT, "facing left, the right hull faces the wave")
	expect_near(last_hit.shove.x, 0.0, 0.0001, "still sideways")
	expect_near(last_hit.shove.y, SHOVE, 0.0001, "still away from the wave")


func test_a_slanted_boat_is_shoved_along_its_own_side() -> void:
	var hits: Array[int] = run(END_TICK, NEAR, PI / 4.0)
	expect_eq(hits.size(), 1, "45 degrees is broadside")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "the left hull faces the wave")
	var side: Vector2 = Vector2.RIGHT.rotated(PI / 4.0) * SHOVE
	expect_near(last_hit.shove.x, side.x, 0.0001, "shoved along the boat's right")
	expect_near(last_hit.shove.y, side.y, 0.0001, "toward the low hull")


func test_one_event_per_trigger() -> void:
	run(HIT_TICK, NEAR, BROADSIDE)
	expect(wake.hit_given, "hit")
	# The boat gets back ahead of the front and meets it again: no second hit.
	var again: Array[int] = run(END_TICK - HIT_TICK, Vector2(-40.0, -950.0), BROADSIDE)
	expect_eq(again.size(), 0, "the front never hits twice")
	expect_eq(wake.state, MotorboatWake.State.SPENT, "spent")
	var later: Array[int] = run(400, NEAR, BROADSIDE)
	expect_eq(later.size(), 0, "a spent trigger does nothing more")
	expect_eq(wake.state, MotorboatWake.State.SPENT, "and stays spent")


func test_a_boat_past_the_course_before_the_front_starts_is_never_hit() -> void:
	run(START_TICK, NEAR, BROADSIDE)
	var hits: Array[int] = run(END_TICK, Vector2(-40.0, -1100.0), BROADSIDE)
	expect_eq(hits.size(), 0, "ahead of the course: the wave rolls away from it")
	expect_eq(wake.state, MotorboatWake.State.SPENT, "spent all the same")


func test_the_hit_applied_to_run_state_knocks_a_beer_over_shoves_and_sets_the_guy_bailing() -> void:
	run(HIT_TICK, NEAR, BROADSIDE)
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
		expect_near(wake.front_y, other.front_y, 0.0, "same front at tick %d" % tick)
	expect_eq(mine.size(), 1, "the moving boat got hit once")
	expect_eq(mine, theirs, "the same hit on the same hull")
