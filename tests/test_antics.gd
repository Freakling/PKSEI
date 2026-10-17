extends "res://tools/test_case.gd"
## T13 · Antics: crossing a drunkenness threshold starts a wind-up of windup_time, then one of
## four antics fires, each with its own effect and recovery; one antic per threshold crossing;
## a shove of pee_fall_shove or more during a pee knocks the guy in (GDD › Systems › Drunkenness).

const SEATS: int = 4

var tuning: DrinkTuning
var antics: Antics
var rng: RandomNumberGenerator


func before_each() -> void:
	tuning = DrinkTuning.new()
	tuning.antic_thresholds = [0.4, 0.6, 0.8]
	tuning.windup_time = 1.5
	tuning.stand_time = 3.0
	tuning.stand_rock = 60.0
	tuning.fish_time = 4.0
	tuning.nap_time = 5.0
	tuning.pee_time = 6.0
	tuning.pee_fall_shove = 100.0
	antics = Antics.new(tuning)
	rng = RandomNumberGenerator.new()
	rng.seed = 7


func test_every_guy_starts_idle_and_stays_idle_below_the_first_threshold() -> void:
	expect_eq(antics.states.size(), SEATS, "one state per seat")
	for seat: int in SEATS:
		expect_eq(antics.state_of(seat), Antics.State.IDLE, "seat %d starts idle" % seat)
		expect(antics.can_stroke(seat), "seat %d gives strokes" % seat)
		expect_near(antics.time_left(seat), 0.0, 0.0001, "seat %d has no timer" % seat)
	for i: int in 100:
		expect_eq(antics.step(0, 1.0, 0.39, rng), Antics.State.IDLE, "below the first threshold nothing happens (%d)" % i)
	expect_false(antics.winding_up(0), "not winding up")


func test_crossing_a_threshold_starts_a_wind_up_of_windup_time_before_the_antic_fires() -> void:
	expect_eq(antics.step(0, 0.1, 0.4, rng), Antics.State.WINDING_UP, "reaching the threshold starts the wind-up")
	expect(antics.winding_up(0), "winding up")
	expect_near(antics.time_left(0), 1.5, 0.0001, "the wind-up lasts windup_time")
	expect(antics.can_stroke(0), "he still paddles during the wind-up")
	expect_false(antics.busy(0), "the antic has not fired yet")
	expect_eq(antics.step(0, 1.0, 0.45, rng), Antics.State.WINDING_UP, "a second in, still announcing")
	expect_near(antics.time_left(0), 0.5, 0.0001, "the wind-up counts down")
	var fired: Antics.State = antics.step(0, 0.5, 0.45, rng)
	expect_ne(fired, Antics.State.WINDING_UP, "after windup_time the antic fires")
	expect_ne(fired, Antics.State.IDLE, "and it is an antic")
	expect(antics.busy(0), "busy with it")
	expect_near(antics.time_left(0), antics.antic_time(antics.kind_of(0)), 0.0001, "for that antic's time")
	expect_eq(antics.state_of(1), Antics.State.IDLE, "other guys are not winding up for him")


func test_the_antic_is_drawn_from_the_seeded_rng() -> void:
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 99
	second.seed = 99
	var twin: Antics = Antics.new(tuning)
	var kinds: Array[Antics.Kind] = []
	var twin_kinds: Array[Antics.Kind] = []
	var seen: Dictionary = {}
	for i: int in 40:
		antics.reset()
		twin.reset()
		antics.step(0, 0.1, 0.4, first)
		twin.step(0, 0.1, 0.4, second)
		kinds.append(antics.kind_of(0))
		twin_kinds.append(twin.kind_of(0))
		seen[antics.kind_of(0)] = true
	expect_eq(kinds, twin_kinds, "the same seed draws the same antics")
	expect_eq(seen.size(), Antics.Kind.size(), "every antic comes up over 40 draws")


func test_standing_up_rocks_the_boat_side_to_side_for_stand_time_then_he_recovers() -> void:
	antics.start(0, Antics.Kind.STAND)
	expect_eq(antics.state_of(0), Antics.State.WINDING_UP, "start() begins the wind-up")
	expect_near(antics.rock(0), 0.0, 0.0001, "no rock during the wind-up")
	expect_eq(antics.step(0, 1.5, 0.5, rng), Antics.State.STANDING, "then he stands")
	expect_near(antics.time_left(0), 3.0, 0.0001, "for stand_time")
	expect(antics.can_stroke(0), "a standing guy still swings his paddle")
	expect_near(antics.rock(0), 0.0, 0.0001, "the swing starts at rest")
	antics.step(0, 0.25, 0.5, rng)
	expect_near(antics.rock(0), 60.0, 0.0001, "a quarter period in, the left-front guy rocks the boat right at stand_rock")
	expect_near(antics.rock(1), 0.0, 0.0001, "a seated guy rocks nothing")
	antics.step(0, 0.5, 0.5, rng)
	expect_near(antics.rock(0), -60.0, 0.0001, "three quarters in, he rocks it left")
	antics.step(0, 2.25, 0.5, rng)
	expect_eq(antics.state_of(0), Antics.State.RECOVERING, "after stand_time he sits back down")
	expect_near(antics.rock(0), 0.0, 0.0001, "no rock once he is down")
	expect(antics.can_stroke(0), "he paddles while settling")
	expect_eq(antics.step(0, Antics.RECOVER_TIME, 0.5, rng), Antics.State.IDLE, "then he is idle again")
	expect_near(antics.time_left(0), 0.0, 0.0001, "with no timer")
	var right: Antics = Antics.new(tuning)
	right.start(2, Antics.Kind.STAND)
	right.step(2, 1.5, 0.5, rng)
	right.step(2, 0.25, 0.5, rng)
	expect_near(right.rock(2), -60.0, 0.0001, "a right-hull guy starts his rock the other way")


