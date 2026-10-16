# Tasks

Milestones, the work queue and bugs: the only place work is tracked. Item format: `.godot-director/tasks.md`. Queue order is priority; reorder by moving items. Pruning moves done items to `TASKS-archive.md`.

**Next IDs:** T14 · B1

## Milestones
| Milestone | Status |
|---|---|
| Design: pitch, pillars and core loop decided | 🟨 in progress (Q3, Q5, Q6 open) |
| Foundation: project settings, first system with a test, check passing | 🟨 in progress (T1 done) |
| Core loop playable (grey-box) | ⬜ |
| Content & balance: no `## PLACEHOLDER` left (human) | ⬜ (0 placeholders) |
| Production art and audio replace placeholders (human) | ⬜ |

✅ done · 🟨 in progress · ⬜ not started

## Queue

### T1 · The check passes on a clean clone · done · S · agent
- Depends on: —
- Touches: project.godot, tools/check.cfg
- Done when: `bash tools/check.sh` exits 0 after deleting `.godot/` (check)
- GDD: —

### T2 · Create the folder layout · todo · S · agent
- Depends on: —
- Touches: scripts/autoload/.gitkeep (new), scripts/systems/.gitkeep (new), scripts/resources/.gitkeep (new), scripts/ui/.gitkeep (new), scenes/.gitkeep (new), data/.gitkeep (new), tests/.gitkeep (new)
- Done when: every folder in AGENTS.md › Layout exists in git (check) · the check still passes (check)
- GDD: —

### T7 · Research: what makes a good rage game · done · S · agent
- Depends on: —
- Touches: design/research/rage-games.md (new)
- Done when: a note compares Getting Over It, A Difficult Game About Climbing, Jump King, Pogostuck and QWOP on setbacks, control, fairness and comedy, and ends with 5–8 principles plus a proposal for Q1, Q2 and Q4 for the human to decide in a design session (check)
- GDD: Design Pillars

### T3 · RunState autoload: the current attempt · todo · M · agent
- Depends on: T2
- Touches: scripts/autoload/run_state.gd (new), project.godot (autoload)
- Done when: `reset()` restores the starting conditions: four guys, mildly tipsy, all aboard, zero progress, phase `launch` (test) · the check runs the autoload without errors (check)
- GDD: Core Loop › Starting conditions

### T4 · Paddling rule class: four charged strokes to thrust and turn, against the current · todo · M · agent
- Depends on: T2
- Touches: scripts/systems/paddling.gd (new), scripts/resources/boat_tuning.gd (new, +stroke_force_min, +stroke_force_max, +charge_time, +turn_torque, +current_speed), data/boat_tuning.tres (new), tests/test_paddling.gd (new)
- Done when: stroke power grows with hold time from stroke_force_min to stroke_force_max over charge_time (test) · equal strokes on both sides give forward thrust and no turn (test) · a stroke on one side turns the boat toward the other (test) · with no strokes the boat moves toward the shore at current_speed (test)
- GDD: Systems › Catamaran and paddling

### T5 · Drunkenness rule class: level, lag, misses and scrambled keys · todo · M · agent
- Depends on: T2
- Touches: scripts/systems/drunkenness.gd (new), scripts/resources/drink_tuning.gd (new, +drink_rate, +start_level, +beer_amount, +lag_curve, +miss_curve, +scramble_level), data/drink_tuning.tres (new), tests/test_drunkenness.gd (new)
- Done when: each guy's level rises by drink_rate per second from start_level, and by beer_amount per rescued beer (test) · stroke delay and miss chance rise with the level per lag_curve and miss_curve (test) · at scramble_level and above, the guy's key maps to another guy's seat, steady until his level drops below it (test)
- GDD: Systems › Drunkenness

### T6 · Grey-box lake: catamaran, four guys and the island, set as main scene · todo · L · agent
- Depends on: T3, T4
- Touches: scenes/lake.tscn (new), scenes/catamaran.tscn (new), scripts/catamaran.gd (new), scripts/ui/hud.gd (new), scenes/main.tscn (replaced), project.godot (main scene, input actions)
- Done when: the check loads the main scene without errors (check) · four keys, hold to charge and release to stroke, paddle the boat from the shore against the current to the island, and reaching it with all four aboard ends the attempt (play) · the HUD shows progress and each guy's drunkenness (play)
- GDD: Systems › Lake and island · Win and Loss

### T8 · Camera follows the boat with look-ahead · todo · S · agent
- Depends on: T6
- Touches: scenes/lake.tscn, scripts/lake_camera.gd (new), data/boat_tuning.tres (+camera_lead)
- Done when: the camera stays centred on the boat and leads toward its direction of travel by camera_lead (play)
- GDD: Presentation and Platforms

### T9 · Rescue: a beer overboard, a guy after it, three paddlers until he is picked up · todo · M · agent
- Depends on: T6, T5
- Touches: scripts/systems/rescue.gd (new), scripts/autoload/run_state.gd, scenes/catamaran.tscn, tests/test_rescue.gd (new)
- Done when: a beer overboard puts one guy in the water, and strokes from his seat do nothing until he is back (test) · the boat reaching the swimmer puts him aboard and raises his level by one beer (test) · the swimmer's position and a second beer overboard follow Q6, placeholders until it is answered (test) · the guy visibly jumps, swims and climbs back in (play)
- GDD: Systems › Setbacks

### T10 · Hazard framework with one placeholder hazard · todo · M · agent
- Depends on: T6, T9
- Touches: scripts/systems/hazards.gd (new), scripts/resources/hazard.gd (new, +spawn_rate), scenes/hazards/log.tscn (new), tests/test_hazards.gd (new)
- Done when: hazards spawn ahead of the boat from a seeded random so an attempt is reproducible (test) · a floating log is visible before it reaches the boat, and bumping it knocks a beer overboard and starts a Rescue (play) · the hazard set is a placeholder until Q3
- GDD: Systems › Hazards

### T13 · Antics: stand up, drop the paddle, nod off, each with a wind-up · todo · M · agent
- Depends on: T5, T6
- Touches: scripts/systems/antics.gd (new), scripts/resources/drink_tuning.gd (+antic_thresholds, +windup_time), scenes/catamaran.tscn, tests/test_antics.gd (new)
- Done when: crossing an antic threshold starts a wind-up of windup_time before the antic fires (test) · standing up rocks the boat, dropping the paddle disables that seat until it is fished out, nodding off makes the seat dead weight; each recovers on its own (test) · each antic reads at a glance on the guy (play)
- GDD: Systems › Drunkenness

### T12 · Placeholder main scene so the web export has something to ship · done · S · agent
- Depends on: —
- Touches: scenes/main.tscn (new), project.godot (main scene)
- Done when: `bash tools/ship.sh --export-only` writes build/web/index.html (check) · the check loads the scene (check)
- GDD: —
- Note: a flat-colour screen with a label; T6 replaces it with the grey-box lake.

### T11 · Ship to itch.io on demand (freakling.itch.io/pksei) · done · — · human
- Depends on: —
- Touches: export_presets.cfg, tools/ship.sh
- Done when: Godot 4.7.2 web export templates are installed (Editor › Manage Export Templates) and `bash tools/ship.sh --export-only` produces build/web/index.html (check) · butler is installed and `butler login` done, `bash tools/ship.sh` pushes the html5 channel and the game runs at the itch.io page, with "This file will be played in the browser" set on that upload (play)
- GDD: Presentation and Platforms

## Notes
- Q6 (rescue edge cases) gates only T9's edge cases; Q3 (hazard set) gates T10's content, not its framework.
- T3, T4 and T5 don't share files and can be built in any order after T2.
