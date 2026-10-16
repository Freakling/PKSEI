extends "res://tools/test_case.gd"
## T9 · Rescue: a beer overboard puts a guy in the water after it; the beer drifts with the
## current, he swims to it, then floats with it until the boat picks him up; no limit on how
## many are in (GDD › Systems › Setbacks).
## B2 · Nothing loose drifts past the shoreline: beers and swimmers stop shore_margin above it,
## and a floating guy lying there is washed up.

const ALL: Array[int] = [
	Paddling.Seat.LEFT_FRONT, Paddling.Seat.LEFT_BACK, Paddling.Seat.RIGHT_FRONT, Paddling.Seat.RIGHT_BACK,
]
const BOAT: Vector2 = Vector2(100.0, -200.0)
const BEER: Vector2 = Vector2(130.0, -200.0)
const CURRENT: Vector2 = Vector2(0.0, 10.0)

var tuning: BoatTuning
var rescue: Rescue


func before_each() -> void:
	tuning = BoatTuning.new()
	tuning.swim_speed = 10.0
	tuning.shore_margin = 40.0
	rescue = Rescue.new()


func test_a_beer_overboard_puts_the_front_guy_on_that_side_in() -> void:
	var seat: int = rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "both left guys aboard: the front one jumps")
	expect(rescue.is_in_water(Paddling.Seat.LEFT_FRONT), "he is in the water")
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(swimmer.position, BOAT, "he jumped from the boat")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "swimming for the beer")
	expect(swimmer.has_beer, "it is his beer")
	expect_eq(swimmer.beer_position, BEER, "the beer landed where it was tossed")
	expect_eq(rescue.beer_overboard(Rescue.Hull.RIGHT, ALL, BOAT, BEER), Paddling.Seat.RIGHT_FRONT, "same rule on the right")


func test_the_side_picks_the_back_guy_then_the_other_hull_then_nobody() -> void:
	var aboard: Array[int] = [Paddling.Seat.LEFT_BACK, Paddling.Seat.RIGHT_FRONT, Paddling.Seat.RIGHT_BACK]
	expect_eq(Rescue.jumper(Rescue.Hull.LEFT, aboard), Paddling.Seat.LEFT_BACK, "only the back guy left on that side")
	aboard = [Paddling.Seat.RIGHT_FRONT, Paddling.Seat.RIGHT_BACK]
	expect_eq(Rescue.jumper(Rescue.Hull.LEFT, aboard), Paddling.Seat.RIGHT_FRONT, "that hull empty: any aboard guy, front first")
	aboard = [Paddling.Seat.RIGHT_BACK]
	expect_eq(Rescue.jumper(Rescue.Hull.LEFT, aboard), Paddling.Seat.RIGHT_BACK, "the last one aboard")
	expect_eq(Rescue.jumper(Rescue.Hull.LEFT, []), Rescue.NOBODY, "nobody aboard, nobody jumps")
	expect_eq(rescue.beer_overboard(Rescue.Hull.LEFT, [], BOAT, BEER), Rescue.NOBODY, "and no swimmer is started")
	expect_eq(rescue.swimmers().size(), 0, "still nobody in the water")


func test_there_is_no_limit_on_how_many_are_in_the_water() -> void:
	var aboard: Array[int] = ALL.duplicate()
	for i: int in 4:
		var seat: int = rescue.beer_overboard(Rescue.Hull.LEFT, aboard, BOAT, BEER)
		expect_ne(seat, Rescue.NOBODY, "beer %d puts one more guy in" % i)
		aboard.erase(seat)
	expect_eq(rescue.swimmers().size(), 4, "all four in the water")
	for seat: int in ALL:
		expect(rescue.is_in_water(seat), "guy %d is in" % seat)


func test_the_beer_drifts_at_current_speed_while_he_swims_for_it() -> void:
	rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	rescue.step(1.0, CURRENT, tuning)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(swimmer.beer_position, BEER + CURRENT, "the beer went current_speed down-current in a second")
	expect_eq(swimmer.position, BOAT + CURRENT + Vector2(10.0, 0.0), "he drifted with it and swam swim_speed toward it")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "still swimming: 30 px away at 10 px/s")


func test_he_floats_with_the_current_once_he_has_the_beer() -> void:
	rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	rescue.step(1.0, CURRENT, tuning)
	rescue.step(1.0, CURRENT, tuning)
	rescue.step(1.0, CURRENT, tuning)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(swimmer.state, Rescue.State.FLOATING, "three seconds at 10 px/s cover the 30 px")
	expect_eq(swimmer.position, BEER + CURRENT * 3.0, "he is where the beer drifted to")
	rescue.step(2.0, CURRENT, tuning)
	expect_eq(swimmer.position, BEER + CURRENT * 5.0, "floating, he drifts at current_speed")
	expect_eq(swimmer.beer_position, swimmer.position, "the beer is in his hand")
	expect_eq(swimmer.state, Rescue.State.FLOATING, "he never swims back")


func test_he_never_overshoots_the_beer() -> void:
	rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BOAT, BOAT + Vector2(5.0, 0.0))
	rescue.step(1.0, Vector2.ZERO, tuning)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(swimmer.position, BOAT + Vector2(5.0, 0.0), "a beer within reach this step is reached exactly")
	expect_eq(swimmer.state, Rescue.State.FLOATING, "and held")