func test_the_rock_period_is_a_tunable_and_a_period_of_zero_rocks_nothing() -> void:
	tuning.stand_rock_period = 2.0
	antics.start(0, Antics.Kind.STAND)
	antics.step(0, 1.5, 0.5, rng)
	antics.step(0, 0.5, 0.5, rng)
	expect_near(antics.rock(0), 60.0, 0.0001, "half a second in, a quarter of stand_rock_period 2 is the peak")
	tuning.stand_rock_period = 0.0
	expect_near(antics.rock(0), 0.0, 0.0001, "a period of zero rocks nothing rather than going NaN")


func test_dropping_the_paddle_disables_the_seat_until_it_is_fished_out() -> void:
	antics.start(1, Antics.Kind.DROP_PADDLE)
	expect(antics.can_stroke(1), "he paddles through the wind-up")
	expect_eq(antics.step(1, 1.5, 0.5, rng), Antics.State.PADDLE_DROPPED, "then the paddle goes")
	expect_near(antics.time_left(1), 4.0, 0.0001, "he fishes for fish_time")
	expect_false(antics.can_stroke(1), "his seat gives no strokes meanwhile")
	expect(antics.can_stroke(0), "the other seats still stroke")
	expect_near(antics.rock(1), 0.0, 0.0001, "and he rocks nothing")
	antics.step(1, 3.5, 0.5, rng)
	expect_false(antics.can_stroke(1), "still fishing")
	expect_eq(antics.step(1, 0.5, 0.5, rng), Antics.State.RECOVERING, "after fish_time he has it back")
	expect(antics.can_stroke(1), "and his seat strokes again")
	expect_eq(antics.step(1, Antics.RECOVER_TIME, 0.5, rng), Antics.State.IDLE, "then he is idle")


func test_nodding_off_makes_the_seat_dead_weight_for_nap_time() -> void:
	antics.start(2, Antics.Kind.NOD_OFF)
	expect_eq(antics.step(2, 1.5, 0.5, rng), Antics.State.NODDED_OFF, "after the wind-up he naps")
	expect_near(antics.time_left(2), 5.0, 0.0001, "for nap_time")
	expect_false(antics.can_stroke(2), "a napping guy gives no strokes")
	expect_near(antics.rock(2), 0.0, 0.0001, "and rocks nothing")
	expect_eq(antics.step(2, 5.0, 0.5, rng), Antics.State.RECOVERING, "after nap_time he wakes")
	expect(antics.can_stroke(2), "and strokes again")
	expect_eq(antics.step(2, Antics.RECOVER_TIME, 0.5, rng), Antics.State.IDLE, "then he is idle")


func test_peeing_disables_the_seat_for_pee_time_and_recovers_on_its_own() -> void:
	antics.start(3, Antics.Kind.PEE)
	expect_eq(antics.step(3, 1.5, 0.5, rng), Antics.State.PEEING, "after the wind-up he pees")
	expect_near(antics.time_left(3), 6.0, 0.0001, "for pee_time")
	expect_false(antics.can_stroke(3), "his seat gives no strokes while he pees")
	expect_eq(antics.step(3, 6.0, 0.5, rng), Antics.State.RECOVERING, "after pee_time he is done")
	expect(antics.can_stroke(3), "and strokes again")
	expect_eq(antics.step(3, Antics.RECOVER_TIME, 0.5, rng), Antics.State.IDLE, "then he is idle")


