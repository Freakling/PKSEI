extends "res://tools/test_case.gd"
## T50 · The Loch-Brez beast: the boat within beast_edge_margin of either edge of lake_width, or
## beyond the island's far side by beast_beyond_island, is out of bounds, and the beast rises at
## once: the fin circles the boat for beast_warning, then the head surfaces beast_ram_distance
## away on the side away from the lake's middle and closes at beast_speed; within
## beast_hit_radius it hits: a shove of beast_shove toward the middle (x = 0 on an edge visit,
## down-screen beyond the island) and the hull it came from in the boat's frame, whose guy it
## grabs. It keeps attacking (circle → ram → beast_pause under → circle…) while the boat stays
## out, and dives as soon as the boat is back inside. A ram the boat outruns gives up after
## beast_ram_timeout and dives; the usual rules follow. Inside, in open water, it rolls once a
## second from the RNG passed in (the beast's own, Beast.rng_for(lake_seed), in the game) at
## beast_random_rate for one grab, then dives. Same inputs and seed, same beast.
## RunState.beast_grab() puts the hit hull's guy in the water beast_spit_distance back toward
## the shore, beerless (GDD › Systems › Hazards, the Loch-Brez beast row; GDD › Systems ›
## Setbacks). B5: a boat anywhere on the guaranteed path is never out of bounds (GDD: "the
## guaranteed path never leads there"). T64: a puke heard (hear_puke) while it is under and the
## boat is in open water rolls beast_puke_chance from the RNG passed in; a hit is a random visit.
##
## The tick is 1/64 s: the warning is 128 ticks, a lap of the fin 80, the ram 5 px a tick, and
## the ram timeout (1 s here) 64 ticks.

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 64.0
const LAKE_WIDTH: float = 640.0
const EDGE_MARGIN: float = 100.0
const ISLAND_DISTANCE: float = 2000.0
const ISLAND_RADIUS: float = 60.0
const BEYOND: float = 100.0
const LAUNCH_MARGIN: float = 96.0
const WARNING: float = 2.0
const SPEED: float = 320.0
const SHOVE: float = 200.0
const RAM_DISTANCE: float = 160.0
const HIT_RADIUS: float = 24.0
const PAUSE: float = 1.5
const DIVE: float = 2.0
## The ram timeout the timeout tests set, and its ticks.
const RAM_TIMEOUT: float = 1.0
const RAM_TIMEOUT_TICKS: int = 64
## Pixels per second a fleeing boat moves at: faster than the beast.
const FLEE_SPEED: float = SPEED * 1.5
## Where the boat is in the tests: the deep middle, past either edge (|x| > 220), beyond the
## island (y < -2100), and still at the launch.
const INSIDE: Vector2 = Vector2(0.0, -1000.0)
const LEFT_OUT: Vector2 = Vector2(-250.0, -1000.0)
const RIGHT_OUT: Vector2 = Vector2(250.0, -1000.0)
const BEYOND_ISLAND: Vector2 = Vector2(0.0, -2150.0)
const LAUNCH: Vector2 = Vector2(0.0, -50.0)
## The tick the beast rises on a boat already out, the tick the ram starts (the warning's 128
## ticks later), the ram's moves to the hit (160 px less the hit radius at 5 px a move, rounded
## up), and the tick it hits.
const RISE_TICK: int = 1
const RAM_TICK: int = RISE_TICK + 128
const RAM_MOVES: int = 28
const HIT_TICK: int = RAM_TICK + RAM_MOVES
const PAUSE_TICKS: int = 96
const DIVE_TICKS: int = 128
## The puke's chance of drawing the beast in these tests: one in fifty, as the GDD has it.
const PUKE_CHANCE: float = 0.02

var tuning: LakeTuning
var beast: Beast
var rng: RandomNumberGenerator
var last_hit: Beast.Hit
## Ticks stepped so far, so hits can be named across several run() calls.
var _tick: int = 0
## The seats RunState's guy_grabbed reported.
var _grabbed: Array[int] = []


func before_each() -> void:
	tuning = own_tuning()
	beast = Beast.new(tuning)
	rng = RandomNumberGenerator.new()
	rng.seed = 7
	last_hit = null
	_tick = 0
	_grabbed = []


