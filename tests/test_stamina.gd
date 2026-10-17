extends "res://tools/test_case.gd"
## T14 · Stamina: strokes burn it by power, it recovers between strokes, a burnt-out guy is
## warned and then breaks, and random breaks get likelier the more is burnt
## (GDD › Systems › Stamina).

const SEATS: int = 4

var tuning: StaminaTuning
var stamina: Stamina
var rng: RandomNumberGenerator


func before_each() -> void:
	tuning = StaminaTuning.new()
	tuning.burn_per_power = 0.003
	tuning.recover_rate = 0.05
	tuning.break_recover_rate = 0.25
	tuning.break_duration = 3.0
	tuning.break_warning = 1.5
	tuning.random_break_curve = Curves.ramp(0.0, 0.0)
	stamina = Stamina.new(tuning)
	rng = RandomNumberGenerator.new()
	rng.seed = 7


func test_every_guy_starts_full_and_a_stroke_burns_burn_per_power_times_its_power() -> void:
	expect_eq(stamina.levels.size(), SEATS, "one level per seat")
	for seat: int in SEATS:
		expect_near(stamina.level_of(seat), 1.0, 0.0001, "seat %d starts full" % seat)
		expect_eq(stamina.state_of(seat), Stamina.State.PADDLING, "seat %d starts paddling" % seat)
		expect(stamina.can_stroke(seat), "seat %d gives strokes" % seat)
	expect_near(stamina.burn_of(100.0), 0.3, 0.0001, "burn_of() is the pure rule")
	expect_near(stamina.burn(0, 100.0), 0.7, 0.0001, "a full-power stroke burns burn_per_power times 100")
	expect_near(stamina.burn(0, 20.0), 0.64, 0.0001, "a tap burns burn_per_power times 20")
	expect_near(stamina.level_of(0), 0.64, 0.0001, "burn() stores the new level")
	expect(stamina.burn_of(100.0) > stamina.burn_of(20.0), "a stronger stroke burns more")
	expect_near(stamina.level_of(1), 1.0, 0.0001, "other guys do not pay for his stroke")
	expect_near(stamina.burn(1, 1000.0), 0.0, 0.0001, "burnt out is the floor")
	expect(stamina.burnt_out(1), "at zero he is burnt out")
	expect_false(stamina.burnt_out(0), "with stamina left he is not")
	expect_near(stamina.burnt_fraction(0), 0.36, 0.0001, "burnt fraction is one minus the level")


func test_stamina_recovers_at_recover_rate_between_strokes_up_to_full() -> void:
	stamina.burn(0, 100.0)
	stamina.step(0, 1.0, rng)
	expect_near(stamina.level_of(0), 0.75, 0.0001, "one second adds recover_rate")
	stamina.step(0, 2.5, rng)
	expect_near(stamina.level_of(0), 0.875, 0.0001, "rate times the step")
	expect_eq(stamina.state_of(0), Stamina.State.PADDLING, "still paddling")
	expect_near(stamina.time_left(0), 0.0, 0.0001, "no timer while paddling")
	stamina.step(0, 100.0, rng)
	expect_near(stamina.level_of(0), 1.0, 0.0001, "full is the cap")
	expect_near(stamina.level_of(1), 1.0, 0.0001, "other guys are untouched")
	stamina.set_level(2, 7.0)
	expect_near(stamina.level_of(2), 1.0, 0.0001, "set_level clamps to the scale")
	stamina.set_level(2, -1.0)
	expect_near(stamina.level_of(2), 0.0, 0.0001, "never below burnt out")


func test_burnt_out_guy_gets_break_warning_then_a_break_with_no_strokes_and_fast_recovery() -> void:
	stamina.burn(0, 1000.0)
	expect_eq(stamina.step(0, 0.1, rng), Stamina.State.WARNING, "a burnt-out guy is warned on his next step")
	expect_near(stamina.time_left(0), 1.5, 0.0001, "the warning lasts break_warning")
	expect(stamina.can_stroke(0), "he still paddles during the warning")
	expect_false(stamina.on_break(0), "not on a break yet")
	expect_near(stamina.level_of(0), 0.005, 0.0001, "he recovers at recover_rate meanwhile")
	stamina.burn(0, 1000.0)
	expect_eq(stamina.step(0, 1.0, rng), Stamina.State.WARNING, "a stroke in the warning does not restart it")
	expect_near(stamina.time_left(0), 0.5, 0.0001, "the warning counts down")
	expect_eq(stamina.step(0, 0.5, rng), Stamina.State.BREAK, "after break_warning the break starts")
	expect_near(stamina.time_left(0), 3.0, 0.0001, "the break lasts break_duration")
	expect_false(stamina.can_stroke(0), "his seat gives no strokes on a break")
	expect(stamina.on_break(0), "on a break")
	expect(stamina.can_stroke(1), "the other seats still stroke")
	expect_near(stamina.level_of(0), 0.075, 0.0001, "the warning recovered at recover_rate")
	stamina.step(0, 1.0, rng)
	expect_near(stamina.level_of(0), 0.325, 0.0001, "a second on a break adds break_recover_rate")
	expect_eq(stamina.state_of(0), Stamina.State.BREAK, "still on the break")
	expect_near(stamina.time_left(0), 2.0, 0.0001, "the break counts down")
	expect_eq(stamina.step(0, 2.0, rng), Stamina.State.PADDLING, "after break_duration he paddles again")
	expect(stamina.can_stroke(0), "his seat gives strokes again")
	expect_near(stamina.level_of(0), 0.825, 0.0001, "the break recovered at break_recover_rate")
	expect_near(stamina.time_left(0), 0.0, 0.0001, "no timer while paddling")
	expect_eq(stamina.state_of(1), Stamina.State.PADDLING, "other guys are not warned for him")


