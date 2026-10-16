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

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 60.0
const BOAT: Vector2 = Vector2(0.0, -300.0)


## A RunState whose guys are sober (no lag, no misses) and whose rolls are seeded.
func sober_state() -> Node:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	return state


## A RunState with a DrinkTuning of this flat lag, flat miss chance and start level.
func drunk_state(lag: float, miss: float, level: float) -> Node:
	var tuning: DrinkTuning = DrinkTuning.new()
	tuning.start_level = level
	tuning.lag_curve = DrinkTuning.ramp(lag, lag)
	tuning.miss_curve = DrinkTuning.ramp(miss, miss)
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.drunkenness = Drunkenness.new(tuning)
	state.reset()
	return state


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
	var motion: RefCounted = state.step(TICK)
	expect_near(motion.thrust, 0.0, 0.0001, "the stroke released before the reset never lands")
	state.free()


func test_sober_stroke_lands_next_step_with_its_force_and_turn() -> void:
	var state: Node = sober_state()
	state.stroke(Paddling.Seat.LEFT_BACK, 10.0)
	var motion: RefCounted = state.step(TICK)
	expect_near(motion.thrust, state.paddling.stroke_force(10.0), 0.0001, "a full hold gives the full force")
	expect(motion.turn > 0.0, "a left-side stroke turns right")
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * TICK, 0.0001, "the current pulls every step")
	var next: RefCounted = state.step(TICK)
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
	state.step(state.stamina.tuning.break_warning + 0.01)
	expect_eq(state.stamina.state_of(Paddling.Seat.LEFT_BACK), Stamina.State.BREAK, "warning over, on a break")
	state.stroke(Paddling.Seat.LEFT_BACK, 10.0)
	state.guys[Paddling.Seat.RIGHT_BACK].aboard = false
	state.stroke(Paddling.Seat.RIGHT_BACK, 10.0)
	var motion: RefCounted = state.step(TICK)
	expect_near(motion.thrust, 0.0, 0.0001, "neither stroke lands")
	expect_near(state.guys[Paddling.Seat.RIGHT_BACK].stamina, 1.0, 0.0001, "a swimmer burns nothing")
	state.free()


func test_drunk_stroke_lands_after_the_lag() -> void:
	var state: Node = drunk_state(0.5, 0.0, 0.5)
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	expect_near(state.step(0.2).thrust, 0.0, 0.0001, "not yet at 0.2 s")
	expect_near(state.step(0.2).thrust, 0.0, 0.0001, "not yet at 0.4 s")
	expect(state.step(0.2).thrust > 0.0, "lands once 0.5 s have passed")
	state.free()


func test_missed_stroke_never_lands_but_still_costs_the_effort() -> void:
	var state: Node = drunk_state(0.0, 1.0, 0.5)
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	expect_near(state.step(TICK).thrust, 0.0, 0.0001, "a sure miss gives no thrust")
	expect(state.guys[Paddling.Seat.LEFT_FRONT].stamina < 1.0, "he swung all the same")
	state.free()


## A RunState whose guys are sober except `seat`, who is on the timing bar with its wind-up
## over: bar_period 2 s and green_width 0.2, so a hold of 0.5 s is a hit and 1.0 s a miss.
func bar_state(seat: int) -> Node:
	var state: Node = drunk_state(0.0, 0.0, 0.0)
	state.drunkenness.tuning.bar_period = 2.0
	state.drunkenness.tuning.green_width = 0.2
	state.drunkenness.set_level(seat, state.drunkenness.tuning.bar_level)
	state.step(Drunkenness.BAR_WINDUP)
	return state


func test_a_bar_hit_gives_the_normal_stroke_and_burns_its_stamina() -> void:
	var state: Node = bar_state(Paddling.Seat.LEFT_BACK)
	expect(state.drunkenness.uses_bar(Paddling.Seat.LEFT_BACK), "the bar applies after the wind-up")
	var before: float = state.guys[Paddling.Seat.LEFT_BACK].stamina
	state.stroke(Paddling.Seat.LEFT_BACK, 0.5)
	var cost: float = state.stamina.burn_of(state.paddling.stroke_force(0.5))
	expect(cost > 0.0, "the stroke costs something")
	expect_near(state.guys[Paddling.Seat.LEFT_BACK].stamina, before - cost, 0.0001, "a hit burns the stroke's stamina")
	var motion: RefCounted = state.step(TICK)
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
	var motion: RefCounted = state.step(TICK)
	expect_near(motion.thrust, -state.paddling.stroke_force(1.0), 0.0001, "a miss paddles backwards at the same power")
	expect_near(motion.turn, -state.paddling.stroke_turn(Paddling.Seat.LEFT_BACK, 1.0), 0.0001, "and turns the other way as much")
	expect(motion.turn < 0.0, "a backwards left-side stroke turns left")
	state.free()