func own_tuning() -> LakeTuning:
	var lake: LakeTuning = LakeTuning.new()
	lake.lake_width = LAKE_WIDTH
	lake.island_distance = ISLAND_DISTANCE
	lake.island_radius = ISLAND_RADIUS
	lake.launch_margin = LAUNCH_MARGIN
	lake.beast_edge_margin = EDGE_MARGIN
	lake.beast_beyond_island = BEYOND
	lake.beast_warning = WARNING
	lake.beast_speed = SPEED
	lake.beast_shove = SHOVE
	lake.beast_ram_distance = RAM_DISTANCE
	lake.beast_hit_radius = HIT_RADIUS
	lake.beast_pause = PAUSE
	lake.beast_dive_time = DIVE
	lake.beast_ram_timeout = 6.0
	lake.beast_random_rate = 0.0
	lake.beast_puke_chance = PUKE_CHANCE
	return lake


## An RNG whose first roll lands under (or, with `under` false, at or over) PUKE_CHANCE: the
## seeds are searched in order, so the test is deterministic and says which way the roll goes.
func rng_rolling(under: bool) -> RandomNumberGenerator:
	for seed: int in range(1, 10000):
		var probe: RandomNumberGenerator = RandomNumberGenerator.new()
		probe.seed = seed
		if (probe.randf() < PUKE_CHANCE) == under:
			var found: RandomNumberGenerator = RandomNumberGenerator.new()
			found.seed = seed
			return found
	fail("no seed rolls %s beast_puke_chance" % ("under" if under else "over"))
	return RandomNumberGenerator.new()


## The state of `source` after one randf(), to check a roll was taken and nothing more.
func rolled_once(source: RandomNumberGenerator) -> int:
	var copy: RandomNumberGenerator = RandomNumberGenerator.new()
	copy.seed = source.seed
	copy.randf()
	return copy.state


## Steps the beast for some ticks with the boat still; returns the ticks (1-based, counted from
## the first run() call) that hit, and keeps the last hit in last_hit.
func run(ticks: int, boat: Vector2, rotation: float = 0.0) -> Array[int]:
	var hits: Array[int] = []
	for tick: int in ticks:
		_tick += 1
		var hit: Beast.Hit = beast.step(TICK, boat, rotation, rng)
		if hit != null:
			hits.append(_tick)
			last_hit = hit
	return hits


func _on_grabbed(seat: int) -> void:
	_grabbed.append(seat)


func test_out_of_bounds_on_both_edges_and_beyond_the_island() -> void:
	expect_false(beast.out_of_bounds(INSIDE), "the deep middle is inside")
	expect(beast.out_of_bounds(LEFT_OUT), "within beast_edge_margin of the left edge")
	expect(beast.out_of_bounds(RIGHT_OUT), "within beast_edge_margin of the right edge")
	expect(beast.out_of_bounds(BEYOND_ISLAND), "beyond the island's far side")
	expect_false(beast.out_of_bounds(Vector2(-220.0, -1000.0)), "exactly at the margin is still inside")
	expect(beast.out_of_bounds(Vector2(-221.0, -1000.0)), "a pixel past it is out")
	expect_false(beast.out_of_bounds(Vector2(0.0, -2100.0)), "exactly beast_beyond_island past the island is still inside")
	expect(beast.out_of_bounds(Vector2(0.0, -2101.0)), "a pixel further is out")
	expect(beast.in_open_water(INSIDE), "the deep middle is open water")
	expect_false(beast.in_open_water(LAUNCH), "the launch is not")
	expect_false(beast.in_open_water(Vector2(0.0, -1950.0)), "nor the island's beach")
	expect_false(beast.in_open_water(LEFT_OUT), "nor out of bounds")


