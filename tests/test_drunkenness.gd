extends "res://tools/test_case.gd"
## T5 · Drunkenness: levels rise with time, faster on a break or in the water; lag and misses
## follow the level (GDD › Systems › Drunkenness).
## T31 · The timing bar at the top tier: the bar sweeps with bar_period, a release inside
## green_width of the centre is a hit, and crossing bar_level is announced with a wind-up.
## T65 · After its wind-up the bar applies for bar_duration then ends, level or no; it can be
## announced again after bar_cooldown if he is still at or above bar_level; dropping below
## bar_level ends it and clears the cooldown.
## T63 · relieve() lowers a level by an amount, never below 0; dropping below bar_level ends the
## bar tier (GDD › Systems › Drunkenness: "drunkenness also comes down").

const SEATS: int = 4
## The bar's duration and cooldown these tests set (T65).
const BAR_DURATION: float = 10.0
const BAR_COOLDOWN: float = 20.0

var tuning: DrinkTuning
var drunkenness: Drunkenness


func before_each() -> void:
	tuning = DrinkTuning.new()
	tuning.start_level = 0.2
	tuning.drink_rate = 0.01
	tuning.break_drink_multiplier = 3.0
	tuning.water_drink_multiplier = 5.0
	tuning.lag_curve = Curves.ramp(0.0, 0.5)
	tuning.miss_curve = Curves.ramp(0.0, 0.4)
	tuning.bar_level = 0.8
	tuning.bar_period = 2.0
	tuning.green_width = 0.2
	tuning.bar_duration = BAR_DURATION
	tuning.bar_cooldown = BAR_COOLDOWN
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
	tuning.miss_curve = Curves.ramp(0.0, 3.0)
	expect_near(drunkenness.miss_chance(1.0), 1.0, 0.0001, "chance is capped at certain")


func test_misses_are_rolled_from_the_given_rng() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	for i: int in 200:
		expect_false(drunkenness.misses(0.0, rng), "no chance, no miss (%d)" % i)
	tuning.miss_curve = Curves.ramp(1.0, 1.0)
	for i: int in 200:
		expect(drunkenness.misses(0.5, rng), "certain chance always misses (%d)" % i)

	tuning.miss_curve = Curves.ramp(0.0, 0.6)
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


func test_bar_position_sweeps_there_and_back_once_per_bar_period() -> void:
	expect_near(drunkenness.bar_position(0.0), 0.0, 0.0001, "the bar starts at the left end")
	expect_near(drunkenness.bar_position(0.5), 0.5, 0.0001, "a quarter period in it is at the centre")
	expect_near(drunkenness.bar_position(1.0), 1.0, 0.0001, "half a period in it is at the right end")
	expect_near(drunkenness.bar_position(1.5), 0.5, 0.0001, "on the way back")
	expect_near(drunkenness.bar_position(2.0), 0.0, 0.0001, "back at the left end after bar_period")
	expect_near(drunkenness.bar_position(2.5), 0.5, 0.0001, "and sweeping again")
	expect_near(drunkenness.bar_position(7.0), 1.0, 0.0001, "the sweep repeats every bar_period")
	var previous: float = drunkenness.bar_position(0.0)
	for i: int in range(1, 81):
		var at: float = drunkenness.bar_position(i * 0.05)
		expect(at >= 0.0 and at <= 1.0, "always on the bar (%d)" % i)
		expect_near(at, previous, 0.0501, "no jumps: the marker slides (%d)" % i)
		previous = at
	tuning.bar_period = 1.0
	expect_near(drunkenness.bar_position(0.25), 0.5, 0.0001, "a shorter period sweeps faster")
	expect_near(drunkenness.bar_position(0.5), 1.0, 0.0001, "reaching the end in half of it")
	tuning.bar_period = 0.0
	expect_near(drunkenness.bar_position(3.0), 0.5, 0.0001, "no period: the bar rests in the middle")


func test_bar_hit_is_a_release_inside_green_width_of_the_centre() -> void:
	expect(drunkenness.bar_hit(0.5), "dead centre is a hit")
	expect(drunkenness.bar_hit(0.45), "just inside the green zone on the way out")
	expect(drunkenness.bar_hit(1.55), "just inside the green zone on the way back")
	expect_false(drunkenness.bar_hit(0.35), "outside the green zone is a miss")
	expect_false(drunkenness.bar_hit(0.0), "a tap, marker at the left end, is a miss")
	expect_false(drunkenness.bar_hit(1.0), "the right end is a miss")
	expect(drunkenness.bar_hit(2.5), "the centre on the next sweep is a hit again")
	tuning.green_width = 0.5
	expect(drunkenness.bar_hit(0.35), "a wider green zone takes the same release")
	tuning.green_width = 1.0
	expect(drunkenness.bar_hit(0.0) and drunkenness.bar_hit(1.0), "the whole bar green: everything hits")
	tuning.green_width = 0.0
	expect_false(drunkenness.bar_hit(0.45), "no green zone: nothing but the centre")
	expect(drunkenness.bar_hit(0.5), "which still hits")