func test_call_break_telegraphs_once_and_reset_restores_full_and_paddling() -> void:
	stamina.call_break(2)
	expect_eq(stamina.state_of(2), Stamina.State.WARNING, "call_break starts the warning")
	stamina.step(2, 1.0, rng)
	stamina.call_break(2)
	expect_near(stamina.time_left(2), 0.5, 0.0001, "a second call does not restart the warning")
	stamina.step(2, 0.5, rng)
	stamina.call_break(2)
	expect_eq(stamina.state_of(2), Stamina.State.BREAK, "a call on a break does nothing")
	stamina.burn(0, 100.0)
	stamina.reset()
	for seat: int in SEATS:
		expect_near(stamina.level_of(seat), 1.0, 0.0001, "seat %d back to full" % seat)
		expect_eq(stamina.state_of(seat), Stamina.State.PADDLING, "seat %d back to paddling" % seat)
		expect_near(stamina.time_left(seat), 0.0, 0.0001, "seat %d has no timer" % seat)


func test_random_break_chance_rises_with_burnt_stamina_per_curve() -> void:
	tuning.random_break_curve = Curves.ramp(0.0, 0.5)
	expect_near(stamina.random_break_chance(1.0), 0.0, 0.001, "nothing burnt, no random breaks")
	expect_near(stamina.random_break_chance(0.5), 0.25, 0.001, "half burnt is halfway along the ramp")
	expect_near(stamina.random_break_chance(0.0), 0.5, 0.001, "burnt out is the end of the ramp")
	expect_near(stamina.random_break_chance(0.25), tuning.random_break_curve.sample(0.75), 0.0001, "chance is the curve at the burnt fraction")
	var previous: float = -1.0
	for i: int in 11:
		var chance: float = stamina.random_break_chance(1.0 - i / 10.0)
		expect(chance >= previous, "chance never drops as more is burnt (%d)" % i)
		previous = chance
	tuning.random_break_curve = Curves.ramp(0.0, 3.0)
	expect_near(stamina.random_break_chance(0.0), 1.0, 0.0001, "chance is capped at certain")
	tuning.random_break_curve = null
	expect_near(stamina.random_break_chance(0.0), 0.0, 0.0001, "no curve means no random breaks")


func test_random_breaks_come_from_the_seeded_rng_likelier_when_burnt_and_get_the_same_warning() -> void:
	tuning.random_break_curve = Curves.ramp(0.0, 0.5)
	for i: int in 500:
		expect_eq(stamina.step(0, 0.1, rng), Stamina.State.PADDLING, "a full guy never breaks at random (%d)" % i)

	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 99
	second.seed = 99
	var twin: Stamina = Stamina.new(tuning)
	var fresh_breaks: int = _count_random_breaks(stamina, 0.9, first, 2000)
	var twin_breaks: int = _count_random_breaks(twin, 0.9, second, 2000)
	expect_eq(twin_breaks, fresh_breaks, "the same seed gives the same breaks")
	expect(fresh_breaks > 0, "a guy who has burnt some stamina does break at random")
	var tired_breaks: int = _count_random_breaks(stamina, 0.3, first, 2000)
	expect(tired_breaks > fresh_breaks * 3, "more burnt, many more breaks: %d vs %d" % [tired_breaks, fresh_breaks])

	stamina.reset()
	tuning.random_break_curve = Curves.ramp(1.0, 1.0)
	stamina.set_level(0, 0.5)
	expect_eq(stamina.step(0, 1.0, first), Stamina.State.WARNING, "a certain chance breaks on the step")
	expect_near(stamina.time_left(0), 1.5, 0.0001, "a random break gets the same break_warning")
	expect(stamina.can_stroke(0), "and he still paddles through it")
	expect_eq(stamina.step(0, 1.5, first), Stamina.State.BREAK, "then the same break")
	expect_near(stamina.time_left(0), 3.0, 0.0001, "of break_duration")
	expect_false(stamina.can_stroke(0), "with no strokes")


func test_tuning_resource_loads_with_placeholders() -> void:
	var loaded: Resource = load("res://data/stamina_tuning.tres")
	expect(loaded is StaminaTuning, "data/stamina_tuning.tres is a StaminaTuning")
	var data: StaminaTuning = loaded
	expect(data.burn_per_power > 0.0, "strokes cost stamina")
	expect(data.recover_rate > 0.0, "stamina recovers between strokes")
	expect(data.break_recover_rate > data.recover_rate, "a break recovers faster")
	expect(data.break_duration > 0.0, "a break lasts a few seconds")
	expect(data.break_warning > 0.0, "a break is telegraphed ahead")
	expect(data.random_break_curve != null, "the random break curve is set")
	var rules: Stamina = Stamina.new(data)
	expect_near(rules.random_break_chance(1.0), 0.0, 0.001, "a full guy never breaks at random")
	expect(rules.random_break_chance(0.0) > rules.random_break_chance(0.5), "random breaks rise with burnt stamina")
	expect(rules.burn_of(100.0) < 1.0, "one full stroke does not burn a guy out")
	expect(rules.burn_of(100.0) > rules.burn_of(20.0), "a strong stroke burns more than a tap")


## Steps seat 0 `steps` times at `level`, 0.1 s each, and counts the random breaks called.
func _count_random_breaks(rules: Stamina, level: float, random: RandomNumberGenerator, steps: int) -> int:
	var breaks: int = 0
	for i: int in steps:
		rules.reset()
		rules.set_level(0, level)
		if rules.step(0, 0.1, random) == Stamina.State.WARNING:
			breaks += 1
	return breaks
