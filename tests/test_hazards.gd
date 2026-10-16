extends "res://tools/test_case.gd"
## T10 · Hazards: each band draws its hazards from the weighted list at density_curve's density,
## from one seed, so the same seed gives the same lake (GDD › Systems › Hazards, Placement); and
## the effects palette (beer overboard, shove, snag, stop, forced break, water aboard) exists as
## calls on RunState that the boat and the guys answer to (GDD › Systems › Hazards, Effects).
## Hazards are planned only between the launch margin and the island's near edge, and the seed
## is drawn per attempt (new_attempt), not per shore reset.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 60.0
const BOAT: Vector2 = Vector2(0.0, -300.0)
## The test lake: the island's centre 1000 px out with a radius of 100, a launch margin of 100,
## so 800 px of planned water in bands of 160, five bands, 1 hazard in the first band rising to
## 3 in the island band (densities 1, 2, 2, 3, 3), 400 px wide.
const DISTANCE: float = 1000.0
const RADIUS: float = 100.0
const MARGIN: float = 100.0
## Where the planned water ends: the island's near edge.
const FAR_EDGE: float = DISTANCE - RADIUS
const BAND: float = 160.0
const WIDTH: float = 400.0
const DENSITIES: Array[int] = [1, 2, 2, 3, 3]

var tuning: LakeTuning


func before_each() -> void:
	tuning = LakeTuning.new()
	tuning.island_distance = DISTANCE
	tuning.island_radius = RADIUS
	tuning.launch_margin = MARGIN
	tuning.band_length = BAND
	tuning.lake_width = WIDTH
	tuning.density_curve = DrinkTuning.ramp(1.0, 3.0)
	tuning.hazards = [spec(1.0, 0), spec(3.0, 2)]


func spec(weight: float, first_band: int) -> HazardSpec:
	var hazard: HazardSpec = HazardSpec.new()
	hazard.weight = weight
	hazard.first_band = first_band
	return hazard


## A RunState whose guys are sober (no lag, no misses) and whose rolls are seeded.
func sober_state() -> Node:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	return state


func count_in_band(placements: Array[Hazards.Placement], band: int) -> int:
	var count: int = 0
	for placement: Hazards.Placement in placements:
		if placement.band == band:
			count += 1
	return count


# --- placement ----------------------------------------------------------------------------------

func test_the_lake_is_the_planned_water_in_bands_rounded_up() -> void:
	expect_near(Hazards.span(tuning), 800.0, 0.0001, "launch margin to the island's near edge")
	expect_eq(Hazards.band_count(tuning), 5, "800 px of planned water in bands of 160")
	tuning.island_distance = 1001.0
	expect_eq(Hazards.band_count(tuning), 6, "a little more needs one more band")
	tuning.launch_margin = 101.0
	expect_eq(Hazards.band_count(tuning), 5, "a wider margin takes it back")
	tuning.band_length = 0.0
	expect_eq(Hazards.band_count(tuning), 0, "no band length, no bands")
	expect_eq(Hazards.plan(tuning, 1).size(), 0, "and nothing to place")
	tuning.band_length = BAND
	tuning.island_distance = RADIUS + tuning.launch_margin
	expect_eq(Hazards.band_count(tuning), 0, "no water between the margin and the island, no bands")
	tuning.island_distance = RADIUS
	expect_eq(Hazards.band_count(tuning), 0, "an island at the launch margin leaves nothing either")
	expect_eq(Hazards.plan(tuning, 1).size(), 0, "and nothing to place")


func test_the_same_seed_gives_the_same_lake_and_another_seed_a_different_one() -> void:
	var first: Array[Hazards.Placement] = Hazards.plan(tuning, 42)
	var again: Array[Hazards.Placement] = Hazards.plan(tuning, 42)
	expect(first.size() > 0, "the lake has hazards")
	expect_eq(again.size(), first.size(), "the same number of hazards")
	for i: int in first.size():
		expect_eq(again[i].spec, first[i].spec, "hazard %d is the same kind" % i)
		expect_eq(again[i].band, first[i].band, "hazard %d is in the same band" % i)
		expect_eq(again[i].position, first[i].position, "hazard %d is in the same place" % i)
	var other: Array[Hazards.Placement] = Hazards.plan(tuning, 43)
	var differs: bool = other.size() != first.size()
	for i: int in mini(other.size(), first.size()):
		if other[i].position != first[i].position:
			differs = true
	expect(differs, "another seed gives another lake")


