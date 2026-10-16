class_name BoatTuning
extends Resource
## BoatTuning · the catamaran's tunables (GDD › Systems › Catamaran and paddling).
##
## Schema only. The instance the human tunes is data/boat_tuning.tres; Paddling reads the stroke
## and current values, the boat scene (scripts/catamaran.gd) the motion ones.

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

## Pixels per second of speed one unit of stroke force adds.
@export var thrust_scale: float = 0.5 ## PLACEHOLDER
## Radians per second of yaw one unit of turn adds.
@export var turn_scale: float = 0.01 ## PLACEHOLDER
## The water's drag on speed, per second.
@export var linear_damping: float = 1.0 ## PLACEHOLDER
## The water's drag on yaw, per second.
@export var angular_damping: float = 3.0 ## PLACEHOLDER
