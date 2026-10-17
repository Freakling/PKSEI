extends "res://tools/test_case.gd"
## Cross-current stripe: a stripe is a rectangle across the whole lake, stripe_length tall from its
## trigger toward the island; the boat inside it is pushed sideways by stripe_force pixels per
## second, rightward when the stripe is left of the lake's middle and leftward otherwise (the
## gust's rule), and the push reaches the boat through RunState.push() / take_push() exactly once
## (GDD › Systems › Hazards, the Cross-current stripe row).

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const LAKE_WIDTH: float = 640.0
const LENGTH: float = 300.0
const FORCE: float = 40.0
## Off the lake's centre line: the stripe spans the lake all the same.
const LEFT_TRIGGER: Vector2 = Vector2(-50.0, -1000.0)
const RIGHT_TRIGGER: Vector2 = Vector2(50.0, -1000.0)
const INSIDE: Vector2 = Vector2(0.0, -1150.0)

var tuning: LakeTuning
var stripe: CrossCurrent


func before_each() -> void:
	tuning = LakeTuning.new()
	tuning.lake_width = LAKE_WIDTH
	tuning.stripe_length = LENGTH
	tuning.stripe_force = FORCE
	stripe = CrossCurrent.new(tuning, LEFT_TRIGGER)


func test_the_stripe_reaches_stripe_length_from_the_trigger_toward_the_island() -> void:
	expect_near(stripe.near_y(), -1000.0, 0.0001, "the shore-side edge is the trigger")
	expect_near(stripe.far_y(), -1300.0, 0.0001, "the island-side edge is stripe_length further up")
	expect(stripe.inside(LEFT_TRIGGER), "the trigger itself is inside")
	expect(stripe.inside(INSIDE), "the middle of the stripe")
	expect(stripe.inside(Vector2(0.0, -1300.0)), "the far edge counts")
	expect_false(stripe.inside(Vector2(0.0, -1301.0)), "past the far edge: out")
	expect_false(stripe.inside(Vector2(0.0, -999.0)), "short of the trigger: out")
	expect_false(stripe.inside(Vector2(0.0, -800.0)), "well short: out")


func test_the_stripe_spans_the_whole_lake() -> void:
	expect_near(stripe.half_width(), 320.0, 0.0001, "half of lake_width")
	expect(stripe.inside(Vector2(-320.0, -1150.0)), "the left edge of the lake")
	expect(stripe.inside(Vector2(320.0, -1150.0)), "the right edge of the lake")
	expect_false(stripe.inside(Vector2(-321.0, -1150.0)), "off the lake: out")
	expect_false(stripe.inside(Vector2(321.0, -1150.0)), "off the lake: out")


func test_the_direction_is_sideways_and_set_by_the_trigger_side_of_the_lake() -> void:
	expect_eq(stripe.direction(), Vector2(1.0, 0.0), "left of the middle pushes rightward")
	var right: CrossCurrent = CrossCurrent.new(tuning, RIGHT_TRIGGER)
	expect_eq(right.direction(), Vector2(-1.0, 0.0), "right of the middle pushes leftward")
	var middle: CrossCurrent = CrossCurrent.new(tuning, Vector2(0.0, -1000.0))
	expect_eq(middle.direction(), Vector2(-1.0, 0.0), "on the middle line the else side: leftward, as the gust")


func test_the_push_is_stripe_force_in_the_stripe_direction() -> void:
	expect_eq(stripe.push(), Vector2(FORCE, 0.0), "stripe_force rightward from the left side")
	var right: CrossCurrent = CrossCurrent.new(tuning, RIGHT_TRIGGER)
	expect_eq(right.push(), Vector2(-FORCE, 0.0), "stripe_force leftward from the right side")
	expect_near(stripe.push().length(), FORCE, 0.0001, "the magnitude is stripe_force per second")


func test_through_run_state_the_push_is_handed_to_the_boat_once() -> void:
	var state: Node = RunStateScript.new()
	# What scripts/hazards/cross_current.gd does each frame the boat is inside.
	state.push(stripe.push())
	expect_eq(state.take_push(), Vector2(FORCE, 0.0), "the boat takes stripe_force in the stripe's direction")
	expect_eq(state.take_push(), Vector2.ZERO, "taken once: the next take has nothing")
	state.free()