func test_each_band_draws_its_density_and_density_rises_toward_the_island() -> void:
	var placements: Array[Hazards.Placement] = Hazards.plan(tuning, 5)
	for band: int in DENSITIES.size():
		expect_eq(Hazards.density(tuning, band), DENSITIES[band], "band %d samples the curve, rounded" % band)
		expect_eq(count_in_band(placements, band), DENSITIES[band], "band %d draws its density" % band)
	expect(count_in_band(placements, 4) > count_in_band(placements, 0), "the island band is denser than the shore band")
	expect_eq(placements.size(), 11, "the whole lake")


func test_every_hazard_lies_inside_its_band_between_the_launch_margin_and_the_island() -> void:
	var seen_first: bool = false
	var seen_last: bool = false
	for lake_seed: int in 20:
		for placement: Hazards.Placement in Hazards.plan(tuning, lake_seed):
			var near: float = -(MARGIN + placement.band * BAND)
			var far: float = -minf(MARGIN + (placement.band + 1) * BAND, FAR_EDGE)
			expect(placement.position.y <= near and placement.position.y >= far, "seed %d: in its band up-screen of the launch margin" % lake_seed)
			expect(placement.position.y <= -MARGIN, "seed %d: clear of the beach and the boat at launch" % lake_seed)
			expect(placement.position.y >= -FAR_EDGE, "seed %d: short of the island" % lake_seed)
			expect(absf(placement.position.x) <= WIDTH * 0.5, "seed %d: within the lake's width" % lake_seed)
			seen_first = seen_first or placement.band == 0
			seen_last = seen_last or placement.band == DENSITIES.size() - 1
	expect(seen_first and seen_last, "the first and the island band are both used")


func test_first_band_keeps_a_hazard_out_of_the_bands_before_it() -> void:
	var seen_late: bool = false
	for lake_seed: int in 50:
		for placement: Hazards.Placement in Hazards.plan(tuning, lake_seed):
			if placement.band < 2:
				expect_eq(placement.spec, 0, "seed %d: only the first kind before band 2" % lake_seed)
			elif placement.spec == 1:
				seen_late = true
	expect(seen_late, "from band 2 on the second kind is drawn")
	expect_eq(Hazards.allowed(tuning, 1), [0] as Array[int], "band 1 may draw the first kind only")
	expect_eq(Hazards.allowed(tuning, 2), [0, 1] as Array[int], "band 2 may draw both")
	tuning.hazards = [spec(1.0, 9)]
	expect_eq(Hazards.plan(tuning, 1).size(), 0, "a band nothing may be drawn in draws nothing")


func test_weights_set_the_share_of_the_draws_over_many_seeds() -> void:
	tuning.hazards = [spec(1.0, 0), spec(3.0, 0), spec(0.0, 0)]
	var heavy: int = 0
	var total: int = 0
	for lake_seed: int in 200:
		for placement: Hazards.Placement in Hazards.plan(tuning, lake_seed):
			expect_ne(placement.spec, 2, "a weight of zero is never drawn")
			total += 1
			if placement.spec == 1:
				heavy += 1
	var share: float = float(heavy) / float(total)
	expect(share > 0.68 and share < 0.82, "weight 3 against 1 draws about three in four (got %.2f)" % share)


# --- effects ------------------------------------------------------------------------------------

func test_a_beer_overboard_puts_the_hit_hulls_guy_in_the_water() -> void:
	var state: Node = sober_state()
	var seat: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy jumped")
	expect_false(state.guys[seat].aboard, "off the boat")
	expect(state.rescue.is_in_water(seat), "in the water after his beer")
	state.free()


