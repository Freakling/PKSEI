extends "res://tools/test_case.gd"
## T4 · Paddling: four charged strokes to thrust and turn, against the current
## (GDD › Systems › Catamaran and paddling).
## T53 · A backwards stroke pushes back by reverse_thrust_fraction of the forward power and
## turns the other way by the same amount (GDD › Presentation and Platforms, Input).

const HOLD: float = 1.0

var tuning: BoatTuning
var paddling: Paddling


func before_each() -> void:
	tuning = BoatTuning.new()
	tuning.stroke_force_min = 10.0
	tuning.stroke_force_max = 50.0
	tuning.charge_time = 2.0
	tuning.reverse_thrust_fraction = 0.6
	tuning.turn_torque = 0.5
	tuning.steer_share_front = 0.2
	tuning.steer_share_back = 0.8
	tuning.current_speed = 3.0
	paddling = Paddling.new(tuning)


func test_stroke_power_grows_with_hold_time_from_min_to_max_over_charge_time() -> void:
	expect_near(paddling.stroke_force(0.0), 10.0, 0.0001, "a tap is stroke_force_min")
	expect_near(paddling.stroke_force(1.0), 30.0, 0.0001, "half the charge time is halfway")
	expect_near(paddling.stroke_force(2.0), 50.0, 0.0001, "charge_time reaches stroke_force_max")
	expect_near(paddling.stroke_force(9.0), 50.0, 0.0001, "holding longer is capped at max")
	expect_near(paddling.stroke_force(-1.0), 10.0, 0.0001, "never below min")
	expect(paddling.stroke_force(0.5) < paddling.stroke_force(1.5), "longer hold, stronger stroke")


func test_equal_strokes_on_both_sides_thrust_forward_without_turning() -> void:
	var fronts: Array[Paddling.Stroke] = [
		Paddling.Stroke.new(Paddling.Seat.LEFT_FRONT, HOLD),
		Paddling.Stroke.new(Paddling.Seat.RIGHT_FRONT, HOLD),
	]
	var front_motion: Paddling.Motion = paddling.step(fronts, 0.1)
	expect_near(front_motion.thrust, 60.0, 0.0001, "two front strokes add their power")
	expect_near(front_motion.turn, 0.0, 0.0001, "front pair goes straight")

	var all_four: Array[Paddling.Stroke] = [
		Paddling.Stroke.new(Paddling.Seat.LEFT_FRONT, HOLD),
		Paddling.Stroke.new(Paddling.Seat.LEFT_BACK, HOLD),
		Paddling.Stroke.new(Paddling.Seat.RIGHT_FRONT, HOLD),
		Paddling.Stroke.new(Paddling.Seat.RIGHT_BACK, HOLD),
	]
	var motion: Paddling.Motion = paddling.step(all_four, 0.1)
	expect_near(motion.thrust, 120.0, 0.0001, "all four strokes add their power")
	expect_near(motion.turn, 0.0, 0.0001, "all four together go straight")
	expect_near(motion.drift_to_shore, 0.3, 0.0001, "the current still pulls while paddling")


func test_left_stroke_turns_right_and_right_stroke_turns_left() -> void:
	expect(paddling.stroke_turn(Paddling.Seat.LEFT_FRONT, HOLD) > 0.0, "left front turns right")
	expect(paddling.stroke_turn(Paddling.Seat.LEFT_BACK, HOLD) > 0.0, "left back turns right")
	expect(paddling.stroke_turn(Paddling.Seat.RIGHT_FRONT, HOLD) < 0.0, "right front turns left")
	expect(paddling.stroke_turn(Paddling.Seat.RIGHT_BACK, HOLD) < 0.0, "right back turns left")

	var left: Array[Paddling.Stroke] = [Paddling.Stroke.new(Paddling.Seat.LEFT_BACK, HOLD)]
	var right: Array[Paddling.Stroke] = [Paddling.Stroke.new(Paddling.Seat.RIGHT_BACK, HOLD)]
	var left_motion: Paddling.Motion = paddling.step(left, 0.1)
	var right_motion: Paddling.Motion = paddling.step(right, 0.1)
	expect(left_motion.turn > 0.0, "a lone left stroke turns the boat right")
	expect(right_motion.turn < 0.0, "a lone right stroke turns the boat left")
	expect_near(left_motion.turn, -right_motion.turn, 0.0001, "mirror seats turn equally")


