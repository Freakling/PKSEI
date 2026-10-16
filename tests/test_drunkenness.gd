extends "res://tools/test_case.gd"
## T5 · Drunkenness: levels rise with time, faster on a break or in the water; lag, misses and
## scrambled keys follow the level (GDD › Systems › Drunkenness).

const SEATS: int = 4

var tuning: DrinkTuning
var drunkenness: Drunkenness


func before_each() -> void:
	tuning = DrinkTuning.new()
	tuning.start_level = 0.2
	tuning.drink_rate = 0.01
	tuning.break_drink_multiplier = 3.0
	tuning.water_drink_multiplier = 5.0
	tuning.lag_curve = DrinkTuning.ramp(0.0, 0.5)
	tuning.miss_curve = DrinkTuning.ramp(0.0, 0.4)
	tuning.scramble_level = 0.8
	drunkenness = Drunkenness.new(tuning)


func test_every_guy_starts_at_start_level_and_rises_by_drink_rate_per_second() -> void:
	expect_eq(drunkenness.levels.size(), SEATS, "one level per seat")
	for seat: int in SEATS:
		expect_near(drunkenness.level_of(seat), 0.2, 0.0001, "seat %d starts at start_level" % seat)
	expect_near(drunkenness.drink(0, 1.0, false, false), 0.21, 0.0001, "one second adds drink_rate")
	expect_near(drunkenness.drink(0, 2.5, false, false), 0.235, 0.0001, "rate times the step")
	expect_near(drunkenness.level_of(0), 0.235, 0.0001, "drink() stores the new level")
	expect_near(drunkenness.level_of(1), 0.2, 0.0001, "other guys do not drink for him")
	expect_near(drunkenness.advance(0.5, 3.0, false, false), 0.53, 0.0001, "advance() is the pure rule")


func test_break_and_water_multiply_the_rate() -> void:
	expect_near(drunkenness.drink_multiplier(false, false), 1.0, 0.0001, "paddling drinks at drink_rate")
	expect_near(drunkenness.drink_multiplier(true, false), 3.0, 0.0001, "a break drinks at break_drink_multiplier")
	expect_near(drunkenness.drink_multiplier(false, true), 5.0, 0.0001, "the water drinks at water_drink_multiplier")
	expect_near(drunkenness.drink_multiplier(true, true), 5.0, 0.0001, "the water rate wins if both are flagged")
	expect_near(drunkenness.drink(1, 1.0, true, false), 0.23, 0.0001, "a second on a break adds three times the rate")
	expect_near(drunkenness.drink(2, 1.0, false, true), 0.25, 0.0001, "a second in the water adds five times the rate")
	expect_near(drunkenness.drink(3, 1.0, false, false), 0.21, 0.0001, "the paddler adds the plain rate")
	expect(drunkenness.level_of(2) > drunkenness.level_of(1), "faster still in the water than on a break")
	expect(drunkenness.level_of(1) > drunkenness.level_of(3), "faster on a break than paddling")


func test_level_is_capped_at_one_and_reset_restores_start_level() -> void:
	expect_near(drunkenness.drink(0, 1000.0, false, true), 1.0, 0.0001, "blind drunk is the cap")
	drunkenness.set_level(1, 7.0)
	expect_near(drunkenness.level_of(1), 1.0, 0.0001, "set_level clamps to the scale")
	drunkenness.set_level(1, -1.0)
	expect_near(drunkenness.level_of(1), 0.0, 0.0001, "never below sober")
	drunkenness.reset()
	for seat: int in SEATS:
		expect_near(drunkenness.level_of(seat), 0.2, 0.0001, "seat %d back at start_level" % seat)


func test_stroke_delay_rises_with_level_per_lag_curve() -> void:
	expect_near(drunkenness.stroke_delay(0.0), 0.0, 0.001, "sober strokes land at once")
	expect_near(drunkenness.stroke_delay(0.5), 0.25, 0.001, "halfway along the ramp")
	expect_near(drunkenness.stroke_delay(1.0), 0.5, 0.001, "blind drunk is the end of the ramp")
	expect_near(drunkenness.stroke_delay(0.5), tuning.lag_curve.sample(0.5), 0.0001, "delay is the curve sample")
	expect_near(drunkenness.stroke_delay(1.5), 0.5, 0.001, "levels above the scale read the end")
	var previous: float = -1.0
	for i: int in 11:
		var delay: float = drunkenness.stroke_delay(i / 10.0)
		expect(delay >= previous, "delay never drops as the level rises (%d)" % i)
		previous = delay
	tuning.lag_curve = null
	expect_near(drunkenness.stroke_delay(0.9), 0.0, 0.0001, "no curve means no lag")


func test_miss_chance_rises_with_level_per_miss_curve() -> void:
	expect_near(drunkenness.miss_chance(0.0), 0.0, 0.001, "sober never misses")
	expect_near(drunkenness.miss_chance(0.25), 0.1, 0.001, "a quarter along the ramp")
	expect_near(drunkenness.miss_chance(1.0), 0.4, 0.001, "blind drunk is the end of the ramp")
	expect_near(drunkenness.miss_chance(0.75), tuning.miss_curve.sample(0.75), 0.0001, "chance is the curve sample")
	var previous: float = -1.0
	for i: int in 11:
		var chance: float = drunkenness.miss_chance(i / 10.0)
		expect(chance >= previous, "chance never drops as the level rises (%d)" % i)
		previous = chance
	tuning.miss_curve = DrinkTuning.ramp(0.0, 3.0)
	expect_near(drunkenness.miss_chance(1.0), 1.0, 0.0001, "chance is capped at certain")


