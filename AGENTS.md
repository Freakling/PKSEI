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
| `scripts/` (root) | scene scripts: `catamaran.gd` (input, motion, telegraphs), `lake.gd` (island arrival, progress; lake values in `LakeTuning`, `scripts/resources/lake_tuning.gd`, `data/lake_tuning.tres`), `lake_camera.gd` (follow with look-ahead by `BoatTuning.camera_lead`) |
| `scripts/hazards/` | hazard scene scripts (one per hazard; rules in `scripts/systems/hazards.gd`) |
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
| `RunState` (autoload) | the current attempt: four `Guy`s (seat, drunkenness, stamina, aboard), progress 0..1 from shore to island, elapsed time, phase LAUNCH → CROSSING → WON; owns the `Paddling`, `Drunkenness` and `Stamina` instances and one RNG; `reset()`, `stroke(seat, hold_time)`, `step(delta) -> Motion`, `set_progress()`, `arrive()` | `scripts/autoload/run_state.gd` | the boat scene calls `stroke`/`step` and applies the `Motion`; the lake sets progress and calls `arrive`; screens read it; emits `run_reset` |
| `Paddling` (rule class) | stroke events (seat, hold time) and a timestep into thrust, signed turn (+ = right) and drift toward the shore; seats enum matching RunState; tuning in `BoatTuning` (`scripts/resources/boat_tuning.gd`, `data/boat_tuning.tres`) | `scripts/systems/paddling.gd` | pure: receives `BoatTuning`; `RunState` owns the instance; `catamaran.gd` applies its `Motion` with the boat feel values in `BoatTuning` (thrust_scale, turn_scale, damping) |
| `Drunkenness` (rule class) | one 0..1 level per seat; drink rate by state (break, water); stroke delay and miss chance per level (`Curve`s); seeded miss roll; scrambled-key mapping at `scramble_level` (fixed: same row, other hull); tuning in `DrinkTuning` (`scripts/resources/drink_tuning.gd`, `data/drink_tuning.tres`) | `scripts/systems/drunkenness.gd` | pure: receives `DrinkTuning` and an RNG; `RunState` owns the instance and steps it |
| `Stamina` (rule class) | one 0..1 level per seat; burn per stroke power, recovery; per-seat PADDLING → WARNING → BREAK machine (`can_stroke`, `time_left`, `call_break` for hazards); random breaks from the caller's RNG; tuning in `StaminaTuning` (`scripts/resources/stamina_tuning.gd`, `data/stamina_tuning.tres`) | `scripts/systems/stamina.gd` | pure: receives `StaminaTuning` and an RNG; `RunState` owns the instance and steps it; `catamaran.gd` reads its state for the telegraphs |

## Project rules
<!-- Only where this project differs from the Godot Director defaults, as agreed with the human. -->
- The agent may produce player-facing text, pixel-art sprites and audio, not only placeholders. The human still owns art direction and reviews every asset like any other change.
- No git remote: never push.
- Model sizing: on (Claude Code only). The `builder` subagent builds `S` items on Haiku.