func test_back_seat_steers_by_back_share_and_front_seat_by_front_share_with_same_push() -> void:
	var force: float = paddling.stroke_force(HOLD)
	var back_turn: float = paddling.stroke_turn(Paddling.Seat.LEFT_BACK, HOLD)
	var front_turn: float = paddling.stroke_turn(Paddling.Seat.LEFT_FRONT, HOLD)
	expect_near(back_turn, tuning.steer_share_back * tuning.turn_torque * force, 0.0001, "back seat steers by steer_share_back")
	expect_near(front_turn, tuning.steer_share_front * tuning.turn_torque * force, 0.0001, "front seat steers by steer_share_front")
	expect_near(back_turn / front_turn, 4.0, 0.0001, "80/20 shares: back turns four times as much")

	var back: Array[Paddling.Stroke] = [Paddling.Stroke.new(Paddling.Seat.LEFT_BACK, HOLD)]
	var front: Array[Paddling.Stroke] = [Paddling.Stroke.new(Paddling.Seat.LEFT_FRONT, HOLD)]
	var back_motion: Paddling.Motion = paddling.step(back, 0.1)
	var front_motion: Paddling.Motion = paddling.step(front, 0.1)
	expect_near(back_motion.thrust, front_motion.thrust, 0.0001, "every seat gives the same forward push")
	expect_near(back_motion.thrust, force, 0.0001, "the push is the stroke's power")
	expect(absf(back_motion.turn) > absf(front_motion.turn), "the back seat is the rudder")


func test_a_backwards_stroke_pushes_back_by_the_reverse_fraction_and_turns_the_other_way_as_much() -> void:
	var force: float = paddling.stroke_force(HOLD)
	expect_near(paddling.stroke_thrust(HOLD, false), force, 0.0001, "a forward stroke pushes by its power")
	expect_near(paddling.stroke_thrust(HOLD, true), -0.6 * force, 0.0001, "a backwards stroke pushes back by the fraction")

	var forward: Array[Paddling.Stroke] = [Paddling.Stroke.new(Paddling.Seat.LEFT_BACK, HOLD)]
	var backwards: Array[Paddling.Stroke] = [Paddling.Stroke.new(Paddling.Seat.LEFT_BACK, HOLD, true)]
	var forward_motion: Paddling.Motion = paddling.step(forward, 0.1)
	var backwards_motion: Paddling.Motion = paddling.step(backwards, 0.1)
	expect_near(backwards_motion.thrust, -tuning.reverse_thrust_fraction * forward_motion.thrust, 0.0001, "the thrust is the forward thrust times the fraction, negated")
	expect(backwards_motion.thrust < 0.0, "it pushes toward the shore")
	expect_near(backwards_motion.turn, -forward_motion.turn, 0.0001, "the turn is the forward turn negated, not scaled")
	expect(backwards_motion.turn < 0.0, "a backwards left-side stroke turns left")
	expect_near(backwards_motion.drift_to_shore, forward_motion.drift_to_shore, 0.0001, "the current is the same")

	tuning.reverse_thrust_fraction = 1.0
	expect_near(paddling.step(backwards, 0.1).thrust, -forward_motion.thrust, 0.0001, "a fraction of 1 mirrors the full push")


func test_no_strokes_drift_toward_shore_at_current_speed() -> void:
	var none: Array[Paddling.Stroke] = []
	var motion: Paddling.Motion = paddling.step(none, 0.5)
	expect_near(motion.thrust, 0.0, 0.0001, "no push without strokes")
	expect_near(motion.turn, 0.0, 0.0001, "no turn without strokes")
	expect_near(motion.drift_to_shore, 1.5, 0.0001, "current_speed times delta toward the shore")
	expect_near(paddling.step(none, 2.0).drift_to_shore, 6.0, 0.0001, "drift scales with the step")


func test_seats_match_run_state() -> void:
	expect_eq(Paddling.Seat.LEFT_FRONT, 0, "seat 0 left front")
	expect_eq(Paddling.Seat.LEFT_BACK, 1, "seat 1 left back")
	expect_eq(Paddling.Seat.RIGHT_FRONT, 2, "seat 2 right front")
	expect_eq(Paddling.Seat.RIGHT_BACK, 3, "seat 3 right back")


func test_tuning_resource_loads_with_placeholders() -> void:
	var loaded: Resource = load("res://data/boat_tuning.tres")
	expect(loaded is BoatTuning, "data/boat_tuning.tres is a BoatTuning")
	var boat: BoatTuning = loaded
	expect(boat.charge_time > 0.0, "charge_time positive")
	expect(boat.stroke_force_max > boat.stroke_force_min, "max above min")
	expect(boat.reverse_thrust_fraction > 0.0 and boat.reverse_thrust_fraction < 1.0, "a reverse stroke pushes, but less than a forward one")
	expect(boat.steer_share_back > boat.steer_share_front, "back seats steer more than front")
	expect(boat.current_speed > 0.0, "the current pulls toward the shore")