## B5 regression: the corridor Hazards plans keeps clear of the beast's edge zone, so a boat
## following it, on its centre or either edge, never summons the beast. Before the fix the
## corridor's centre could sit lake_width / 2 - path_width / 2 out, with its edge at the lake's
## edge, well inside beast_edge_margin.
func test_a_boat_anywhere_on_the_guaranteed_path_is_never_out_of_bounds() -> void:
	tuning.band_length = 160.0
	tuning.path_width = 120.0
	tuning.path_wander = 200.0
	var half_path: float = tuning.path_width * 0.5
	var bound: float = LAKE_WIDTH * 0.5 - EDGE_MARGIN
	var furthest: float = 0.0
	for lake_seed: int in 50:
		var y: float = 0.0
		while y >= -ISLAND_DISTANCE:
			var centre: float = Hazards.corridor_x(tuning, lake_seed, y)
			for x: float in [centre - half_path, centre, centre + half_path]:
				expect_false(beast.out_of_bounds(Vector2(x, y)), "seed %d y %.0f: a boat on the path at x %.1f is inside the bounds" % [lake_seed, y, x])
			furthest = maxf(furthest, absf(centre) + half_path)
			y -= 4.0
	expect(furthest > bound - HIT_RADIUS - 1.0, "the path does wander out to its reach (%.1f), a beast's half-width short of the bound (%.1f)" % [furthest, bound])
	expect(furthest <= bound - HIT_RADIUS + 0.0001, "and no further")


func test_it_stays_under_while_the_boat_is_inside() -> void:
	var hits: Array[int] = run(500, INSIDE)
	expect_eq(beast.state, Beast.State.SUBMERGED, "under water")
	expect_eq(hits.size(), 0, "no hit")


func test_it_rises_and_circles_for_beast_warning_then_rams_from_the_far_side() -> void:
	run(RISE_TICK, LEFT_OUT)
	expect_eq(beast.state, Beast.State.CIRCLING, "out past the left edge: the fin rises")
	expect_false(beast.random_visit, "a boundary visit")
	expect_near(beast.time_left, WARNING, 0.0001, "beast_warning to go")
	expect_eq(beast.toward_middle, Vector2.RIGHT, "the middle is to the right")
	expect_near(beast.position.distance_to(LEFT_OUT), Beast.CIRCLE_RADIUS, 0.0001, "the fin at the circle's radius")
	expect(beast.position.x < LEFT_OUT.x, "it rose on the side away from the middle")
	for tick: int in 40:
		run(1, LEFT_OUT)
		expect_eq(beast.state, Beast.State.CIRCLING, "still circling, tick %d" % (tick + 2))
		expect_near(beast.position.distance_to(LEFT_OUT), Beast.CIRCLE_RADIUS, 0.001, "on the circle, tick %d" % (tick + 2))
	expect(beast.position.x > LEFT_OUT.x + 40.0, "half a lap later the fin is on the other side of the boat")
	run(RAM_TICK - RISE_TICK - 1 - 40, LEFT_OUT)
	expect_eq(beast.state, Beast.State.CIRCLING, "still the warning one tick short")
	expect_near(beast.time_left, TICK, 0.0001, "one tick to go")
	run(1, LEFT_OUT)
	expect_eq(beast.state, Beast.State.RAMMING, "then the head surfaces")
	expect_eq(beast.position, LEFT_OUT - Vector2.RIGHT * RAM_DISTANCE, "beast_ram_distance out on the side away from the middle")
	expect_near(beast.ram_left, 6.0, 0.0001, "beast_ram_timeout to land it")
	expect_eq(beast.direction, Vector2.RIGHT, "charging at the boat")
	var hits: Array[int] = run(RAM_MOVES - 1, LEFT_OUT)
	expect_eq(hits.size(), 0, "no hit on the way in")
	expect_eq(beast.state, Beast.State.RAMMING, "still closing")
	expect_near(beast.position.x, LEFT_OUT.x - RAM_DISTANCE + SPEED * TICK * (RAM_MOVES - 1), 0.001, "beast_speed a second toward the boat")
	hits = run(1, LEFT_OUT)
	expect_eq(hits, [HIT_TICK] as Array[int], "the hit, the move that brings it within beast_hit_radius")
	expect_eq(last_hit.shove, Vector2.RIGHT * SHOVE, "shoved toward x = 0 by beast_shove")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "facing the island, it hit the left hull: the side it came from")
	expect_near(beast.position.distance_to(LEFT_OUT), HIT_RADIUS, 0.001, "the head at the hull")
	expect_eq(beast.state, Beast.State.DIVING, "then it goes under")
	expect_near(beast.time_left, PAUSE, 0.0001, "for the short pause between rams")
	expect_eq(beast.ram_left, 0.0, "the ram is over")


