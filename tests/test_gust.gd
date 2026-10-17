extends "res://tools/test_case.gd"
## T17 · Wind gust: the boat passing a gust trigger (within gust_trigger_radius) starts the
## warning, gust_warning seconds of ripples with no push, then the gust pushes the boat sideways
## across the lake at gust_shove pixels per second for gust_time seconds, compounding with the
## current, which the boat applies through RunState.push() (GDD › Systems › Hazards, the Wind
## gust row). The direction is fixed per event from the trigger's side of the lake: left of the
## middle blows rightward, otherwise leftward. One event per trigger; the same inputs give the
## same push.
##
## The tick is 1/64 s and the times are multiples of it, so every sum is exact and the ticks can
## be named: the warning is 64 ticks and the push 128.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 64.0
const RADIUS: float = 100.0
const WARNING: float = 1.0
const TIME: float = 2.0
const SHOVE: float = 50.0
const WARNING_TICKS: int = 64
const PUSH_TICKS: int = 128
## Left of the lake's middle: the wind blows rightward.
const TRIGGER: Vector2 = Vector2(-100.0, -1000.0)
## Inside the radius, 60 px to the right of the trigger.
const NEAR: Vector2 = Vector2(-40.0, -1000.0)
const FAR: Vector2 = Vector2(-100.0, -800.0)
const RIGHTWARD: Vector2 = Vector2(SHOVE, 0.0)
const LEFTWARD: Vector2 = Vector2(-SHOVE, 0.0)

var tuning: LakeTuning
var gust: WindGust
var last_push: Vector2 = Vector2.ZERO


func before_each() -> void:
	tuning = LakeTuning.new()
	tuning.gust_trigger_radius = RADIUS
	tuning.gust_warning = WARNING
	tuning.gust_time = TIME
	tuning.gust_shove = SHOVE
	gust = WindGust.new(tuning, TRIGGER)
	last_push = Vector2.ZERO


## Steps the gust for some ticks with the boat still; returns how many ticks pushed, and keeps
## the last push in last_push.
func run(ticks: int, boat: Vector2) -> int:
	var pushed: int = 0
	for tick: int in ticks:
		var push: Vector2 = gust.step(TICK, boat)
		if push != Vector2.ZERO:
			pushed += 1
			last_push = push
	return pushed


func test_nothing_happens_outside_the_radius() -> void:
	expect_eq(run(400, FAR), 0, "no push")
	expect_eq(gust.state, WindGust.State.WAITING, "still armed")


func test_the_boat_inside_the_radius_starts_the_warning_ripples_first() -> void:
	expect_eq(run(1, NEAR), 0, "no push on the tick it starts")
	expect_eq(gust.state, WindGust.State.WARNING, "the ripples race: the warning")
	expect_near(gust.time_left, WARNING, 0.0001, "for gust_warning")
	expect_eq(run(WARNING_TICKS - 1, NEAR), 0, "ripples only, no push, through the warning")
	expect_eq(gust.state, WindGust.State.WARNING, "still warning one tick short")
	expect_eq(run(1, NEAR), 0, "the tick the warning ends has no push yet")
	expect_eq(gust.state, WindGust.State.BLOWING, "then the gust blows")
	expect_near(gust.time_left, TIME, 0.0001, "for gust_time")


func test_then_the_boat_is_pushed_sideways_by_gust_shove_for_gust_time() -> void:
	run(1 + WARNING_TICKS, NEAR)
	expect_eq(run(1, NEAR), 1, "the push starts")
	expect_eq(last_push, RIGHTWARD, "gust_shove per second, sideways across the lake, rightward")
	expect_eq(run(PUSH_TICKS - 2, NEAR), PUSH_TICKS - 2, "every tick pushes")
	expect_eq(last_push, RIGHTWARD, "the same push throughout")
	expect_eq(gust.state, WindGust.State.BLOWING, "still blowing one tick short of gust_time")
	expect_eq(run(1, NEAR), 1, "the last tick of the push")
	expect_eq(gust.state, WindGust.State.SPENT, "spent after gust_time")
	expect_eq(run(1, NEAR), 0, "no push once spent")


