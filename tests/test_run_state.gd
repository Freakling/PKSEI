extends "res://tools/test_case.gd"
## T3 · RunState.reset() restores the starting conditions (GDD › Core Loop › Starting conditions).
## T6 · RunState wires Paddling, Drunkenness and Stamina: stroke() and step() turn key releases
## into the boat's Motion; set_progress() and arrive() drive the phases (GDD › Win and Loss).
## T9 · RunState wires Rescue: beer_overboard() and guy_overboard() take a guy off the boat,
## pickup() brings him back, a swimmer drinks only while he has a beer, and shore_touched() while
## crossing (never while launching) restores the starting conditions (GDD › Systems › Setbacks).
## T31 · On the timing bar (the top drunkenness tier) a release in the green zone is the normal
## stroke and one outside it a backwards stroke of the same power; both burn stamina.
## T32 · A guy in the water neither recovers stamina nor rolls random breaks, and comes back in
## the state he left when he is picked up (GDD › Systems › Stamina).
## B1 · A stroke released before its guy goes overboard never lands: the strokes still waiting to
## land are dropped when he goes in (GDD › Systems › Setbacks).
## B2 · A guy washed up at the shoreline climbs back aboard on his own while the boat rests at the
## launch shore (LAUNCH); under way (CROSSING) he waits there for the boat or the shore reset.
## T34 · A beer overboard leaves its guy aboard and paddling for BoatTuning.jump_delay; step()
## takes him off the boat when he jumps, and drops his strokes still waiting then.
## T35 · Beers and swimmers drift at BoatTuning.loose_drift_speed while the boat drifts at
## current_speed (GDD › Systems › Catamaran and paddling).
## T25 · RunState tells the Audio autoload what happened: stroke_landed, stroke_fumbled,
## guy_jumped, guy_picked_up and beer_overboard_started fire where those things happen
## (GDD › Presentation and Platforms, Audio).
## T46 · After a beer goes over, beer_overboard() does nothing for BoatTuning.beer_loss_cooldown
## seconds while shove() and stop() still reach the boat; the cooldown resets with the attempt.
## T47 · With nobody aboard the boat's drift is current_speed times empty_drift_multiplier per
## second; with anyone aboard it is current_speed (GDD › Systems › Setbacks).

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 60.0
const BOAT: Vector2 = Vector2(0.0, -300.0)
const DELAY: float = 2.5
## The beer-loss cooldown the T46 tests set on their own BoatTuning (GDD › Systems › Hazards).
const COOLDOWN: float = 2.0
## The empty-boat drift multiplier the T47 tests set on their own BoatTuning (GDD › Systems › Setbacks).
const EMPTY_MULTIPLIER: float = 5.0
## The harsh-wind extra drift the T47 test adds, per second.
const WIND: float = 25.0


## A RunState whose guys are sober (no lag, no misses), whose rolls are seeded, and whose
## BoatTuning is its own (jump_delay DELAY, no beer-loss cooldown), so a test can change it.
func sober_state() -> Node:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.paddling = Paddling.new(own_boat_tuning())
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	return state


## A RunState with a DrinkTuning of this flat lag, flat miss chance and start level, and its own
## BoatTuning (jump_delay DELAY).
func drunk_state(lag: float, miss: float, level: float) -> Node:
	var tuning: DrinkTuning = DrinkTuning.new()
	tuning.start_level = level
	tuning.lag_curve = Curves.ramp(lag, lag)
	tuning.miss_curve = Curves.ramp(miss, miss)
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.paddling = Paddling.new(own_boat_tuning())
	state.drunkenness = Drunkenness.new(tuning)
	state.reset()
	return state


## No beer-loss cooldown here: the cascade tests drop beers back to back. The T46 tests set it.
func own_boat_tuning() -> BoatTuning:
	var tuning: BoatTuning = BoatTuning.new()
	tuning.jump_delay = DELAY
	tuning.beer_loss_cooldown = 0.0
	return tuning


## A beer over on `side` with the boat at `at` and no wind-up: the chosen guy is in the water at
## `at` at once (the T9 shape; the wind-up has its own tests). The state's jump_delay stays 0.
func jump_now(state: Node, side: Rescue.Hull, at: Vector2) -> int:
	state.paddling.tuning.jump_delay = 0.0
	var seat: int = state.beer_overboard(side, at)
	state.step(0.0, at)
	return seat


func test_reset_restores_starting_conditions() -> void:
	var state: Node = RunStateScript.new()
	state.progress = 0.7
	state.elapsed = 42.0
	state.reset()
	var start_level: float = state.drunkenness.tuning.start_level
	expect_eq(state.guys.size(), 4, "four guys")
	for i: int in state.guys.size():
		var guy: RefCounted = state.guys[i]
		expect_eq(guy.seat, i, "seat %d" % i)
		expect(guy.aboard, "guy %d aboard" % i)
		expect_near(guy.stamina, RunStateScript.STAMINA_FULL, 0.0001, "guy %d stamina full" % i)
		expect_near(guy.drunkenness, start_level, 0.0001, "guy %d at DrinkTuning.start_level" % i)
		expect(guy.drunkenness > 0.0, "tipsy means above sober")
	expect_near(state.progress, 0.0, 0.0001, "progress at the shore")
	expect_near(state.elapsed, 0.0, 0.0001, "elapsed reset")
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "phase launch")
	state.free()


func test_reset_emits_run_reset() -> void:
	var state: Node = RunStateScript.new()
	var fired: Array[bool] = []
	state.run_reset.connect(func() -> void: fired.append(true))
	state.reset()
	expect_eq(fired.size(), 1, "run_reset emitted once")
	state.free()


func test_reset_replaces_guys_rather_than_adding() -> void:
	var state: Node = RunStateScript.new()
	state.reset()
	state.reset()
	expect_eq(state.guys.size(), 4, "still four guys after two resets")
	state.free()


