class_name LakeTuning
extends Resource
## LakeTuning · the lake's tunables (GDD › Systems › Lake and island).
##
## Schema only. The instance the human tunes is data/lake_tuning.tres; the lake scene
## (scripts/lake.gd) reads it. T10 adds the hazard bands here.

## Pixels from the shore line (y = 0) to the island's centre. The first lake is short.
@export var island_distance: float = 800.0 ## PLACEHOLDER
