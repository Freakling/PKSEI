# Tasks

Milestones, the work queue and bugs: the only place work is tracked. Item format: `.godot-director/tasks.md`. Queue order is priority; reorder by moving items. Pruning moves done items to `TASKS-archive.md`.

**Next IDs:** T29 · B1

## Milestones
| Milestone | Status |
|---|---|
| Design: pitch, pillars and core loop decided | ✅ done (Q5, co-op timing, still open) |
| Foundation: project settings, first system with a test, check passing | 🟨 in progress (T1 done) |
| Core loop playable (grey-box): T6, T8, T9, T13, T28 | ⬜ |
| Hazards complete: T10, T15–T21 | ⬜ |
| Pixel art and animation, telegraphs first: T22–T24 | ⬜ |
| Audio, telegraphs first: T25–T26 | ⬜ |
| Content & balance: no `## PLACEHOLDER` left (human) | ⬜ (0 placeholders) |

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
- Touches: scripts/systems/paddling.gd (new), scripts/resources/boat_tuning.gd (new, +stroke_force_min, +stroke_force_max, +charge_time, +turn_torque, +steer_share_front, +steer_share_back, +current_speed), data/boat_tuning.tres (new), tests/test_paddling.gd (new)
- Done when: stroke power grows with hold time from stroke_force_min to stroke_force_max over charge_time (test) · equal strokes on both sides give forward thrust and no turn (test) · a left-side stroke turns the boat right and a right-side stroke left (test) · a back-seat stroke turns the boat by steer_share_back and a front-seat stroke by steer_share_front, with the same forward push (test) · with no strokes the boat moves toward the shore at current_speed (test)
- GDD: Systems › Catamaran and paddling

### T5 · Drunkenness rule class: level, lag, misses and scrambled keys · todo · M · agent
- Depends on: T2
- Touches: scripts/systems/drunkenness.gd (new), scripts/resources/drink_tuning.gd (new, +drink_rate, +break_drink_multiplier, +water_drink_multiplier, +start_level, +lag_curve, +miss_curve, +scramble_level), data/drink_tuning.tres (new), tests/test_drunkenness.gd (new)
- Done when: each guy's level rises by drink_rate per second from start_level, times break_drink_multiplier while he is on a break, and times water_drink_multiplier while he floats in the water (test) · stroke delay and miss chance rise with the level per lag_curve and miss_curve (test) · at scramble_level and above, the guy's key maps to another guy's seat, steady until his level drops below it (test)
- GDD: Systems › Drunkenness

### T14 · Stamina rule class: strokes burn it, breaks recover it, telegraphed · todo · M · agent
- Depends on: T2
- Touches: scripts/systems/stamina.gd (new), scripts/resources/stamina_tuning.gd (new, +burn_per_power, +recover_rate, +break_recover_rate, +break_duration, +break_warning, +random_break_curve), data/stamina_tuning.tres (new), tests/test_stamina.gd (new)
- Done when: a stroke burns stamina in proportion to its power, and stamina recovers at recover_rate between strokes (test) · a burnt-out guy gets a warning of break_warning, then a break of break_duration during which his seat gives no strokes and stamina recovers at break_recover_rate (test) · the chance of a random break per second rises with burnt stamina per random_break_curve, from a seeded random, and gets the same warning (test)
- GDD: Systems › Stamina

### T6 · Grey-box lake: catamaran, four guys and the island, set as main scene · todo · L · agent
- Depends on: T3, T4, T14
- Touches: scenes/lake.tscn (new), scenes/catamaran.tscn (new), scripts/catamaran.gd (new), scripts/ui/hud.gd (new), scenes/main.tscn (replaced), project.godot (main scene, input actions)
- Done when: the check loads the main scene without errors (check) · Q, A, I and K (left front, left back, right front, right back), hold to charge and release to stroke, paddle the boat from the shore against the current to the island, and reaching it with all four aboard ends the attempt (play) · a guy's break warning and break read at a glance on him (play) · the HUD shows progress and each guy's drunkenness and stamina (play)
- GDD: Systems › Lake and island · Win and Loss

