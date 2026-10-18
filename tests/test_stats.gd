extends "res://tools/test_case.gd"
## T86 · Stats counts every event RunState logs (strokes, beers, the water, antics, breaks, hazard
## effects, shore resets, drunkenness) and lists them as rows for the win title (GDD › Win and
## Loss). Every counter is driven through a RunState of its own, not the autoload.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 60.0
const BOAT: Vector2 = Vector2(0.0, -300.0)


## A RunState with its own DrinkTuning (no lag, a flat miss chance), sober guys, and a
## level_per_beer of 0.1.
func _state(miss: float = 0.0) -> Node:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	var tuning: DrinkTuning = (preload("res://data/drink_tuning.tres") as DrinkTuning).duplicate()
	tuning.lag_curve = Curves.ramp(0.0, 0.0)
	tuning.miss_curve = Curves.ramp(miss, miss)
	tuning.level_per_beer = 0.1
	state.drunkenness = Drunkenness.new(tuning)
	state.antics = Antics.new(tuning)
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	return state


func _step(state: Node, seconds: float) -> void:
	for i: int in ceili(seconds / TICK):
		state.step(TICK, BOAT)


func _row(rows: Array[Dictionary], label: String) -> String:
	for row: Dictionary in rows:
		if row["label"] == label:
			return row["value"]
	return "(missing)"


func test_strokes_landed_fumbled_and_reverse_are_counted() -> void:
	var state: Node = _state()
	state.stroke(0, 0.3)
	state.stroke(1, 0.3)
	state.stroke(2, 0.3, true)
	_step(state, 0.5)
	expect_eq(state.stats.strokes, 3, "three strokes landed")
	expect_eq(state.stats.reverse_strokes, 1, "one of them reverse")
	expect_eq(state.stats.fumbles, 0, "no fumbles")
	state.free()
	var clumsy: Node = _state(1.0)
	clumsy.stroke(0, 0.3)
	clumsy.stroke(1, 0.3, true)
	_step(clumsy, 0.5)
	expect_eq(clumsy.stats.fumbles, 2, "both strokes fumbled")
	expect_eq(clumsy.stats.strokes, 0, "a fumble is no landed stroke")
	expect_eq(clumsy.stats.reverse_strokes, 0, "nor a reverse one")
	clumsy.free()


func test_a_blocked_stroke_is_not_counted() -> void:
	var state: Node = _state()
	state.guy_overboard(0, BOAT)
	state.stroke(0, 0.3)
	_step(state, 0.5)
	expect_eq(state.stats.strokes, 0, "a guy in the water gives no stroke")
	expect_eq(state.stats.fumbles, 0)
	state.free()


func test_beers_overboard_jumps_and_a_rescue_with_the_beer_are_counted() -> void:
	var state: Node = _state()
	var seat: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	expect_eq(state.stats.beers_overboard, 1, "a beer went over")
	expect_eq(state.stats.jumps, 0, "he has not jumped yet")
	_step(state, state.paddling.tuning.jump_delay + 0.5)
	expect_eq(state.stats.jumps, 1, "he jumped after his beer")
	expect_eq(state.stats.times_in_water(), 1)
	state.pickup(seat)
	expect_eq(state.stats.pickups, 1, "picked up")
	expect_eq(state.stats.beers_rescued, 1, "with his beer")
	state.free()


func test_a_beer_held_back_by_the_cooldown_is_not_counted() -> void:
	var state: Node = _state()
	state.paddling.tuning = state.paddling.tuning.duplicate()
	state.paddling.tuning.beer_loss_cooldown = 5.0
	state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	expect_eq(state.stats.beers_overboard, 1, "the second was held back")
	state.free()


func test_a_fall_a_grab_and_a_pickup_without_a_beer_are_counted() -> void:
	var state: Node = _state()
	state.guy_overboard(0, BOAT, "pee")
	state.guy_overboard(0, BOAT, "pee")
	expect_eq(state.stats.falls, 1, "a second fall of a guy already in the water is none")
	var grabbed: int = state.beast_grab(Rescue.Hull.RIGHT, BOAT, 100.0)
	expect_ne(grabbed, Rescue.NOBODY)
	expect_eq(state.stats.grabs, 1, "the beast grabbed one")
	state.pickup(0)
	state.pickup(grabbed)
	expect_eq(state.stats.pickups, 2, "both back aboard")
	expect_eq(state.stats.beers_rescued, 0, "neither had a beer")
	expect_eq(state.stats.times_in_water(), 2, "jumps + falls + grabs")
	state.free()


