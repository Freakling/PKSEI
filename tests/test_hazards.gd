extends "res://tools/test_case.gd"
## T10 · Hazards: each band draws its hazards from the weighted list at density_curve's density,
## from one seed, so the same seed gives the same lake (GDD › Systems › Hazards, Placement); and
## the effects palette (beer overboard, shove, snag, stop, forced break, water aboard) exists as
## calls on RunState that the boat and the guys answer to (GDD › Systems › Hazards, Effects).
## Hazards are planned only between the launch margin and the island's near edge, and the seed
## is drawn per attempt (new_attempt), not per shore reset. T33: each band is planned on its own
## from (seed, band, generation) (plan() is generation 0 band by band), and each band's draw stays
## inside its band. T36: hazards are objects, so a planned log stays where the plan put it.
## T37: a guaranteed path winds through every band: a corridor path_width wide no object is placed
## in, whose centre wanders by at most path_wander between bands, stays inside the lake, and runs
## continuously from the launch (x = 0) to the island (x = 0), the same for the same seed.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const LogScene: PackedScene = preload("res://scenes/hazards/log.tscn")
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
## The path: a corridor 80 px wide whose centre moves by at most 100 px between bands, so it can
## sit anywhere within 160 px of the middle with the whole corridor inside the 400 px of water.
const PATH_WIDTH: float = 80.0
const WANDER: float = 100.0
const REACH: float = WIDTH * 0.5 - PATH_WIDTH * 0.5

var tuning: LakeTuning


func before_each() -> void:
	tuning = LakeTuning.new()
	tuning.island_distance = DISTANCE
	tuning.island_radius = RADIUS
	tuning.launch_margin = MARGIN
	tuning.band_length = BAND
	tuning.lake_width = WIDTH
	tuning.density_curve = DrinkTuning.ramp(1.0, 3.0)
	tuning.path_width = PATH_WIDTH
	tuning.path_wander = WANDER
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


func same_placements(a: Array[Hazards.Placement], b: Array[Hazards.Placement], what: String) -> void:
	expect_eq(b.size(), a.size(), "%s: the same number of hazards" % what)
	for i: int in mini(a.size(), b.size()):
		expect_eq(b[i].spec, a[i].spec, "%s: hazard %d is the same kind" % [what, i])
		expect_eq(b[i].band, a[i].band, "%s: hazard %d is in the same band" % [what, i])
		expect_eq(b[i].position, a[i].position, "%s: hazard %d is in the same place" % [what, i])


func test_a_band_plans_the_same_for_the_same_seed_band_and_generation() -> void:
	for generation: int in 3:
		var first: Array[Hazards.Placement] = Hazards.plan_band(tuning, 42, 1, generation)
		expect_eq(first.size(), DENSITIES[1], "generation %d of band 1 draws its density" % generation)
		same_placements(first, Hazards.plan_band(tuning, 42, 1, generation), "generation %d again" % generation)
	expect_eq(Hazards.band_seed(42, 1, 2), Hazards.band_seed(42, 1, 2), "the band's seed is a function of the three")
	expect_ne(Hazards.band_seed(42, 1, 2), Hazards.band_seed(43, 1, 2), "another lake seed, another band seed")
	expect_ne(Hazards.band_seed(42, 1, 2), Hazards.band_seed(42, 2, 2), "another band, another band seed")
	expect_ne(Hazards.band_seed(42, 1, 2), Hazards.band_seed(42, 1, 3), "another generation, another band seed")


func test_the_lake_as_launched_is_each_bands_generation_zero_band_by_band() -> void:
	var whole: Array[Hazards.Placement] = Hazards.plan(tuning, 42)
	var by_band: Array[Hazards.Placement] = []
	for band: int in Hazards.band_count(tuning):
		by_band.append_array(Hazards.plan_band(tuning, 42, band, 0))
	expect_eq(whole.size(), 11, "the whole lake")
	same_placements(whole, by_band, "band by band")
	var other_band: Array[Hazards.Placement] = Hazards.plan_band(tuning, 42, 2, 0)
	expect_ne(other_band[0].position, by_band[1].position, "each band has its own draw, not a shared stream")


