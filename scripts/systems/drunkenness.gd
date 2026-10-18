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
## The timing bar, the top tier: at bar_level and above a guy's stroke is a timing test. While
## his key is held a bar sweeps 0→1→0 every bar_period seconds (bar_position); a release inside
## green_width of the centre is a hit (bar_hit) and gives the normal stroke, anything else a
## backwards one (RunState applies that). The tier runs a small cycle per seat (BarPhase), tracked
## here as the levels change: crossing bar_level is announced with a wind-up of BAR_WINDUP
## seconds (bar_winding_up() true, uses_bar() still false); the bar then applies for bar_duration
## (uses_bar()), ends, and after bar_cooldown more seconds, if he is still at or above bar_level,
## the wind-up and the bar come again (T65; GDD: "it lasts ten to fifteen seconds at most ... it
## can return after a while if he is still that drunk"). Dropping below bar_level ends whichever
## phase runs and forgets the cooldown, so the next crossing is announced at once. The cycle's
## clock stops while he is in the water (drink()'s in_water), so a crossing there is registered
## and the wind-up waits, full, until he is back aboard. The boat scene draws the bar and the
## wind-up. Antics (the middle tier) are run by the Antics class.

## Seconds between a guy crossing bar_level and the bar applying to his strokes: the tier's
## wind-up (GDD › Drunkenness: "announced with a wind-up"). Cosmetic timing, not a tunable.
const BAR_WINDUP: float = 1.5

## Where a seat is in the bar tier's cycle: OFF below bar_level; at or above it WINDING_UP
## (BAR_WINDUP) → ON (bar_duration) → COOLING (bar_cooldown) → WINDING_UP again.
enum BarPhase { OFF, WINDING_UP, ON, COOLING }

var tuning: DrinkTuning
## One level per seat, 0..1.
var levels: Array[float] = []
## The bar tier's phase per seat.
var _bar_phase: Array[BarPhase] = []
## Seconds left of the phase per seat; 0 while OFF.
var _bar_time: Array[float] = []


func _init(drink_tuning: DrinkTuning) -> void:
	tuning = drink_tuning
	reset()


## Every guy back to start_level (the starting conditions and the shore reset), the bar tier
## forgotten.
func reset() -> void:
	levels.clear()
	_bar_phase.clear()
	_bar_time.clear()
	for seat: int in Paddling.Seat.size():
		levels.append(clampf(tuning.start_level, 0.0, 1.0))
		_bar_phase.append(BarPhase.OFF)
		_bar_time.append(0.0)
		_track_bar_tier(seat, 0.0)


func level_of(seat: int) -> float:
	return levels[seat]


func set_level(seat: int, level: float) -> void:
	levels[seat] = clampf(level, 0.0, 1.0)
	_track_bar_tier(seat, 0.0)


## Lowers one guy's level by `amount` (a finished pee's pee_relief, a puke's puke_relief; T63,
## GDD › Drunkenness: "drunkenness also comes down"), never below 0, and returns it. Dropping
## below bar_level ends the bar tier like any other fall.
func relieve(seat: int, amount: float) -> float:
	levels[seat] = clampf(levels[seat] - maxf(amount, 0.0), 0.0, 1.0)
	_track_bar_tier(seat, 0.0)
	return levels[seat]


## Advances one guy's level by `delta` seconds of paddling, a break or floating, and returns it;
## with `drinking` false (a swimmer with no beer) it holds. The bar tier's clock (wind-up, bar
## and cooldown) counts down by `delta` whether he drinks or not, but not while he is
## `in_water`: his square and the announcement are hidden there, so a crossing in the water is
## registered and the wind-up waits, full, until he is back aboard.
func drink(seat: int, delta: float, on_break: bool, in_water: bool, drinking: bool = true) -> float:
	levels[seat] = advance(levels[seat], delta, on_break, in_water, drinking)
	_track_bar_tier(seat, 0.0 if in_water else delta)
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


## Whether the timing bar applies to this guy's strokes: at bar_level or above, wind-up over,
## and bar_duration not yet up.
func uses_bar(seat: int) -> bool:
	return _bar_phase[seat] == BarPhase.ON


## Whether this guy's bar is being announced: he has just crossed bar_level, or its cooldown has
## just run out with him still there.
func bar_winding_up(seat: int) -> bool:
	return _bar_phase[seat] == BarPhase.WINDING_UP


## Where the bar's marker is after the key has been held `hold_time` seconds: 0..1, sweeping
## 0→1→0 as a triangle wave once every bar_period seconds. Without a period it rests in the
## middle.
func bar_position(hold_time: float) -> float:
	if tuning.bar_period <= 0.0:
		return 0.5
	var phase: float = fposmod(hold_time, tuning.bar_period) / tuning.bar_period
	return 1.0 - absf(2.0 * phase - 1.0)


## Whether a release after `hold_time` seconds lands in the green zone: the marker within
## green_width / 2 of the bar's centre.
func bar_hit(hold_time: float) -> bool:
	return absf(bar_position(hold_time) - 0.5) <= tuning.green_width * 0.5


## Follows a level change for one seat through the tier's cycle: below bar_level everything is
## off; crossing up to it starts the wind-up; `delta` seconds at or above it (0 when the time
## must not count, as in the water) run the phase's clock down, and at 0 the next phase starts:
## wind-up → bar (bar_duration) → cooldown (bar_cooldown) → wind-up again.
func _track_bar_tier(seat: int, delta: float) -> void:
	if levels[seat] < tuning.bar_level:
		_bar_phase[seat] = BarPhase.OFF
		_bar_time[seat] = 0.0
		return
	if _bar_phase[seat] == BarPhase.OFF:
		_enter_bar_phase(seat, BarPhase.WINDING_UP)
		return
	_bar_time[seat] = maxf(_bar_time[seat] - delta, 0.0)
	if _bar_time[seat] > 0.0:
		return
	match _bar_phase[seat]:
		BarPhase.WINDING_UP:
			_enter_bar_phase(seat, BarPhase.ON)
		BarPhase.ON:
			_enter_bar_phase(seat, BarPhase.COOLING)
		BarPhase.COOLING:
			_enter_bar_phase(seat, BarPhase.WINDING_UP)


## Starts one phase of the cycle with its full time: BAR_WINDUP, bar_duration or bar_cooldown.
## The dev menu's inspector (T72, tools/dev_menu.gd): per seat, the level and the timing bar's tier.
func debug_inspect() -> Dictionary:
	var values: Dictionary = {}
	for seat: int in levels.size():
		var bar: String = "on" if uses_bar(seat) else ("winding up" if bar_winding_up(seat) else "off")
		values["seat %d" % seat] = "level %.2f, timing bar %s" % [levels[seat], bar]
	return values


func _enter_bar_phase(seat: int, phase: BarPhase) -> void:
	_bar_phase[seat] = phase
	match phase:
		BarPhase.WINDING_UP:
			_bar_time[seat] = BAR_WINDUP
		BarPhase.ON:
			_bar_time[seat] = tuning.bar_duration
		BarPhase.COOLING:
			_bar_time[seat] = tuning.bar_cooldown
		_:
			_bar_time[seat] = 0.0


## A missing curve means no effect at any level.
static func _sample(curve: Curve, level: float) -> float:
	if curve == null:
		return 0.0
	return curve.sample(clampf(level, 0.0, 1.0))
