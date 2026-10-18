extends "res://tools/test_case.gd"
## T9 · Rescue: a beer overboard puts a guy in the water after it; the beer drifts with the
## current, he swims to it, then floats with it until the boat picks him up; no limit on how
## many are in (GDD › Systems › Setbacks).
## B2 · Nothing loose drifts past the shoreline: beers and swimmers stop shore_margin above it,
## and a floating guy lying there is washed up.
## T34 · A beer overboard bobs away loose for jump_delay seconds while its guy winds up aboard;
## he jumps from where the boat is then, not before.
## T59 · After swim_back_delay seconds adrift a floating guy swims back toward the boat at
## swim_back_speed on top of the drift, never past it; a guy swimming for his beer and a
## washed-up one don't, and the data keeps swim_back_speed below loose_drift_speed.

const BOAT_DATA: BoatTuning = preload("res://data/boat_tuning.tres")
const ALL: Array[int] = [
	Paddling.Seat.LEFT_FRONT, Paddling.Seat.LEFT_BACK, Paddling.Seat.RIGHT_FRONT, Paddling.Seat.RIGHT_BACK,
]
const BOAT: Vector2 = Vector2(100.0, -200.0)
const BEER: Vector2 = Vector2(130.0, -200.0)
const CURRENT: Vector2 = Vector2(0.0, 10.0)
const DELAY: float = 2.5
const SWIM_BACK_DELAY: float = 5.0
const SWIM_BACK_SPEED: float = 12.0

var tuning: BoatTuning
var rescue: Rescue


func before_each() -> void:
	tuning = BoatTuning.new()
	tuning.swim_speed = 10.0
	tuning.shore_margin = 40.0
	tuning.swim_back_delay = SWIM_BACK_DELAY
	tuning.swim_back_speed = SWIM_BACK_SPEED
	rescue = Rescue.new()


## A beer over with no wind-up: the chosen guy is in the water at `boat_at` at once.
func jump_now(side: Rescue.Hull, aboard: Array[int], boat_at: Vector2, beer_at: Vector2) -> int:
	var seat: int = rescue.beer_overboard(side, aboard, beer_at, 0.0)
	rescue.step(0.0, Vector2.ZERO, tuning, boat_at)
	return seat


func test_a_beer_overboard_puts_the_front_guy_on_that_side_in() -> void:
	var seat: int = jump_now(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "both left guys aboard: the front one jumps")
	expect(rescue.is_in_water(Paddling.Seat.LEFT_FRONT), "he is in the water")
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(swimmer.position, BOAT, "he jumped from the boat")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "swimming for the beer")
	expect(swimmer.has_beer, "it is his beer")
	expect_eq(swimmer.beer_position, BEER, "the beer landed where it was tossed")
	expect_eq(jump_now(Rescue.Hull.RIGHT, ALL, BOAT, BEER), Paddling.Seat.RIGHT_FRONT, "same rule on the right")


func test_the_side_picks_the_back_guy_then_the_other_hull_then_nobody() -> void:
	var aboard: Array[int] = [Paddling.Seat.LEFT_BACK, Paddling.Seat.RIGHT_FRONT, Paddling.Seat.RIGHT_BACK]
	expect_eq(Rescue.jumper(Rescue.Hull.LEFT, aboard), Paddling.Seat.LEFT_BACK, "only the back guy left on that side")
	aboard = [Paddling.Seat.RIGHT_FRONT, Paddling.Seat.RIGHT_BACK]
	expect_eq(Rescue.jumper(Rescue.Hull.LEFT, aboard), Paddling.Seat.RIGHT_FRONT, "that hull empty: any aboard guy, front first")
	aboard = [Paddling.Seat.RIGHT_BACK]
	expect_eq(Rescue.jumper(Rescue.Hull.LEFT, aboard), Paddling.Seat.RIGHT_BACK, "the last one aboard")
	expect_eq(Rescue.jumper(Rescue.Hull.LEFT, []), Rescue.NOBODY, "nobody aboard, nobody jumps")
	expect_eq(rescue.beer_overboard(Rescue.Hull.LEFT, [], BEER, DELAY), Rescue.NOBODY, "and no wind-up is started")
	expect_eq(rescue.loose_beers().size(), 0, "nor a beer to go after")
	expect_eq(rescue.swimmers().size(), 0, "still nobody in the water")


