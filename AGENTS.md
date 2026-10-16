# PKSEI

Four drunk guys have lashed two aluminium canoes into a catamaran and need to reach an island in the middle of the lake. You control all four at once. The lake throws random hazards at them, and they keep drinking, so the boat gets harder to control the longer the crossing takes. Nobody dies: a bad stretch drifts the boat back into water already crossed. A top-down, bright pixel-art rage game in the spirit of Getting Over It, played for the comedy of watching four idiots fail together.

Instructions for AI assistants working on this game. The workflow is Godot Director: its rules are in `.godot-director/rules.md`, which names the procedure for each kind of request. Read it before any work, unless your tool has already loaded it (Claude Code imports it: @.godot-director/rules.md).

## Project facts
- Godot 4.7 · GDScript · 2D, top-down · Web (HTML5, itch.io); desktop builds for development
- Rendering and window: GL Compatibility · 640×360 viewport, `canvas_items` stretch, aspect `keep`, integer scaling · nearest texture filter, 2D transforms snapped to pixels

## Layout
<!-- The real folders of this project. T2 creates them; keep this current when folders move. -->
| Folder | Holds |
|---|---|
| `scripts/autoload/` | autoloads: current state, signals |
| `scripts/systems/` | game-rule classes (`RefCounted`) |
| `scripts/resources/` | Resource schemas for tunable data |
| `scripts/ui/` | screen scripts (display only; checked by tools/check.cfg) |
| `scripts/` (root) | scene scripts: `catamaran.gd` (input, motion, telegraphs, debug beer keys F5/F6), `lake.gd` (island arrival, progress, swimmers, pickup, shore reset, hazard spawning from the plan, debug path overlay on F7; lake values in `LakeTuning`, `scripts/resources/lake_tuning.gd`, `data/lake_tuning.tres`), `lake_camera.gd` (follow with look-ahead by `BoatTuning.camera_lead`) |
| `scripts/hazards/` | hazard scene scripts (one per hazard; rules in `scripts/systems/hazards.gd`); their specs are `data/hazards/*.tres` (`HazardSpec`) |
| `scenes/` | scenes: `main.tscn` → `lake.tscn` (water, shore, island, camera, HUD) → `catamaran.tscn` (boat, guys); `scenes/hazards/` one scene per hazard |
| `data/` | `.tres` content: the values the human tunes |
| `tests/` | rule tests (`test_*.gd`) |
| `assets/sprites/`, `assets/audio/` | pixel art and sound (agent-made, human-reviewed; see Project rules) |
| `design/` | GDD, decisions and research notes (not loaded by Godot) |
| `playtesting/` | playtest template and reports (not loaded by Godot) |

## Architecture
One row per system: what it owns and where its boundary is. Screens depend on systems, never the other way round.