func test_a_band_at_any_generation_stays_inside_its_band_and_draws_what_the_band_allows() -> void:
	for lake_seed: int in 10:
		for band: int in DENSITIES.size():
			for generation: int in 4:
				var placements: Array[Hazards.Placement] = Hazards.plan_band(tuning, lake_seed, band, generation)
				expect_eq(placements.size(), DENSITIES[band], "seed %d band %d generation %d: the band's density" % [lake_seed, band, generation])
				var near: float = -Hazards.near_edge(tuning, band)
				var far: float = -minf(MARGIN + (band + 1) * BAND, FAR_EDGE)
				for placement: Hazards.Placement in placements:
					expect_eq(placement.band, band, "seed %d: placed in the band asked for" % lake_seed)
					expect(placement.position.y <= near and placement.position.y >= far, "seed %d band %d generation %d: inside the band" % [lake_seed, band, generation])
					expect(absf(placement.position.x) <= WIDTH * 0.5, "seed %d: within the lake's width" % lake_seed)
					expect(Hazards.allowed(tuning, band).has(placement.spec), "seed %d band %d: a kind the band allows" % [lake_seed, band])
	expect_near(Hazards.near_edge(tuning, 0), MARGIN, 0.0001, "the first band starts at the launch margin")
	expect_near(Hazards.near_edge(tuning, 3), MARGIN + 3.0 * BAND, 0.0001, "three bands further for band 3")
	expect_eq(Hazards.plan_band(tuning, 1, 5, 0).size(), 0, "a band past the island plans nothing")
	expect_eq(Hazards.plan_band(tuning, 1, -1, 0).size(), 0, "nor one before the shore")
	expect_eq(Hazards.plan_band(tuning, 1, 0, 7).size(), DENSITIES[0], "the first band at generation 7 draws its density too")


# --- the path -----------------------------------------------------------------------------------

func test_no_object_is_placed_inside_the_corridor() -> void:
	var total: int = 0
	for lake_seed: int in 100:
		for placement: Hazards.Placement in Hazards.plan(tuning, lake_seed):
			var gap: float = absf(placement.position.x - Hazards.corridor_x(tuning, lake_seed, placement.position.y))
			expect(gap >= PATH_WIDTH * 0.5, "seed %d: clear of the corridor at its y (gap %.1f)" % [lake_seed, gap])
			expect(absf(placement.position.x) <= WIDTH * 0.5, "seed %d: still within the lake's width" % lake_seed)
			total += 1
	expect_eq(total, 100 * 11, "every band still draws its density")
	for lake_seed: int in 10:
		for band: int in DENSITIES.size():
			for generation: int in 3:
				for placement: Hazards.Placement in Hazards.plan_band(tuning, lake_seed, band, generation):
					var gap: float = absf(placement.position.x - Hazards.corridor_x(tuning, lake_seed, placement.position.y))
					expect(gap >= PATH_WIDTH * 0.5, "seed %d band %d generation %d: a re-plan stays clear of the corridor too" % [lake_seed, band, generation])


func test_objects_land_on_both_sides_of_the_corridor_and_right_up_to_it() -> void:
	var left: int = 0
	var right: int = 0
	var closest: float = WIDTH
	for lake_seed: int in 100:
		for placement: Hazards.Placement in Hazards.plan(tuning, lake_seed):
			var offset: float = placement.position.x - Hazards.corridor_x(tuning, lake_seed, placement.position.y)
			closest = minf(closest, absf(offset))
			if offset < 0.0:
				left += 1
			else:
				right += 1
	expect(left > 300 and right > 300, "objects fall on either side of the path (%d left, %d right)" % [left, right])
	expect(closest < PATH_WIDTH * 0.5 + 5.0, "and some sit right at its edge (closest %.1f)" % closest)