### T8 · Camera follows the boat with look-ahead · todo · S · agent
- Depends on: T6
- Touches: scenes/lake.tscn, scripts/lake_camera.gd (new), data/boat_tuning.tres (+camera_lead)
- Done when: the camera stays centred on the boat and leads toward its direction of travel by camera_lead (play)
- GDD: Presentation and Platforms

### T9 · Rescue: beers overboard, guys after them, fewer paddlers until each is picked up, shore reset · todo · L · agent
- Depends on: T6, T5
- Touches: scripts/systems/rescue.gd (new), scripts/resources/boat_tuning.gd (+swim_speed), scripts/autoload/run_state.gd, scenes/catamaran.tscn, scenes/lake.tscn, tests/test_rescue.gd (new)
- Done when: each beer overboard puts one more guy in the water (the one on the side the hazard hit), with no limit, and strokes from his seat do nothing until he is back (test) · the beer drifts at current_speed, the swimmer swims to it at swim_speed, then drifts with it (test) · the boat reaching a swimmer puts him aboard (test) · with nobody aboard the boat drifts at current_speed, and reaching the shore resets the attempt to the starting conditions (test) · the guy visibly jumps, swims, floats drinking, and climbs back in (play)
- GDD: Systems › Setbacks

### T10 · Hazard framework: seeded bands, effects palette, and the floating log · todo · M · agent
- Depends on: T6, T9
- Touches: scripts/systems/hazards.gd (new), scripts/resources/hazard.gd (new, +weight, +first_band), scripts/resources/lake_tuning.gd (new, +band_length, +density_curve), data/lake_tuning.tres (new), scripts/hazards/log.gd (new), scenes/hazards/log.tscn (new), tests/test_hazards.gd (new)
- Done when: each band draws hazards from the weighted list with density per density_curve, from one seed, so the same seed gives the same lake (test) · the effects beer overboard, shove, snag, stop, forced break and water aboard exist as calls on the boat and the guys (test) · a floating log drifts at current_speed, is visible before it reaches the boat, and a bump knocks a beer overboard on the side hit and shoves the boat (play)
- GDD: Systems › Hazards

### T15 · Angry geese guarding goslings · todo · M · agent
- Depends on: T10
- Touches: scripts/hazards/geese.gd (new), scenes/hazards/geese.tscn (new), data/lake_tuning.tres (+geese_radius, +geese_attack_time)
- Done when: a flock hisses when the boat enters geese_radius, charges and pecks for geese_attack_time, each peck a beer overboard, then returns (test) · the warning and the attack read at a glance (play)
- GDD: Systems › Hazards

### T16 · Motorboat wake · todo · M · agent
- Depends on: T10
- Touches: scripts/hazards/wake.gd (new), scenes/hazards/wake.tscn (new), data/lake_tuning.tres (+wake_speed, +wake_shove, +wake_water), data/boat_tuning.tres (+bail_rate)
- Done when: a motorboat crosses ahead, then a wave front follows it; a head-on crossing does nothing, a broadside one knocks a beer overboard on the high side, shoves the boat sideways by wake_shove and puts wake_water aboard, which the guy on that side bails at bail_rate while his seat gives no strokes (test) · the boat is seen before the wave (play)
- GDD: Systems › Hazards

### T17 · Wind: gusts and harsh-wind stretches · todo · M · agent
- Depends on: T10, T14
- Touches: scripts/hazards/gust.gd (new), scripts/hazards/headwind.gd (new), scenes/hazards/gust.tscn (new), scenes/hazards/headwind.tscn (new), data/lake_tuning.tres (+gust_shove, +gust_time, +headwind_force)
- Done when: ripples precede a gust by about a second, then the boat is shoved sideways by gust_shove for gust_time (test) · inside a headwind stretch the current is stronger by headwind_force, so only strong strokes gain water (test) · whitecaps mark the stretch before the boat reaches it (play)
- GDD: Systems › Hazards

### T18 · Cross-current stripe · todo · S · agent
- Depends on: T10
- Touches: scripts/hazards/cross_current.gd (new), scenes/hazards/cross_current.tscn (new), data/lake_tuning.tres (+stripe_force)
- Done when: while the boat is inside the stripe it is pushed by stripe_force in the stripe's direction (test) · the stripe is visible as a band of faster water (play)
- GDD: Systems › Hazards