func test_the_bar_applies_after_a_wind_up_at_bar_level_and_lasts_bar_duration() -> void:
	drunkenness.set_level(0, 0.79)
	expect_false(drunkenness.uses_bar(0), "just below bar_level his strokes are plain")
	expect_false(drunkenness.bar_winding_up(0), "and nothing is announced")
	drunkenness.set_level(0, 0.8)
	expect(drunkenness.bar_winding_up(0), "at bar_level the tier is announced")
	expect_false(drunkenness.uses_bar(0), "the bar does not apply during the wind-up")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 0.5, false, false)
	expect(drunkenness.bar_winding_up(0), "still announcing halfway through")
	expect_false(drunkenness.uses_bar(0), "still not applied")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 0.5, false, false)
	expect(drunkenness.uses_bar(0), "the bar applies once the wind-up is over")
	expect_false(drunkenness.bar_winding_up(0), "the announcement is over")
	drunkenness.drink(0, BAR_DURATION * 0.5, false, false)
	expect(drunkenness.uses_bar(0), "and holds as he drinks on, halfway through bar_duration")
	drunkenness.set_level(0, 1.0)
	expect(drunkenness.uses_bar(0) and not drunkenness.bar_winding_up(0), "no new wind-up while he stays in the tier")
	drunkenness.drink(0, BAR_DURATION * 0.5 - 0.1, false, false)
	expect(drunkenness.uses_bar(0), "still on, a tenth of a second short of bar_duration")
	drunkenness.drink(0, 0.1, false, false)
	expect_false(drunkenness.uses_bar(0), "after bar_duration the bar ends")
	expect_false(drunkenness.bar_winding_up(0), "with no new announcement")
	expect(drunkenness.level_of(0) >= tuning.bar_level, "though he is still at the top of the meter")
	drunkenness.drink(0, 1.0, false, false)
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "and stays ended: plain lag and misses")
	drunkenness.set_level(0, 0.79)
	expect_false(drunkenness.uses_bar(0), "below bar_level his strokes are plain")
	expect_false(drunkenness.bar_winding_up(0), "nothing announced")
	drunkenness.set_level(0, 0.9)
	expect(drunkenness.bar_winding_up(0), "crossing again is announced again")
	expect_false(drunkenness.uses_bar(0), "before the bar applies")
	expect_false(drunkenness.uses_bar(2) or drunkenness.bar_winding_up(2), "the other guys are unaffected")
	drunkenness.reset()
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "a reset forgets the tier")


## T65: once the bar has ended, bar_cooldown later it is announced again if he is still at or
## above bar_level, and the cycle repeats; like the wind-up, the clock waits in the water.
func test_it_can_be_announced_again_after_bar_cooldown_if_he_is_still_at_bar_level() -> void:
	drunkenness.set_level(0, 0.9)
	drunkenness.drink(0, Drunkenness.BAR_WINDUP, false, false)
	expect(drunkenness.uses_bar(0), "the bar applies after its wind-up")
	drunkenness.drink(0, BAR_DURATION, false, false)
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "and ends after bar_duration")
	drunkenness.drink(0, BAR_COOLDOWN * 0.5, false, false)
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "halfway through the cooldown: nothing")
	drunkenness.drink(0, BAR_COOLDOWN, false, true)
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "the cooldown waits while he floats")
	drunkenness.drink(0, BAR_COOLDOWN * 0.5 - 0.1, false, false)
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "a tenth of a second short of bar_cooldown: still nothing")
	drunkenness.drink(0, 0.1, false, false)
	expect(drunkenness.level_of(0) >= tuning.bar_level, "he is still at the top")
	expect(drunkenness.bar_winding_up(0), "so after bar_cooldown the bar is announced again")
	expect_false(drunkenness.uses_bar(0), "and does not apply during the new wind-up")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 0.5, false, false)
	expect(drunkenness.bar_winding_up(0), "a full wind-up, not a shortened one")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 0.5, false, false)
	expect(drunkenness.uses_bar(0), "then the bar applies again")
	expect_false(drunkenness.bar_winding_up(0), "the announcement over")
	drunkenness.drink(0, BAR_DURATION, false, false)
	expect_false(drunkenness.uses_bar(0), "and ends again after bar_duration: the cycle repeats")
	expect_false(drunkenness.uses_bar(1) or drunkenness.bar_winding_up(1), "the other guys are unaffected")