func test_a_band_the_corridor_fills_places_nothing() -> void:
	tuning.path_width = WIDTH
	expect_near(Hazards.open_width(tuning), 0.0, 0.0001, "no water outside a corridor as wide as the lake")
	expect_eq(Hazards.plan(tuning, 42).size(), 0, "nothing is placed in it")
	tuning.path_width = WIDTH + 50.0
	expect_eq(Hazards.plan(tuning, 42).size(), 0, "nor in a wider one")
	expect_near(Hazards.corridor_x(tuning, 42, -500.0), 0.0, 0.0001, "whose centre can only be the middle")
	tuning.path_width = WIDTH - 2.0
	expect_eq(Hazards.plan(tuning, 42).size(), 11, "a sliver of open water on each side is enough to place in")
	for placement: Hazards.Placement in Hazards.plan(tuning, 42):
		expect(absf(placement.position.x) >= WIDTH * 0.5 - 2.0, "placed in the sliver")


func test_the_paths_centre_moves_by_at_most_path_wander_and_stays_inside_the_lake() -> void:
	var wandered: bool = false
	var reached_far: bool = false
	for lake_seed: int in 100:
		var centers: PackedFloat64Array = Hazards.path_centers(tuning, lake_seed)
		expect_eq(centers.size(), DENSITIES.size() + 1, "seed %d: a centre at every band's near edge and one at the island" % lake_seed)
		expect_near(centers[0], 0.0, 0.0001, "seed %d: the path starts at the launch, x = 0" % lake_seed)
		expect_near(centers[centers.size() - 1], 0.0, 0.0001, "seed %d: and ends on the island, x = 0" % lake_seed)
		for band: int in centers.size():
			expect_near(Hazards.path_center(tuning, lake_seed, band), centers[band], 0.0001, "seed %d band %d: path_center reads the same" % [lake_seed, band])
			expect(absf(centers[band]) <= REACH + 0.0001, "seed %d band %d: the whole corridor inside the lake (centre %.1f)" % [lake_seed, band, centers[band]])
			if band > 0:
				var step: float = absf(centers[band] - centers[band - 1])
				expect(step <= WANDER + 0.0001, "seed %d band %d: a step of at most path_wander (got %.1f)" % [lake_seed, band, step])
			wandered = wandered or absf(centers[band]) > 1.0
			reached_far = reached_far or absf(centers[band]) > REACH - 1.0
	expect(wandered, "the path does wander")
	expect(reached_far, "and over many seeds goes as far as the corridor's width allows")
	expect_near(Hazards.path_center(tuning, 1, -1), 0.0, 0.0001, "no band before the shore")
	expect_near(Hazards.path_center(tuning, 1, 9), 0.0, 0.0001, "no band past the island")


func test_the_path_never_shares_a_bands_rng_with_its_objects() -> void:
	expect(Hazards.PATH_GENERATION < 0, "the path's generation is none an object ever has")
	for band: int in DENSITIES.size():
		for generation: int in 4:
			expect_ne(Hazards.band_seed(42, band, Hazards.PATH_GENERATION), Hazards.band_seed(42, band, generation), "band %d: the path's seed is not generation %d's" % [band, generation])


