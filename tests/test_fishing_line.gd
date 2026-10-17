extends "res://tools/test_case.gd"
## T20 · Fishing line: crossing the line snags the paddle on the side that crossed it for snag_time
## seconds (GDD › Systems › Hazards, the Fishing line row). The crossing is scripted in the scene
## (scripts/hazards/fishing_line.gd, _on_body_entered), so this test proves the effect through
## RunState: crossing() makes the same call as the script, snag(hull, tuning.snag_time), and the
## guy answers to it through can_paddle().

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const BOAT: Vector2 = Vector2(0.0, -300.0)

var tuning: LakeTuning


func before_each() -> void:
	tuning = load("res://data/lake_tuning.tres") as LakeTuning


## A RunState whose guys are sober and whose rolls are seeded (as in test_rock.gd).
func sober_state() -> Node:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	return state


## The boat crossing the line on `side`: what fishing_line.gd's _on_body_entered calls.
## Returns the seat snagged, or Rescue.NOBODY.
func crossing(state: Node, side: Rescue.Hull) -> int:
	return state.snag(side, tuning.snag_time)


func test_a_crossing_snags_the_hulls_front_guy_for_snag_time() -> void:
	var state: Node = sober_state()
	var seconds: float = tuning.snag_time
	expect_eq(crossing(state, Rescue.Hull.LEFT), Paddling.Seat.LEFT_FRONT, "the left front guy is the one snagged")
	expect(state.is_snagged(Paddling.Seat.LEFT_FRONT), "snagged at the crossing")
	expect_false(state.can_paddle(Paddling.Seat.LEFT_FRONT), "he gives no strokes while snagged")
	# Halves are exact in floating point, so the time left after each step is exact.
	state.step(seconds * 0.5, BOAT)
	expect_near(state.snag_left(Paddling.Seat.LEFT_FRONT), seconds * 0.5, 0.0001, "half of snag_time still to go")
	expect_false(state.can_paddle(Paddling.Seat.LEFT_FRONT), "still unable to paddle halfway through")
	state.step(seconds * 0.5, BOAT)
	expect_false(state.is_snagged(Paddling.Seat.LEFT_FRONT), "free once snag_time has passed")
	expect(state.can_paddle(Paddling.Seat.LEFT_FRONT), "able to paddle again after snag_time")
	state.free()


func test_the_other_side_keeps_paddling_through_the_snag() -> void:
	var state: Node = sober_state()
	crossing(state, Rescue.Hull.LEFT)
	state.step(tuning.snag_time * 0.5, BOAT)
	expect(state.can_paddle(Paddling.Seat.RIGHT_FRONT), "the right front guy paddles")
	expect(state.can_paddle(Paddling.Seat.RIGHT_BACK), "the right back guy paddles")
	expect(state.can_paddle(Paddling.Seat.LEFT_BACK), "the left back guy paddles: only the front one is snagged")
	expect_false(state.is_snagged(Paddling.Seat.RIGHT_FRONT), "the right side is not snagged")
	state.free()


func test_a_crossing_on_the_right_snags_only_the_right_front_guy() -> void:
	var state: Node = sober_state()
	expect_eq(crossing(state, Rescue.Hull.RIGHT), Paddling.Seat.RIGHT_FRONT, "the right front guy is the one snagged")
	expect_false(state.can_paddle(Paddling.Seat.RIGHT_FRONT), "he gives no strokes while snagged")
	expect(state.can_paddle(Paddling.Seat.LEFT_FRONT), "the left front guy paddles")
	expect(state.can_paddle(Paddling.Seat.LEFT_BACK), "the left back guy paddles")
	state.free()
