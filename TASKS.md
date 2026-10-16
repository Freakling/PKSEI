# Tasks

Milestones, the work queue and bugs: the only place work is tracked. Item format: `.godot-director/tasks.md`. Queue order is priority; reorder by moving items. Pruning moves done items to `TASKS-archive.md`.

**Next IDs:** T11 · B1

## Milestones
| Milestone | Status |
|---|---|
| Design: pitch, pillars and core loop decided | 🟨 in progress (Q1–Q5 open) |
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

### T7 · Research: what makes a good rage game · todo · S · agent
- Depends on: —
- Touches: design/research/rage-games.md (new)
- Done when: a note compares Getting Over It, A Difficult Game About Climbing, Jump King, Pogostuck and QWOP on setbacks, control, fairness and comedy, and ends with 5–8 principles plus a proposal for Q1, Q2 and Q4 for the human to decide in a design session (check)
- GDD: Design Pillars

### T3 · RunState autoload: the current attempt · todo · M · agent
- Depends on: T2
- Touches: scripts/autoload/run_state.gd (new), project.godot (autoload)
- Done when: `reset()` restores the starting conditions: four guys, mildly tipsy, zero progress, phase `launch` (test) · the check runs the autoload without errors (check)
- GDD: Core Loop › Starting conditions

### T4 · Paddling rule class: four inputs to thrust and turn · todo · M · agent
- Depends on: T2
- Touches: scripts/systems/paddling.gd (new), scripts/resources/boat_tuning.gd (new, +stroke_force, +turn_torque, +lean_tip), data/boat_tuning.tres (new), tests/test_paddling.gd (new)
- Done when: equal strokes on both sides give forward thrust and no turn (test) · a stroke on one side turns the boat toward the other (test) · leaning adds tip proportional to lean_tip (test)
- GDD: Systems › Catamaran and paddling

### T5 · Drunkenness rule class · todo · M · agent
- Depends on: T2
- Touches: scripts/systems/drunkenness.gd (new), scripts/resources/drink_tuning.gd (new, +drink_rate, +start_level), data/drink_tuning.tres (new), tests/test_drunkenness.gd (new)
- Done when: each guy's level rises by drink_rate per second from start_level (test) · a control-reliability factor falls as the level rises; the mapping is a placeholder until Q4 (test)
- GDD: Systems › Drunkenness

### T6 · Grey-box lake: catamaran, four guys and the island, set as main scene · todo · L · agent
- Depends on: T3, T4
- Touches: scenes/lake.tscn (new), scenes/catamaran.tscn (new), scripts/catamaran.gd (new), scripts/ui/hud.gd (new), project.godot (main scene, input actions)
- Done when: the check loads the main scene without errors (check) · a temporary keyboard mapping (placeholder until Q1) paddles the boat from the shore to the island and reaching it ends the attempt (play) · the HUD shows progress and each guy's drunkenness (play)
- GDD: Systems › Lake and island · Win and Loss

### T8 · Camera follows the boat with look-ahead · todo · S · agent
- Depends on: T6
- Touches: scenes/lake.tscn, scripts/lake_camera.gd (new), data/boat_tuning.tres (+camera_lead)
- Done when: the camera stays centred on the boat and leads toward its direction of travel by camera_lead (play)
- GDD: Presentation and Platforms

### T9 · Setbacks: drifting back into crossed water · todo · M · agent
- Depends on: T6, T5
- Touches: scripts/systems/setbacks.gd (new), scripts/autoload/run_state.gd, tests/test_setbacks.gd (new)
- Done when: a setback moves the boat's progress back by the rule in Q2, which is a placeholder until answered (test) · the guys are drunker after a setback than before it (test)
- GDD: Systems › Setbacks

### T10 · Hazard framework with one placeholder hazard · todo · M · agent
- Depends on: T6
- Touches: scripts/systems/hazards.gd (new), scripts/resources/hazard.gd (new, +spawn_rate), scenes/hazards/log.tscn (new), tests/test_hazards.gd (new)
- Done when: hazards spawn ahead of the boat from a seeded random so an attempt is reproducible (test) · a floating log pushes the boat on contact and is visible before it reaches the boat (play) · the hazard set is a placeholder until Q3
- GDD: Systems › Hazards

## Notes
- Q1 (control scheme) gates T6's input mapping; T7's research is meant to inform Q1, Q2 and Q4, so run T7 before the design session that answers them.
- T3, T4 and T5 don't share files and can be built in any order after T2.
