class_name Drunkenness
extends RefCounted
## Drunkenness · how fast the four guys drink and what it does to their strokes
## (GDD › Systems › Drunkenness, GDD › Core Loop › Starting conditions).
##
## A plain rule class: it receives its DrinkTuning and never touches the scene tree or RunState.
## It holds one level per seat (seats equal RunState.Guy.seat and Paddling.Seat) on a 0..1 scale,
## 0 sober and 1 blind drunk. Each step the caller says how a guy spent it: paddling, on a stamina
## break, or floating in the water with his beer. A swimmer without a beer (he fell in while
## peeing) is stepped with both flags false, since he isn't drinking.
##
## Lag and misses: stroke_delay() and miss_chance() read the tuning's curves at a level; whether
## a stroke misses is rolled by misses() from the caller's RandomNumberGenerator, so tests seed it.
##
## Scrambled keys, the top tier: at scramble_level and above a guy's key drives the seat beside
## him on the other hull (scramble_target), the same seat every time, so the mapping is steady
## until his level drops below scramble_level. The wind-up and the on-screen marker belong to the
## boat scene; it asks scrambled() and key_target(). Antics (the middle tier) are T13's.

var tuning: DrinkTuning
## One level per seat, 0..1.
var levels: Array[float] = []


func _init(drink_tuning: DrinkTuning) -> void:
	tuning = drink_tuning
	reset()


## Every guy back to start_level (the starting conditions and the shore reset).
func reset() -> void:
	levels.clear()
	for seat: int in Paddling.Seat.size():
		levels.append(clampf(tuning.start_level, 0.0, 1.0))


func level_of(seat: int) -> float:
	return levels[seat]


func set_level(seat: int, level: float) -> void:
	levels[seat] = clampf(level, 0.0, 1.0)


## Advances one guy's level by `delta` seconds of paddling, a break or floating, and returns it.
func drink(seat: int, delta: float, on_break: bool, in_water: bool) -> float:
	levels[seat] = advance(levels[seat], delta, on_break, in_water)
	return levels[seat]


## The level `delta` seconds after `level`: drink_rate per second, times the break or water
## multiplier, capped at 1.
func advance(level: float, delta: float, on_break: bool, in_water: bool) -> float:
	var gained: float = tuning.drink_rate * drink_multiplier(on_break, in_water) * delta
	return clampf(level + gained, 0.0, 1.0)


## water_drink_multiplier in the water, else break_drink_multiplier on a break, else 1.
## A guy can't float and take a break at once; if both are flagged, the water rate wins.
func drink_multiplier(on_break: bool, in_water: bool) -> float:
	if in_water:
		return tuning.water_drink_multiplier
	if on_break:
		return tuning.break_drink_multiplier
	return 1.0


## Seconds a stroke released at this level lands after the release, per lag_curve.
func stroke_delay(level: float) -> float:
	return maxf(_sample(tuning.lag_curve, level), 0.0)


## Chance 0..1 that a stroke released at this level never lands, per miss_curve.
func miss_chance(level: float) -> float:
	return clampf(_sample(tuning.miss_curve, level), 0.0, 1.0)


## Rolls one stroke at this level: true when it misses.
func misses(level: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < miss_chance(level)


## Whether this guy's level is at scramble_level or above, so his key isn't his.
func scrambled(seat: int) -> bool:
	return levels[seat] >= tuning.scramble_level


## The seat this guy's key drives right now: his own, or scramble_target while scrambled.
func key_target(seat: int) -> int:
	return scramble_target(seat) if scrambled(seat) else seat


## The seat a scrambled key drives: the guy beside him on the other hull, front to front and
## back to back, so the mapping is fixed by the seat and never changes while he stays scrambled.
static func scramble_target(seat: int) -> int:
	match seat:
		Paddling.Seat.LEFT_FRONT:
			return Paddling.Seat.RIGHT_FRONT
		Paddling.Seat.LEFT_BACK:
			return Paddling.Seat.RIGHT_BACK
		Paddling.Seat.RIGHT_FRONT:
			return Paddling.Seat.LEFT_FRONT
		_:
			return Paddling.Seat.LEFT_BACK


## A missing curve means no effect at any level.
static func _sample(curve: Curve, level: float) -> float:
	if curve == null:
		return 0.0
	return curve.sample(clampf(level, 0.0, 1.0))