func test_the_corridor_is_continuous_from_the_launch_to_the_island() -> void:
	var step: float = 1.0
	## The corridor moves at most path_wander over one band, so at most this much per pixel.
	var slope: float = WANDER / BAND
	for lake_seed: int in 20:
		expect_near(Hazards.corridor_x(tuning, lake_seed, 0.0), 0.0, 0.0001, "seed %d: at the shore line the path is at x = 0" % lake_seed)
		expect_near(Hazards.corridor_x(tuning, lake_seed, -MARGIN), 0.0, 0.0001, "seed %d: and still at the launch margin" % lake_seed)
		expect_near(Hazards.corridor_x(tuning, lake_seed, -FAR_EDGE), 0.0, 0.0001, "seed %d: on the island's near edge, x = 0" % lake_seed)
		expect_near(Hazards.corridor_x(tuning, lake_seed, -DISTANCE), 0.0, 0.0001, "seed %d: and at the island's centre" % lake_seed)
		for band: int in DENSITIES.size():
			var at_edge: float = Hazards.corridor_x(tuning, lake_seed, -Hazards.near_edge(tuning, band))
			expect_near(at_edge, Hazards.path_center(tuning, lake_seed, band), 0.0001, "seed %d band %d: the band's centre at its near edge" % [lake_seed, band])
		var previous: float = Hazards.corridor_x(tuning, lake_seed, 0.0)
		var y: float = -step
		while y >= -DISTANCE:
			var x: float = Hazards.corridor_x(tuning, lake_seed, y)
			expect(absf(x - previous) <= slope * step + 0.0001, "seed %d y %.0f: a small step down the lake moves the path a little (%.2f)" % [lake_seed, y, x - previous])
			expect(absf(x) <= REACH + 0.0001, "seed %d y %.0f: the corridor stays inside the lake" % [lake_seed, y])
			previous = x
			y -= step


func test_the_same_seed_gives_the_same_path_and_another_seed_another() -> void:
	var first: PackedFloat64Array = Hazards.path_centers(tuning, 42)
	expect_eq(Hazards.path_centers(tuning, 42), first, "the same centres again")
	for y: int in range(0, int(DISTANCE), 7):
		expect_near(Hazards.corridor_x(tuning, 42, -y), Hazards.corridor_x(tuning, 42, -y), 0.0001, "the same corridor at y = %d" % y)
	expect_ne(Hazards.path_centers(tuning, 43), first, "another seed, another path")


func test_no_wander_is_a_straight_path_up_the_middle() -> void:
	tuning.path_wander = 0.0
	for lake_seed: int in 20:
		for band: int in DENSITIES.size() + 1:
			expect_near(Hazards.path_center(tuning, lake_seed, band), 0.0, 0.0001, "seed %d band %d: dead centre" % [lake_seed, band])
		for placement: Hazards.Placement in Hazards.plan(tuning, lake_seed):
			expect(absf(placement.position.x) >= PATH_WIDTH * 0.5, "seed %d: nothing in the middle strip" % lake_seed)


# --- objects ------------------------------------------------------------------------------------

func test_a_planned_log_stays_where_the_plan_put_it() -> void:
	var placements: Array[Hazards.Placement] = Hazards.plan(tuning, 42)
	expect(placements.size() > 0, "the lake has hazards")
	for placement: Hazards.Placement in placements:
		var hazard: Node2D = LogScene.instantiate() as Node2D
		var spec: HazardSpec = tuning.hazards[placement.spec]
		hazard.set(&"spec", spec)
		hazard.position = placement.position
		expect_eq(hazard.position, placement.position, "placed where the plan said")
		# Ten seconds of frames: a fixed object does not move while the water runs.
		for frame: int in 600:
			hazard.call(&"_physics_process", TICK)
		expect_eq(hazard.position, placement.position, "still where the plan put it after ten seconds")
		hazard.free()


# --- effects ------------------------------------------------------------------------------------

func test_a_beer_overboard_puts_the_hit_hulls_guy_in_the_water() -> void:
	var state: Node = sober_state()
	var seat: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy is the one to jump")
	expect(state.rescue.winding_up(seat), "winding up first (T34)")
	state.step(state.paddling.tuning.jump_delay, BOAT)
	expect_false(state.guys[seat].aboard, "off the boat once the wind-up is over")
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
	var motion: RefCounted = state.step(TICK, BOAT)
	expect_near(motion.thrust, 0.0, 0.0001, "his stroke does nothing")
	expect_near(state.guys[Paddling.Seat.LEFT_FRONT].stamina, 1.0, 0.0001, "and costs nothing, like a break")
	state.stroke(Paddling.Seat.LEFT_BACK, 10.0)
	expect(state.step(TICK, BOAT).thrust > 0.0, "the other guy on the hull still paddles")
	state.snag(Rescue.Hull.LEFT, 0.5)
	expect(state.snag_left(Paddling.Seat.LEFT_FRONT) > 1.5, "snagged again, he keeps the longer time")
	state.step(2.0, BOAT)
	expect_false(state.is_snagged(Paddling.Seat.LEFT_FRONT), "free once the time has run out")
	state.stroke(Paddling.Seat.LEFT_FRONT, 10.0)
	expect(state.step(TICK, BOAT).thrust > 0.0, "and paddling again")
	state.free()