func test_antics_are_counted_when_they_start_running() -> void:
	var state: Node = _state()
	var wind_up: float = state.antics.tuning.windup_time + 0.2
	state.debug_force_antic(0, Antics.Kind.STAND)
	_step(state, wind_up)
	expect_eq(state.stats.stand_ups, 1, "stand-up")
	state.debug_force_antic(1, Antics.Kind.DROP_PADDLE)
	_step(state, wind_up)
	expect_eq(state.stats.paddles_dropped, 1, "paddle dropped")
	state.debug_force_antic(2, Antics.Kind.NOD_OFF)
	_step(state, wind_up)
	expect_eq(state.stats.naps, 1, "nap")
	state.debug_force_antic(3, Antics.Kind.PEE)
	_step(state, wind_up)
	expect_eq(state.stats.pisses, 1, "piss")
	expect_eq(state.stats.pukes, 0, "no puke yet")
	state.free()


func test_a_puke_is_counted_when_it_finishes_and_not_as_an_antic() -> void:
	var state: Node = _state()
	state.debug_force_antic(0, Antics.Kind.PUKE)
	_step(state, state.antics.tuning.windup_time + 0.2)
	expect_eq(state.stats.pukes, 0, "still retching")
	_step(state, state.antics.tuning.puke_time + 0.5)
	expect_eq(state.stats.pukes, 1, "he puked")
	expect_eq(state.stats.pisses + state.stats.naps + state.stats.stand_ups + state.stats.paddles_dropped, 0)
	state.free()


func test_a_break_is_counted_when_it_begins_and_not_at_its_warning() -> void:
	var state: Node = _state()
	state.debug_force_break(0)
	_step(state, 0.2)
	expect_eq(state.stats.breaks, 0, "the warning is no break")
	_step(state, state.stamina.tuning.break_warning)
	expect_eq(state.stats.breaks, 1, "the break began")
	state.force_break(Rescue.Hull.RIGHT)
	_step(state, state.stamina.tuning.break_warning + 0.2)
	expect_eq(state.stats.breaks, 2, "a forced break counts too")
	state.free()


func test_hazard_hits_are_counted_by_effect() -> void:
	var state: Node = _state()
	state.shove(Vector2(30.0, 0.0))
	state.shove(Vector2(0.0, -30.0))
	state.stop()
	state.snag(Rescue.Hull.LEFT, 2.0)
	state.push(Vector2(40.0, 0.0))
	state.push(Vector2(40.0, 0.0))
	expect_eq(state.stats.shoves, 2, "two shoves")
	expect_eq(state.stats.stops, 1, "one stop")
	expect_eq(state.stats.snags, 1, "one snag")
	expect_eq(state.stats.pushes, 1, "a push counts once while it lasts")
	state.free()


func test_a_snag_that_finds_nobody_is_no_hit() -> void:
	var state: Node = _state()
	for seat: int in state.guys.size():
		state.guy_overboard(seat, BOAT)
	state.snag(Rescue.Hull.LEFT, 2.0)
	expect_eq(state.stats.snags, 0, "nobody was aboard to snag")
	state.free()


func test_water_aboard_adds_up_the_amounts() -> void:
	var state: Node = _state()
	state.water_aboard(Rescue.Hull.LEFT, 3.0)
	state.water_aboard(Rescue.Hull.RIGHT, 1.5)
	expect_near(state.stats.water, 4.5, 0.001, "the water put aboard")
	state.free()


func test_drunkenness_gained_and_the_drunkest_level_are_tracked_and_relief_is_not_counted() -> void:
	var state: Node = _state()
	state.drunkenness.tuning.drink_rate = 0.01
	_step(state, 5.0)
	# Four guys, 0.01 a second each, five seconds: 0.2.
	expect_near(state.stats.drunk_gained, 0.2, 0.002, "the sum of what the four drank")
	expect_eq(state.stats.beers_drunk(0.1), 2, "0.2 at 0.1 a beer is two beers")
	expect_near(state.stats.max_drunkenness, 0.05, 0.002, "the drunkest level so far")
	var gained: float = state.stats.drunk_gained
	state.drunkenness.relieve(0, 0.04)
	_step(state, TICK)
	expect(state.stats.drunk_gained - gained < 0.001, "relief takes nothing off what was gained")
	expect_near(state.stats.max_drunkenness, 0.05, 0.002, "the drunkest moment is kept")
	state.free()