func test_strokes_are_plain_below_bar_level_and_during_the_wind_up() -> void:
	var state: Node = drunk_state(0.0, 0.0, 0.0)
	state.drunkenness.tuning.bar_period = 2.0
	state.drunkenness.tuning.green_width = 0.2
	state.stroke(Paddling.Seat.LEFT_FRONT, 1.0)
	expect(state.step(TICK).thrust > 0.0, "below bar_level a would-be miss is a plain stroke")
	state.drunkenness.set_level(Paddling.Seat.LEFT_FRONT, state.drunkenness.tuning.bar_level)
	expect(state.drunkenness.bar_winding_up(Paddling.Seat.LEFT_FRONT), "crossing bar_level is announced first")
	state.stroke(Paddling.Seat.LEFT_FRONT, 1.0)
	expect(state.step(TICK).thrust > 0.0, "during the wind-up the stroke is still plain")
	state.free()


func test_step_advances_time_and_mirrors_the_levels() -> void:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	state.step(1.0)
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
	var motion: RefCounted = state.step(1.0)
	expect_near(motion.thrust, 0.0, 0.0001, "no thrust after the win")
	expect_near(motion.drift_to_shore, 0.0, 0.0001, "no drift after the win")
	expect_near(state.elapsed, elapsed, 0.0001, "the clock stops")
	expect_near(state.guys[Paddling.Seat.LEFT_FRONT].stamina, 1.0, 0.0001, "keys do nothing")
	state.free()


func test_a_beer_overboard_takes_the_guy_off_the_boat_and_his_key_does_nothing() -> void:
	var state: Node = sober_state()
	var seat: int = state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	expect_eq(seat, Paddling.Seat.RIGHT_FRONT, "the right front guy jumped")
	expect_false(state.guys[seat].aboard, "he is no longer aboard")
	expect(state.rescue.is_in_water(seat), "Rescue has him")
	expect_eq(state.rescue.swimmer_of(seat).position, BOAT, "he went in at the boat")
	var toss: float = state.paddling.tuning.beer_toss
	expect_eq(state.rescue.swimmer_of(seat).beer_position, BOAT + Vector2(toss, 0.0), "the beer landed beer_toss to the right")
	state.stroke(seat, 10.0)
	var motion: RefCounted = state.step(TICK)
	expect_near(motion.thrust, 0.0, 0.0001, "a stroke from his seat does nothing")
	expect_near(state.guys[seat].stamina, 1.0, 0.0001, "and costs nothing")
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * TICK, 0.0001, "the current still pulls")
	state.free()


