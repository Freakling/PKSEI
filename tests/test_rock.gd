extends "res://tools/test_case.gd"
## T19 · Rock or buoy: a hit stops the boat once and knocks a beer overboard on the side it hit
## (GDD › Systems › Hazards, the Rock or buoy row). The hit is scripted in the scene
## (scripts/hazards/rock.gd, _on_body_entered), so this test proves the effects through RunState:
## rock_hit() makes the same two calls, stop() and then beer_overboard(hull, boat), in the same
## order as rock.gd does, and the boat and the guys answer to them.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const BOAT: Vector2 = Vector2(0.0, -300.0)


## A RunState whose guys are sober and whose rolls are seeded (as in test_hazards.gd).
func sober_state() -> Node:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	return state


## The rock's hit on `side` with the boat at BOAT: what rock.gd's _on_body_entered calls, in order.
## Returns the guy who winds up to jump, or Rescue.NOBODY.
func rock_hit(state: Node, side: Rescue.Hull) -> int:
	state.stop()
	return state.beer_overboard(side, BOAT)


func test_a_rock_hit_stops_the_boat_once_and_the_hit_hulls_guy_winds_up() -> void:
	var state: Node = sober_state()
	var seat: int = rock_hit(state, Rescue.Hull.LEFT)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy is the one to jump")
	expect(state.rescue.winding_up(seat), "the hit hull's guy is winding up")
	expect(state.take_stop(), "the boat stops")
	expect_false(state.take_stop(), "the stop is handed to the boat once")
	expect_eq(state.take_shove(), Vector2.ZERO, "a rock does not shove the boat")
	state.free()


func test_a_rock_hit_on_the_right_winds_up_only_the_right_hulls_guy() -> void:
	var state: Node = sober_state()
	var seat: int = rock_hit(state, Rescue.Hull.RIGHT)
	expect_eq(seat, Paddling.Seat.RIGHT_FRONT, "the right front guy is the one to jump")
	expect(state.rescue.winding_up(seat), "the hit hull's guy is winding up")
	expect_false(state.rescue.winding_up(Paddling.Seat.LEFT_FRONT), "nobody on the other hull is")
	expect_false(state.rescue.winding_up(Paddling.Seat.LEFT_BACK), "nobody on the other hull is")
	state.free()