func test_there_is_no_limit_on_how_many_are_in_the_water() -> void:
	var aboard: Array[int] = ALL.duplicate()
	for i: int in 4:
		var seat: int = jump_now(Rescue.Hull.LEFT, aboard, BOAT, BEER)
		expect_ne(seat, Rescue.NOBODY, "beer %d puts one more guy in" % i)
		aboard.erase(seat)
	expect_eq(rescue.swimmers().size(), 4, "all four in the water")
	for seat: int in ALL:
		expect(rescue.is_in_water(seat), "guy %d is in" % seat)


func test_the_beer_drifts_at_current_speed_while_he_swims_for_it() -> void:
	jump_now(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	rescue.step(1.0, CURRENT, tuning, BOAT)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(swimmer.beer_position, BEER + CURRENT, "the beer went current_speed down-current in a second")
	expect_eq(swimmer.position, BOAT + CURRENT + Vector2(10.0, 0.0), "he drifted with it and swam swim_speed toward it")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "still swimming: 30 px away at 10 px/s")


func test_he_floats_with_the_current_once_he_has_the_beer() -> void:
	jump_now(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	rescue.step(1.0, CURRENT, tuning, BOAT)
	rescue.step(1.0, CURRENT, tuning, BOAT)
	rescue.step(1.0, CURRENT, tuning, BOAT)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(swimmer.state, Rescue.State.FLOATING, "three seconds at 10 px/s cover the 30 px")
	expect_eq(swimmer.position, BEER + CURRENT * 3.0, "he is where the beer drifted to")
	rescue.step(2.0, CURRENT, tuning, BOAT)
	expect_eq(swimmer.position, BEER + CURRENT * 5.0, "floating, he drifts at current_speed")
	expect_eq(swimmer.beer_position, swimmer.position, "the beer is in his hand")
	expect_eq(swimmer.state, Rescue.State.FLOATING, "he never swims back")


func test_he_never_overshoots_the_beer() -> void:
	jump_now(Rescue.Hull.LEFT, ALL, BOAT, BOAT + Vector2(5.0, 0.0))
	rescue.step(1.0, Vector2.ZERO, tuning, BOAT)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(swimmer.position, BOAT + Vector2(5.0, 0.0), "a beer within reach this step is reached exactly")
	expect_eq(swimmer.state, Rescue.State.FLOATING, "and held")


func test_pickup_takes_him_out_and_says_whether_he_had_his_beer() -> void:
	jump_now(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	expect(rescue.pickup(Paddling.Seat.LEFT_FRONT), "he had his beer")
	expect_false(rescue.is_in_water(Paddling.Seat.LEFT_FRONT), "and is out of the water")
	expect_eq(rescue.swimmers().size(), 0, "nobody left in")
	expect_false(rescue.pickup(Paddling.Seat.LEFT_FRONT), "picking up a guy who isn't in is nothing")


func test_only_a_floating_guy_within_the_radius_is_within_reach() -> void:
	jump_now(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	expect_eq(rescue.within_reach(BOAT, 50.0), [] as Array[int], "still swimming for the beer: out of reach even beside the boat")
	rescue.step(3.0, Vector2.ZERO, tuning, BOAT)
	expect_eq(rescue.within_reach(BOAT, 50.0), [Paddling.Seat.LEFT_FRONT] as Array[int], "floating 30 px away, within 50")
	expect_eq(rescue.within_reach(BOAT, 20.0), [] as Array[int], "not within 20")


func test_a_guy_overboard_without_a_beer_floats_at_once_and_drifts() -> void:
	rescue.guy_overboard(Paddling.Seat.RIGHT_BACK, BOAT)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.RIGHT_BACK)
	expect_eq(swimmer.state, Rescue.State.FLOATING, "nothing to swim for")
	expect_false(swimmer.has_beer, "no beer in hand")
	rescue.step(1.0, CURRENT, tuning, BOAT)
	expect_eq(swimmer.position, BOAT + CURRENT, "drifts with the current")
	rescue.guy_overboard(Paddling.Seat.RIGHT_BACK, BOAT)
	expect_eq(rescue.swimmers().size(), 1, "a guy already in the water isn't added twice")
	expect_false(rescue.pickup(Paddling.Seat.RIGHT_BACK), "picked up without a beer")


func test_reset_takes_everyone_out() -> void:
	jump_now(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	rescue.beer_overboard(Rescue.Hull.RIGHT, ALL, BEER, DELAY)
	rescue.guy_overboard(Paddling.Seat.RIGHT_BACK, BOAT)
	rescue.reset()
	expect_eq(rescue.swimmers().size(), 0, "nobody in the water")
	expect_eq(rescue.loose_beers().size(), 0, "no beer loose")
	expect_false(rescue.winding_up(Paddling.Seat.RIGHT_FRONT), "the wind-up is dropped")


## B2 regression: the current carries a floating guy and a loose beer to the shoreline and no
## further; lying there he is washed up.
func test_nothing_loose_drifts_past_the_shoreline() -> void:
	var floater: int = Paddling.Seat.RIGHT_BACK
	rescue.guy_overboard(floater, Vector2(50.0, -60.0))
	var boat_at: Vector2 = Vector2(100.0, -60.0)
	jump_now(Rescue.Hull.LEFT, ALL, boat_at, Vector2(200.0, -60.0))
	rescue.step(1.0, CURRENT, tuning, boat_at)
	var floating: Rescue.Swimmer = rescue.swimmer_of(floater)
	var swimming: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(floating.position, Vector2(50.0, -50.0), "still open water: he drifts as before")
	expect_false(floating.washed_up, "not washed up yet")
	expect_false(swimming.washed_up, "nor the swimmer")
	rescue.step(5.0, CURRENT, tuning, boat_at)
	expect_eq(floating.position, Vector2(50.0, -40.0), "the floating guy stops shore_margin above the shoreline")
	expect(floating.washed_up, "and is washed up")
	expect_eq(floating.beer_position, floating.position, "nothing for him to reach past it")
	expect_eq(swimming.beer_position, Vector2(200.0, -40.0), "the loose beer stops there too")
	expect_near(swimming.position.y, -40.0, 0.0001, "and so does the guy swimming for it")
	rescue.step(10.0, CURRENT, tuning, boat_at)
	expect_eq(floating.position, Vector2(50.0, -40.0), "the current can't take him further")
	expect_eq(swimming.position, Vector2(200.0, -40.0), "the swimmer reached his beer along the shoreline")
	expect_eq(swimming.state, Rescue.State.FLOATING, "and holds it")
	expect(swimming.washed_up, "washed up with it")


## B2 regression: a beer knocked over with the boat resting at the launch shore (y about -28, past
## the shoreline) puts the guy and the beer at the shoreline at once; once he has the beer he is
## washed up, though out of reach of the boat itself.
func test_a_beer_over_at_the_launch_shore_washes_him_up() -> void:
	var at_shore: Vector2 = Vector2(0.0, -28.0)
	jump_now(Rescue.Hull.LEFT, ALL, at_shore, at_shore + Vector2(-32.0, 0.0))
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(rescue.washed_up(), [] as Array[int], "not washed up before he has his beer")
	rescue.step(1.0, CURRENT, tuning, at_shore)
	expect_near(swimmer.position.y, -40.0, 0.0001, "held back to the shoreline at once")
	expect_near(swimmer.beer_position.y, -40.0, 0.0001, "the beer too")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "32 px along the shoreline at 10 px/s: still swimming")
	expect_eq(rescue.washed_up(), [] as Array[int], "a guy still swimming is not listed")
	rescue.step(3.0, CURRENT, tuning, at_shore)
	expect_eq(swimmer.state, Rescue.State.FLOATING, "he has it")
	expect_eq(rescue.washed_up(), [Paddling.Seat.LEFT_FRONT] as Array[int], "washed up with his beer")
	expect_eq(rescue.within_reach(at_shore, 20.0), [] as Array[int], "34 px from the boat: it can't reach him itself")
	expect(rescue.pickup(Paddling.Seat.LEFT_FRONT), "picked up with his beer")


## T34: the beer floats loose and drifts from the start; the chosen guy winds up aboard.
func test_a_beer_overboard_drifts_loose_while_its_guy_winds_up() -> void:
	var seat: int = rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BEER, DELAY)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the front guy on that side is chosen")
	expect(rescue.winding_up(seat), "he is winding up")
	expect_near(rescue.wind_up_left(seat), DELAY, 0.0001, "with the whole delay ahead")
	expect_false(rescue.is_in_water(seat), "and not in the water")
	expect_false(rescue.winding_up(Paddling.Seat.LEFT_BACK), "nobody else is")
	expect_near(rescue.wind_up_left(Paddling.Seat.LEFT_BACK), 0.0, 0.0001, "no time left for a guy not winding up")
	expect_eq(rescue.loose_beers().size(), 1, "one beer loose, drawable")
	var beer: Rescue.LooseBeer = rescue.beer_of(seat)
	expect_eq(beer.position, BEER, "where it was tossed")
	expect_eq(rescue.step(1.0, CURRENT, tuning, BOAT), [] as Array[int], "a second in: nobody jumped")
	expect_eq(beer.position, BEER + CURRENT, "the beer drifted current_speed down-current")
	expect_near(rescue.wind_up_left(seat), DELAY - 1.0, 0.0001, "the wind-up counted down")
	expect_eq(rescue.swimmers().size(), 0, "still nobody in the water")


## T34: he jumps once jump_delay has passed, from where the boat is then, and not before.
func test_the_jumper_appears_after_jump_delay_not_before() -> void:
	var seat: int = rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BEER, DELAY)
	rescue.step(DELAY - 0.5, CURRENT, tuning, BOAT)
	expect_false(rescue.is_in_water(seat), "0.5 s short of the delay: still aboard")
	expect(rescue.winding_up(seat), "still winding up")
	var boat_later: Vector2 = BOAT + Vector2(0.0, -50.0)
	expect_eq(rescue.step(0.5, CURRENT, tuning, boat_later), [seat] as Array[int], "at the delay he jumps, and the step says so")
	expect(rescue.is_in_water(seat), "in the water")
	expect_false(rescue.winding_up(seat), "the wind-up is over")
	expect_eq(rescue.loose_beers().size(), 0, "the beer is his to swim for now")
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(seat)
	expect_eq(swimmer.position, boat_later, "he jumped from where the boat is now, not where the beer went over")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "swimming for the beer")
	expect(swimmer.has_beer, "it is his beer")
	expect_eq(swimmer.beer_position, BEER + CURRENT * DELAY, "the beer kept drifting the whole wind-up")
	expect_eq(rescue.step(1.0, CURRENT, tuning, boat_later), [] as Array[int], "a later step reports no new jump")