func test_the_right_edge_mirrors() -> void:
	var hits: Array[int] = run(HIT_TICK, RIGHT_OUT)
	expect_eq(hits, [HIT_TICK] as Array[int], "one hit on the same tick")
	expect_eq(last_hit.shove, Vector2.LEFT * SHOVE, "shoved leftward, toward x = 0")
	expect_eq(last_hit.hull, Rescue.Hull.RIGHT, "the right hull faces the right edge")


func test_beyond_the_island_it_rams_back_toward_the_islands_near_side() -> void:
	run(RAM_TICK, BEYOND_ISLAND, PI * 0.5)
	expect_eq(beast.state, Beast.State.RAMMING, "ramming")
	expect_eq(beast.position, BEYOND_ISLAND + Vector2.UP * RAM_DISTANCE, "from further beyond the island")
	var hits: Array[int] = run(RAM_MOVES, BEYOND_ISLAND, PI * 0.5)
	expect_eq(hits, [HIT_TICK] as Array[int], "one hit")
	expect_eq(last_hit.shove, Vector2.DOWN * SHOVE, "shoved down-screen, back toward the island")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "facing right, the left hull faces up-screen")
	beast.reset()
	run(HIT_TICK, BEYOND_ISLAND, 0.0)
	expect_eq(last_hit.hull, Rescue.Hull.RIGHT, "dead ahead counts as the right hull")


func test_the_hull_is_the_side_it_came_from_in_the_boats_frame() -> void:
	run(HIT_TICK, LEFT_OUT, PI)
	expect_eq(last_hit.hull, Rescue.Hull.RIGHT, "facing the shore, the right hull faces the left edge")
	expect_eq(last_hit.shove, Vector2.RIGHT * SHOVE, "the shove is still toward the middle, not the boat's side")
	beast.reset()
	run(HIT_TICK, LEFT_OUT, -PI / 4.0)
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "slanted left: the left hull still faces it")


func test_it_keeps_attacking_while_the_boat_stays_out() -> void:
	var first: Array[int] = run(HIT_TICK, LEFT_OUT)
	expect_eq(first.size(), 1, "the first hit")
	run(PAUSE_TICKS, LEFT_OUT)
	expect_eq(beast.state, Beast.State.SUBMERGED, "under for the pause")
	run(1, LEFT_OUT)
	expect_eq(beast.state, Beast.State.CIRCLING, "still out: the fin is back")
	var second: Array[int] = run(RAM_TICK - RISE_TICK + RAM_MOVES, LEFT_OUT)
	expect_eq(second, [HIT_TICK + PAUSE_TICKS + HIT_TICK] as Array[int], "a second hit, one warning and one ram later")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "the same hull again")


func test_it_dives_once_the_boat_is_back_inside() -> void:
	run(RISE_TICK + 10, LEFT_OUT)
	expect_eq(beast.state, Beast.State.CIRCLING, "circling")
	run(1, INSIDE)
	expect_eq(beast.state, Beast.State.DIVING, "back inside while it circles: it dives")
	expect_near(beast.time_left, DIVE, 0.0001, "gone for the dive time")
	run(DIVE_TICKS, INSIDE)
	expect_eq(beast.state, Beast.State.SUBMERGED, "under water")
	var hits: Array[int] = run(500, INSIDE)
	expect_eq(hits.size(), 0, "and nothing more while the boat stays inside")
	expect_eq(beast.state, Beast.State.SUBMERGED, "still under")
	beast.reset()
	run(RAM_TICK + 5, LEFT_OUT)
	expect_eq(beast.state, Beast.State.RAMMING, "ramming")
	hits = run(1, INSIDE)
	expect_eq(hits.size(), 0, "back inside during the ram: no hit")
	expect_eq(beast.state, Beast.State.DIVING, "it dives")
	run(DIVE_TICKS + 500, INSIDE)
	expect_eq(beast.state, Beast.State.SUBMERGED, "and stays under")


