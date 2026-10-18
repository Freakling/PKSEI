class_name LakeTuning
extends Resource
## LakeTuning · the lake's tunables (GDD › Systems › Lake and island; GDD › Systems › Hazards,
## Placement).
##
## Schema only. The instance the human tunes is data/lake_tuning.tres; the lake scene
## (scripts/lake.gd) reads the island, Hazards.plan() the bands and the path. The curve maps a
## band's place in the lake (x: 0 the first band, 1 the island band) to hazards per band (y);
## Curves.ramp() builds a straight one.

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
@export var density_curve: Curve = Curves.ramp(1.0, 3.0) ## PLACEHOLDER
## Width in pixels of the guaranteed path: the corridor no object is placed in, measured across
## the lake. A corridor as wide as the lake leaves nowhere to place anything.
@export var path_width: float = 120.0 ## PLACEHOLDER
## Pixels either side of the corridor's centre within which an object's centre is placed, so the
## obstacles crowd the path; 0 places objects over the whole lake. An object's footprint still keeps
## path_width / 2 + its half_width clear, so a spread no wider than that leaves an object no water
## (a fishing line, half_width 200, needs a spread above 260 to fit).
@export var object_spread: float = 300.0 ## PLACEHOLDER
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
## Pixels ahead of the trigger (toward the island) the motorboat's course runs; the wake's V
## trails it along that line.
@export var wake_lead: float = 160.0 ## PLACEHOLDER
## Pixels per second the two wake fronts spread outward (away from the course) once the motorboat
## has crossed.
@export var wake_speed: float = 60.0 ## PLACEHOLDER
## Degrees either side of the motorboat's course at which the two wake fronts trail behind it
## (the half-angle of the V).
@export var wake_angle: float = 30.0 ## PLACEHOLDER
## Degrees either side of straight into or straight away from a front's normal within which the
## front passes under the boat harmlessly; any other heading is broadside.
@export var wake_head_on_angle: float = 20.0 ## PLACEHOLDER
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
## Jet-ski idiot (the Jet-ski idiot row; read by JetSki, scripts/systems/jetski.gd).
## Pixels from a jet-ski trigger within which the boat sets the event off.
@export var jetski_trigger_radius: float = 240.0 ## PLACEHOLDER
## Seconds of noise from offscreen before the jet-ski appears: the warning.
@export var jetski_warning: float = 1.5 ## PLACEHOLDER
## Pixels per second the jet-ski crosses the lake at, from off-screen on one side to the other.
@export var jetski_speed: float = 480.0 ## PLACEHOLDER
## Pixels ahead of the boat (toward the island), as it was when the crossing started, the
## jet-ski's straight line runs through.
@export var jetski_lead: float = 120.0 ## PLACEHOLDER
## Pixels from the boat's centre within which the jet-ski's path counts as a hit.
@export var jetski_hit_radius: float = 28.0 ## PLACEHOLDER
## Pixels per second a hit shoves the boat along the jet-ski's travel: hard.
@export var jetski_shove: float = 240.0 ## PLACEHOLDER
## Fishing line (the Fishing line row; read by scripts/hazards/fishing_line.gd).
## Pixels the line runs sideways from its dinghy, across the water.
@export var line_length: float = 200.0 ## PLACEHOLDER
## Seconds a crossing of the line snags the paddle on the side that crossed it.
@export var snag_time: float = 3.0 ## PLACEHOLDER
## The Loch-Brez beast (the Loch-Brez beast row; read by Beast, scripts/systems/beast.gd).
## Pixels in from either edge of lake_width within which the boat has strayed too far and the
## beast rises.
@export var beast_edge_margin: float = 120.0 ## PLACEHOLDER
## Pixels past the island's centre (up-screen, beyond its far side) at which the beast rises.
@export var beast_beyond_island: float = 200.0 ## PLACEHOLDER
## Pixels inside the out-of-bounds line (beast_edge_margin in from either edge, beast_beyond_island
## past the island) where the warning band starts: a guy calls out `edge` when the boat comes into
## it from inside (T69; read by Beast, scripts/systems/beast.gd).
@export var beast_warn_margin: float = 200.0 ## PLACEHOLDER
## Seconds the fin circles the boat before the ram: the warning.
@export var beast_warning: float = 2.5 ## PLACEHOLDER
## Pixels per second the beast closes on the boat at while it rams.
@export var beast_speed: float = 200.0 ## PLACEHOLDER
## Pixels from the boat the head surfaces at when the ram starts, on the side away from the middle.
@export var beast_ram_distance: float = 160.0 ## PLACEHOLDER
## Pixels from the boat's centre within which the ram is a hit.
@export var beast_hit_radius: float = 24.0 ## PLACEHOLDER
## Seconds a ram lasts at most: one that hasn't hit by then (the boat outran it) gives up and
## dives for beast_dive_time.
@export var beast_ram_timeout: float = 6.0 ## PLACEHOLDER
## Pixels per second the ram shoves the boat back toward the lake's middle: hard.
@export var beast_shove: float = 260.0 ## PLACEHOLDER
## Pixels back toward the shore (down-screen) from the boat the grabbed guy is spat out at.
@export var beast_spit_distance: float = 150.0 ## PLACEHOLDER
## Seconds under water between rams while the boat stays out of bounds.
@export var beast_pause: float = 1.5 ## PLACEHOLDER
## Seconds under water after the random visit's grab, after a ram that gave up, or after the boat
## came back inside.
@export var beast_dive_time: float = 2.0 ## PLACEHOLDER
## Chance per roll, rolled once a second while the boat is inside the bounds and in open water,
## that the beast rises anyway for one grab. Zero: the beast is never a random encounter; it
## comes only out of bounds and when a puke calls it (beast_puke_chance). The roll stays so a
## lake could turn it back on; a five-minute crossing is 300 rolls, expecting rate × 300 visits.
@export var beast_random_rate: float = 0.0 ## PLACEHOLDER
## Chance that a guy's puke, heard while the beast is under and the boat is in open water, draws
## it up for one grab: the random visit again (T64; GDD › Drunkenness: "about one in fifty").
@export var beast_puke_chance: float = 0.02 ## PLACEHOLDER
## Pixels from a log or a rock within which, with the boat heading toward it, a guy calls it out
## in a bubble (T56; read by scripts/hazards/log.gd and rock.gd). Objects have no warning of their
## own: being ahead on the path is theirs.
@export var call_out_distance: float = 160.0 ## PLACEHOLDER
## The hazards a band draws from, each with its weight and first band (data/hazards/*.tres).
@export var hazards: Array[HazardSpec] = []