func test_a_shove_of_pee_fall_shove_or_more_during_a_pee_knocks_him_in_and_interrupt_ends_it() -> void:
	expect_false(antics.knocked_in(0, 500.0), "an idle guy is not knocked in")
	antics.start(0, Antics.Kind.PEE)
	expect_false(antics.knocked_in(0, 500.0), "nor one winding up")
	antics.step(0, 1.5, 0.5, rng)
	expect_eq(antics.state_of(0), Antics.State.PEEING, "peeing")
	expect_false(antics.knocked_in(0, 99.9), "a shove under pee_fall_shove leaves him standing")
	expect(antics.knocked_in(0, 100.0), "pee_fall_shove exactly knocks him in")
	expect(antics.knocked_in(0, 240.0), "and anything harder")
	expect_false(antics.knocked_in(1, 240.0), "a seated guy is not knocked in")
	antics.interrupt(0)
	expect_eq(antics.state_of(0), Antics.State.IDLE, "interrupt ends the antic at once")
	expect(antics.can_stroke(0), "his seat is free again (he is in the water now, RunState's rule)")
	expect_near(antics.time_left(0), 0.0, 0.0001, "no timer")
	antics.start(1, Antics.Kind.STAND)
	antics.step(1, 1.5, 0.5, rng)
	antics.step(1, 1.0, 0.5, rng)
	expect_false(antics.knocked_in(1, 500.0), "a standing guy is not knocked in by a shove")


func test_each_threshold_fires_one_antic_per_attempt_rising_only_and_a_busy_guy_waits() -> void:
	tuning.windup_time = 1.0
	tuning.stand_time = 1.0
	tuning.fish_time = 1.0
	tuning.nap_time = 1.0
	tuning.pee_time = 1.0
	# Two thresholds reached at once: two antics, one after the other, and not a third.
	expect_eq(antics.step(0, 0.1, 0.7, rng), Antics.State.WINDING_UP, "the first crossing fires")
	var antics_started: int = 1
	var previous: Antics.State = Antics.State.WINDING_UP
	for i: int in 200:
		var state: Antics.State = antics.step(0, 0.1, 0.7, rng)
		if state == Antics.State.WINDING_UP and previous != Antics.State.WINDING_UP:
			antics_started += 1
		previous = state
	expect_eq(antics_started, 2, "two thresholds crossed, two antics")
	expect_eq(antics.state_of(0), Antics.State.IDLE, "then he is idle")
	for i: int in 50:
		expect_eq(antics.step(0, 0.1, 0.7, rng), Antics.State.IDLE, "holding at the level fires nothing more (%d)" % i)
	for i: int in 50:
		expect_eq(antics.step(0, 0.1, 0.3, rng), Antics.State.IDLE, "dropping below does nothing (%d)" % i)
	for i: int in 50:
		expect_eq(antics.step(0, 0.1, 0.7, rng), Antics.State.IDLE, "rising past them again fires nothing (%d)" % i)
	expect_eq(antics.step(0, 0.1, 0.8, rng), Antics.State.WINDING_UP, "the third threshold fires once reached")
	# A crossing while he is busy waits for him.
	antics.reset()
	antics.start(1, Antics.Kind.NOD_OFF)
	antics.step(1, 1.0, 0.2, rng)
	expect_eq(antics.state_of(1), Antics.State.NODDED_OFF, "napping")
	expect_eq(antics.step(1, 0.5, 0.4, rng), Antics.State.NODDED_OFF, "a crossing mid-nap does not cut it short")
	antics.step(1, 0.5, 0.4, rng)
	antics.step(1, Antics.RECOVER_TIME, 0.4, rng)
	expect_eq(antics.state_of(1), Antics.State.IDLE, "the nap ran its course")
	expect_eq(antics.step(1, 0.1, 0.4, rng), Antics.State.WINDING_UP, "then the waiting crossing fires")
	antics.start(1, Antics.Kind.PEE)
	expect_near(antics.time_left(1), 1.0, 0.0001, "start() on a busy guy does nothing")
	expect_eq(antics.state_of(2), Antics.State.IDLE, "other guys are untouched")
	# The reset forgets the crossings.
	antics.reset()
	for seat: int in SEATS:
		expect_eq(antics.state_of(seat), Antics.State.IDLE, "seat %d idle after reset" % seat)
	expect_eq(antics.step(0, 0.1, 0.7, rng), Antics.State.WINDING_UP, "after reset the thresholds fire again")


func test_tuning_resource_loads_with_placeholders() -> void:
	var loaded: Resource = load("res://data/drink_tuning.tres")
	expect(loaded is DrinkTuning, "data/drink_tuning.tres is a DrinkTuning")
	var data: DrinkTuning = loaded
	expect(data.antic_thresholds.size() > 0, "there are antic thresholds")
	var previous: float = data.start_level
	for threshold: float in data.antic_thresholds:
		expect(threshold > previous, "thresholds rise and sit above start_level")
		expect(threshold < data.bar_level, "and below the timing bar's tier")
		previous = threshold
	expect(data.windup_time > 0.0, "an antic is announced ahead")
	expect(data.stand_time > 0.0, "standing lasts")
	expect(data.stand_rock > 0.0, "and rocks the boat")
	expect(data.stand_rock_period > 0.0, "one rock takes time")
	expect(data.fish_time > 0.0, "fishing the paddle out takes time")
	expect(data.nap_time > 0.0, "a nap lasts")
	expect(data.pee_time > 0.0, "a pee lasts")
	expect(data.pee_fall_shove > 0.0, "it takes a real shove to knock him in")