func test_reset_restores_the_rule_classes_and_drops_pending_strokes() -> void:
	var state: Node = sober_state()
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	state.stamina.call_break(Paddling.Seat.RIGHT_BACK)
	state.reset()
	expect_near(state.stamina.level_of(Paddling.Seat.LEFT_FRONT), 1.0, 0.0001, "stamina back to full")
	expect_eq(state.stamina.state_of(Paddling.Seat.RIGHT_BACK), Stamina.State.PADDLING, "break cancelled")
	var motion: RefCounted = state.step(TICK, BOAT)
	expect_near(motion.thrust, 0.0, 0.0001, "the stroke released before the reset never lands")
	state.free()


func test_sober_stroke_lands_next_step_with_its_force_and_turn() -> void:
	var state: Node = sober_state()
	state.stroke(Paddling.Seat.LEFT_BACK, 10.0)
	var motion: RefCounted = state.step(TICK, BOAT)
	expect_near(motion.thrust, state.paddling.stroke_force(10.0), 0.0001, "a full hold gives the full force")
	expect(motion.turn > 0.0, "a left-side stroke turns right")
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * TICK, 0.0001, "the current pulls every step")
	var next: RefCounted = state.step(TICK, BOAT)
	expect_near(next.thrust, 0.0, 0.0001, "a stroke lands once")
	state.free()


func test_stroke_burns_the_target_guys_stamina_by_power() -> void:
	var state: Node = sober_state()
	state.stroke(Paddling.Seat.RIGHT_FRONT, 10.0)
	var cost: float = state.stamina.burn_of(state.paddling.stroke_force(10.0))
	expect(cost > 0.0, "a full stroke costs something")
	expect_near(state.guys[Paddling.Seat.RIGHT_FRONT].stamina, 1.0 - cost, 0.0001, "mirrored into the guy at once")
	expect_near(state.guys[Paddling.Seat.LEFT_FRONT].stamina, 1.0, 0.0001, "nobody else pays")
	state.free()


func test_stroke_is_ignored_on_a_break_or_overboard() -> void:
	var state: Node = sober_state()
	state.stamina.call_break(Paddling.Seat.LEFT_BACK)
	state.step(state.stamina.tuning.break_warning + 0.01, BOAT)
	expect_eq(state.stamina.state_of(Paddling.Seat.LEFT_BACK), Stamina.State.BREAK, "warning over, on a break")
	state.stroke(Paddling.Seat.LEFT_BACK, 10.0)
	state.guys[Paddling.Seat.RIGHT_BACK].aboard = false
	state.stroke(Paddling.Seat.RIGHT_BACK, 10.0)
	var motion: RefCounted = state.step(TICK, BOAT)
	expect_near(motion.thrust, 0.0, 0.0001, "neither stroke lands")
	expect_near(state.guys[Paddling.Seat.RIGHT_BACK].stamina, 1.0, 0.0001, "a swimmer burns nothing")
	state.free()


func test_drunk_stroke_lands_after_the_lag() -> void:
	var state: Node = drunk_state(0.5, 0.0, 0.5)
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	expect_near(state.step(0.2, BOAT).thrust, 0.0, 0.0001, "not yet at 0.2 s")
	expect_near(state.step(0.2, BOAT).thrust, 0.0, 0.0001, "not yet at 0.4 s")
	expect(state.step(0.2, BOAT).thrust > 0.0, "lands once 0.5 s have passed")
	state.free()


func test_missed_stroke_never_lands_but_still_costs_the_effort() -> void:
	var state: Node = drunk_state(0.0, 1.0, 0.5)
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	expect_near(state.step(TICK, BOAT).thrust, 0.0, 0.0001, "a sure miss gives no thrust")
	expect(state.guys[Paddling.Seat.LEFT_FRONT].stamina < 1.0, "he swung all the same")
	state.free()


## A RunState whose guys are sober except `seat`, who is on the timing bar with its wind-up
## over: bar_period 2 s and green_width 0.2, so a hold of 0.5 s is a hit and 1.0 s a miss.
func bar_state(seat: int) -> Node:
	var state: Node = drunk_state(0.0, 0.0, 0.0)
	state.drunkenness.tuning.bar_period = 2.0
	state.drunkenness.tuning.green_width = 0.2
	state.drunkenness.set_level(seat, state.drunkenness.tuning.bar_level)
	state.step(Drunkenness.BAR_WINDUP, BOAT)
	return state


func test_a_bar_hit_gives_the_normal_stroke_and_burns_its_stamina() -> void:
	var state: Node = bar_state(Paddling.Seat.LEFT_BACK)
	expect(state.drunkenness.uses_bar(Paddling.Seat.LEFT_BACK), "the bar applies after the wind-up")
	var before: float = state.guys[Paddling.Seat.LEFT_BACK].stamina
	state.stroke(Paddling.Seat.LEFT_BACK, 0.5)
	var cost: float = state.stamina.burn_of(state.paddling.stroke_force(0.5))
	expect(cost > 0.0, "the stroke costs something")
	expect_near(state.guys[Paddling.Seat.LEFT_BACK].stamina, before - cost, 0.0001, "a hit burns the stroke's stamina")
	var motion: RefCounted = state.step(TICK, BOAT)
	expect_near(motion.thrust, state.paddling.stroke_force(0.5), 0.0001, "a hit is the normal stroke")
	expect_near(motion.turn, state.paddling.stroke_turn(Paddling.Seat.LEFT_BACK, 0.5), 0.0001, "with its normal turn")
	expect(motion.turn > 0.0, "a left-side stroke turns right")
	state.free()


func test_a_bar_miss_is_a_backwards_stroke_of_the_same_power_and_still_burns() -> void:
	var state: Node = bar_state(Paddling.Seat.LEFT_BACK)
	var before: float = state.guys[Paddling.Seat.LEFT_BACK].stamina
	state.stroke(Paddling.Seat.LEFT_BACK, 1.0)
	var cost: float = state.stamina.burn_of(state.paddling.stroke_force(1.0))
	expect(cost > 0.0, "the stroke costs something")
	expect_near(state.guys[Paddling.Seat.LEFT_BACK].stamina, before - cost, 0.0001, "a miss burns the same stamina as a hit")
	expect_near(state.guys[Paddling.Seat.RIGHT_BACK].stamina, 1.0, 0.0001, "nobody else pays")
	var motion: RefCounted = state.step(TICK, BOAT)
	expect_near(motion.thrust, -state.paddling.stroke_force(1.0), 0.0001, "a miss paddles backwards at the same power")
	expect_near(motion.turn, -state.paddling.stroke_turn(Paddling.Seat.LEFT_BACK, 1.0), 0.0001, "and turns the other way as much")
	expect(motion.turn < 0.0, "a backwards left-side stroke turns left")
	state.free()