### T19 · Rock or buoy · todo · S · agent
- Depends on: T10
- Touches: scripts/hazards/rock.gd (new), scenes/hazards/rock.tscn (new)
- Done when: hitting it stops the boat and knocks a beer overboard on the side hit (test)
- GDD: Systems › Hazards

### T20 · Fishing line · todo · S · agent
- Depends on: T10
- Touches: scripts/hazards/fishing_line.gd (new), scenes/hazards/fishing_line.tscn (new), data/lake_tuning.tres (+snag_time)
- Done when: crossing the line snags the paddle on the side that crossed it for snag_time (test) · the dinghy and the line are visible before the boat reaches them (play)
- GDD: Systems › Hazards

### T21 · Jet-ski idiot · todo · M · agent
- Depends on: T10
- Touches: scripts/hazards/jetski.gd (new), scenes/hazards/jetski.tscn (new), data/lake_tuning.tres (+jetski_speed, +jetski_warning, +jetski_shove)
- Done when: a warning of jetski_warning sounds from offscreen, then the jet-ski crosses on a straight line at jetski_speed; a hit shoves the boat hard and knocks a beer overboard (test) · the warning is loud enough to react to (play)
- GDD: Systems › Hazards

### T22 · Pixel art pass 1: catamaran, four guys, water, shore and island · todo · M · agent
- Depends on: T6
- Touches: assets/sprites/ (new), scenes/catamaran.tscn, scenes/lake.tscn
- Done when: the `Visual` nodes show sprites drawn for the 640×360 canvas, nearest-filtered, in place of the primitives (play) · the human signs off the look (play)
- GDD: Presentation and Platforms

### T23 · Guy animations: stroke, fumble, break warning, antic wind-ups, scrambled-key tell · todo · M · agent
- Depends on: T22, T13, T14
- Touches: assets/sprites/guys/ (new), scenes/catamaran.tscn, scripts/catamaran.gd
- Done when: every telegraph in GDD › Drunkenness and GDD › Stamina has its own animation that starts at the warning and ends at the effect (play) · a late or missed stroke is visible as a fumble (play)
- GDD: Systems › Drunkenness · Systems › Stamina

### T24 · Hazard telegraph animations · todo · M · agent
- Depends on: T22, T15, T16, T17, T18, T19, T20, T21
- Touches: assets/sprites/hazards/ (new), scenes/hazards/*.tscn
- Done when: each telegraph in the GDD › Hazards table is an animation that plays before the effect (play)
- GDD: Systems › Hazards

### T25 · Audio framework: buses, stroke, splash and guy noises · todo · M · agent
- Depends on: T6
- Touches: assets/audio/ (new), scripts/autoload/audio.gd (new), project.godot (autoload, audio buses)
- Done when: the check runs the autoload without errors (check) · strokes, splashes, jumps and pick-ups have sounds, and the master volume follows the player setting (play)
- GDD: Presentation and Platforms

### T26 · Audio telegraphs: engine before the wake, jet-ski offscreen, geese hiss, wind rising · todo · M · agent
- Depends on: T25, T15, T16, T17, T21
- Touches: assets/audio/hazards/ (new), scenes/hazards/wake.tscn, scenes/hazards/jetski.tscn, scenes/hazards/geese.tscn, scenes/hazards/gust.tscn, scenes/hazards/headwind.tscn
- Done when: each audio telegraph in GDD › Presentation and Platforms › Audio sounds before its hazard is visible, or at its wind-up (play)
- GDD: Systems › Hazards

### T28 · Win cutscene: the boys land, make camp and drink · todo · M · agent
- Depends on: T6
- Touches: scenes/win.tscn (new), scripts/win_cutscene.gd (new), scripts/autoload/run_state.gd (phase `won`)
- Done when: reaching the island with all four aboard sets the phase to `won` (test) · the cutscene plays: the boys step onto the island, set up camp and drink, then the crossing ends (play) · the check loads the scene (check)
- GDD: Win and Loss

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
- T15–T21 are independent of each other once T10 is done; T17 also needs T14 (stamina).
- Stages, as the human wants them: functionality (through T21), then pixel art and animation with telegraphs first (T22–T24), then audio with telegraphs first (T25–T26).
- Player settings have no item yet; the human will decide what they should do later.
- T3, T4, T5 and T14 don't share files and can be built in any order after T2.
