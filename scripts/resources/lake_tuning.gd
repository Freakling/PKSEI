class_name LakeTuning
extends Resource
## LakeTuning · the lake's tunables (GDD › Systems › Lake and island; GDD › Systems › Hazards,
## Placement).
##
## Schema only. The instance the human tunes is data/lake_tuning.tres; the lake scene
## (scripts/lake.gd) reads the island, Hazards.plan() the bands and the path. The curve maps a
## band's place in the lake (x: 0 the first band, 1 the island band) to hazards per band (y);
## DrinkTuning.ramp() builds a straight one.

## Pixels from the shore line (y = 0) to the island's centre.
@export var island_distance: float = 800.0 ## PLACEHOLDER
## The island's radius in pixels: its collision circle, and where the planned hazards stop.
@export var island_radius: float = 60.0 ## PLACEHOLDER
## Pixels of water off the shore line kept clear of hazards: the beach and the boat at launch.
@export var launch_margin: float = 96.0 ## PLACEHOLDER
## Width of the water hazards are placed across, in pixels, centred on x = 0.
@export var lake_width: float = 480.0 ## PLACEHOLDER
## Pixels of crossing per band; the open water between launch_margin and the island's near edge
## is ceil(span / band_length) bands, the last one possibly shorter.
@export var band_length: float = 160.0 ## PLACEHOLDER
## Hazards per band (y, rounded) against the band's place in the lake (x), rising toward the island.
@export var density_curve: Curve = DrinkTuning.ramp(1.0, 3.0) ## PLACEHOLDER
## Width in pixels of the guaranteed path: the corridor no object is placed in, measured across
## the lake. A corridor as wide as the lake leaves nowhere to place anything.
@export var path_width: float = 120.0 ## PLACEHOLDER
## Furthest the corridor's centre moves across the lake, in pixels, between one band's near edge
## and the next's; 0 makes the path a straight line up the middle.
@export var path_wander: float = 160.0 ## PLACEHOLDER
## Pixels from a geese nest within which the boat sets the flock hissing (the Angry geese row).
@export var geese_radius: float = 160.0 ## PLACEHOLDER
## Seconds of hissing and raised wings before the flock charges: the warning.
@export var geese_warning: float = 1.0 ## PLACEHOLDER
## Seconds the flock charges and pecks before it gives up and returns to the nest.
@export var geese_attack_time: float = 4.0 ## PLACEHOLDER
## Pixels per second the flock flies at, charging and returning.
@export var geese_speed: float = 140.0 ## PLACEHOLDER
## Seconds between pecks while the flock is within peck range of the boat; each is a beer overboard.
@export var geese_peck_interval: float = 1.0 ## PLACEHOLDER
## Pixels from the boat's centre within which the flock pecks.
@export var geese_peck_range: float = 40.0 ## PLACEHOLDER
## Seconds after returning to the nest before the flock can hiss again.
@export var geese_cooldown: float = 5.0 ## PLACEHOLDER
## Motorboat wake (the Motorboat wake row; read by MotorboatWake, scripts/systems/wake.gd).
## Pixels from a wake trigger within which the boat sets the event off.
@export var wake_trigger_radius: float = 240.0 ## PLACEHOLDER
## Pixels per second the motorboat crosses the lake at, from one edge of lake_width to the other.
@export var wake_boat_speed: float = 320.0 ## PLACEHOLDER
## Pixels ahead of the trigger (toward the island) the motorboat's course runs; the wave front
## starts there once it has crossed.
@export var wake_lead: float = 160.0 ## PLACEHOLDER
## Pixels per second the wave front rolls toward the shore.
@export var wake_speed: float = 60.0 ## PLACEHOLDER
## Degrees either side of straight into or straight away from the wave within which the front
## passes under the boat harmlessly; any other heading is broadside.
@export var wake_head_on_angle: float = 30.0 ## PLACEHOLDER
## Pixels per second a broadside hit shoves the boat sideways, away from the wave.
@export var wake_shove: float = 120.0 ## PLACEHOLDER
## Water a broadside hit puts aboard the high hull, bailed at BoatTuning.bail_rate per second.
@export var wake_water: float = 3.0 ## PLACEHOLDER
## Wind gust (the Wind gust row; read by WindGust, scripts/systems/gust.gd).
## Pixels from a gust trigger within which the boat sets the gust off.
@export var gust_trigger_radius: float = 200.0 ## PLACEHOLDER
## Seconds of ripples racing across the water before the push: the warning.
@export var gust_warning: float = 1.0 ## PLACEHOLDER
## Pixels per second the gust pushes the boat sideways across the lake while it blows.
@export var gust_shove: float = 60.0 ## PLACEHOLDER
## Seconds the push lasts.
@export var gust_time: float = 3.0 ## PLACEHOLDER
## Harsh wind (the Harsh wind row; read by Headwind, scripts/systems/headwind.gd).
## Pixels per second added to the current's pull toward the shore while the boat is inside a
## headwind stretch; a stroke has to outpace BoatTuning.current_speed plus this to gain water.
@export var headwind_force: float = 25.0 ## PLACEHOLDER
## Pixels of crossing a headwind stretch covers, from its trigger toward the island, across the
## whole lake_width; the whitecaps cover it.
@export var headwind_length: float = 400.0 ## PLACEHOLDER
## Cross-current stripe (the Cross-current stripe row; read by CrossCurrent, scripts/systems/cross_current.gd).
## Pixels per second the stripe pushes the boat sideways, in the stripe's direction, while the boat is inside it.
@export var stripe_force: float = 40.0 ## PLACEHOLDER
## Pixels of crossing a cross-current stripe covers, from its trigger toward the island, across the
## whole lake_width; the faster water covers it.
@export var stripe_length: float = 300.0 ## PLACEHOLDER
## The hazards a band draws from, each with its weight and first band (data/hazards/*.tres).
@export var hazards: Array[HazardSpec] = []