func test_a_shove_is_handed_to_the_boat_once() -> void:
	var state: Node = sober_state()
	expect_eq(state.take_shove(), Vector2.ZERO, "nothing pending")
	state.shove(Vector2(10.0, 0.0))
	state.shove(Vector2(0.0, 5.0))
	expect_eq(state.take_shove(), Vector2(10.0, 5.0), "shoves in a frame add up")
	expect_eq(state.take_shove(), Vector2.ZERO, "taken once")
	state.shove(Vector2(10.0, 0.0))
	state.reset()
	expect_eq(state.take_shove(), Vector2.ZERO, "a reset drops it")
	state.free()


func test_a_stop_is_handed_to_the_boat_once() -> void:
	var state: Node = sober_state()
	expect_false(state.take_stop(), "nothing pending")
	state.stop()
	expect(state.take_stop(), "the boat stops")
	expect_false(state.take_stop(), "taken once")
	state.stop()
	state.reset()
	expect_false(state.take_stop(), "a reset drops it")
	state.free()


func test_a_snag_blocks_the_hulls_guy_for_its_time() -> void:
	var state: Node = sober_state()
	expect_eq(state.snag(Rescue.Hull.LEFT, 2.0), Paddling.Seat.LEFT_FRONT, "the front guy on that hull is snagged")
	expect(state.is_snagged(Paddling.Seat.LEFT_FRONT), "snagged")
	expect_near(state.snag_left(Paddling.Seat.LEFT_FRONT), 2.0, 0.0001, "for two seconds")
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	var motion: RefCounted = state.step(TICK)
	expect_near(motion.thrust, 0.0, 0.0001, "his stroke does nothing")
	expect_near(state.guys[Paddling.Seat.LEFT_FRONT].stamina, 1.0, 0.0001, "and costs nothing, like a break")
	state.stroke(Paddling.Seat.LEFT_BACK, 10.0)
	expect(state.step(TICK).thrust > 0.0, "the other guy on the hull still paddles")
	state.snag(Rescue.Hull.LEFT, 0.5)
	expect(state.snag_left(Paddling.Seat.LEFT_FRONT) > 1.5, "snagged again, he keeps the longer time")
	state.step(2.0)
	expect_false(state.is_snagged(Paddling.Seat.LEFT_FRONT), "free once the time has run out")
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	expect(state.step(TICK).thrust > 0.0, "and paddling again")
	state.free()


func test_a_snag_takes_the_back_guy_when_the_front_one_is_in_the_water_and_nobody_on_an_empty_hull() -> void:
	var state: Node = sober_state()
	state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	expect_eq(state.snag(Rescue.Hull.RIGHT, 1.0), Paddling.Seat.RIGHT_BACK, "the back guy is the one left on that hull")
	state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	expect_eq(state.snag(Rescue.Hull.RIGHT, 1.0), Rescue.NOBODY, "an empty hull has no paddle to snag")
	expect_eq(state.force_break(Rescue.Hull.RIGHT), Rescue.NOBODY, "and nobody to break")
	state.free()


func test_a_forced_break_starts_the_hit_guys_warning_then_his_break() -> void:
	var state: Node = sober_state()
	expect_eq(state.force_break(Rescue.Hull.RIGHT), Paddling.Seat.RIGHT_FRONT, "the right front guy is hit")
	expect_eq(state.stamina.state_of(Paddling.Seat.RIGHT_FRONT), Stamina.State.WARNING, "his break is telegraphed at once")
	state.step(state.stamina.tuning.break_warning + 0.01)
	expect_eq(state.stamina.state_of(Paddling.Seat.RIGHT_FRONT), Stamina.State.BREAK, "then he is on his break")
	state.stroke(Paddling.Seat.RIGHT_FRONT, 10.0)
	expect_near(state.step(TICK).thrust, 0.0, 0.0001, "and gives no strokes")
	expect_eq(state.stamina.state_of(Paddling.Seat.LEFT_FRONT), Stamina.State.PADDLING, "nobody else is")
	state.free()