func test_the_push_lasts_gust_time_in_all() -> void:
	run(1 + WARNING_TICKS, NEAR)
	expect_eq(run(1000, NEAR), PUSH_TICKS, "gust_time of pushing ticks, no more")


func test_the_gust_blows_whether_or_not_the_boat_stays() -> void:
	run(1, NEAR)
	expect_eq(gust.state, WindGust.State.WARNING, "started")
	expect_eq(run(1000, FAR), PUSH_TICKS, "it runs its course with the boat gone")
	expect_eq(last_push, RIGHTWARD, "the same way")
	expect_eq(gust.state, WindGust.State.SPENT, "spent")


func test_the_direction_is_fixed_by_the_triggers_side_of_the_lake() -> void:
	expect_eq(gust.direction, 1.0, "a trigger left of the middle: rightward, known before the start")
	var mirrored: WindGust = WindGust.new(tuning, Vector2(100.0, -1000.0))
	expect_eq(mirrored.direction, -1.0, "a trigger right of the middle: leftward")
	var boat: Vector2 = Vector2(40.0, -1000.0)
	for tick: int in 1 + WARNING_TICKS:
		expect_eq(mirrored.step(TICK, boat), Vector2.ZERO, "no push at tick %d" % tick)
	expect_eq(mirrored.step(TICK, boat), LEFTWARD, "pushed leftward")
	expect_eq(mirrored.step(TICK, Vector2(-200.0, -1000.0)), LEFTWARD, "the boat crossing to the other side changes nothing: fixed per event")
	var middle: WindGust = WindGust.new(tuning, Vector2(0.0, -1000.0))
	expect_eq(middle.direction, -1.0, "on the middle counts as the right side")


func test_one_event_per_trigger() -> void:
	expect_eq(run(1 + WARNING_TICKS + PUSH_TICKS, NEAR), PUSH_TICKS, "one gust")
	expect_eq(gust.state, WindGust.State.SPENT, "spent")
	expect_eq(run(400, NEAR), 0, "a spent trigger does nothing more")
	expect_eq(gust.state, WindGust.State.SPENT, "and stays spent")
	gust.reset()
	expect_eq(gust.state, WindGust.State.WAITING, "reset arms it again")
	expect_eq(gust.direction, 1.0, "the same way")


func test_same_inputs_same_push() -> void:
	var other: WindGust = WindGust.new(tuning, TRIGGER)
	var mine: int = 0
	var theirs: int = 0
	for tick: int in 800:
		var boat: Vector2 = NEAR + Vector2(30.0 * sin(tick * 0.05), -0.5 * tick)
		var push: Vector2 = gust.step(TICK, boat)
		var their_push: Vector2 = other.step(TICK, boat)
		if push != Vector2.ZERO:
			mine += 1
		if their_push != Vector2.ZERO:
			theirs += 1
		expect_eq(push, their_push, "same push at tick %d" % tick)
		expect_eq(gust.state, other.state, "same state at tick %d" % tick)
		expect_near(gust.time_left, other.time_left, 0.0, "same time left at tick %d" % tick)
	expect_eq(mine, PUSH_TICKS, "the moving boat was pushed for gust_time")
	expect_eq(mine, theirs, "both the same")


func test_the_push_applied_to_run_state_reaches_the_boat_once_per_frame() -> void:
	run(1 + WARNING_TICKS + 1, NEAR)
	expect_eq(last_push, RIGHTWARD, "blowing")
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	# What scripts/hazards/gust.gd does each frame the gust blows.
	state.push(last_push)
	expect_eq(state.take_push(), RIGHTWARD, "the boat takes the push")
	expect_eq(state.take_push(), Vector2.ZERO, "once: the next frame needs a new push")
	state.push(last_push)
	state.push(Vector2(0.0, 10.0))
	expect_eq(state.take_push(), RIGHTWARD + Vector2(0.0, 10.0), "pushes in one frame add up")
	expect_eq(state.take_shove(), Vector2.ZERO, "a push is not a one-off shove")
	state.push(last_push)
	state.reset()
	expect_eq(state.take_push(), Vector2.ZERO, "a reset drops it")
	state.free()