func test_misses_are_rolled_from_the_given_rng() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	for i: int in 200:
		expect_false(drunkenness.misses(0.0, rng), "no chance, no miss (%d)" % i)
	tuning.miss_curve = DrinkTuning.ramp(1.0, 1.0)
	for i: int in 200:
		expect(drunkenness.misses(0.5, rng), "certain chance always misses (%d)" % i)

	tuning.miss_curve = DrinkTuning.ramp(0.0, 0.6)
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 99
	second.seed = 99
	var missed: int = 0
	var rolls: int = 4000
	for i: int in rolls:
		var miss: bool = drunkenness.misses(0.5, first)
		expect_eq(drunkenness.misses(0.5, second), miss, "same seed, same roll (%d)" % i)
		if miss:
			missed += 1
	var rate: float = float(missed) / rolls
	expect(rate > 0.25 and rate < 0.35, "about 30%% of strokes miss at chance 0.3, got %f" % rate)


func test_at_scramble_level_the_key_drives_the_other_hull_neighbour_until_he_sobers() -> void:
	drunkenness.set_level(0, 0.79)
	expect_false(drunkenness.scrambled(0), "just below scramble_level is still his key")
	expect_eq(drunkenness.key_target(0), 0, "his key drives his own seat")
	drunkenness.set_level(0, 0.8)
	expect(drunkenness.scrambled(0), "at scramble_level the key is scrambled")
	expect_eq(drunkenness.key_target(0), Paddling.Seat.RIGHT_FRONT, "left front key drives right front")
	drunkenness.drink(0, 5.0, false, true)
	expect(drunkenness.scrambled(0), "still scrambled as he drinks on")
	expect_eq(drunkenness.key_target(0), Paddling.Seat.RIGHT_FRONT, "the same seat while he stays drunk")
	drunkenness.set_level(0, 1.0)
	expect_eq(drunkenness.key_target(0), Paddling.Seat.RIGHT_FRONT, "the same seat at the cap")
	drunkenness.set_level(0, 0.79)
	expect_false(drunkenness.scrambled(0), "below scramble_level his key is his again")
	expect_eq(drunkenness.key_target(0), 0, "sobering up unscrambles")
	expect_false(drunkenness.scrambled(2), "the target seat guy is unaffected")
	expect_eq(drunkenness.key_target(2), 2, "his key is still his own")


func test_scramble_target_is_fixed_per_seat_on_the_other_hull_same_row() -> void:
	expect_eq(Drunkenness.scramble_target(Paddling.Seat.LEFT_FRONT), Paddling.Seat.RIGHT_FRONT, "left front to right front")
	expect_eq(Drunkenness.scramble_target(Paddling.Seat.LEFT_BACK), Paddling.Seat.RIGHT_BACK, "left back to right back")
	expect_eq(Drunkenness.scramble_target(Paddling.Seat.RIGHT_FRONT), Paddling.Seat.LEFT_FRONT, "right front to left front")
	expect_eq(Drunkenness.scramble_target(Paddling.Seat.RIGHT_BACK), Paddling.Seat.LEFT_BACK, "right back to left back")
	for seat: int in SEATS:
		var target: int = Drunkenness.scramble_target(seat)
		expect_ne(target, seat, "seat %d never keeps its own key" % seat)
		expect_ne(Paddling.seat_side(target), Paddling.seat_side(seat), "seat %d maps across the hulls" % seat)
		expect_eq(Paddling.is_back_seat(target), Paddling.is_back_seat(seat), "seat %d keeps its row" % seat)
		drunkenness.set_level(seat, 1.0)
		expect_eq(drunkenness.key_target(seat), target, "seat %d scrambled drives its target" % seat)


func test_tuning_resource_loads_with_placeholders() -> void:
	var loaded: Resource = load("res://data/drink_tuning.tres")
	expect(loaded is DrinkTuning, "data/drink_tuning.tres is a DrinkTuning")
	var drink: DrinkTuning = loaded
	expect(drink.start_level > 0.0, "the guys start tipsy, not sober")
	expect(drink.start_level < drink.scramble_level, "nobody starts scrambled")
	expect(drink.scramble_level <= 1.0, "the top tier is reachable")
	expect(drink.drink_rate > 0.0, "the crate gets drunk")
	expect(drink.break_drink_multiplier > 1.0, "a break drinks faster")
	expect(drink.water_drink_multiplier > drink.break_drink_multiplier, "the water drinks faster still")
	expect(drink.lag_curve != null and drink.miss_curve != null, "both curves are set")
	var rules: Drunkenness = Drunkenness.new(drink)
	expect_near(rules.stroke_delay(0.0), 0.0, 0.001, "sober strokes land at once")
	expect(rules.stroke_delay(1.0) > rules.stroke_delay(0.5), "lag rises with the level")
	expect_near(rules.miss_chance(0.0), 0.0, 0.001, "sober never misses")
	expect(rules.miss_chance(1.0) > rules.miss_chance(0.5), "misses rise with the level")
