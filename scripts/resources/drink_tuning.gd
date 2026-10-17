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
## Seconds the bar applies after its wind-up before it ends, whatever his level (GDD: "ten to
## fifteen seconds at most").
@export var bar_duration: float = 12.0 ## PLACEHOLDER
## Seconds after the bar ends before it can be announced again, if he is still at or above
## bar_level.
@export var bar_cooldown: float = 20.0 ## PLACEHOLDER
## Antics (the middle tier, Antics): levels at which a guy does something stupid, each once per
## attempt the first time his level reaches it; rising order.
@export var antic_thresholds: Array[float] = [0.4, 0.55, 0.7] ## PLACEHOLDER
## Seconds between a guy crossing a threshold and his antic starting: the visible wind-up.
@export var windup_time: float = 1.5 ## PLACEHOLDER
## Seconds a guy who stands up rocks the boat before he sits down.
@export var stand_time: float = 3.0 ## PLACEHOLDER
## Yaw impulse per second (the scale of Paddling.Motion.turn) a standing guy's rock puts on the
## boat at the peak of each swing; it swings side to side.
@export var stand_rock: float = 60.0 ## PLACEHOLDER
## Seconds for one full side-to-side rock of a standing guy: the boat's yaw swings once per this.
@export var stand_rock_period: float = 1.0 ## PLACEHOLDER
## Seconds a guy who drops his paddle takes to fish it out; his seat gives no strokes meanwhile.
@export var fish_time: float = 4.0 ## PLACEHOLDER
## Seconds a guy who nods off is dead weight; his seat gives no strokes meanwhile.
@export var nap_time: float = 5.0 ## PLACEHOLDER
## Seconds a guy pees at the hull's edge; his seat gives no strokes meanwhile.
@export var pee_time: float = 6.0 ## PLACEHOLDER
## A shove (lake pixels per second, RunState.shove) of this or more while he pees knocks him in.
@export var pee_fall_shove: float = 100.0 ## PLACEHOLDER
## Level a guy's drunkenness drops by when he finishes a pee (not when he is knocked in).
@export var pee_relief: float = 0.08 ## PLACEHOLDER
## Level at and above which a guy aboard pukes overboard (the top of the meter): a wind-up, then
## his seat is out for puke_time, then his level drops by puke_relief. He pukes again only after
## his level has dipped below this and reached it again.
@export var puke_level: float = 1.0 ## PLACEHOLDER
## Seconds a guy leans over the side puking; his seat gives no strokes meanwhile.
@export var puke_time: float = 3.0 ## PLACEHOLDER
## Level a guy's drunkenness drops by when his puke ends.
@export var puke_relief: float = 0.4 ## PLACEHOLDER