func test_each_beer_puts_one_more_guy_in_until_nobody_is_aboard_and_the_boat_still_drifts() -> void:
	var state: Node = sober_state()
	for i: int in 4:
		expect_ne(state.beer_overboard(Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "beer %d puts one more guy in" % i)
	expect_eq(state.rescue.swimmers().size(), 4, "all four in the water")
	expect_false(state.all_aboard(), "nobody aboard")
	expect_eq(state.beer_overboard(Rescue.Hull.LEFT, BOAT), Rescue.NOBODY, "a fifth beer has nobody to jump")
	for seat: int in state.guys.size():
		state.stroke(seat, 10.0)
	var motion: RefCounted = state.step(TICK)
	expect_near(motion.thrust, 0.0, 0.0001, "no key moves the boat")
	expect_near(motion.turn, 0.0, 0.0001, "or turns it")
	expect_near(motion.drift_to_shore, state.paddling.tuning.current_speed * TICK, 0.0001, "the boat drifts home at current_speed")
	state.free()


func test_the_swimmers_and_their_beers_move_with_the_current_each_step() -> void:
	var state: Node = sober_state()
	var seat: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	state.step(1.0)
	var swimmer: RefCounted = state.rescue.swimmer_of(seat)
	var current: Vector2 = Vector2.DOWN * state.paddling.tuning.current_speed
	var toss: float = state.paddling.tuning.beer_toss
	expect_eq(swimmer.beer_position, BOAT + Vector2(-toss, 0.0) + current, "the beer drifted down-screen at current_speed")
	expect(swimmer.position.y > BOAT.y, "the swimmer drifted too")
	expect(swimmer.position.x < BOAT.x, "and swam toward the beer")
	state.free()


func test_a_swimmer_drinks_only_while_he_has_a_beer() -> void:
	var state: Node = sober_state()
	var with_beer: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	state.guy_overboard(Paddling.Seat.RIGHT_BACK, BOAT)
	expect_false(state.guys[Paddling.Seat.RIGHT_BACK].aboard, "the beerless guy is off the boat too")
	state.step(1.0)
	var rate: float = state.drunkenness.tuning.drink_rate
	var water: float = state.drunkenness.tuning.water_drink_multiplier
	expect_near(state.guys[with_beer].drunkenness, rate * water, 0.0001, "floating with his beer: the water rate")
	expect_near(state.guys[Paddling.Seat.RIGHT_BACK].drunkenness, 0.0, 0.0001, "no beer in the water: he doesn't drink")
	expect_near(state.guys[Paddling.Seat.RIGHT_FRONT].drunkenness, rate, 0.0001, "aboard and paddling: the plain rate")
	state.free()


func test_pickup_puts_him_back_aboard() -> void:
	var state: Node = sober_state()
	var seat: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	expect(state.pickup(seat), "he brought his beer back")
	expect(state.guys[seat].aboard, "aboard again")
	expect_false(state.rescue.is_in_water(seat), "out of the water")
	expect(state.all_aboard(), "all four aboard")
	state.stroke(seat, 10.0)
	expect(state.step(TICK).thrust > 0.0, "his key paddles again")
	state.free()


func test_shore_touched_while_launching_does_nothing() -> void:
	var state: Node = sober_state()
	var fired: Array[bool] = []
	state.shore_reset_done.connect(func() -> void: fired.append(true))
	var seat: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	state.step(2.0)
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
	state.step(5.0)
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
	state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	state.step(5.0)
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
		state.step(1.0)
	expect_near(state.stamina.level_of(warned), 0.4, 0.0001, "in the water: no recovery")
	expect_eq(state.stamina.state_of(warned), Stamina.State.WARNING, "still in his warning")
	expect_near(state.stamina.time_left(warned), warning_left, 0.0001, "the warning's time is frozen")
	expect_near(state.guys[warned].stamina, 0.4, 0.0001, "the guy mirrors the frozen level")
	expect_near(state.stamina.level_of(burnt), 0.0, 0.0001, "burnt out in the water: no break rolled")
	expect_eq(state.stamina.state_of(burnt), Stamina.State.PADDLING, "and no break called")
	expect(state.stamina.level_of(Paddling.Seat.LEFT_FRONT) > 0.5, "aboard guys still recover")
	state.pickup(warned)
	state.pickup(burnt)
	state.step(TICK)
	expect(state.stamina.level_of(warned) > 0.4, "picked up: he recovers again")
	expect(state.stamina.time_left(warned) < warning_left, "and his warning counts down again")
	expect_eq(state.stamina.state_of(burnt), Stamina.State.WARNING, "picked up burnt out: his break is called now")
	state.free()


func test_a_guy_in_the_water_stays_on_his_break_until_picked_up() -> void:
	var state: Node = sober_state()
	var seat: int = Paddling.Seat.LEFT_BACK
	state.stamina.call_break(seat)
	state.step(state.stamina.tuning.break_warning + 0.01)
	expect_eq(state.stamina.state_of(seat), Stamina.State.BREAK, "on a break")
	var level: float = state.stamina.level_of(seat)
	state.guy_overboard(seat, BOAT)
	var break_left: float = state.stamina.time_left(seat)
	state.step(5.0)
	expect_eq(state.stamina.state_of(seat), Stamina.State.BREAK, "still on the break while in the water")
	expect_near(state.stamina.time_left(seat), break_left, 0.0001, "the break's time is frozen")
	expect_near(state.stamina.level_of(seat), level, 0.0001, "his stamina is frozen")
	state.pickup(seat)
	state.step(1.0)
	expect_eq(state.stamina.state_of(seat), Stamina.State.BREAK, "the break carries on once he is back")
	expect(state.stamina.time_left(seat) < break_left, "and counts down again")
	state.step(2.5)
	expect_eq(state.stamina.state_of(seat), Stamina.State.PADDLING, "the break ends after its time")
	state.free()