func test_a_random_visit_from_the_seeded_rng_is_one_grab_then_a_dive() -> void:
	tuning.beast_random_rate = 1.0
	run(63, INSIDE)
	expect_eq(beast.state, Beast.State.SUBMERGED, "no roll before the first second is up")
	run(1, INSIDE)
	expect_eq(beast.state, Beast.State.CIRCLING, "the roll at one second: a certain rate rises")
	expect(beast.random_visit, "a random visit")
	expect_eq(beast.toward_middle, Vector2.LEFT, "on x = 0 the middle counts as leftward")
	run(128, INSIDE)
	expect_eq(beast.state, Beast.State.RAMMING, "the warning over, it rams")
	expect_eq(beast.position, INSIDE + Vector2.RIGHT * RAM_DISTANCE, "from the right")
	var hits: Array[int] = run(RAM_MOVES, INSIDE)
	expect_eq(hits, [64 + 128 + RAM_MOVES] as Array[int], "one grab")
	expect_eq(last_hit.hull, Rescue.Hull.RIGHT, "on the hull it came from")
	expect_eq(last_hit.shove, Vector2.LEFT * SHOVE, "shoved toward the middle")
	expect_eq(beast.state, Beast.State.DIVING, "then it dives")
	expect_near(beast.time_left, DIVE, 0.0001, "for the dive time, not the short pause")
	run(DIVE_TICKS, INSIDE)
	expect_eq(beast.state, Beast.State.SUBMERGED, "under water")
	expect_false(beast.random_visit, "the visit is over")
	hits = run(63, INSIDE)
	expect_eq(hits.size(), 0, "no second grab: the next roll is a full second after it submerged")
	expect_eq(beast.state, Beast.State.SUBMERGED, "still under")


func test_the_random_visit_only_happens_in_open_water() -> void:
	tuning.beast_random_rate = 1.0
	run(500, LAUNCH)
	expect_eq(beast.state, Beast.State.SUBMERGED, "never at the launch")
	run(500, Vector2(0.0, -1950.0))
	expect_eq(beast.state, Beast.State.SUBMERGED, "never at the island's beach")
	var fresh: RandomNumberGenerator = RandomNumberGenerator.new()
	fresh.seed = 7
	expect_eq(rng.state, fresh.state, "and the RNG was never rolled")


func test_a_zero_rate_never_rises_and_the_rolls_come_from_the_rng_passed_in() -> void:
	var untouched: RandomNumberGenerator = RandomNumberGenerator.new()
	untouched.seed = 7
	run(640, INSIDE)
	expect_eq(beast.state, Beast.State.SUBMERGED, "rate 0: under for ten seconds")
	for roll: int in 10:
		untouched.randf()
	expect_eq(rng.state, untouched.state, "ten rolls were taken from the RNG passed in, one a second, and from nothing else")


func test_two_beasts_seeded_from_the_same_lake_seed_visit_alike() -> void:
	tuning.beast_random_rate = 0.2
	var mine_rng: RandomNumberGenerator = Beast.rng_for(123456)
	var theirs_rng: RandomNumberGenerator = Beast.rng_for(123456)
	expect_eq(mine_rng.seed, theirs_rng.seed, "the same lake seed, the same beast seed")
	expect_ne(mine_rng.seed, Beast.rng_for(123457).seed, "another lake, another beast seed")
	var fresh: RandomNumberGenerator = RandomNumberGenerator.new()
	fresh.seed = 123456
	expect_ne(mine_rng.seed, fresh.seed, "on a stream of its own, not the lake seed as it is")
	var other: Beast = Beast.new(tuning)
	var mine: Array[int] = []
	var theirs: Array[int] = []
	# The boat sits in the deep middle for a minute: only the random visit can rise.
	for tick: int in 3840:
		var hit: Beast.Hit = beast.step(TICK, INSIDE, 0.0, mine_rng)
		var their_hit: Beast.Hit = other.step(TICK, INSIDE, 0.0, theirs_rng)
		if hit != null:
			mine.append(tick)
		if their_hit != null:
			theirs.append(tick)
		expect_eq(beast.state, other.state, "same state at tick %d" % tick)
		expect_eq(beast.random_visit, other.random_visit, "same visit at tick %d" % tick)
	expect(mine.size() >= 2, "the beast visited more than once in a minute at a fifth a second")
	expect_eq(mine, theirs, "the same visits on the same ticks")