func test_a_snag_takes_the_back_guy_when_the_front_one_is_in_the_water_and_nobody_on_an_empty_hull() -> void:
	var state: Node = sober_state()
	var delay: float = state.paddling.tuning.jump_delay
	state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	state.step(delay, BOAT)
	expect_eq(state.snag(Rescue.Hull.RIGHT, 1.0), Paddling.Seat.RIGHT_BACK, "the back guy is the one left on that hull")
	state.beer_overboard(Rescue.Hull.RIGHT, BOAT)
	state.step(delay, BOAT)
	expect_eq(state.snag(Rescue.Hull.RIGHT, 1.0), Rescue.NOBODY, "an empty hull has no paddle to snag")
	expect_eq(state.force_break(Rescue.Hull.RIGHT), Rescue.NOBODY, "and nobody to break")
	state.free()


func test_a_forced_break_starts_the_hit_guys_warning_then_his_break() -> void:
	var state: Node = sober_state()
	expect_eq(state.force_break(Rescue.Hull.RIGHT), Paddling.Seat.RIGHT_FRONT, "the right front guy is hit")
	expect_eq(state.stamina.state_of(Paddling.Seat.RIGHT_FRONT), Stamina.State.WARNING, "his break is telegraphed at once")
	state.step(state.stamina.tuning.break_warning + 0.01, BOAT)
	expect_eq(state.stamina.state_of(Paddling.Seat.RIGHT_FRONT), Stamina.State.BREAK, "then he is on his break")
	state.stroke(Paddling.Seat.RIGHT_FRONT, 10.0)
	expect_near(state.step(TICK, BOAT).thrust, 0.0, 0.0001, "and gives no strokes")
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
	expect_near(state.step(TICK, BOAT).thrust, 0.0, 0.0001, "a bailing guy gives no strokes")
	state.stroke(Paddling.Seat.RIGHT_BACK, 10.0)
	expect(state.step(TICK, BOAT).thrust > 0.0, "the other one still paddles")
	state.step(1.0, BOAT)
	expect_near(state.water_of(Rescue.Hull.RIGHT), 3.0 - 2.0 * (1.0 + 2.0 * TICK), 0.0001, "bailed at bail_rate per second")
	state.step(1.0, BOAT)
	expect_near(state.water_of(Rescue.Hull.RIGHT), 0.0, 0.0001, "the water is out")
	expect_eq(state.bailer_of(Rescue.Hull.RIGHT), Rescue.NOBODY, "nobody bails any more")
	state.stroke(Paddling.Seat.RIGHT_FRONT, 10.0)
	expect(state.step(TICK, BOAT).thrust > 0.0, "he paddles again")
	state.free()


func test_water_on_an_empty_hull_waits_for_a_guy() -> void:
	var state: Node = sober_state()
	state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	var back: int = state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	state.step(state.paddling.tuning.jump_delay, BOAT)
	expect_eq(back, Paddling.Seat.LEFT_BACK, "both left guys are in the water")
	expect_false(state.guys[back].aboard, "the back guy too, once the wind-up is over")
	state.water_aboard(Rescue.Hull.LEFT, 1.0)
	expect_eq(state.bailer_of(Rescue.Hull.LEFT), Rescue.NOBODY, "nobody on that hull to bail")
	state.step(5.0, BOAT)
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