func test_pickup_takes_him_out_and_says_whether_he_had_his_beer() -> void:
	rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	expect(rescue.pickup(Paddling.Seat.LEFT_FRONT), "he had his beer")
	expect_false(rescue.is_in_water(Paddling.Seat.LEFT_FRONT), "and is out of the water")
	expect_eq(rescue.swimmers().size(), 0, "nobody left in")
	expect_false(rescue.pickup(Paddling.Seat.LEFT_FRONT), "picking up a guy who isn't in is nothing")


func test_only_a_floating_guy_within_the_radius_is_within_reach() -> void:
	rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	expect_eq(rescue.within_reach(BOAT, 50.0), [] as Array[int], "still swimming for the beer: out of reach even beside the boat")
	rescue.step(3.0, Vector2.ZERO, tuning)
	expect_eq(rescue.within_reach(BOAT, 50.0), [Paddling.Seat.LEFT_FRONT] as Array[int], "floating 30 px away, within 50")
	expect_eq(rescue.within_reach(BOAT, 20.0), [] as Array[int], "not within 20")


func test_a_guy_overboard_without_a_beer_floats_at_once_and_drifts() -> void:
	rescue.guy_overboard(Paddling.Seat.RIGHT_BACK, BOAT)
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.RIGHT_BACK)
	expect_eq(swimmer.state, Rescue.State.FLOATING, "nothing to swim for")
	expect_false(swimmer.has_beer, "no beer in hand")
	rescue.step(1.0, CURRENT, tuning)
	expect_eq(swimmer.position, BOAT + CURRENT, "drifts with the current")
	rescue.guy_overboard(Paddling.Seat.RIGHT_BACK, BOAT)
	expect_eq(rescue.swimmers().size(), 1, "a guy already in the water isn't added twice")
	expect_false(rescue.pickup(Paddling.Seat.RIGHT_BACK), "picked up without a beer")


func test_reset_takes_everyone_out() -> void:
	rescue.beer_overboard(Rescue.Hull.LEFT, ALL, BOAT, BEER)
	rescue.guy_overboard(Paddling.Seat.RIGHT_BACK, BOAT)
	rescue.reset()
	expect_eq(rescue.swimmers().size(), 0, "nobody in the water")


## B2 regression: the current carries a floating guy and a loose beer to the shoreline and no
## further; lying there he is washed up.
func test_nothing_loose_drifts_past_the_shoreline() -> void:
	var floater: int = Paddling.Seat.RIGHT_BACK
	rescue.guy_overboard(floater, Vector2(50.0, -60.0))
	rescue.beer_overboard(Rescue.Hull.LEFT, ALL, Vector2(100.0, -60.0), Vector2(200.0, -60.0))
	rescue.step(1.0, CURRENT, tuning)
	var floating: Rescue.Swimmer = rescue.swimmer_of(floater)
	var swimming: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(floating.position, Vector2(50.0, -50.0), "still open water: he drifts as before")
	expect_false(floating.washed_up, "not washed up yet")
	expect_false(swimming.washed_up, "nor the swimmer")
	rescue.step(5.0, CURRENT, tuning)
	expect_eq(floating.position, Vector2(50.0, -40.0), "the floating guy stops shore_margin above the shoreline")
	expect(floating.washed_up, "and is washed up")
	expect_eq(floating.beer_position, floating.position, "nothing for him to reach past it")
	expect_eq(swimming.beer_position, Vector2(200.0, -40.0), "the loose beer stops there too")
	expect_near(swimming.position.y, -40.0, 0.0001, "and so does the guy swimming for it")
	rescue.step(10.0, CURRENT, tuning)
	expect_eq(floating.position, Vector2(50.0, -40.0), "the current can't take him further")
	expect_eq(swimming.position, Vector2(200.0, -40.0), "the swimmer reached his beer along the shoreline")
	expect_eq(swimming.state, Rescue.State.FLOATING, "and holds it")
	expect(swimming.washed_up, "washed up with it")


## B2 regression: a beer knocked over with the boat resting at the launch shore (y about -28, past
## the shoreline) puts the guy and the beer at the shoreline at once; once he has the beer he is
## washed up, though out of reach of the boat itself.
func test_a_beer_over_at_the_launch_shore_washes_him_up() -> void:
	var at_shore: Vector2 = Vector2(0.0, -28.0)
	rescue.beer_overboard(Rescue.Hull.LEFT, ALL, at_shore, at_shore + Vector2(-32.0, 0.0))
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(Paddling.Seat.LEFT_FRONT)
	expect_eq(rescue.washed_up(), [] as Array[int], "not washed up before he has his beer")
	rescue.step(1.0, CURRENT, tuning)
	expect_near(swimmer.position.y, -40.0, 0.0001, "held back to the shoreline at once")
	expect_near(swimmer.beer_position.y, -40.0, 0.0001, "the beer too")
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "32 px along the shoreline at 10 px/s: still swimming")
	expect_eq(rescue.washed_up(), [] as Array[int], "a guy still swimming is not listed")
	rescue.step(3.0, CURRENT, tuning)
	expect_eq(swimmer.state, Rescue.State.FLOATING, "he has it")
	expect_eq(rescue.washed_up(), [Paddling.Seat.LEFT_FRONT] as Array[int], "washed up with his beer")
	expect_eq(rescue.within_reach(at_shore, 20.0), [] as Array[int], "34 px from the boat: it can't reach him itself")
	expect(rescue.pickup(Paddling.Seat.LEFT_FRONT), "picked up with his beer")