func test_strokes_are_plain_below_bar_level_and_during_the_wind_up() -> void:
	var state: Node = drunk_state(0.0, 0.0, 0.0)
	state.drunkenness.tuning.bar_period = 2.0
	state.drunkenness.tuning.green_width = 0.2
	state.stroke(Paddling.Seat.LEFT_FRONT, 1.0)
	expect(state.step(TICK, BOAT).thrust > 0.0, "below bar_level a would-be miss is a plain stroke")
	state.drunkenness.set_level(Paddling.Seat.LEFT_FRONT, state.drunkenness.tuning.bar_level)
	expect(state.drunkenness.bar_winding_up(Paddling.Seat.LEFT_FRONT), "crossing bar_level is announced first")
	state.stroke(Paddling.Seat.LEFT_FRONT, 1.0)
	expect(state.step(TICK, BOAT).thrust > 0.0, "during the wind-up the stroke is still plain")
	state.free()


func test_step_advances_time_and_mirrors_the_levels() -> void:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	state.step(1.0, BOAT)
	expect_near(state.elapsed, 1.0, 0.0001, "elapsed advances")
	for seat: int in state.guys.size():
		var guy: RefCounted = state.guys[seat]
		expect(guy.drunkenness > state.drunkenness.tuning.start_level, "guy %d drank" % seat)
		expect_near(guy.drunkenness, state.drunkenness.level_of(seat), 0.0001, "guy %d drunkenness mirrored" % seat)
		expect_near(guy.stamina, state.stamina.level_of(seat), 0.0001, "guy %d stamina mirrored" % seat)
	state.free()


func test_progress_is_clamped_and_leaving_the_shore_starts_the_crossing() -> void:
	var state: Node = sober_state()
	state.set_progress(-0.5)
	expect_near(state.progress, 0.0, 0.0001, "never below the shore")
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "still launching at the shore")
	state.set_progress(0.3)
	expect_near(state.progress, 0.3, 0.0001, "progress stored")
	expect_eq(state.phase, RunStateScript.Phase.CROSSING, "under way")
	state.set_progress(2.0)
	expect_near(state.progress, 1.0, 0.0001, "never past the island")
	state.free()


func test_arrive_wins_only_with_all_four_aboard() -> void:
	var state: Node = sober_state()
	state.set_progress(1.0)
	state.guys[Paddling.Seat.RIGHT_BACK].aboard = false
	state.arrive()
	expect_eq(state.phase, RunStateScript.Phase.CROSSING, "a swimmer left behind is no win")
	state.guys[Paddling.Seat.RIGHT_BACK].aboard = true
	state.arrive()
	expect_eq(state.phase, RunStateScript.Phase.WON, "all four at the island wins")
	state.free()


func test_a_won_attempt_stops_stepping_and_ignores_keys() -> void:
	var state: Node = sober_state()
	state.set_progress(1.0)
	state.arrive()
	var elapsed: float = state.elapsed
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	var motion: RefCounted = state.step(1.0, BOAT)
	expect_near(motion.thrust, 0.0, 0.0001, "no thrust after the win")
	expect_near(motion.drift_to_shore, 0.0, 0.0001, "no drift after the win")
	expect_near(state.elapsed, elapsed, 0.0001, "the clock stops")
	expect_near(state.guys[Paddling.Seat.LEFT_FRONT].stamina, 1.0, 0.0001, "keys do nothing")
	state.free()


func test_a_beer_overboard_takes_the_guy_off_the_boat_and_his_key_does_nothing() -> void:
	var state: Node = sober_state()
	var seat: int = jump_now(state, Rescue.Hull.RIGHT, BOAT)
	expect_eq(seat, Paddling.Seat.RIGHT_FRONT, "the right front guy jumped")
	expect_false(state.guys[seat].aboard, "he is no longer aboard")
	expect(state.rescue.is_in_water(seat), "Rescue has him")
	expect_eq(state.rescue.swimmer_of(seat).position, BOAT, "he went in at the boat")
	var toss: float = state.paddling.tuning.beer_toss
	expect_eq(state.rescue.swimmer_of(seat).beer_position, BOAT + Vector2(toss, 0.0), "the beer landed beer_toss to the right")
	state.stroke(seat, 10.0)
	var motion: RefCounted = state.step(TICK, BOAT)
	expect_near(motion.thrust, 0.0, 0.0001, "a stroke from his seat does nothing")
	expect_near(state.guys[seat].stamina, 1.0, 0.0001, "and costs nothing")
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * TICK, 0.0001, "the current still pulls")
	state.free()


func test_each_beer_puts_one_more_guy_in_until_nobody_is_aboard_and_the_boat_still_drifts() -> void:
	var state: Node = sober_state()
	for i: int in 4:
		expect_ne(jump_now(state, Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "beer %d puts one more guy in" % i)
	expect_eq(state.rescue.swimmers().size(), 4, "all four in the water")
	expect_false(state.all_aboard(), "nobody aboard")
	expect_eq(jump_now(state, Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "a fifth beer has nobody to jump")
	for seat: int in state.guys.size():
		state.stroke(seat, 10.0)
	var motion: RefCounted = state.step(TICK, BOAT)
	expect_near(motion.thrust, 0.0, 0.0001, "no key moves the boat")
	expect_near(motion.turn, 0.0, 0.0001, "or turns it")
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * state.paddling.tuning.empty_drift_multiplier * TICK, 0.0001, "the boat drifts home at current_speed times empty_drift_multiplier (T47)")
	state.free()


## T35 · Beers and swimmers drift at loose_drift_speed, the boat at current_speed: a floating
## swimmer moves by loose_drift_speed * delta per step while Motion.drift_to_shore is
## current_speed * delta (GDD › Systems › Catamaran and paddling).
func test_loose_things_drift_at_loose_drift_speed_and_the_boat_at_current_speed() -> void:
	var loaded: BoatTuning = load("res://data/boat_tuning.tres") as BoatTuning
	expect(loaded.loose_drift_speed > loaded.current_speed, "loose things drift faster than the boat")
	var state: Node = sober_state()
	state.paddling.tuning.beer_toss = 0.0
	var seat: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	state.step(0.0, BOAT)
	var swimmer: RefCounted = state.rescue.swimmer_of(seat)
	expect_eq(swimmer.state, Rescue.State.FLOATING, "he floats with his beer")
	var before: Vector2 = swimmer.position
	var delta: float = 0.5
	var motion: RefCounted = state.step(delta, BOAT)
	expect_near(swimmer.position.y - before.y, state.paddling.tuning.loose_drift_speed * delta, 0.0001, "the swimmer drifts at loose_drift_speed")
	expect_near(swimmer.position.x, before.x, 0.0001, "straight down-screen")
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * delta, 0.0001, "the boat drifts at current_speed")
	state.free()


func test_the_swimmers_and_their_beers_move_with_the_loose_drift_each_step() -> void:
	var state: Node = sober_state()
	var seat: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	state.step(1.0, BOAT)
	var swimmer: RefCounted = state.rescue.swimmer_of(seat)
	var loose: Vector2 = Vector2.DOWN * state.paddling.tuning.loose_drift_speed
	var toss: float = state.paddling.tuning.beer_toss
	expect_eq(swimmer.beer_position, BOAT + Vector2(-toss, 0.0) + loose, "the beer drifted down-screen at loose_drift_speed")
	expect(swimmer.position.y > BOAT.y, "the swimmer drifted too")
	expect(swimmer.position.x < BOAT.x, "and swam toward the beer")
	state.free()


func test_a_swimmer_drinks_only_while_he_has_a_beer() -> void:
	var state: Node = sober_state()
	var with_beer: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	state.guy_overboard(Paddling.Seat.RIGHT_BACK, BOAT)
	expect_false(state.guys[Paddling.Seat.RIGHT_BACK].aboard, "the beerless guy is off the boat too")
	state.step(1.0, BOAT)
	var rate: float = state.drunkenness.tuning.drink_rate
	var water: float = state.drunkenness.tuning.water_drink_multiplier
	expect_near(state.guys[with_beer].drunkenness, rate * water, 0.0001, "floating with his beer: the water rate")
	expect_near(state.guys[Paddling.Seat.RIGHT_BACK].drunkenness, 0.0, 0.0001, "no beer in the water: he doesn't drink")
	expect_near(state.guys[Paddling.Seat.RIGHT_FRONT].drunkenness, rate, 0.0001, "aboard and paddling: the plain rate")
	state.free()


func test_pickup_puts_him_back_aboard() -> void:
	var state: Node = sober_state()
	var seat: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	expect(state.pickup(seat), "he brought his beer back")
	expect(state.guys[seat].aboard, "aboard again")
	expect_false(state.rescue.is_in_water(seat), "out of the water")
	expect(state.all_aboard(), "all four aboard")
	state.stroke(seat, 10.0)
	expect(state.step(TICK, BOAT).thrust > 0.0, "his key paddles again")
	state.free()


## B1 regression: a drunk guy's stroke is still pending (lag 0.5 s) when his beer goes over, so
## it must not land from the water once the lag has run out.
func test_a_stroke_released_before_its_guy_goes_overboard_never_lands() -> void:
	var state: Node = drunk_state(0.5, 0.0, 0.5)
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	var seat: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy, who released the stroke, jumped")
	state.step(0.2, BOAT)
	state.step(0.2, BOAT)
	var motion: RefCounted = state.step(0.2, BOAT)
	expect_near(motion.thrust, 0.0, 0.0001, "past the 0.5 s lag the stroke from the water never lands")
	expect_near(motion.turn, 0.0, 0.0001, "and steers nothing")
	state.free()


func test_a_pending_stroke_of_a_guy_still_aboard_lands_when_another_goes_overboard() -> void:
	var state: Node = drunk_state(0.5, 0.0, 0.5)
	state.stroke(Paddling.Seat.RIGHT_BACK, 10.0)
	var seat: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy jumped, not the right back one")
	state.step(0.2, BOAT)
	state.step(0.2, BOAT)
	var motion: RefCounted = state.step(0.2, BOAT)
	expect(motion.thrust > 0.0, "the right back stroke still lands once its lag has passed")
	state.free()


func test_a_stroke_does_not_come_back_when_he_is_picked_up_before_the_lag_ends() -> void:
	var state: Node = drunk_state(0.5, 0.0, 0.5)
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	var seat: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	state.pickup(seat)
	expect(state.guys[seat].aboard, "back aboard")
	var motion: RefCounted = state.step(0.6, BOAT)
	expect_near(motion.thrust, 0.0, 0.0001, "the stroke he released in the water stays dropped")
	state.free()


func test_shore_touched_while_launching_does_nothing() -> void:
	var state: Node = sober_state()
	var fired: Array[bool] = []
	state.shore_reset_done.connect(func() -> void: fired.append(true))
	var seat: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	state.step(2.0, BOAT)
	state.shore_touched()
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "still launching")
	expect(state.rescue.is_in_water(seat), "the swimmer is still in the water")
	expect_false(state.guys[seat].aboard, "and still off the boat")
	expect_near(state.elapsed, 2.0, 0.0001, "the clock kept its time")
	expect_eq(fired.size(), 0, "no shore reset while the boat rests against the shore")
	state.free()


func test_shore_touched_while_crossing_resets_even_with_all_aboard() -> void:
	var state: Node = sober_state()
	var fired: Array[bool] = []
	state.shore_reset_done.connect(func() -> void: fired.append(true))
	state.set_progress(0.4)
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	state.step(5.0, BOAT)
	expect(state.all_aboard(), "everyone aboard")
	state.shore_touched()
	var start_level: float = state.drunkenness.tuning.start_level
	for seat: int in state.guys.size():
		expect_near(state.guys[seat].drunkenness, start_level, 0.0001, "guy %d mildly tipsy again" % seat)
		expect_near(state.guys[seat].stamina, RunStateScript.STAMINA_FULL, 0.0001, "guy %d stamina full" % seat)
	expect_near(state.progress, 0.0, 0.0001, "progress zero")
	expect_near(state.elapsed, 0.0, 0.0001, "elapsed reset")
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "phase launch")
	expect_eq(fired.size(), 1, "shore_reset_done emitted once")
	state.free()


