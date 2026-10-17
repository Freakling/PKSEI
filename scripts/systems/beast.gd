class_name Beast
extends RefCounted
## Beast · the Loch-Brez beast: the lake's boundary enforcer and, rarely, a deep-water visitor
## (GDD › Systems › Hazards, the Loch-Brez beast row).
##
## A plain rule class: it receives its LakeTuning and never touches the scene tree or RunState.
## There is one per attempt, not planned by Hazards: the lake spawns it. It runs one state
## machine, advanced by step() with the boat's position and heading and an RNG:
##   SUBMERGED: nothing shows. The boat out of bounds (out_of_bounds: within beast_edge_margin
##              of either edge of lake_width, or beyond the island's far side by
##              beast_beyond_island) makes it rise at once, a boundary visit. Inside the bounds
##              and in open water (in_open_water: past the launch margin, short of the island)
##              it rolls once a second from the caller's RNG: a chance of beast_random_rate to
##              rise anyway, the rare random visit;
##   CIRCLING:  the telegraph. The fin (`position`) circles the boat at CIRCLE_RADIUS, one lap
##              per CIRCLE_PERIOD, for beast_warning seconds (a low rumble comes with T26's
##              audio). On a boundary visit a boat back inside makes it dive without ramming;
##   RAMMING:   the head surfaces beast_ram_distance from the boat on the side away from the
##              lake's middle (`toward_middle`: toward x = 0 on an edge visit or a random visit,
##              toward the island's near side, down-screen, beyond the island) and closes on the
##              boat at beast_speed, following it. The step it comes within beast_hit_radius is
##              the hit: a shove of beast_shove along toward_middle, so the boat is pushed back
##              inside, and the hull it hit, the side it came from in the boat's frame; the guy
##              on that hull is grabbed (RunState.beast_grab). A boundary visit's boat back
##              inside makes it dive before the hit. A ram that hasn't hit within
##              beast_ram_timeout (the boat outran it; `ram_left` counts down) gives up: it
##              dives for beast_dive_time, and the usual rules follow (it rises again if the
##              boat is still out; a random visit is over);
##   DIVING:    gone under for a while: beast_pause after a hit on a boundary visit (then it
##              rises again if the boat is still out: circle → ram → pause → circle…),
##              beast_dive_time after the random visit's one grab, after a ram that gave up or
##              when the boat came back inside. Then SUBMERGED.
## The only randomness is the random visit's roll, from the RNG the caller passes, so the same
## inputs and the same seed give the same visit. In the game that is the beast's own RNG,
## rng_for(RunState.lake_seed): the crew's RunState.rng stream is never touched and the same
## lake gives the same visits. Positions are in the boat's frame of reference (the scene uses
## global coordinates), with the island up-screen (negative y) and the lake's middle at x = 0.

## What the beast is doing.
enum State { SUBMERGED, CIRCLING, RAMMING, DIVING }

## One ram: `shove` in pixels per second toward the lake's middle, and the hull it hit, whose
## guy it grabs.
class Hit extends RefCounted:
	var hull: Rescue.Hull = Rescue.Hull.LEFT
	var shove: Vector2 = Vector2.ZERO


## Pixels from the boat's centre the fin circles at, and seconds per lap (cosmetic: the
## telegraph's shape; its length is beast_warning).
const CIRCLE_RADIUS: float = 48.0
const CIRCLE_PERIOD: float = 1.25
## Seconds between the random visit's rolls while submerged in open water.
const ROLL_INTERVAL: float = 1.0


var tuning: LakeTuning
var state: State = State.SUBMERGED
## Whether this surfacing is the rare random visit (one grab, then it dives) rather than a
## boundary visit (it keeps attacking until the boat is back inside).
var random_visit: bool = false
## Seconds left of the circling (CIRCLING) or under water (DIVING); 0 otherwise.
var time_left: float = 0.0
## Seconds left of the ram (RAMMING) before it gives up, from beast_ram_timeout; 0 otherwise.
var ram_left: float = 0.0
## Where the beast is: the fin while CIRCLING, the head while RAMMING; stale otherwise.
var position: Vector2 = Vector2.ZERO
## Unit direction it moves in: along the circle while CIRCLING, at the boat while RAMMING.
var direction: Vector2 = Vector2.UP
## Unit direction toward the lake's middle for this visit: where the ram shoves the boat.
var toward_middle: Vector2 = Vector2.LEFT
## The fin's angle around the boat while CIRCLING, in radians.
var angle: float = 0.0
## Seconds until the next random visit's roll.
var roll_left: float = ROLL_INTERVAL


func _init(lake_tuning: LakeTuning) -> void:
	tuning = lake_tuning
	reset()


## Under water, nothing showing, the next roll a full interval away.
func reset() -> void:
	state = State.SUBMERGED
	random_visit = false
	time_left = 0.0
	ram_left = 0.0
	position = Vector2.ZERO
	direction = Vector2.UP
	toward_middle = Vector2.LEFT
	angle = 0.0
	roll_left = ROLL_INTERVAL


## The beast's own RNG for an attempt, seeded from the lake's seed on a stream of its own (not
## the hazards' band seeds, not RunState.rng), so the same lake gives the same random visits and
## the beast's rolls never shift the crew's.
static func rng_for(lake_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("beast:%d" % lake_seed)
	return rng


## Whether the boat has strayed too far: within beast_edge_margin of either edge of lake_width,
## or beyond the island's far side by beast_beyond_island.
func out_of_bounds(boat_position: Vector2) -> bool:
	return beyond_island(boat_position) \
			or absf(boat_position.x) > tuning.lake_width * 0.5 - tuning.beast_edge_margin


## Whether the boat is past the island's far side.
func beyond_island(boat_position: Vector2) -> bool:
	return boat_position.y < -(tuning.island_distance + tuning.beast_beyond_island)


## Whether the boat is in the deep middle where the random visit can happen: inside the bounds,
## past the launch margin and short of the island's near edge.
func in_open_water(boat_position: Vector2) -> bool:
	if out_of_bounds(boat_position):
		return false
	return boat_position.y < -tuning.launch_margin \
			and boat_position.y > -(tuning.island_distance - tuning.island_radius)


## Unit direction from the boat toward the lake's middle: down-screen (toward the island's near
## side) beyond the island, else toward x = 0; a boat exactly on x = 0 is pushed left.
func middle_direction(boat_position: Vector2) -> Vector2:
	if beyond_island(boat_position):
		return Vector2.DOWN
	return Vector2.RIGHT if boat_position.x < 0.0 else Vector2.LEFT


## The hull the beast hit, from where it is in the boat's own frame; dead ahead or astern counts
## as the right hull.
func hull_hit(boat_position: Vector2, boat_rotation: float) -> Rescue.Hull:
	var from_beast: Vector2 = (position - boat_position).rotated(-boat_rotation)
	return Rescue.Hull.LEFT if from_beast.x < 0.0 else Rescue.Hull.RIGHT


## Advances the beast by delta with the boat where it is; `rng` rolls the random visit (the
## caller's: rng_for() in the game, a seeded one in tests). Returns the hit it lands this step,
## or null.
func step(delta: float, boat_position: Vector2, boat_rotation: float, rng: RandomNumberGenerator) -> Hit:
	var hit: Hit = null
	match state:
		State.SUBMERGED:
			if out_of_bounds(boat_position):
				_rise(boat_position, false)
			elif in_open_water(boat_position):
				roll_left -= delta
				if roll_left <= 0.0:
					roll_left += ROLL_INTERVAL
					if rng.randf() < tuning.beast_random_rate:
						_rise(boat_position, true)
		State.CIRCLING:
			if not random_visit and not out_of_bounds(boat_position):
				_dive(tuning.beast_dive_time)
			else:
				time_left -= delta
				angle += TAU * delta / CIRCLE_PERIOD
				position = boat_position + Vector2.from_angle(angle) * CIRCLE_RADIUS
				direction = Vector2.from_angle(angle + PI * 0.5)
				if time_left <= 0.0:
					_ram(boat_position)
		State.RAMMING:
			if not random_visit and not out_of_bounds(boat_position):
				_dive(tuning.beast_dive_time)
			else:
				ram_left -= delta
				var to_boat: Vector2 = boat_position - position
				var reach: float = tuning.beast_speed * delta
				if not to_boat.is_zero_approx():
					direction = to_boat.normalized()
				if to_boat.length() - reach <= tuning.beast_hit_radius:
					position = boat_position - direction * minf(tuning.beast_hit_radius, to_boat.length())
					hit = Hit.new()
					hit.hull = hull_hit(boat_position, boat_rotation)
					hit.shove = toward_middle * tuning.beast_shove
					_dive(tuning.beast_dive_time if random_visit else tuning.beast_pause)
				elif ram_left <= 0.0:
					# Outrun: the ram gives up without a hit.
					_dive(tuning.beast_dive_time)
				else:
					position += direction * reach
		State.DIVING:
			time_left -= delta
			if time_left <= 0.0:
				state = State.SUBMERGED
				time_left = 0.0
				random_visit = false
				roll_left = ROLL_INTERVAL
	return hit


## The fin surfaces on the side away from the middle and starts circling.
func _rise(boat_position: Vector2, random: bool) -> void:
	state = State.CIRCLING
	random_visit = random
	time_left = tuning.beast_warning
	toward_middle = middle_direction(boat_position)
	angle = (-toward_middle).angle()
	position = boat_position + Vector2.from_angle(angle) * CIRCLE_RADIUS
	direction = Vector2.from_angle(angle + PI * 0.5)


## The head surfaces beast_ram_distance from the boat on the side away from the middle and
## charges, with beast_ram_timeout to land the hit.
func _ram(boat_position: Vector2) -> void:
	state = State.RAMMING
	time_left = 0.0
	ram_left = tuning.beast_ram_timeout
	toward_middle = middle_direction(boat_position)
	position = boat_position - toward_middle * tuning.beast_ram_distance
	direction = toward_middle


## Under water for `seconds`.
func _dive(seconds: float) -> void:
	state = State.DIVING
	time_left = seconds
	ram_left = 0.0