## T34: a second beer while the first guy is still winding up picks the next guy; while he winds
## up he can't be chosen again.
func test_a_guy_winding_up_is_not_chosen_for_a_second_beer() -> void:
	expect_eq(rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BEER, DELAY), Paddling.Seat.LEFT_FRONT, "the first beer: the front guy")
	expect_eq(rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BEER, DELAY), Paddling.Seat.LEFT_BACK, "the second: the back guy, the front one is winding up")
	expect_eq(rescue.loose_beers().size(), 2, "two beers loose")
	var one_free: Array[int] = [Paddling.Seat.LEFT_FRONT]
	expect_eq(rescue.beer_overboard(Rescue.Hull.LEFT, one_free, BEER, DELAY), Rescue.NOBODY, "everyone aboard winding up: nobody to jump")
	expect_eq(rescue.loose_beers().size(), 2, "and no third beer to go after")
	rescue.step(DELAY, CURRENT, tuning, BOAT)
	expect_eq(rescue.swimmers().size(), 2, "both jumped together")


## T34: a guy who falls in some other way during his wind-up swims for his beer anyway, as if he
## had jumped early: the loose beer becomes his target and he holds it once he reaches it.
func test_falling_in_during_the_wind_up_swims_for_the_beer_anyway() -> void:
	var seat: int = rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BEER, DELAY)
	rescue.step(1.0, CURRENT, tuning, BOAT)
	var beer_at: Vector2 = rescue.beer_of(seat).position
	expect_eq(beer_at, BEER + CURRENT, "the beer drifted a second before he fell in")
	rescue.guy_overboard(seat, BOAT)
	expect_false(rescue.winding_up(seat), "no wind-up left")
	expect_eq(rescue.loose_beers().size(), 0, "the loose beer is gone: it is his target now")
	expect(rescue.is_in_water(seat), "he is in the water")
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(seat)
	expect_eq(swimmer.position, BOAT, "from where he fell in")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "swimming for the beer")
	expect_eq(swimmer.beer_position, beer_at, "toward where the beer is now")
	expect(swimmer.has_beer, "it is his beer")
	rescue.step(DELAY, CURRENT, tuning, BOAT)
	expect_eq(rescue.swimmers().size(), 1, "the delay passing adds nobody")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "31.6 px off at 10 px/s: still swimming after 2.5 s")
	rescue.step(1.0, CURRENT, tuning, BOAT)
	expect_eq(swimmer.state, Rescue.State.FLOATING, "he reached it and holds it")
	expect_eq(swimmer.position, swimmer.beer_position, "where the beer drifted to")
	expect(rescue.pickup(seat), "picked up with his beer")