func test_a_ram_the_boat_outruns_gives_up_and_the_usual_rules_follow() -> void:
	tuning.beast_ram_timeout = RAM_TIMEOUT
	run(RAM_TICK, LEFT_OUT)
	expect_eq(beast.state, Beast.State.RAMMING, "ramming")
	expect_near(beast.ram_left, RAM_TIMEOUT, 0.0001, "beast_ram_timeout to land it")
	var boat: Vector2 = LEFT_OUT
	var hits: Array[int] = []
	for tick: int in RAM_TIMEOUT_TICKS - 1:
		# Fleeing up-screen faster than beast_speed, still within the edge margin.
		boat += Vector2.UP * FLEE_SPEED * TICK
		hits.append_array(run(1, boat))
	expect_eq(hits.size(), 0, "outrun: no hit")
	expect_eq(beast.state, Beast.State.RAMMING, "still chasing, one tick short of the timeout")
	expect_near(beast.ram_left, TICK, 0.0001, "one tick to go")
	expect(beast.position.distance_to(boat) > HIT_RADIUS, "and never caught up")
	boat += Vector2.UP * FLEE_SPEED * TICK
	hits = run(1, boat)
	expect_eq(hits.size(), 0, "the timeout: still no hit")
	expect_eq(beast.state, Beast.State.DIVING, "it gives up and dives")
	expect_near(beast.time_left, DIVE, 0.0001, "for the dive time")
	expect_eq(beast.ram_left, 0.0, "the ram is over")
	run(DIVE_TICKS, boat)
	expect_eq(beast.state, Beast.State.SUBMERGED, "under water")
	run(1, boat)
	expect_eq(beast.state, Beast.State.CIRCLING, "the boat still out: it rises again")
	expect_false(beast.random_visit, "a boundary visit")
	hits = run(RAM_TICK - RISE_TICK + RAM_MOVES, boat)
	expect_eq(hits.size(), 1, "the boat now still, the next ram lands")
	expect_eq(last_hit.hull, Rescue.Hull.LEFT, "on the hull facing the edge")


func test_a_random_visit_the_boat_outruns_is_over() -> void:
	tuning.beast_random_rate = 1.0
	tuning.beast_ram_timeout = RAM_TIMEOUT
	run(64 + 128, INSIDE)
	expect_eq(beast.state, Beast.State.RAMMING, "a random visit's ram")
	expect(beast.random_visit, "a random visit")
	var boat: Vector2 = INSIDE
	var hits: Array[int] = []
	for tick: int in RAM_TIMEOUT_TICKS:
		boat += Vector2.UP * FLEE_SPEED * TICK
		hits.append_array(run(1, boat))
	expect_eq(hits.size(), 0, "outrun: no grab")
	expect_eq(beast.state, Beast.State.DIVING, "it gives up and dives")
	expect_near(beast.time_left, DIVE, 0.0001, "for the dive time")
	run(DIVE_TICKS, boat)
	expect_eq(beast.state, Beast.State.SUBMERGED, "under water")
	expect_false(beast.random_visit, "the visit is over, grab or not")
	expect_near(beast.roll_left, Beast.ROLL_INTERVAL, 0.0001, "the next roll a full second away")


func test_same_inputs_and_seed_same_beast() -> void:
	tuning.beast_random_rate = 0.2
	var other: Beast = Beast.new(tuning)
	var other_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	other_rng.seed = 7
	var mine: Array[int] = []
	var theirs: Array[int] = []
	for tick: int in 1500:
		# A boat that wanders out past the left edge and back, and on up beyond the island.
		var boat: Vector2 = Vector2(-300.0 * sin(tick * 0.005), -1000.0 - float(tick))
		var rotation: float = 0.3 * sin(tick * 0.02)
		var hit: Beast.Hit = beast.step(TICK, boat, rotation, rng)
		if hit != null:
			mine.append(tick * 2 + int(hit.hull))
		var their_hit: Beast.Hit = other.step(TICK, boat, rotation, other_rng)
		if their_hit != null:
			theirs.append(tick * 2 + int(their_hit.hull))
		expect_eq(beast.state, other.state, "same state at tick %d" % tick)
		expect_eq(beast.position, other.position, "same beast at tick %d" % tick)
	expect(mine.size() >= 2, "the wandering boat was hit at the edge and beyond the island")
	expect_eq(mine, theirs, "the same hits on the same hulls")


