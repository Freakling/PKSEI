extends "res://tools/test_case.gd"
## T62 · The hold-to-reset button's rule (GDD › Presentation and Platforms, Reset): a touch
## must be held for reset_hold_time before it resets, so a stray tap does nothing; the ring's
## progress is 0..1, clamped and never going back as the hold goes on. B7: a holding finger keeps
## the hold while it stays within DRAG_SLACK of the button's rect, so a wobbling thumb doesn't
## cancel it.

const HOLD: float = 1.2


func test_a_short_hold_does_not_fire() -> void:
	expect_false(ResetButton.ResetHold.fires(0.0, HOLD), "the press itself")
	expect_false(ResetButton.ResetHold.fires(0.1, HOLD), "a tap")
	expect_false(ResetButton.ResetHold.fires(HOLD * 0.5, HOLD), "half way")
	expect_false(ResetButton.ResetHold.fires(HOLD - 0.001, HOLD), "just short")


func test_exactly_hold_time_fires_and_so_does_longer() -> void:
	expect(ResetButton.ResetHold.fires(HOLD, HOLD), "exactly hold_time")
	expect(ResetButton.ResetHold.fires(HOLD + 0.01, HOLD), "a frame past it")
	expect(ResetButton.ResetHold.fires(HOLD * 3.0, HOLD), "well past it")


func test_progress_is_zero_at_the_press_and_one_at_hold_time() -> void:
	expect_near(ResetButton.ResetHold.progress(0.0, HOLD), 0.0)
	expect_near(ResetButton.ResetHold.progress(HOLD * 0.25, HOLD), 0.25)
	expect_near(ResetButton.ResetHold.progress(HOLD * 0.5, HOLD), 0.5)
	expect_near(ResetButton.ResetHold.progress(HOLD, HOLD), 1.0)


func test_progress_is_clamped() -> void:
	expect_near(ResetButton.ResetHold.progress(-0.5, HOLD), 0.0, 0.0001, "before the press")
	expect_near(ResetButton.ResetHold.progress(HOLD * 2.0, HOLD), 1.0, 0.0001, "past hold_time")
	expect_near(ResetButton.ResetHold.progress(1000.0, HOLD), 1.0, 0.0001, "far past it")


func test_progress_is_monotone() -> void:
	var last: float = -1.0
	for step: int in 61:
		var held: float = float(step) * HOLD * 2.0 / 60.0
		var now: float = ResetButton.ResetHold.progress(held, HOLD)
		expect(now >= last, "progress at %s s went back" % held)
		expect(now >= 0.0 and now <= 1.0, "progress at %s s out of 0..1" % held)
		last = now


## A hold time of zero or less is a plain button: it fires at the press, and the ring is full.
func test_no_hold_time_fires_at_once() -> void:
	expect(ResetButton.ResetHold.fires(0.0, 0.0))
	expect_near(ResetButton.ResetHold.progress(0.0, 0.0), 1.0)
	expect_near(ResetButton.ResetHold.progress(0.0, -1.0), 1.0)


func test_a_finger_keeps_the_hold_on_the_button_and_within_the_slack() -> void:
	var rect: Rect2 = Rect2(Vector2(588.0, 4.0), Vector2(48.0, 48.0))
	expect(ResetButton.ResetHold.keeps_hold(rect, Vector2(600.0, 20.0), 24.0), "on the button")
	expect(ResetButton.ResetHold.keeps_hold(rect, Vector2(570.0, 30.0), 24.0), "18 px left of it")
	expect(ResetButton.ResetHold.keeps_hold(rect, Vector2(610.0, 70.0), 24.0), "18 px below it")
	expect(ResetButton.ResetHold.keeps_hold(rect, Vector2(564.0, 4.0), 24.0), "exactly at the slack")


func test_a_finger_far_outside_the_slack_cancels_the_hold() -> void:
	var rect: Rect2 = Rect2(Vector2(588.0, 4.0), Vector2(48.0, 48.0))
	expect_false(ResetButton.ResetHold.keeps_hold(rect, Vector2(560.0, 30.0), 24.0), "28 px left of it")
	expect_false(ResetButton.ResetHold.keeps_hold(rect, Vector2(610.0, 90.0), 24.0), "well below it")
	expect_false(ResetButton.ResetHold.keeps_hold(rect, Vector2(570.0, 30.0), 0.0), "no slack: off the rect")
	expect_false(ResetButton.ResetHold.keeps_hold(rect, Vector2(570.0, 30.0), -5.0), "a negative slack counts as none")