func test_shore_touched_while_crossing_with_a_swimmer_restores_the_starting_conditions() -> void:
	var state: Node = sober_state()
	var fired: Array[bool] = []
	state.shore_reset_done.connect(func() -> void: fired.append(true))
	state.set_progress(0.4)
	jump_now(state, Rescue.Hull.LEFT, BOAT)
	jump_now(state, Rescue.Hull.RIGHT, BOAT)
	state.step(5.0, BOAT)
	state.shore_touched()
	var start_level: float = state.drunkenness.tuning.start_level
	for seat: int in state.guys.size():
		expect(state.guys[seat].aboard, "guy %d aboard" % seat)
		expect_near(state.guys[seat].drunkenness, start_level, 0.0001, "guy %d mildly tipsy again" % seat)
		expect_near(state.guys[seat].stamina, RunStateScript.STAMINA_FULL, 0.0001, "guy %d stamina full" % seat)
	expect_eq(state.rescue.swimmers().size(), 0, "nobody in the water")
	expect_near(state.progress, 0.0, 0.0001, "progress zero")
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "phase launch")
	expect_eq(fired.size(), 1, "shore_reset_done emitted once")
	state.free()


func test_a_guy_in_the_water_keeps_his_stamina_and_state_until_picked_up() -> void:
	var state: Node = sober_state()
	var warned: int = Paddling.Seat.LEFT_BACK
	var burnt: int = Paddling.Seat.RIGHT_BACK
	state.stamina.set_level(warned, 0.4)
	state.stamina.call_break(warned)
	state.stamina.set_level(burnt, 0.0)
	state.stamina.set_level(Paddling.Seat.LEFT_FRONT, 0.5)
	state.stamina.set_level(Paddling.Seat.RIGHT_FRONT, 0.5)
	state.guy_overboard(warned, BOAT)
	state.guy_overboard(burnt, BOAT)
	var warning_left: float = state.stamina.time_left(warned)
	for i: int in 5:
		state.step(1.0, BOAT)
	expect_near(state.stamina.level_of(warned), 0.4, 0.0001, "in the water: no recovery")
	expect_eq(state.stamina.state_of(warned), Stamina.State.WARNING, "still in his warning")
	expect_near(state.stamina.time_left(warned), warning_left, 0.0001, "the warning's time is frozen")
	expect_near(state.guys[warned].stamina, 0.4, 0.0001, "the guy mirrors the frozen level")
	expect_near(state.stamina.level_of(burnt), 0.0, 0.0001, "burnt out in the water: no break rolled")
	expect_eq(state.stamina.state_of(burnt), Stamina.State.PADDLING, "and no break called")
	expect(state.stamina.level_of(Paddling.Seat.LEFT_FRONT) > 0.5, "aboard guys still recover")
	state.pickup(warned)
	state.pickup(burnt)
	state.step(TICK, BOAT)
	expect(state.stamina.level_of(warned) > 0.4, "picked up: he recovers again")
	expect(state.stamina.time_left(warned) < warning_left, "and his warning counts down again")
	expect_eq(state.stamina.state_of(burnt), Stamina.State.WARNING, "picked up burnt out: his break is called now")
	state.free()


func test_a_guy_in_the_water_stays_on_his_break_until_picked_up() -> void:
	var state: Node = sober_state()
	var seat: int = Paddling.Seat.LEFT_BACK
	state.stamina.call_break(seat)
	state.step(state.stamina.tuning.break_warning + 0.01, BOAT)
	expect_eq(state.stamina.state_of(seat), Stamina.State.BREAK, "on a break")
	var level: float = state.stamina.level_of(seat)
	state.guy_overboard(seat, BOAT)
	var break_left: float = state.stamina.time_left(seat)
	state.step(5.0, BOAT)
	expect_eq(state.stamina.state_of(seat), Stamina.State.BREAK, "still on the break while in the water")
	expect_near(state.stamina.time_left(seat), break_left, 0.0001, "the break's time is frozen")
	expect_near(state.stamina.level_of(seat), level, 0.0001, "his stamina is frozen")
	state.pickup(seat)
	state.step(1.0, BOAT)
	expect_eq(state.stamina.state_of(seat), Stamina.State.BREAK, "the break carries on once he is back")
	expect(state.stamina.time_left(seat) < break_left, "and counts down again")
	state.step(2.5, BOAT)
	expect_eq(state.stamina.state_of(seat), Stamina.State.PADDLING, "the break ends after its time")
	state.free()


## B2 regression: F5 at the launch shore (boat centre y about -28, past the shoreline). The guy
## and his beer are held at the shoreline; once he has the beer he climbs back aboard by himself.
func test_a_washed_up_swimmer_climbs_back_aboard_while_launching() -> void:
	var state: Node = sober_state()
	var at_shore: Vector2 = Vector2(0.0, -28.0)
	var shoreline: float = -state.paddling.tuning.shore_margin
	var seat: int = jump_now(state, Rescue.Hull.LEFT, at_shore)
	state.step(TICK, at_shore)
	var swimmer: RefCounted = state.rescue.swimmer_of(seat)
	expect_near(swimmer.position.y, shoreline, 0.0001, "held at the shoreline, not under the shore")
	expect_false(state.guys[seat].aboard, "still swimming for his beer: not aboard yet")
	for i: int in 120:
		state.step(TICK, at_shore)
	expect(state.guys[seat].aboard, "with his beer at the shoreline he climbed back aboard")
	expect_false(state.rescue.is_in_water(seat), "out of the water")
	expect(state.all_aboard(), "all four aboard again")
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "still launching")
	expect_near(state.elapsed, TICK * 121.0, 0.0001, "no reset: the clock kept its time")
	state.drunkenness.set_level(seat, 0.0)
	state.stroke(seat, 10.0)
	expect(state.step(TICK, at_shore).thrust > 0.0, "his key paddles again")
	state.free()