| System | Owns | Where | Talks to |
|---|---|---|---|
| `RunState` (autoload) | the current attempt: four `Guy`s (seat, drunkenness, stamina, aboard), progress 0..1 from shore to island, elapsed time, phase LAUNCH → CROSSING → WON; owns the `Paddling`, `Drunkenness`, `Stamina` and `Rescue` instances and one RNG; the hazard effects' state (pending shove and stop, per-seat snag timers, per-hull water and its bailer) and `lake_seed`; `new_attempt()` (draws `lake_seed`; a shore reset keeps it), `reset()`, `stroke(seat, hold_time)`, `step(delta, boat_at) -> Motion` (takes jumpers off the boat), `set_progress()`, `arrive()`, `beer_overboard(hull, at)`, `guy_overboard(seat, at)`, `pickup(seat)`, `shore_touched()` (resets only in CROSSING; a washed-up swimmer re-boards on his own in LAUNCH), `shove()`/`take_shove()`, `stop()`/`take_stop()`, `snag(hull, s)`, `force_break(hull)`, `water_aboard(hull, amount)`, `can_paddle(seat)` | `scripts/autoload/run_state.gd` | the boat scene calls `stroke`/`step` and applies the `Motion`; the lake sets progress, calls `arrive`, `pickup` and `shore_touched`; screens read it; emits `run_reset`, `shore_reset_done` |
| `Paddling` (rule class) | stroke events (seat, hold time, backwards) and a timestep into thrust, signed turn (+ = right) and drift toward the shore; seats enum matching RunState; tuning in `BoatTuning` (`scripts/resources/boat_tuning.gd`, `data/boat_tuning.tres`) | `scripts/systems/paddling.gd` | pure: receives `BoatTuning`; `RunState` owns the instance; `catamaran.gd` applies its `Motion` with the boat feel values in `BoatTuning` (thrust_scale, turn_scale, damping) |
| `Drunkenness` (rule class) | one 0..1 level per seat; drink rate by state (break, water, no beer); stroke delay and miss chance per level (`Curve`s); seeded miss roll; the timing bar at `bar_level` after a wind-up that waits while he is in the water (`uses_bar`, `bar_winding_up`, `bar_position`, `bar_hit`; `bar_period`, `green_width`); tuning in `DrinkTuning` (`scripts/resources/drink_tuning.gd`, `data/drink_tuning.tres`) | `scripts/systems/drunkenness.gd` | pure: receives `DrinkTuning` and an RNG; `RunState` owns the instance and steps it |
| `Stamina` (rule class) | one 0..1 level per seat; burn per stroke power, recovery; per-seat PADDLING → WARNING → BREAK machine (`can_stroke`, `time_left`, `call_break` for hazards); random breaks from the caller's RNG; tuning in `StaminaTuning` (`scripts/resources/stamina_tuning.gd`, `data/stamina_tuning.tres`) | `scripts/systems/stamina.gd` | pure: receives `StaminaTuning` and an RNG; `RunState` owns the instance and steps it; `catamaran.gd` reads its state for the telegraphs |
| `Hazards` (rule class) | hazard placement: the lake in bands of `band_length`, each drawing `density_curve` hazards from the weighted `HazardSpec` list (`weight`, `first_band`), positions within `lake_width` but never inside the guaranteed path, a corridor of `path_width` whose centre random-walks by at most `path_wander` per band from the launch to the island (`path_center`, `corridor_x(tuning, seed, y)`), all from one seed (`plan(tuning, seed)`; per band `plan_band(tuning, seed, band, generation)`, kept for the path and future events; objects are fixed and never refill) | `scripts/systems/hazards.gd` | pure; `lake.gd` spawns the planned scenes under its `Hazards` node from `RunState.lake_seed`; hazard scenes (`scripts/hazards/*.gd`) call `RunState`'s effect methods on contact |
| `GeeseFlock` (rule class) | one flock: NESTING → HISSING (warning) → CHARGING (pecks at an interval while in range, each a beer overboard on the nearest hull) → RETURNING → cooldown; its position and timers; tunables `geese_*` on `LakeTuning` | `scripts/systems/geese.gd` | pure; `scripts/hazards/geese.gd` steps it with the boat's position and applies pecks via `RunState.beer_overboard` |
| `MotorboatWake` (rule class) | one wake event: WAITING → CROSSING (a motorboat across the lake ahead of the trigger) → ROLLING (a front toward the shore at `wake_speed`) → SPENT; a head-on boat is untouched, a broadside one gets a beer overboard on the high hull, a sideways shove and water aboard; tunables `wake_*` on `LakeTuning` | `scripts/systems/wake.gd` | pure; `scripts/hazards/wake.gd` steps it with the boat's position and heading and applies the hit via `RunState` |
| `Rescue` (rule class) | the guys in the water and their beers: `LooseBeer` records (a beer bobbing away while its guy winds up for `jump_delay`), `Swimmer` records (seat, position, beer, SWIMMING → FLOATING, has_beer), who jumps for a beer on a hull, `step(delta, current, tuning, boat_at) -> seats that jumped`, `winding_up`, `within_reach`, `pickup`; no limit on swimmers; nothing loose drifts past the shoreline (`BoatTuning.shore_margin`), a floating guy there is `washed_up`; `guy_overboard` for beerless falls (pee antic; a guy winding up swims for his beer instead) | `scripts/systems/rescue.gd` | pure; `RunState` owns the instance; `lake.gd` draws swimmers and beers, picks up within `BoatTuning.pickup_radius`, and reports shore contact |

## Project rules
<!-- Only where this project differs from the Godot Director defaults, as agreed with the human. -->
- The agent may produce player-facing text, pixel-art sprites and audio, not only placeholders. The human still owns art direction and reviews every asset like any other change.
- No git remote: never push.
- Model sizing: on (Claude Code only). The `builder` subagent builds `S` items on Haiku.
