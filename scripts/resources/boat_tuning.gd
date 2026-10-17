class_name BoatTuning
extends Resource
## BoatTuning · the catamaran's tunables (GDD › Systems › Catamaran and paddling).
##
## Schema only. The instance the human tunes is data/boat_tuning.tres; Paddling reads the stroke
## and current values, RunState the loose-things drift, the boat scene (scripts/catamaran.gd) the
## motion ones.

## Power of a tapped stroke (key held for no time).
@export var stroke_force_min: float = 20.0 ## PLACEHOLDER
## Power of a fully charged stroke (key held for charge_time or longer).
@export var stroke_force_max: float = 100.0 ## PLACEHOLDER
## Seconds the key must be held to reach stroke_force_max.
@export var charge_time: float = 1.0 ## PLACEHOLDER
## Yaw per unit of stroke force, before the seat's steer share.
@export var turn_torque: float = 1.0 ## PLACEHOLDER
## Share of turn_torque a front-seat stroke steers with (back/front meant to feel like 80/20).
@export var steer_share_front: float = 0.2 ## PLACEHOLDER
## Share of turn_torque a back-seat stroke steers with.
@export var steer_share_back: float = 0.8 ## PLACEHOLDER
## Speed of the current toward the shore, in pixels per second (the boat applies it as velocity).
@export var current_speed: float = 10.0 ## PLACEHOLDER
## Multiplier on current_speed while nobody is aboard: an empty boat drifts home this many times
## faster (GDD › Systems › Setbacks). A harsh-wind stretch's extra drift is not multiplied. Read by RunState.
@export var empty_drift_multiplier: float = 5.0 ## PLACEHOLDER
## Pixels per second the wind carries beers and swimmers back toward the shore; larger than
## current_speed (GDD › Systems › Catamaran and paddling). Read by RunState, passed to Rescue.
@export var loose_drift_speed: float = 30.0 ## PLACEHOLDER
## Pixels the camera leads the boat by at full speed, toward its direction of travel
## (GDD › Presentation and Platforms, Camera). Read by scripts/lake_camera.gd.
@export var camera_lead: float = 80.0 ## PLACEHOLDER

## Rescue (GDD › Systems › Setbacks; read by Rescue through RunState).
## How fast a guy swims for his beer, in pixels per second through the water (on top of the current).
@export var swim_speed: float = 30.0 ## PLACEHOLDER
## Pixels a beer knocked overboard lands from the boat's centre, to the side the hazard hit.
@export var beer_toss: float = 32.0 ## PLACEHOLDER
## Seconds a beer overboard bobs away while its guy winds up aboard, before he jumps in after it
## (GDD › Setbacks: "two or three seconds"). Read by RunState, passed to Rescue.
@export var jump_delay: float = 2.5 ## PLACEHOLDER
## Pixels from the boat's centre within which a floating guy is picked up (the lake checks it).
@export var pickup_radius: float = 20.0 ## PLACEHOLDER
## Pixels above the shoreline (y = 0) where everything loose stops (B2): no beer or swimmer drifts
## past y = -shore_margin, so a washed-up guy lies within pickup_radius of a boat resting at the
## shore. Read by Rescue.
@export var shore_margin: float = 40.0 ## PLACEHOLDER
## Water a guy bails out per second while his hull has water aboard (the water aboard effect,
## GDD › Systems › Hazards); his seat gives no strokes meanwhile. Read by RunState.
@export var bail_rate: float = 1.0 ## PLACEHOLDER
## Seconds after a beer goes over during which no further beer goes over; hits inside the window
## still shove or stop the boat (GDD › Systems › Hazards, Beer overboard). Read by RunState.
@export var beer_loss_cooldown: float = 2.0 ## PLACEHOLDER

## Pixels per second of speed one unit of stroke force adds.
@export var thrust_scale: float = 0.5 ## PLACEHOLDER
## Radians per second of yaw one unit of turn adds.
@export var turn_scale: float = 0.01 ## PLACEHOLDER
## The water's drag on speed, per second.
@export var linear_damping: float = 1.0 ## PLACEHOLDER
## The water's drag on yaw, per second.
@export var angular_damping: float = 3.0 ## PLACEHOLDER