## B2: under way, a guy the current carries to the shoreline stays in the water there until the
## boat comes for him or touches the shore.
func test_a_washed_up_swimmer_waits_at_the_shoreline_while_crossing() -> void:
	var state: Node = sober_state()
	var shoreline: float = -state.paddling.tuning.shore_margin
	state.set_progress(0.4)
	var seat: int = jump_now(state, Rescue.Hull.LEFT, BOAT)
	for i: int in 60:
		state.step(1.0, BOAT)
	var swimmer: RefCounted = state.rescue.swimmer_of(seat)
	expect(swimmer != null, "still in the water")
	expect_near(swimmer.position.y, shoreline, 0.0001, "lying at the shoreline")
	expect(swimmer.washed_up, "washed up")
	expect_false(state.guys[seat].aboard, "crossing: he doesn't climb aboard by himself")
	expect_eq(state.phase, RunStateScript.Phase.CROSSING, "still under way")
	state.shore_touched()
	expect(state.guys[seat].aboard, "the boat back at the shore is the shore reset: everyone aboard")
	expect_eq(state.rescue.swimmers().size(), 0, "nobody in the water")
	state.free()


## T34: during the wind-up the chosen guy is still aboard and his seat paddles; once jump_delay
## has passed he is off the boat, in the water where the boat is, and his key does nothing.
func test_a_guy_winding_up_still_paddles_until_he_jumps() -> void:
	var state: Node = sober_state()
	var seat: int = state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	expect_eq(seat, Paddling.Seat.RIGHT_FRONT, "the right front guy is chosen")
	expect(state.guys[seat].aboard, "still aboard")
	expect(state.rescue.winding_up(seat), "winding up")
	expect_false(state.rescue.is_in_water(seat), "not in the water")
	expect(state.can_paddle(seat), "his seat still paddles")
	expect_eq(state.rescue.loose_beers().size(), 1, "the beer is loose for the lake to draw")
	state.stroke(seat, 10.0)
	var motion: RefCounted = state.step(TICK, BOAT)
	expect(motion.thrust > 0.0, "a stroke from his seat lands during the wind-up")
	expect(state.guys[seat].stamina < 1.0, "and costs him stamina")
	expect(state.guys[seat].aboard, "a tick in: still aboard")
	var boat_later: Vector2 = BOAT + Vector2(0.0, -40.0)
	state.step(DELAY, boat_later)
	expect_false(state.guys[seat].aboard, "jump_delay over: he is off the boat")
	expect(state.rescue.is_in_water(seat), "in the water")
	expect_false(state.rescue.winding_up(seat), "no longer winding up")
	expect_eq(state.rescue.swimmer_of(seat).position, boat_later, "he jumped from where the boat is now")
	var stamina: float = state.guys[seat].stamina
	state.stroke(seat, 10.0)
	motion = state.step(TICK, boat_later)
	expect_near(motion.thrust, 0.0, 0.0001, "from the water a stroke does nothing")
	expect_near(state.guys[seat].stamina, stamina, 0.0001, "and costs nothing")
	state.free()


## T34: a stroke still waiting when the beer goes over lands if its lag ends during the wind-up;
## the strokes still waiting at the jump are dropped then (B1 at the jump, not at the beer).
func test_pending_strokes_land_during_the_wind_up_and_are_dropped_at_the_jump() -> void:
	var state: Node = drunk_state(0.5, 0.0, 0.5)
	state.paddling.tuning.jump_delay = 1.0
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	var seat: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the guy with the stroke waiting is the one winding up")
	expect(state.step(0.6, BOAT).thrust > 0.0, "0.6 s in: the stroke lands, he is still aboard")
	state.stroke(seat, 10.0)
	expect_near(state.step(0.2, BOAT).thrust, 0.0, 0.0001, "a second stroke, 0.3 s of wind-up left: still waiting")
	expect(state.guys[seat].aboard, "still aboard at 0.8 s")
	expect_near(state.step(0.3, BOAT).thrust, 0.0, 0.0001, "at the jump the waiting stroke is dropped")
	expect_false(state.guys[seat].aboard, "he jumped at 1.0 s")
	expect_near(state.step(0.3, BOAT).thrust, 0.0, 0.0001, "past its lag it never lands from the water")
	state.free()


## T34: a guy who falls in some other way during his wind-up is off the boat and swims for his
## beer anyway, as if he had jumped early; a shore reset drops every wind-up.
func test_falling_in_during_the_wind_up_is_an_early_jump_and_the_reset_drops_it() -> void:
	var state: Node = sober_state()
	var seat: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	var beer_at: Vector2 = state.rescue.beer_of(seat).position
	expect_eq(beer_at, BOAT + Vector2(-state.paddling.tuning.beer_toss, 0.0), "the beer landed to the left")
	state.guy_overboard(seat, BOAT)
	expect_false(state.guys[seat].aboard, "he is off the boat")
	expect_false(state.rescue.winding_up(seat), "the wind-up is over early")
	expect_eq(state.rescue.loose_beers().size(), 0, "the loose beer is his target now")
	var swimmer: Rescue.Swimmer = state.rescue.swimmer_of(seat)
	expect_eq(swimmer.state, Rescue.State.SWIMMING, "swimming")
	expect_eq(swimmer.beer_position, beer_at, "toward where the beer is")
	expect_false(state.can_paddle(seat), "his seat gives no strokes from the water")
	state.step(DELAY, BOAT)
	expect_eq(state.rescue.swimmers().size(), 1, "the delay passing adds nobody")
	expect_eq(swimmer.state, Rescue.State.FLOATING, "32 px at 30 px/s: he reached it")
	expect(swimmer.has_beer, "and has his beer")
	var other: int = state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	state.set_progress(0.4)
	state.shore_touched()
	expect_false(state.rescue.winding_up(other), "the shore reset drops the wind-up")
	expect_eq(state.rescue.loose_beers().size(), 0, "no beer loose")
	expect(state.all_aboard(), "everyone aboard")
	state.free()


