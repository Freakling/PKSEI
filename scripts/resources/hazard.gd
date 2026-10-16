class_name HazardSpec
extends Resource
## HazardSpec · one kind of hazard the lake can place (GDD › Systems › Hazards, Placement).
##
## Schema only. One instance per hazard in data/hazards/*.tres, listed in LakeTuning.hazards;
## Hazards.plan() draws from that list by weight and first_band, and lake.gd instances `scene`
## at each placement and hands the instance this spec as `spec`, so the hazard's strengths are
## tuned here and not in its script.

## The hazard's scene (scenes/hazards/*.tscn, script in scripts/hazards/).
@export var scene: PackedScene
## Its share of a band's draws against the other hazards allowed there; 0 never draws it.
@export var weight: float = 1.0 ## PLACEHOLDER
## The first band (0 is the shore band) that may draw it; bands before it never do.
@export var first_band: int = 0 ## PLACEHOLDER
## Pixels per second a hit pushes the boat away from the hazard (the shove effect).
@export var shove_strength: float = 80.0 ## PLACEHOLDER
## Seconds after a hit before the same hazard can hit again, so one bump is one hit.
@export var hit_cooldown: float = 1.0 ## PLACEHOLDER