func test_run_state_beast_grab_puts_the_hulls_guy_in_the_water_far_back_toward_the_shore_beerless() -> void:
	var boat: Vector2 = Vector2(0.0, -300.0)
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.paddling = Paddling.new(BoatTuning.new())
	state.reset()
	state.set_progress(0.5)
	for seat: int in state.guys.size():
		state.drunkenness.set_level(seat, 0.0)
	state.guy_grabbed.connect(_on_grabbed)
	# What scripts/hazards/beast.gd does with a hit: the shove, then the grab.
	state.shove(Vector2.RIGHT * SHOVE)
	var seat: int = state.beast_grab(Rescue.Hull.LEFT, boat, 200.0)
	expect_eq(seat, Paddling.Seat.LEFT_FRONT, "the left front guy, front first")
	expect_false(state.guys[seat].aboard, "off the boat")
	var swimmer: Rescue.Swimmer = state.rescue.swimmer_of(seat)
	expect(swimmer != null, "in the water")
	expect_eq(swimmer.position, boat + Vector2.DOWN * 200.0, "beast_spit_distance back toward the shore")
	expect_eq(swimmer.state, Rescue.State.FLOATING, "floating: nothing to swim for")
	expect_false(swimmer.has_beer, "beerless")
	expect_eq(_grabbed, [seat] as Array[int], "guy_grabbed said who")
	expect_eq(state.take_shove(), Vector2.RIGHT * SHOVE, "the boat still takes the shove")
	var other: int = state.beer_overboard(Rescue.Hull.RIGHT, boat)
	expect_eq(other, Paddling.Seat.RIGHT_FRONT, "no beer went over, so the beer-loss cooldown didn't start")
	var back: int = state.beast_grab(Rescue.Hull.LEFT, boat, 900.0)
	expect_eq(back, Paddling.Seat.LEFT_BACK, "the left back guy next")
	state.step(TICK, boat)
	var far: Rescue.Swimmer = state.rescue.swimmer_of(back)
	expect_near(far.position.y, -state.paddling.tuning.shore_margin, 0.0001, "spat out past the shoreline: held there")
	expect(far.washed_up, "washed up")
	expect_eq(state.beast_grab(Rescue.Hull.LEFT, boat, 900.0), Rescue.NOBODY, "an empty hull: nobody to grab")
	expect_eq(_grabbed.size(), 2, "and no signal for it")
	state.free()


## T64: a puke heard under water in open water rolls beast_puke_chance once from the RNG passed
## in; a roll under it is a random visit: the fin, the ram, one grab, then the dive.
func test_a_puke_heard_in_open_water_that_rolls_under_beast_puke_chance_starts_a_random_visit() -> void:
	var lucky: RandomNumberGenerator = rng_rolling(true)
	var after_one: int = rolled_once(lucky)
	expect(beast.hear_puke(INSIDE, lucky), "the roll under the chance: it rises")
	expect_eq(lucky.state, after_one, "one roll taken, no more")
	expect_eq(beast.state, Beast.State.CIRCLING, "the fin is up")
	expect(beast.random_visit, "a random visit")
	expect_near(beast.time_left, WARNING, 0.0001, "beast_warning to go")
	expect_eq(beast.toward_middle, Vector2.LEFT, "on x = 0 the middle counts as leftward")
	expect_near(beast.position.distance_to(INSIDE), Beast.CIRCLE_RADIUS, 0.0001, "the fin at the circle's radius")
	run(RAM_TICK - RISE_TICK, INSIDE)
	expect_eq(beast.state, Beast.State.RAMMING, "the warning over, it rams")
	expect_eq(beast.position, INSIDE + Vector2.RIGHT * RAM_DISTANCE, "from the side away from the middle")
	var hits: Array[int] = run(RAM_MOVES, INSIDE)
	expect_eq(hits.size(), 1, "one grab")
	expect_eq(last_hit.hull, Rescue.Hull.RIGHT, "on the hull it came from")
	expect_eq(last_hit.shove, Vector2.LEFT * SHOVE, "shoved toward the middle")
	expect_eq(beast.state, Beast.State.DIVING, "then it dives")
	expect_near(beast.time_left, DIVE, 0.0001, "for the dive time, not the short pause")
	run(DIVE_TICKS, INSIDE)
	expect_eq(beast.state, Beast.State.SUBMERGED, "under water")
	expect_false(beast.random_visit, "the visit is over")
	expect_eq(run(500, INSIDE).size(), 0, "and no second grab on its own (rate 0)")