## T25: a sober stroke fires stroke_landed with its seat when it lands, not when it is released;
## a guaranteed miss fires stroke_fumbled at the release and never lands.
func test_stroke_signals_landed_and_fumbled() -> void:
	var state: Node = sober_state()
	var landed: Array[int] = []
	var fumbled: Array[int] = []
	state.stroke_landed.connect(func(seat: int) -> void: landed.append(seat))
	state.stroke_fumbled.connect(func(seat: int) -> void: fumbled.append(seat))
	state.stroke(Paddling.Seat.RIGHT_BACK, 10.0)
	expect_eq(landed.size(), 0, "released, not landed yet")
	state.step(TICK, BOAT)
	expect_eq(landed, [Paddling.Seat.RIGHT_BACK] as Array[int], "stroke_landed once, with the seat")
	expect_eq(fumbled.size(), 0, "a sober stroke never fumbles")
	state.free()
	var drunk: Node = drunk_state(0.0, 1.0, 0.5)
	drunk.stroke_landed.connect(func(seat: int) -> void: landed.append(seat))
	drunk.stroke_fumbled.connect(func(seat: int) -> void: fumbled.append(seat))
	drunk.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	expect_eq(fumbled, [Paddling.Seat.LEFT_FRONT] as Array[int], "stroke_fumbled at the release, with the seat")
	drunk.step(TICK, BOAT)
	expect_eq(landed.size(), 1, "the miss never lands")
	drunk.free()


## T25: a beer over fires beer_overboard_started with its hull, the jump at the end of the
## wind-up fires guy_jumped with the seat, and the pickup fires guy_picked_up; a beer over with
## nobody free to jump is no beer over.
func test_rescue_signals_beer_jump_and_pickup() -> void:
	var state: Node = sober_state()
	var beers: Array[int] = []
	var jumped: Array[int] = []
	var picked: Array[int] = []
	state.beer_overboard_started.connect(func(hull: Rescue.Hull) -> void: beers.append(hull))
	state.guy_jumped.connect(func(seat: int) -> void: jumped.append(seat))
	state.guy_picked_up.connect(func(seat: int) -> void: picked.append(seat))
	var seat: int = state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	expect_eq(beers, [Rescue.Hull.RIGHT] as Array[int], "beer_overboard_started with the hull")
	expect_eq(jumped.size(), 0, "winding up: not jumped yet")
	state.step(DELAY, BOAT)
	expect_eq(jumped, [seat] as Array[int], "guy_jumped once the wind-up ends, with the seat")
	state.pickup(seat)
	expect_eq(picked, [seat] as Array[int], "guy_picked_up with the seat")
	for other: int in state.guys.size():
		state.guys[other].aboard = false
	state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	expect_eq(beers.size(), 1, "nobody aboard to jump: no beer went over, no signal")
	state.free()


## T13: a RunState whose guys are sober with no antic thresholds (nothing fires on its own), its
## own DrinkTuning (windup_time 1, pee_time 5, pee_fall_shove 100, stand_rock 60) shared by its
## Drunkenness and Antics, so a test starts an antic by hand.
func antic_state() -> Node:
	var tuning: DrinkTuning = DrinkTuning.new()
	tuning.start_level = 0.0
	tuning.drink_rate = 0.0
	tuning.lag_curve = Curves.ramp(0.0, 0.0)
	tuning.miss_curve = Curves.ramp(0.0, 0.0)
	tuning.antic_thresholds = []
	tuning.windup_time = 1.0
	tuning.stand_time = 3.0
	tuning.stand_rock = 60.0
	tuning.pee_time = 5.0
	tuning.pee_fall_shove = 100.0
	var state: Node = sober_state()
	state.drunkenness = Drunkenness.new(tuning)
	state.antics = Antics.new(tuning)
	state.reset()
	return state


## T13: while a guy pees his seat gives no strokes; a shove under pee_fall_shove leaves him at
## the edge, one of pee_fall_shove or more puts him in the water without a beer (he doesn't drink
## there) and ends the antic; the shove still reaches the boat.
func test_a_shove_of_pee_fall_shove_during_a_pee_puts_him_in_without_a_beer_and_ends_the_antic() -> void:
	var state: Node = antic_state()
	state.antics.start(0, Antics.Kind.PEE)
	expect(state.can_paddle(0), "he paddles through the wind-up")
	state.step(1.0, BOAT)
	expect_eq(state.antics.state_of(0), Antics.State.PEEING, "after windup_time he pees")
	expect_false(state.can_paddle(0), "his seat gives no strokes while he pees")
	state.stroke(0, 1.0)
	expect_near(state.guys[0].stamina, 1.0, 0.0001, "his key does nothing")
	expect(state.can_paddle(1), "the other seats still stroke")
	state.shove(Vector2(99.0, 0.0))
	expect(state.guys[0].aboard, "a shove under pee_fall_shove leaves him aboard")
	expect_eq(state.antics.state_of(0), Antics.State.PEEING, "still peeing")
	expect_eq(state.take_shove(), Vector2(99.0, 0.0), "the shove reaches the boat")
	# A drinking rate only from here on: until he is in, nothing drinks, so his level is 0.0 at the
	# knock-in and any rise after it is the water's doing. Without a rate the check below is vacuous.
	state.drunkenness.tuning.drink_rate = 0.1
	state.shove(Vector2(0.0, 100.0))
	expect_false(state.guys[0].aboard, "pee_fall_shove exactly puts him in")
	expect_eq(state.antics.state_of(0), Antics.State.IDLE, "and the antic is over")
	var swimmer: Rescue.Swimmer = state.rescue.swimmer_of(0)
	expect(swimmer != null, "he is a swimmer")
	expect_false(swimmer.has_beer, "without a beer")
	expect_eq(swimmer.state, Rescue.State.FLOATING, "floating from the start")
	expect_eq(state.rescue.loose_beers().size(), 0, "no beer went over with him")
	expect_eq(state.take_shove(), Vector2(0.0, 100.0), "that shove reaches the boat too")
	expect(state.guys[1].aboard, "the others are untouched")
	expect_false(state.can_paddle(0), "his seat gives no strokes from the water")
	state.step(1.0, BOAT)
	expect_near(state.guys[0].drunkenness, 0.0, 0.0001, "with no beer he doesn't drink in the water")
	expect(state.guys[1].drunkenness > 0.0, "while the paddler aboard drinks at the rate")
	expect_eq(state.antics.state_of(0), Antics.State.IDLE, "a swimmer runs no antics")
	state.shove(Vector2(0.0, 500.0))
	expect_eq(state.rescue.swimmers().size(), 1, "a shove on a swimmer does nothing more")
	state.free()


