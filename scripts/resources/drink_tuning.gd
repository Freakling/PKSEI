class_name DrinkTuning
extends Resource
## DrinkTuning · the crate's tunables (GDD › Systems › Drunkenness, GDD › Core Loop › Starting
## conditions).
##
## Schema only. The instance the human tunes is data/drink_tuning.tres; Drunkenness reads it.
## Levels are on a 0..1 scale, 0 sober and 1 blind drunk, the scale of RunState.Guy.drunkenness.
## The two curves map the level (x, 0..1) to an effect (y); Curves.ramp() builds a straight one.

## Level every guy starts the crossing with: "mildly tipsy".
@export var start_level: float = 0.15 ## PLACEHOLDER
## Level a guy gains per second while he paddles.
@export var drink_rate: float = 0.004 ## PLACEHOLDER
## drink_rate is multiplied by this while a guy is on a stamina break.
@export var break_drink_multiplier: float = 3.0 ## PLACEHOLDER
## drink_rate is multiplied by this while a guy floats in the water with his beer.
@export var water_drink_multiplier: float = 5.0 ## PLACEHOLDER
## Seconds a stroke lands after the release (y) against the level (x).
@export var lag_curve: Curve = Curves.ramp(0.0, 0.6) ## PLACEHOLDER
## Chance 0..1 that a stroke never lands (y) against the level (x).
@export var miss_curve: Curve = Curves.ramp(0.0, 0.35) ## PLACEHOLDER
## Level at and above which a guy's strokes go through the timing bar (the top tier).
@export var bar_level: float = 0.85 ## PLACEHOLDER
## Seconds the timing bar takes for one full sweep, there and back.
@export var bar_period: float = 1.0 ## PLACEHOLDER
## Width of the bar's green zone as a fraction 0..1 of the bar, centred on its middle.
@export var green_width: float = 0.2 ## PLACEHOLDER