## T59: a floating guy stays put for swim_back_delay, then swims swim_back_speed toward where
## the boat is now, on top of the drift, and lands on it rather than passing it.
func test_after_swim_back_delay_a_floating_guy_swims_slowly_back_toward_the_boat() -> void:
	var seat: int = Paddling.Seat.RIGHT_BACK
	var fell_in: Vector2 = BOAT + Vector2(100.0, 0.0)
	rescue.guy_overboard(seat, fell_in)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(seat)
	rescue.step(SWIM_BACK_DELAY, Vector2.ZERO, tuning, BOAT)
	expect_eq(swimmer.position, fell_in, "at the delay he is still where he fell in")
	expect_near(swimmer.adrift, SWIM_BACK_DELAY, 0.0001, "the clock counts his seconds afloat")
	rescue.step(1.0, Vector2.ZERO, tuning, BOAT)
	expect_eq(swimmer.position, fell_in + Vector2(-SWIM_BACK_SPEED, 0.0), "past the delay he swam swim_back_speed toward the boat")
	expect_eq(swimmer.beer_position, swimmer.position, "the beer still in his hand")
	expect_eq(swimmer.state, Rescue.State.FLOATING, "still floating")
	var before: Vector2 = swimmer.position
	rescue.step(1.0, CURRENT, tuning, BOAT)
	var drifted: Vector2 = before + CURRENT
	var expected: Vector2 = drifted + (BOAT - drifted).normalized() * SWIM_BACK_SPEED
	expect(swimmer.position.is_equal_approx(expected), "with a current he drifts and swims toward the boat on top of it (got %s, expected %s)" % [swimmer.position, expected])
	var boat_later: Vector2 = swimmer.position + Vector2(5.0, 5.0)
	rescue.step(1.0, Vector2.ZERO, tuning, boat_later)
	expect_eq(swimmer.position, boat_later, "a boat within reach this step is reached exactly, never passed, where it is now")
	expect_eq(rescue.within_reach(boat_later, 1.0), [seat] as Array[int], "and he is there to pick up")


## T59: a guy swimming for his beer keeps swimming for it, his clock not started; a washed-up
## guy lies where he is; and the shoreline hold still applies to a guy swimming back.
func test_a_guy_swimming_for_his_beer_and_a_washed_up_one_dont_swim_back() -> void:
	var far_beer: Vector2 = BOAT + Vector2(300.0, 0.0)
	jump_now(Rescue.Hull.LEFT, ALL, BOAT, far_beer)
	var swimming: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	rescue.step(SWIM_BACK_DELAY + 1.0, Vector2.ZERO, tuning, BOAT)
	expect_eq(swimming.state, Rescue.State.SWIMMING, "300 px at 10 px/s: still swimming for the beer after 6 s")
	expect_eq(swimming.position, BOAT + Vector2(60.0, 0.0), "away from the boat, toward the beer, at swim_speed alone")
	expect_near(swimming.adrift, 0.0, 0.0001, "his clock hasn't started")
	var washed: int = Paddling.Seat.RIGHT_BACK
	var at_shoreline: Vector2 = Vector2(50.0, -tuning.shore_margin)
	rescue.guy_overboard(washed, at_shoreline)
	var lying: Rescue.Swimmer = rescue.swimmer_of(washed)
	rescue.step(SWIM_BACK_DELAY + 1.0, Vector2.ZERO, tuning, BOAT)
	expect(lying.washed_up, "washed up")
	expect_eq(lying.position, at_shoreline, "he lies where he is, past the delay or not")
	rescue.step(10.0, CURRENT, tuning, BOAT)
	expect_eq(lying.position, at_shoreline, "the current and the clock change nothing")
	var held: int = Paddling.Seat.RIGHT_FRONT
	var near_shore: Vector2 = Vector2(50.0, -tuning.shore_margin - 5.0)
	var boat_at_shore: Vector2 = Vector2(50.0, -tuning.shore_margin + 10.0)
	rescue.guy_overboard(held, near_shore)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(held)
	rescue.step(SWIM_BACK_DELAY, Vector2.ZERO, tuning, boat_at_shore)
	expect_eq(swimmer.position, near_shore, "5 px off the shoreline, at the delay: he stays")
	rescue.step(1.0, Vector2.ZERO, tuning, boat_at_shore)
	expect_eq(swimmer.position, Vector2(50.0, -tuning.shore_margin), "swimming back toward a boat at the shore he is held at the shoreline")
	expect(swimmer.washed_up, "and lies there washed up")