## T65: dropping below bar_level ends the bar, as before, and forgets the cooldown: a re-crossing
## is announced at once, with a full wind-up.
func test_dropping_below_bar_level_ends_the_bar_and_clears_the_cooldown() -> void:
	drunkenness.set_level(0, 0.9)
	drunkenness.drink(0, Drunkenness.BAR_WINDUP, false, false)
	drunkenness.drink(0, 2.0, false, false)
	expect(drunkenness.uses_bar(0), "the bar is on")
	drunkenness.set_level(0, 0.79)
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "below bar_level it ends")
	drunkenness.set_level(0, 0.9)
	expect(drunkenness.bar_winding_up(0), "crossing again is announced at once")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP, false, false)
	drunkenness.drink(0, BAR_DURATION, false, false)
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "the bar ran its course")
	drunkenness.drink(0, 1.0, false, false)
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "a second into the cooldown")
	drunkenness.relieve(0, 0.25)
	expect(drunkenness.level_of(0) < tuning.bar_level, "a puke's relief takes him below bar_level")
	expect_false(drunkenness.uses_bar(0) or drunkenness.bar_winding_up(0), "nothing shows below it")
	drunkenness.set_level(0, 0.9)
	expect(drunkenness.bar_winding_up(0), "crossing again is announced at once: the cooldown is forgotten")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 0.5, false, false)
	expect(drunkenness.bar_winding_up(0), "with a full wind-up")
	expect_false(drunkenness.uses_bar(0), "the bar not yet applying")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 0.5, false, false)
	expect(drunkenness.uses_bar(0), "then the bar")


func test_the_wind_up_waits_while_he_is_in_the_water_and_counts_down_once_aboard() -> void:
	drunkenness.set_level(0, 0.79)
	drunkenness.drink(0, 1.0, false, true)
	expect(drunkenness.level_of(0) >= tuning.bar_level, "a second in the water carries him over bar_level")
	expect(drunkenness.bar_winding_up(0), "the crossing in the water is registered")
	expect_false(drunkenness.uses_bar(0), "but the bar does not apply yet")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 2.0, false, true)
	expect(drunkenness.bar_winding_up(0), "the wind-up does not count down while he floats")
	expect_false(drunkenness.uses_bar(0), "so he cannot come aboard already on the bar")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 2.0, false, true, false)
	expect(drunkenness.bar_winding_up(0), "nor while he floats without a beer")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 0.5, false, false)
	expect(drunkenness.bar_winding_up(0), "back aboard it counts down: halfway, still announcing")
	expect_false(drunkenness.uses_bar(0), "still not applied")
	drunkenness.drink(0, Drunkenness.BAR_WINDUP * 0.5, false, false)
	expect(drunkenness.uses_bar(0), "the full wind-up ran aboard, then the bar applies")
	expect_false(drunkenness.bar_winding_up(0), "the announcement is over")
	drunkenness.drink(0, 3.0, false, true)
	expect(drunkenness.uses_bar(0), "once applied, the bar holds through another dip in the water")


func test_tuning_resource_loads_with_placeholders() -> void:
	var loaded: Resource = load("res://data/drink_tuning.tres")
	expect(loaded is DrinkTuning, "data/drink_tuning.tres is a DrinkTuning")
	var drink: DrinkTuning = loaded
	expect(drink.start_level > 0.0, "the guys start tipsy, not sober")
	expect(drink.start_level < drink.bar_level, "nobody starts on the bar")
	expect(drink.bar_level <= 1.0, "the top tier is reachable")
	expect(drink.bar_period > 0.0, "the bar sweeps")
	expect(drink.green_width > 0.0 and drink.green_width < 1.0, "a thin green zone: not none, not the whole bar")
	expect(drink.bar_duration >= 10.0 and drink.bar_duration <= 15.0, "the bar lasts ten to fifteen seconds (GDD)")
	expect(drink.bar_cooldown > 0.0, "and comes back only after a while")
	expect(drink.drink_rate > 0.0, "the crate gets drunk")
	expect(drink.break_drink_multiplier > 1.0, "a break drinks faster")
	expect(drink.water_drink_multiplier > drink.break_drink_multiplier, "the water drinks faster still")
	expect(drink.lag_curve != null and drink.miss_curve != null, "both curves are set")
	var rules: Drunkenness = Drunkenness.new(drink)
	expect_near(rules.stroke_delay(0.0), 0.0, 0.001, "sober strokes land at once")
	expect(rules.stroke_delay(1.0) > rules.stroke_delay(0.5), "lag rises with the level")
	expect_near(rules.miss_chance(0.0), 0.0, 0.001, "sober never misses")
	expect(rules.miss_chance(1.0) > rules.miss_chance(0.5), "misses rise with the level")


## T63: relieve() takes an amount off one guy's level, never below 0, and a drop below bar_level
## ends the bar tier like any other fall.
func test_relieve_lowers_the_level_and_clamps_at_zero() -> void:
	expect_near(drunkenness.relieve(0, 0.05), 0.15, 0.0001, "relieve takes the amount off")
	expect_near(drunkenness.level_of(0), 0.15, 0.0001, "and stores it")
	expect_near(drunkenness.level_of(1), 0.2, 0.0001, "other guys keep theirs")
	expect_near(drunkenness.relieve(0, 1.0), 0.0, 0.0001, "never below 0")
	expect_near(drunkenness.relieve(1, -0.5), 0.2, 0.0001, "a negative amount relieves nothing")
	drunkenness.set_level(2, 0.9)
	expect(drunkenness.bar_winding_up(2), "at bar_level the bar is announced")
	expect_near(drunkenness.relieve(2, 0.4), 0.5, 0.0001, "a puke's worth comes off")
	expect_false(drunkenness.bar_winding_up(2), "below bar_level the bar is no longer announced")
	expect_false(drunkenness.uses_bar(2), "and does not apply")