func test_the_drunkest_level_follows_a_set_level_without_counting_it_as_drunk() -> void:
	var state: Node = _state()
	state.debug_set_drunkenness(2, 0.9)
	_step(state, TICK)
	expect(state.stats.max_drunkenness >= 0.9, "he reached 0.9")
	expect(state.stats.drunk_gained < 0.01, "a level set by hand is not a drink")
	state.free()


func test_beers_drunk_rounds_the_gain_over_level_per_beer() -> void:
	var stats: Stats = Stats.new()
	stats.add_drunk(0.2, 0.2)
	expect_eq(stats.beers_drunk(0.15), 1, "1.33 rounds down")
	stats.add_drunk(0.03, 0.2)
	expect_eq(stats.beers_drunk(0.15), 2, "1.53 rounds up")
	expect_eq(stats.beers_drunk(0.0), 0, "no beer size, no beers")
	stats.add_drunk(-0.5, 0.0)
	expect_near(stats.drunk_gained, 0.23, 0.0001, "a drop is never subtracted")


func test_rows_have_a_stable_order_and_keep_the_zero_rows() -> void:
	var stats: Stats = Stats.new()
	var labels: PackedStringArray = PackedStringArray()
	for row: Dictionary in stats.rows(0.0, 0.15):
		labels.append(row["label"])
		expect_eq(typeof(row["value"]), TYPE_STRING, "values are Strings")
	var again: PackedStringArray = PackedStringArray()
	stats.strokes = 5
	stats.grabs = 2
	for row: Dictionary in stats.rows(75.0, 0.15):
		again.append(row["label"])
	expect(labels == again, "the order does not depend on the counts")
	expect_eq(labels.size(), 24, "a row for every counter")
	expect_eq(labels[0], "Time", "time first")
	expect_eq(labels[1], "Shore resets")
	expect_eq(labels[labels.size() - 1], "Drunkest", "the drunkest moment last")
	var zero: Array[Dictionary] = Stats.new().rows(0.0, 0.15)
	expect_eq(_row(zero, "Pukes"), "0", "zero rows stay")
	expect_eq(_row(zero, "Water bailed"), "0.0")
	expect_eq(_row(zero, "Drunkest"), "0%")
	var full: Array[Dictionary] = stats.rows(75.0, 0.15)
	expect_eq(_row(full, "Time"), "1:15")
	expect_eq(_row(full, "Strokes"), "5")
	expect_eq(_row(full, "Beast grabs"), "2")
	expect_eq(_row(full, "Times in the water"), "2", "jumps + falls + grabs")


func test_rows_from_a_run_read_the_counters() -> void:
	var state: Node = _state()
	state.stroke(0, 0.3)
	state.water_aboard(Rescue.Hull.LEFT, 2.0)
	state.guy_overboard(1, BOAT)
	_step(state, 0.5)
	var rows: Array[Dictionary] = state.stats.rows(state.elapsed, state.drunkenness.tuning.level_per_beer)
	expect_eq(_row(rows, "Strokes"), "1")
	expect_eq(_row(rows, "Fell in"), "1")
	expect_eq(_row(rows, "Water bailed"), "2.0")
	state.free()


func test_a_new_attempt_starts_the_stats_over_and_a_shore_reset_keeps_them() -> void:
	var state: Node = _state()
	state.new_attempt()
	state.drunkenness.tuning.drink_rate = 0.01
	state.stroke(0, 0.3)
	state.shove(Vector2(10.0, 0.0))
	state.set_progress(0.4)
	_step(state, 2.0)
	state.shore_touched()
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "the shore reset happened")
	expect_eq(state.stats.shore_resets, 1, "the reset is counted")
	expect_eq(state.stats.strokes, 1, "and the stats are kept")
	expect_eq(state.stats.shoves, 1)
	expect(state.stats.drunk_gained > 0.0, "the drunkenness gained is kept")
	state.new_attempt()
	expect_eq(state.stats.shore_resets, 0, "a new attempt starts over")
	expect_eq(state.stats.strokes, 0)
	expect_eq(state.stats.shoves, 0)
	expect_near(state.stats.drunk_gained, 0.0, 0.0001)
	expect_near(state.stats.max_drunkenness, 0.0, 0.0001)
	state.free()


func test_the_level_per_beer_is_a_tunable_with_a_placeholder_default() -> void:
	var tuning: DrinkTuning = preload("res://data/drink_tuning.tres") as DrinkTuning
	expect(tuning.level_per_beer > 0.0, "a beer is worth some drunkenness")