## T13: a standing guy's rock goes into the Motion's turn, swinging side to side; a dropped
## paddle, a nap and the shore reset go through can_paddle and reset.
func test_a_standing_guy_rocks_the_boat_through_the_motion_and_the_reset_clears_antics() -> void:
	var state: Node = antic_state()
	state.antics.start(0, Antics.Kind.STAND)
	state.step(1.0, BOAT)
	expect_eq(state.antics.state_of(0), Antics.State.STANDING, "standing")
	expect(state.can_paddle(0), "a standing guy still swings")
	var motion: Paddling.Motion = state.step(0.25, BOAT)
	expect_near(motion.turn, 15.0, 0.0001, "a quarter swing in, stand_rock times the step turns the boat right")
	motion = state.step(0.5, BOAT)
	expect_near(motion.turn, -30.0, 0.0001, "three quarters in, it turns left")
	state.antics.start(1, Antics.Kind.DROP_PADDLE)
	state.step(1.0, BOAT)
	expect_false(state.can_paddle(1), "a dropped paddle gives no strokes")
	state.set_progress(0.4)
	state.shore_touched()
	expect_eq(state.antics.state_of(0), Antics.State.IDLE, "the shore reset ends the stand")
	expect_eq(state.antics.state_of(1), Antics.State.IDLE, "and the fishing")
	expect(state.can_paddle(1), "his seat strokes again")
	expect_near(state.step(TICK, BOAT).turn, 0.0, 0.0001, "nobody rocks the boat")
	state.free()


## T46: after a beer goes over, beer_overboard() does nothing for beer_loss_cooldown seconds, while
## shove() and stop() still reach the boat; once the cooldown has run out a beer goes over again
## (GDD › Systems › Hazards: at most one beer every couple of seconds).
func test_after_a_beer_goes_over_no_beer_does_for_the_cooldown_but_shoves_and_stops_still_apply() -> void:
	var state: Node = sober_state()
	state.paddling.tuning.beer_loss_cooldown = COOLDOWN
	expect_ne(state.beer_overboard(Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "the first beer goes over")
	state.step(COOLDOWN * 0.5, BOAT)
	expect_eq(state.beer_overboard(Rescue.Hull.RIGHT, BOAT), Rescue.NOBODY, "a second beer inside the cooldown goes nowhere")
	expect_eq(state.rescue.loose_beers().size(), 1, "still one beer loose")
	state.shove(Vector2(50.0, 0.0))
	state.stop()
	expect_eq(state.take_shove(), Vector2(50.0, 0.0), "the shove still reaches the boat inside the cooldown")
	expect(state.take_stop(), "and so does the stop")
	state.step(COOLDOWN * 0.5, BOAT)
	expect_ne(state.beer_overboard(Rescue.Hull.RIGHT, BOAT), Rescue.NOBODY, "the cooldown has run out: a beer goes over again")
	expect_eq(state.rescue.loose_beers().size(), 2, "two beers loose")
	state.free()


## T46: the cooldown starts only when a beer actually goes over: with nobody free to jump, no beer
## goes over and the next one goes over at once.
func test_a_beer_that_goes_nowhere_starts_no_cooldown() -> void:
	var state: Node = sober_state()
	state.paddling.tuning.beer_loss_cooldown = COOLDOWN
	for seat: int in state.guys.size():
		state.guys[seat].aboard = false
	expect_eq(state.beer_overboard(Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "nobody aboard: no beer goes over")
	for seat: int in state.guys.size():
		state.guys[seat].aboard = true
	expect_ne(state.beer_overboard(Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "so the next beer goes over at once")
	state.free()


## T46: the cooldown resets with the attempt: a reset() (and a shore reset) lets a beer go over at once.
func test_the_cooldown_resets_with_the_attempt() -> void:
	var state: Node = sober_state()
	state.paddling.tuning.beer_loss_cooldown = COOLDOWN
	state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	expect_eq(state.beer_overboard(Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "blocked inside the cooldown")
	state.reset()
	expect_ne(state.beer_overboard(Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "a fresh attempt: a beer goes over at once")
	expect_eq(state.rescue.loose_beers().size(), 1, "one beer loose")
	state.set_progress(0.4)
	state.shore_touched()
	expect_ne(state.beer_overboard(Rescue.Hull.RIGHT, BOAT), Rescue.NOBODY, "and a shore reset does the same")
	state.free()


## T47: with nobody aboard the current's drift is current_speed times empty_drift_multiplier per
## second; a harsh-wind stretch's extra drift is added as it is (GDD › Systems › Setbacks).
func test_an_empty_boat_drifts_home_at_empty_drift_multiplier_times_the_current() -> void:
	var state: Node = sober_state()
	state.paddling.tuning.empty_drift_multiplier = EMPTY_MULTIPLIER
	state.set_progress(0.4)
	for seat: int in state.guys.size():
		state.guy_overboard(seat, BOAT)
	for seat: int in state.guys.size():
		expect_false(state.guys[seat].aboard, "guy %d overboard" % seat)
	var delta: float = 0.5
	var motion: Paddling.Motion = state.step(delta, BOAT)
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * EMPTY_MULTIPLIER * delta, 0.0001, "nobody aboard: current_speed times the multiplier per second")
	state.set_extra_drift(WIND)
	motion = state.step(delta, BOAT)
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * EMPTY_MULTIPLIER * delta + WIND * delta, 0.0001, "a harsh-wind stretch adds its drift unmultiplied")
	state.free()


## T47: with anyone aboard the boat drifts at current_speed, not multiplied.
func test_with_anyone_aboard_the_boat_drifts_at_current_speed() -> void:
	var state: Node = sober_state()
	state.paddling.tuning.empty_drift_multiplier = EMPTY_MULTIPLIER
	state.set_progress(0.4)
	for seat: int in range(1, state.guys.size()):
		state.guy_overboard(seat, BOAT)
	expect(state.guys[0].aboard, "one guy still aboard")
	var delta: float = 0.5
	var motion: Paddling.Motion = state.step(delta, BOAT)
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * delta, 0.0001, "one aboard: current_speed per second")
	state.free()
