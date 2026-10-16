extends "res://tools/test_case.gd"
## T3 · RunState.reset() restores the starting conditions (GDD › Core Loop › Starting conditions).
## T6 · RunState wires Paddling, Drunkenness and Stamina: stroke() and step() turn key releases
## into the boat's Motion; set_progress() and arrive() drive the phases (GDD › Win and Loss).

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 60.0


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


func test_scrambled_key_drives_the_seat_beside_him() -> void:
	var state: Node = drunk_state(0.0, 0.0, 0.0)
	state.drunkenness.set_level(Paddling.Seat.LEFT_BACK, state.drunkenness.tuning.scramble_level)
	state.stroke(Paddling.Seat.LEFT_BACK, 10.0)
	var motion: RefCounted = state.step(TICK)
	expect(motion.turn < 0.0, "his key paddled the right hull, so the boat turns left")
	expect(state.guys[Paddling.Seat.RIGHT_BACK].stamina < 1.0, "the right back guy did the work")
	expect_near(state.guys[Paddling.Seat.LEFT_BACK].stamina, 1.0, 0.0001, "the key owner burnt nothing")
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