## T80: a swimmer's kind (what the bubbles and the HUD read) follows his state: fetching while he
## swims for his beer, drinking with it or fallen in without one before he swims back, swimming
## back once adrift is past swim_back_delay (exactly at it he still floats), washed up at the shore.
func _swimmer(state: Rescue.State, has_beer: bool, adrift: float, washed: bool) -> Rescue.Swimmer:
	var swimmer: Rescue.Swimmer = Rescue.Swimmer.new(Paddling.Seat.LEFT_FRONT, BOAT, BEER, state, has_beer)
	swimmer.adrift = adrift
	swimmer.washed_up = washed
	return swimmer


func test_a_swimmers_kind_follows_his_state() -> void:
	expect_eq(_swimmer(Rescue.State.SWIMMING, true, 0.0, false).kind(SWIM_BACK_DELAY), Rescue.KIND_FETCH,
			"swimming for his beer")
	expect_eq(_swimmer(Rescue.State.FLOATING, true, 2.0, false).kind(SWIM_BACK_DELAY), Rescue.KIND_DRINK,
			"floating with his beer before he swims back")
	expect_eq(_swimmer(Rescue.State.FLOATING, false, 2.0, false).kind(SWIM_BACK_DELAY), Rescue.KIND_FELL,
			"floating without a beer before he swims back")
	expect_eq(_swimmer(Rescue.State.FLOATING, true, 6.0, false).kind(SWIM_BACK_DELAY), Rescue.KIND_BACK,
			"swimming back, with a beer")
	expect_eq(_swimmer(Rescue.State.FLOATING, false, 6.0, false).kind(SWIM_BACK_DELAY), Rescue.KIND_BACK,
			"swimming back, without one")


func test_exactly_at_the_delay_he_still_floats_with_his_beer() -> void:
	expect_eq(_swimmer(Rescue.State.FLOATING, true, SWIM_BACK_DELAY, false).kind(SWIM_BACK_DELAY), Rescue.KIND_DRINK,
			"not yet started back")
	expect_eq(_swimmer(Rescue.State.FLOATING, false, SWIM_BACK_DELAY, false).kind(SWIM_BACK_DELAY), Rescue.KIND_FELL,
			"and without one he has not started back either")


func test_washed_up_is_its_own_kind_whatever_his_state() -> void:
	expect_eq(_swimmer(Rescue.State.FLOATING, true, 9.0, true).kind(SWIM_BACK_DELAY), Rescue.KIND_WASHED_UP,
			"washed up, past the delay")
	expect_eq(_swimmer(Rescue.State.SWIMMING, true, 0.0, true).kind(SWIM_BACK_DELAY), Rescue.KIND_WASHED_UP,
			"washed up while swimming too")


func test_the_kinds_are_the_line_keys_the_bubbles_use() -> void:
	expect_eq(Rescue.KIND_FETCH, &"swim_fetch")
	expect_eq(Rescue.KIND_DRINK, &"swim_drink")
	expect_eq(Rescue.KIND_FELL, &"swim_fell")
	expect_eq(Rescue.KIND_BACK, &"swim_back")
	expect_eq(Rescue.KIND_WASHED_UP, &"washed_up")


## T59: the data's swim-back is a placeholder slower than the wind carries him, so the boat still
## has to come for him.
func test_the_data_swims_back_slower_than_the_drift() -> void:
	expect(BOAT_DATA.swim_back_delay > 0.0, "a few seconds adrift first")
	expect(BOAT_DATA.swim_back_speed > 0.0, "he does swim back")
	expect(BOAT_DATA.swim_back_speed < BOAT_DATA.loose_drift_speed, "slower than loose_drift_speed: he still loses water, so the rescue is the boat's job")