func test_a_puke_that_rolls_over_beast_puke_chance_leaves_it_under() -> void:
	var unlucky: RandomNumberGenerator = rng_rolling(false)
	var after_one: int = rolled_once(unlucky)
	expect_false(beast.hear_puke(INSIDE, unlucky), "the roll at or over the chance: nothing")
	expect_eq(unlucky.state, after_one, "but the roll was taken")
	expect_eq(beast.state, Beast.State.SUBMERGED, "still under")
	expect_false(beast.random_visit, "no visit")
	expect_eq(run(500, INSIDE).size(), 0, "and nothing follows")
	tuning.beast_puke_chance = 0.0
	var lucky: RandomNumberGenerator = rng_rolling(true)
	expect_false(beast.hear_puke(INSIDE, lucky), "a chance of 0 never rises, whatever the roll")
	expect_eq(beast.state, Beast.State.SUBMERGED, "still under")


func test_a_puke_is_not_heard_while_it_is_up_or_diving_and_the_rng_is_left_alone() -> void:
	var lucky: RandomNumberGenerator = rng_rolling(true)
	var untouched: int = lucky.state
	run(RISE_TICK + 10, LEFT_OUT)
	expect_eq(beast.state, Beast.State.CIRCLING, "a boundary visit circles")
	expect_false(beast.hear_puke(LEFT_OUT, lucky), "a puke while it circles: nothing")
	expect_eq(beast.state, Beast.State.CIRCLING, "still circling")
	expect_false(beast.random_visit, "still the boundary visit")
	run(RAM_TICK - RISE_TICK - 10, LEFT_OUT)
	expect_eq(beast.state, Beast.State.RAMMING, "ramming")
	expect_false(beast.hear_puke(LEFT_OUT, lucky), "a puke while it rams: nothing")
	expect_eq(beast.state, Beast.State.RAMMING, "still ramming")
	run(1, INSIDE)
	expect_eq(beast.state, Beast.State.DIVING, "back inside: it dives")
	expect_false(beast.hear_puke(INSIDE, lucky), "a puke while it dives: nothing")
	expect_eq(beast.state, Beast.State.DIVING, "still diving")
	expect_near(beast.time_left, DIVE, 0.0001, "the dive untouched")
	expect_eq(lucky.state, untouched, "and the RNG was never rolled")
	run(DIVE_TICKS, INSIDE)
	expect_eq(beast.state, Beast.State.SUBMERGED, "under water again")
	expect(beast.hear_puke(INSIDE, lucky), "now a puke is heard")
	expect(beast.random_visit, "a random visit")


func test_a_puke_is_not_heard_out_of_open_water_and_the_rng_is_left_alone() -> void:
	var lucky: RandomNumberGenerator = rng_rolling(true)
	var untouched: int = lucky.state
	expect_false(beast.hear_puke(LAUNCH, lucky), "never at the launch")
	expect_false(beast.hear_puke(Vector2(0.0, -1950.0), lucky), "never at the island's beach")
	expect_false(beast.hear_puke(LEFT_OUT, lucky), "never out of bounds: the boundary rules apply there")
	expect_false(beast.hear_puke(BEYOND_ISLAND, lucky), "nor beyond the island")
	expect_eq(beast.state, Beast.State.SUBMERGED, "still under")
	expect_eq(lucky.state, untouched, "and the RNG was never rolled")
	expect(beast.hear_puke(INSIDE, lucky), "the same roll in open water rises")
