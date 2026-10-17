class_name StaminaTuning
extends Resource
## StaminaTuning · the guys' stamina tunables (GDD › Systems › Stamina, GDD › Core Loop › Moment
## to moment).
##
## Schema only. The instance the human tunes is data/stamina_tuning.tres; Stamina reads it.
## Stamina is on a 0..1 scale, 0 burnt out and 1 full, the scale of RunState.Guy.stamina.
## Power is the stroke force Paddling.stroke_force() computes (BoatTuning's stroke_force_min to
## stroke_force_max). The curve maps the burnt fraction (x = 1 − stamina, 0..1) to a chance per
## second (y); Curves.ramp() builds a straight one.

## Stamina a stroke burns per unit of its power.
@export var burn_per_power: float = 0.003 ## PLACEHOLDER
## Stamina a guy regains per second while he paddles or waits for a break (the warning).
@export var recover_rate: float = 0.05 ## PLACEHOLDER
## Stamina a guy regains per second while he is on a break.
@export var break_recover_rate: float = 0.25 ## PLACEHOLDER
## Seconds a break lasts: no strokes from his seat, fast recovery.
@export var break_duration: float = 3.0 ## PLACEHOLDER
## Seconds a break is telegraphed on the guy before it starts; he still paddles meanwhile.
@export var break_warning: float = 1.5 ## PLACEHOLDER
## Chance per second 0..1 that a guy takes a break before he is burnt out (y) against the
## fraction of his stamina he has burnt (x, 0 full to 1 burnt out).
@export var random_break_curve: Curve = Curves.ramp(0.0, 0.2) ## PLACEHOLDER
