class_name Drunkenness
extends RefCounted
## Drunkenness · how fast the four guys drink and what it does to their strokes
## (GDD › Systems › Drunkenness, GDD › Core Loop › Starting conditions).
##
## A plain rule class: it receives its DrinkTuning and never touches the scene tree or RunState.
## It holds one level per seat (seats equal RunState.Guy.seat and Paddling.Seat) on a 0..1 scale,
## 0 sober and 1 blind drunk. Each step the caller says how a guy spent it: paddling, on a stamina
## break, or floating in the water; and whether he is drinking at all, which a swimmer without a
## beer (he fell in while peeing) isn't, so his level holds.
##
## Lag and misses: stroke_delay() and miss_chance() read the tuning's curves at a level; whether
## a stroke misses is rolled by misses() from the caller's RandomNumberGenerator, so tests seed it.
##
## Seeing double, the top tier: at double_level and above a guy's controls reverse. While it
## lasts (reversed()) his forward key paddles in reverse (the weaker reverse stroke) and his
## reverse key paddles forward, every stroke whatever the hold time; RunState applies that. The
## tier runs a small cycle per seat (DoublePhase), tracked here as the levels change: crossing
## double_level is announced with a wind-up of DOUBLE_WINDUP seconds (double_winding_up() true,
## reversed() still false); the controls then stay reversed for double_duration (reversed()), it
## ends, and after double_cooldown more seconds, if he is still at or above double_level, the
## wind-up and the reversal come again (T65, T89; GDD: "it lasts ten to fifteen seconds at most
## ... it can return after a while if he is still that drunk"). Dropping below double_level ends
## whichever phase runs and forgets the cooldown, so the next crossing is announced at once. The
## cycle's clock stops while he is in the water (drink()'s in_water), so a crossing there is
## registered and the wind-up waits, full, until he is back aboard. The boat scene shows the
## wind-up and the reversal as the guy swaying. Antics (the middle tier) are run by the Antics
## class.

## Seconds between a guy crossing double_level and his controls reversing: the tier's
## wind-up (GDD › Drunkenness: "announced with a wind-up"). Cosmetic timing, not a tunable.
const DOUBLE_WINDUP: float = 1.5

## Where a seat is in the seeing-double tier's cycle: OFF below double_level; at or above it WINDING_UP
## (DOUBLE_WINDUP) → ON (double_duration) → COOLING (double_cooldown) → WINDING_UP again.
enum DoublePhase { OFF, WINDING_UP, ON, COOLING }

var tuning: DrinkTuning
## One level per seat, 0..1.
var levels: Array[float] = []
## The seeing-double tier's phase per seat.
var _double_phase: Array[DoublePhase] = []
## Seconds left of the phase per seat; 0 while OFF.
var _double_time: Array[float] = []


func _init(drink_tuning: DrinkTuning) -> void:
	tuning = drink_tuning
	reset()


## Every guy back to start_level (the starting conditions and the shore reset), the seeing-double tier
## forgotten.
func reset() -> void:
	levels.clear()
	_double_phase.clear()
	_double_time.clear()
	for seat: int in Paddling.Seat.size():
		levels.append(clampf(tuning.start_level, 0.0, 1.0))
		_double_phase.append(DoublePhase.OFF)
		_double_time.append(0.0)
		_track_double_tier(seat, 0.0)


func level_of(seat: int) -> float:
	return levels[seat]


func set_level(seat: int, level: float) -> void:
	levels[seat] = clampf(level, 0.0, 1.0)
	_track_double_tier(seat, 0.0)


## Lowers one guy's level by `amount` (a finished pee's pee_relief, a puke's puke_relief; T63,
## GDD › Drunkenness: "drunkenness also comes down"), never below 0, and returns it. Dropping
## below double_level ends the seeing-double tier like any other fall.
func relieve(seat: int, amount: float) -> float:
	levels[seat] = clampf(levels[seat] - maxf(amount, 0.0), 0.0, 1.0)
	_track_double_tier(seat, 0.0)
	return levels[seat]


## Advances one guy's level by `delta` seconds of paddling, a break or floating, and returns it;
## with `drinking` false (a swimmer with no beer) it holds. The tier's clock (wind-up, reversal
## and cooldown) counts down by `delta` whether he drinks or not, but not while he is
## `in_water`: his square and the announcement are hidden there, so a crossing in the water is
## registered and the wind-up waits, full, until he is back aboard.
func drink(seat: int, delta: float, on_break: bool, in_water: bool, drinking: bool = true) -> float:
	levels[seat] = advance(levels[seat], delta, on_break, in_water, drinking)
	_track_double_tier(seat, 0.0 if in_water else delta)
	return levels[seat]


## The level `delta` seconds after `level`: drink_rate per second, times the break or water
## multiplier, capped at 1; unchanged when he isn't `drinking`.
func advance(level: float, delta: float, on_break: bool, in_water: bool, drinking: bool = true) -> float:
	if not drinking:
		return level
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


## Whether this guy's controls are reversed: at double_level or above, wind-up over, and
## double_duration not yet up.
func reversed(seat: int) -> bool:
	return _double_phase[seat] == DoublePhase.ON


## Whether his seeing double is being announced: he has just crossed double_level, or its
## cooldown has just run out with him still there.
func double_winding_up(seat: int) -> bool:
	return _double_phase[seat] == DoublePhase.WINDING_UP


## Follows a level change for one seat through the tier's cycle: below double_level everything is
## off; crossing up to it starts the wind-up; `delta` seconds at or above it (0 when the time
## must not count, as in the water) run the phase's clock down, and at 0 the next phase starts:
## wind-up → reversed (double_duration) → cooldown (double_cooldown) → wind-up again.
func _track_double_tier(seat: int, delta: float) -> void:
	if levels[seat] < tuning.double_level:
		_double_phase[seat] = DoublePhase.OFF
		_double_time[seat] = 0.0
		return
	if _double_phase[seat] == DoublePhase.OFF:
		_enter_double_phase(seat, DoublePhase.WINDING_UP)
		return
	_double_time[seat] = maxf(_double_time[seat] - delta, 0.0)
	if _double_time[seat] > 0.0:
		return
	match _double_phase[seat]:
		DoublePhase.WINDING_UP:
			_enter_double_phase(seat, DoublePhase.ON)
		DoublePhase.ON:
			_enter_double_phase(seat, DoublePhase.COOLING)
		DoublePhase.COOLING:
			_enter_double_phase(seat, DoublePhase.WINDING_UP)


## Starts one phase of the cycle with its full time: DOUBLE_WINDUP, double_duration or double_cooldown.
## The dev menu's inspector (T72, tools/dev_menu.gd): per seat, the level and the seeing-double tier.
func debug_inspect() -> Dictionary:
	var values: Dictionary = {}
	for seat: int in levels.size():
		var tier: String = "on" if reversed(seat) else ("winding up" if double_winding_up(seat) else "off")
		values["seat %d" % seat] = "level %.2f, seeing double %s" % [levels[seat], tier]
	return values


func _enter_double_phase(seat: int, phase: DoublePhase) -> void:
	_double_phase[seat] = phase
	match phase:
		DoublePhase.WINDING_UP:
			_double_time[seat] = DOUBLE_WINDUP
		DoublePhase.ON:
			_double_time[seat] = tuning.double_duration
		DoublePhase.COOLING:
			_double_time[seat] = tuning.double_cooldown
		_:
			_double_time[seat] = 0.0


## A missing curve means no effect at any level.
static func _sample(curve: Curve, level: float) -> float:
	if curve == null:
		return 0.0
	return curve.sample(clampf(level, 0.0, 1.0))