func test_water_aboard_keeps_the_hulls_guy_bailing_until_it_is_out() -> void:
	var state: Node = sober_state()
	var boat_tuning: BoatTuning = BoatTuning.new()
	boat_tuning.bail_rate = 2.0
	state.paddling = Paddling.new(boat_tuning)
	state.water_aboard(Rescue.Hull.RIGHT, 3.0)
	expect_near(state.water_of(Rescue.Hull.RIGHT), 3.0, 0.0001, "three units of water came in")
	expect_eq(state.bailer_of(Rescue.Hull.RIGHT), Paddling.Seat.RIGHT_FRONT, "the right front guy bails")
	expect(state.is_bailing(Paddling.Seat.RIGHT_FRONT), "bailing")
	expect_false(state.is_bailing(Paddling.Seat.RIGHT_BACK), "the other guy on the hull is not")
	state.stroke(Paddling.Seat.RIGHT_FRONT, 10.0)
	expect_near(state.step(TICK).thrust, 0.0, 0.0001, "a bailing guy gives no strokes")
	state.stroke(Paddling.Seat.RIGHT_BACK, 10.0)
	expect(state.step(TICK).thrust > 0.0, "the other one still paddles")
	state.step(1.0)
	expect_near(state.water_of(Rescue.Hull.RIGHT), 3.0 - 2.0 * (1.0 + 2.0 * TICK), 0.0001, "bailed at bail_rate per second")
	state.step(1.0)
	expect_near(state.water_of(Rescue.Hull.RIGHT), 0.0, 0.0001, "the water is out")
	expect_eq(state.bailer_of(Rescue.Hull.RIGHT), Rescue.NOBODY, "nobody bails any more")
	state.stroke(Paddling.Seat.RIGHT_FRONT, 10.0)
	expect(state.step(TICK).thrust > 0.0, "he paddles again")
	state.free()


func test_water_on_an_empty_hull_waits_for_a_guy() -> void:
	var state: Node = sober_state()
	state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	var back: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	expect_eq(back, Paddling.Seat.LEFT_BACK, "both left guys are in the water")
	state.water_aboard(Rescue.Hull.LEFT, 1.0)
	expect_eq(state.bailer_of(Rescue.Hull.LEFT), Rescue.NOBODY, "nobody on that hull to bail")
	state.step(5.0)
	expect_near(state.water_of(Rescue.Hull.LEFT), 1.0, 0.0001, "the water stays")
	state.pickup(back)
	expect_eq(state.bailer_of(Rescue.Hull.LEFT), back, "picked up, he bails")
	state.free()


func test_reset_clears_the_effects_and_keeps_the_lake_seed() -> void:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.new_attempt()
	var first_seed: int = state.lake_seed
	state.snag(Rescue.Hull.LEFT, 5.0)
	state.water_aboard(Rescue.Hull.LEFT, 5.0)
	state.reset()
	expect_false(state.is_snagged(Paddling.Seat.LEFT_FRONT), "no snag after a reset")
	expect_near(state.water_of(Rescue.Hull.LEFT), 0.0, 0.0001, "no water after a reset")
	expect_eq(state.lake_seed, first_seed, "a reset alone keeps the lake")
	state.free()


func test_a_shore_reset_keeps_the_lake_seed_and_a_new_attempt_draws_another() -> void:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.new_attempt()
	var first_seed: int = state.lake_seed
	var fired: Array[bool] = []
	state.shore_reset_done.connect(func() -> void: fired.append(true))
	state.set_progress(0.4)
	state.shore_touched()
	expect_eq(fired.size(), 1, "the boat under way touched the shore: a shore reset")
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "back at the shore")
	expect_eq(state.lake_seed, first_seed, "the same lake again after a shore reset")
	state.new_attempt()
	expect_ne(state.lake_seed, first_seed, "a new attempt gets another lake")
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "and starts at the shore")
	state.rng.seed = 7
	state.new_attempt()
	expect_eq(state.lake_seed, first_seed, "the same RNG seed gives the same lake again")
	state.free()
