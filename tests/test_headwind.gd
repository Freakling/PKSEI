extends "res://tools/test_case.gd"
## T17 · Harsh wind: a headwind stretch is a rectangle across the whole lake, headwind_length
## tall from its trigger toward the island; inside it the current pulls headwind_force pixels
## per second harder, so a weak stroke no longer gains water while a strong one still does
## (GDD › Systems › Hazards, the Harsh wind row). Through RunState: the scene sets the extra
## drift each step the boat is inside, and that step's Motion.drift_to_shore is current_speed +
## headwind_force per second; the next step is the plain current again unless it is set again.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 64.0
const LAKE_WIDTH: float = 640.0
const LENGTH: float = 200.0
const FORCE: float = 20.0
const CURRENT: float = 5.0
const STROKE_MIN: float = 20.0
const STROKE_MAX: float = 100.0
const CHARGE_TIME: float = 1.0
## What catamaran.gd makes of a Motion: thrust times thrust_scale is the speed a stroke gives,
## against drift_to_shore / delta, the speed the current pulls at. A tap gives 10 px/s and a
## full charge 50 px/s; the plain current is 5 px/s and the headwind makes it 25.
const THRUST_SCALE: float = 0.5
## Off the lake's centre line: the stretch spans the lake all the same.
const TRIGGER: Vector2 = Vector2(50.0, -1000.0)
const INSIDE: Vector2 = Vector2(0.0, -1100.0)

var tuning: LakeTuning
var wind: Headwind


func before_each() -> void:
	tuning = LakeTuning.new()
	tuning.lake_width = LAKE_WIDTH
	tuning.headwind_length = LENGTH
	tuning.headwind_force = FORCE
	wind = Headwind.new(tuning, TRIGGER)


## A RunState with a known boat tuning, sober guys (strokes land at once) and a seeded RNG.
func make_state() -> Node:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	var boat_tuning: BoatTuning = BoatTuning.new()
	boat_tuning.current_speed = CURRENT
	boat_tuning.stroke_force_min = STROKE_MIN
	boat_tuning.stroke_force_max = STROKE_MAX
	boat_tuning.charge_time = CHARGE_TIME
	state.paddling = Paddling.new(boat_tuning)
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	return state


func test_the_stretch_reaches_headwind_length_from_the_trigger_toward_the_island() -> void:
	expect_near(wind.near_y(), -1000.0, 0.0001, "the shore-side edge is the trigger")
	expect_near(wind.far_y(), -1200.0, 0.0001, "the island-side edge is headwind_length further up")
	expect(wind.inside(TRIGGER), "the trigger itself is inside")
	expect(wind.inside(INSIDE), "the middle of the stretch")
	expect(wind.inside(Vector2(0.0, -1200.0)), "the far edge counts")
	expect_false(wind.inside(Vector2(0.0, -1201.0)), "past the far edge: out")
	expect_false(wind.inside(Vector2(0.0, -999.0)), "short of the trigger: out")
	expect_false(wind.inside(Vector2(0.0, -800.0)), "well short: out")


func test_the_stretch_spans_the_whole_lake() -> void:
	expect_near(wind.half_width(), 320.0, 0.0001, "half of lake_width")
	expect(wind.inside(Vector2(-320.0, -1100.0)), "the left edge of the lake")
	expect(wind.inside(Vector2(320.0, -1100.0)), "the right edge of the lake")
	expect_false(wind.inside(Vector2(-321.0, -1100.0)), "off the lake: out")
	expect_false(wind.inside(Vector2(321.0, -1100.0)), "off the lake: out")


func test_extra_drift_is_headwind_force_inside_and_nothing_outside() -> void:
	expect_near(wind.extra_drift(INSIDE), FORCE, 0.0001, "headwind_force inside")
	expect_near(wind.extra_drift(Vector2(0.0, -900.0)), 0.0, 0.0001, "nothing outside")


func test_through_run_state_the_drift_is_current_plus_force_for_that_step() -> void:
	var state: Node = make_state()
	# What scripts/hazards/headwind.gd does each frame the boat is inside.
	state.set_extra_drift(wind.extra_drift(INSIDE))
	var motion: Paddling.Motion = state.step(TICK, INSIDE)
	expect_near(motion.drift_to_shore, (CURRENT + FORCE) * TICK, 0.0001, "current_speed + headwind_force per second")
	motion = state.step(TICK, INSIDE)
	expect_near(motion.drift_to_shore, CURRENT * TICK, 0.0001, "for that step only: the stretch sets it again while the boat is inside")
	state.set_extra_drift(FORCE)
	state.set_extra_drift(FORCE * 0.5)
	motion = state.step(TICK, INSIDE)
	expect_near(motion.drift_to_shore, (CURRENT + FORCE) * TICK, 0.0001, "overlapping stretches: the strongest wins, no stacking")
	state.set_extra_drift(FORCE)
	state.reset()
	motion = state.step(TICK, INSIDE)
	expect_near(motion.drift_to_shore, CURRENT * TICK, 0.0001, "a reset drops it")
	state.free()


func test_only_a_strong_stroke_outpaces_the_headwind() -> void:
	var state: Node = make_state()
	state.stroke(Paddling.Seat.LEFT_FRONT, 0.0)
	var motion: Paddling.Motion = state.step(TICK, INSIDE)
	expect_near(motion.thrust, STROKE_MIN, 0.0001, "a tap lands at stroke_force_min")
	expect(motion.thrust * THRUST_SCALE > motion.drift_to_shore / TICK, "without the headwind a weak stroke outpaces the current")
	state.set_extra_drift(FORCE)
	state.stroke(Paddling.Seat.RIGHT_FRONT, 0.0)
	motion = state.step(TICK, INSIDE)
	expect_near(motion.thrust, STROKE_MIN, 0.0001, "a tap again")
	expect_near(motion.drift_to_shore / TICK, CURRENT + FORCE, 0.0001, "against the headwind")
	expect(motion.thrust * THRUST_SCALE < motion.drift_to_shore / TICK, "in the headwind a weak stroke loses water")
	state.set_extra_drift(FORCE)
	state.stroke(Paddling.Seat.LEFT_BACK, CHARGE_TIME)
	motion = state.step(TICK, INSIDE)
	expect_near(motion.thrust, STROKE_MAX, 0.0001, "a full charge lands at stroke_force_max")
	expect(motion.thrust * THRUST_SCALE > motion.drift_to_shore / TICK, "a strong stroke still gains water")
	state.free()
