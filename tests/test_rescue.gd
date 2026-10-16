extends "res://tools/test_case.gd"
## T9 · Rescue: a beer overboard puts a guy in the water after it; the beer drifts with the
## current, he swims to it, then floats with it until the boat picks him up; no limit on how
## many are in (GDD › Systems › Setbacks).

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
