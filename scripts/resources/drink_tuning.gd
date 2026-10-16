class_name DrinkTuning
extends Resource
## DrinkTuning · the crate's tunables (GDD › Systems › Drunkenness, GDD › Core Loop › Starting
## conditions).
##
## Schema only. The instance the human tunes is data/drink_tuning.tres; Drunkenness reads it.
## Levels are on a 0..1 scale, 0 sober and 1 blind drunk, the scale of RunState.Guy.drunkenness.
## The two curves map the level (x, 0..1) to an effect (y); ramp() builds a straight one.

## Level every guy starts the crossing with: "mildly tipsy".
@export var start_level: float = 0.15 ## PLACEHOLDER
## Level a guy gains per second while he paddles.
@export var drink_rate: float = 0.004 ## PLACEHOLDER
## drink_rate is multiplied by this while a guy is on a stamina break.
@export var break_drink_multiplier: float = 3.0 ## PLACEHOLDER
## drink_rate is multiplied by this while a guy floats in the water with his beer.
@export var water_drink_multiplier: float = 5.0 ## PLACEHOLDER
## Seconds a stroke lands after the release (y) against the level (x).
@export var lag_curve: Curve = ramp(0.0, 0.6) ## PLACEHOLDER
## Chance 0..1 that a stroke never lands (y) against the level (x).
@export var miss_curve: Curve = ramp(0.0, 0.35) ## PLACEHOLDER
## Level at and above which a guy's key drives another seat (the top tier).
@export var scramble_level: float = 0.85 ## PLACEHOLDER


## A straight line from (0, y_sober) to (1, y_blind): linear tangents, so sample(x) is the lerp.
static func ramp(y_sober: float, y_blind: float) -> Curve:
	var curve: Curve = Curve.new()
	curve.min_value = minf(0.0, minf(y_sober, y_blind))
	curve.max_value = maxf(1.0, maxf(y_sober, y_blind))
	var slope: float = y_blind - y_sober
	curve.add_point(Vector2(0.0, y_sober), slope, slope, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(1.0, y_blind), slope, slope, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve
