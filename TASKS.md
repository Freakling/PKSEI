# Tasks

Milestones, the work queue and bugs: the only place work is tracked. Item format: `.godot-director/tasks.md`. Queue order is priority; reorder by moving items. Pruning moves done items to `TASKS-archive.md`.

**Next IDs:** T44 · B4

## Milestones
| Milestone | Status |
|---|---|
| Design: pitch, pillars and core loop decided | ✅ done (Q5, co-op timing, still open) |
| Foundation: project settings, first system with a test, check passing | ✅ done |
| Core loop playable (grey-box): T6, T8, T9, T13, T28 | ⬜ |
| Hazards complete: T10, T15–T21 | ⬜ |
| Pixel art and animation, telegraphs first: T22–T24 | ⬜ |
| Audio, telegraphs first: T25–T26 | ⬜ |
| Content & balance: no `## PLACEHOLDER` left (human) | ⬜ (70 placeholders) |

✅ done · 🟨 in progress · ⬜ not started

## Queue

### T1 · The check passes on a clean clone · done · S · agent
- Depends on: —
- Touches: project.godot, tools/check.cfg
- Done when: `bash tools/check.sh` exits 0 after deleting `.godot/` (check)
- GDD: —

### T2 · Create the folder layout · done · S · agent
- Depends on: —
- Touches: scripts/autoload/.gitkeep (new), scripts/systems/.gitkeep (new), scripts/resources/.gitkeep (new), scripts/ui/.gitkeep (new), scenes/.gitkeep (new), data/.gitkeep (new), tests/.gitkeep (new)
- Done when: every folder in AGENTS.md › Layout exists in git (check) · the check still passes (check)
- GDD: —

### T7 · Research: what makes a good rage game · done · S · agent
- Depends on: —
- Touches: design/research/rage-games.md (new)
- Done when: a note compares Getting Over It, A Difficult Game About Climbing, Jump King, Pogostuck and QWOP on setbacks, control, fairness and comedy, and ends with 5–8 principles plus a proposal for Q1, Q2 and Q4 for the human to decide in a design session (check)
- GDD: Design Pillars

### T3 · RunState autoload: the current attempt · done · M · agent
- Depends on: T2
- Touches: scripts/autoload/run_state.gd (new), project.godot (autoload)
- Done when: `reset()` restores the starting conditions: four guys, mildly tipsy, all aboard, zero progress, phase `launch` (test) · the check runs the autoload without errors (check)
- GDD: Core Loop › Starting conditions

### T4 · Paddling rule class: four charged strokes to thrust and turn, against the current · done · M · agent
- Depends on: T2
- Touches: scripts/systems/paddling.gd (new), scripts/resources/boat_tuning.gd (new, +stroke_force_min, +stroke_force_max, +charge_time, +turn_torque, +steer_share_front, +steer_share_back, +current_speed), data/boat_tuning.tres (new), tests/test_paddling.gd (new)
- Done when: stroke power grows with hold time from stroke_force_min to stroke_force_max over charge_time (test) · equal strokes on both sides give forward thrust and no turn (test) · a left-side stroke turns the boat right and a right-side stroke left (test) · a back-seat stroke turns the boat by steer_share_back and a front-seat stroke by steer_share_front, with the same forward push (test) · with no strokes the boat moves toward the shore at current_speed (test)
- GDD: Systems › Catamaran and paddling

### T5 · Drunkenness rule class: level, lag, misses and scrambled keys · done · M · agent
- Depends on: T2
- Touches: scripts/systems/drunkenness.gd (new), scripts/resources/drink_tuning.gd (new, +drink_rate, +break_drink_multiplier, +water_drink_multiplier, +start_level, +lag_curve, +miss_curve, +scramble_level), data/drink_tuning.tres (new), tests/test_drunkenness.gd (new)
- Done when: each guy's level rises by drink_rate per second from start_level, times break_drink_multiplier while he is on a break, and times water_drink_multiplier while he floats in the water (test) · stroke delay and miss chance rise with the level per lag_curve and miss_curve (test) · at scramble_level and above, the guy's key maps to another guy's seat, steady until his level drops below it (test)
- GDD: Systems › Drunkenness

### T14 · Stamina rule class: strokes burn it, breaks recover it, telegraphed · done · M · agent
- Depends on: T2
- Touches: scripts/systems/stamina.gd (new), scripts/resources/stamina_tuning.gd (new, +burn_per_power, +recover_rate, +break_recover_rate, +break_duration, +break_warning, +random_break_curve), data/stamina_tuning.tres (new), tests/test_stamina.gd (new)
- Done when: a stroke burns stamina in proportion to its power, and stamina recovers at recover_rate between strokes (test) · a burnt-out guy gets a warning of break_warning, then a break of break_duration during which his seat gives no strokes and stamina recovers at break_recover_rate (test) · the chance of a random break per second rises with burnt stamina per random_break_curve, from a seeded random, and gets the same warning (test)
- GDD: Systems › Stamina

### T6 · Grey-box lake: catamaran, four guys and the island, set as main scene · done · L · agent
- Depends on: T3, T4, T14
- Touches: scenes/lake.tscn (new), scripts/lake.gd (new), scenes/catamaran.tscn (new), scripts/catamaran.gd (new), scripts/ui/hud.gd (new), scenes/main.tscn (replaced), project.godot (main scene, input actions), scripts/autoload/run_state.gd (reset() reads DrinkTuning.start_level and drops STARTING_DRUNKENNESS; wires Paddling, Drunkenness and Stamina), tests/test_run_state.gd, scripts/resources/boat_tuning.gd (+thrust_scale, +turn_scale, +linear_damping, +angular_damping), data/boat_tuning.tres, scripts/resources/lake_tuning.gd (new, +island_distance), data/lake_tuning.tres (new)
- Done when: the check loads the main scene without errors (check) · Q, A, I and K (left front, left back, right front, right back), hold to charge and release to stroke, paddle the boat from the shore against the current to the island, and reaching it with all four aboard ends the attempt (play) · a guy's break warning and break read at a glance on him (play) · the HUD shows progress and each guy's drunkenness and stamina (play)
- GDD: Systems › Lake and island · Win and Loss

### T31 · Timing-bar strokes at the top drunkenness tier replace the scrambled keys · done · M · agent
- Depends on: T6
- Touches: scripts/systems/drunkenness.gd (replace scrambled/key_target/scramble_target with the timing bar), scripts/resources/drink_tuning.gd (+bar_period, +green_width; scramble_level renamed bar_level), data/drink_tuning.tres, scripts/autoload/run_state.gd (stroke: outside the green zone the stroke is backwards), scripts/catamaran.gd (the bar next to the guy while his key is held), scripts/systems/paddling.gd (Stroke.backwards), tests/test_drunkenness.gd, tests/test_run_state.gd
- Done when: at bar_level and above, the bar position for a hold time sweeps back and forth with bar_period, and a release inside green_width of the centre counts as a hit (test) · a hit gives the normal stroke, a miss a backwards stroke of the same power, and both burn stamina (test) · the bar is visible next to the guy while his key is held, and the tier is announced with a wind-up (play) · nothing references the old scrambled-key mapping (check)
- GDD: Systems › Drunkenness

### T8 · Camera follows the boat with look-ahead · done · S · agent
- Depends on: T6
- Touches: scenes/lake.tscn, scenes/catamaran.tscn (camera moved out), scripts/lake_camera.gd (new), scripts/resources/boat_tuning.gd (+camera_lead), data/boat_tuning.tres
- Done when: the camera stays centred on the boat and leads toward its direction of travel by camera_lead (play)
- GDD: Presentation and Platforms

### T9 · Rescue: beers overboard, guys after them, fewer paddlers until each is picked up, shore reset · done · L · agent
- Depends on: T6, T5
- Touches: scripts/systems/rescue.gd (new), scripts/resources/boat_tuning.gd (+swim_speed, +beer_toss, +pickup_radius), data/boat_tuning.tres, scripts/autoload/run_state.gd, scripts/catamaran.gd, scripts/lake.gd, scenes/lake.tscn, project.godot (debug_beer_left F5, debug_beer_right F6, debug builds only), scripts/systems/drunkenness.gd (drinking flag), tests/test_rescue.gd (new), tests/test_run_state.gd
- Done when: each beer overboard puts one more guy in the water (the one on the side the hazard hit), with no limit, and strokes from his seat do nothing until he is back (test) · the beer drifts at current_speed, the swimmer swims to it at swim_speed, then drifts with it (test) · the boat reaching a swimmer puts him aboard (test) · with nobody aboard the boat drifts at current_speed, and reaching the shore resets the attempt to the starting conditions (test) · the guy visibly jumps, swims, floats drinking, and climbs back in (play)
- GDD: Systems › Setbacks

### T32 · Stamina pauses for a guy in the water · done · S · agent
- Depends on: T9
- Touches: scripts/autoload/run_state.gd, tests/test_run_state.gd
- Done when: a guy in the water neither recovers stamina nor rolls random breaks, and comes back in the state he left (test)
- GDD: Systems › Stamina

### B1 · A stroke released just before the guy jumps still lands · done · S · agent · low
- Depends on: T9
- Touches: scripts/autoload/run_state.gd, tests/test_run_state.gd
- Repro: release a key, then knock that guy's beer over (F5/F6 in a debug build) before the pending stroke lands (same physics frame, or within a drunk guy's lag) → expected: no stroke / actual: the stroke lands from the water
- Found in: T9
- GDD: Systems › Setbacks

### T10 · Hazard framework: seeded bands, effects palette, and the floating log · done · M · agent
- Depends on: T6, T9
- Touches: scripts/systems/hazards.gd (new), scripts/resources/hazard.gd (new, +weight, +first_band, +shove_strength, +hit_cooldown), data/hazards/log.tres (new), scripts/resources/lake_tuning.gd (+lake_width, +band_length, +density_curve, +hazards, +launch_margin, +island_radius), data/lake_tuning.tres, scripts/resources/boat_tuning.gd (+bail_rate), data/boat_tuning.tres, scripts/autoload/run_state.gd (effects palette, lake_seed), scripts/lake.gd, scenes/lake.tscn, scripts/catamaran.gd, scripts/hazards/log.gd (new), scenes/hazards/log.tscn (new), tests/test_hazards.gd (new)
- Done when: each band draws hazards from the weighted list with density per density_curve, from one seed, so the same seed gives the same lake (test) · the effects beer overboard, shove, snag, stop, forced break and water aboard exist as calls on the boat and the guys (test) · a floating log drifts at current_speed, is visible before it reaches the boat, and a bump knocks a beer overboard on the side hit and shoves the boat (play)
- GDD: Systems › Hazards

### T33 · Hazards respawn: a lake that has drifted its hazards past the shore refills ahead of the boat · done · M · agent
- Depends on: T10
- Touches: scripts/systems/hazards.gd, scripts/lake.gd, tests/test_hazards.gd
- Done when: a band whose hazards have all drifted past the shore is re-planned from the attempt's seed and a band counter, so a long crossing never meets an empty lake (test) · respawned hazards appear outside the camera's look-ahead (play)
- GDD: Systems › Hazards

### B2 · A swimmer who drifts past the shoreline can't be picked up · done · M · agent · med
- Depends on: T10
- Touches: scripts/systems/rescue.gd, scripts/autoload/run_state.gd, scripts/resources/boat_tuning.gd (+shore_margin), data/boat_tuning.tres, tests/test_rescue.gd, tests/test_run_state.gd
- Repro: knock a beer over while the boat rests at the launch shore (a band-1 log drifting into it, or F5) → the swimmer drifts down through the shoreline where the boat can't reach him; shore_touched() does nothing in LAUNCH → expected: he washes up and climbs back aboard, or the shore stops him within reach / actual: stuck until the player paddles off and comes back for a shore reset
- Found in: T10 review
- GDD: Systems › Setbacks

### B3 · The camera never followed the boat · done · S · agent · high
- Depends on: T8
- Touches: scenes/lake.tscn
- Repro: paddle away from the shore → expected: the view follows the boat / actual: the view stays on the launch shore. The camera's exported `boat` node was null because the hand-written scene lacked the `node_paths` marker Godot needs to resolve an exported node.
- Found in: ad hoc (the human's first play)
- GDD: Presentation and Platforms

### T34 · A beer bobs away for a moment before a guy winds up and jumps · done · M · agent
- Depends on: T9
- Touches: scripts/systems/rescue.gd, scripts/resources/boat_tuning.gd (+jump_delay), data/boat_tuning.tres, scripts/autoload/run_state.gd, scripts/lake.gd, scripts/catamaran.gd, tests/test_rescue.gd, tests/test_run_state.gd, tests/test_hazards.gd
- Done when: a beer overboard floats loose for jump_delay seconds before the chosen guy leaves the boat; his seat still paddles until he jumps (test) · the wind-up reads on the guy and the beer is visible drifting during the delay (play)
- GDD: Systems › Setbacks

### T35 · Loose things drift faster than the boat · done · S · agent
- Depends on: T9
- Touches: scripts/resources/boat_tuning.gd (+loose_drift_speed), data/boat_tuning.tres, scripts/autoload/run_state.gd, tests/test_run_state.gd
- Done when: beers and swimmers drift at loose_drift_speed while the boat drifts at current_speed, with loose_drift_speed the larger placeholder (test)
- GDD: Systems › Catamaran and paddling · Systems › Setbacks

### T36 · Objects are fixed: the log stops drifting, the band refill goes · done · S · agent
- Depends on: T33
- Touches: scripts/hazards/log.gd, scripts/lake.gd, scripts/systems/hazards.gd, tests/test_hazards.gd
- Done when: a log stays where it was planned (test) · no band refill code remains; plan_band stays for the path and future events (check) · the check passes (check)
- GDD: Systems › Hazards

### T37 · A guaranteed path winds through every band · done · M · agent
- Depends on: T36
- Touches: scripts/systems/hazards.gd, scripts/resources/lake_tuning.gd (+path_width, +path_wander), data/lake_tuning.tres, tests/test_hazards.gd
- Done when: no object is placed inside the corridor, whose centre moves by at most path_wander between neighbouring bands and stays inside the lake (test) · the corridor is continuous from the launch to the island (test)
- GDD: Systems › Hazards

### T38 · Size the lake for a five-minute clean crossing · done · S · agent
- Depends on: T37
- Touches: data/lake_tuning.tres, scripts/lake.gd, scripts/resources/lake_tuning.gd
- Done when: island_distance, lake_width and band_length are set so a steady full-power crossing with no incidents takes about five minutes at the current boat speed, and the water polygon covers the whole lake (check: the arithmetic quoted) · the crossing feels huge (play)
- GDD: Core Loop › Session

### T39 · Debug overlay draws the guaranteed path · done · S · agent
- Depends on: T37
- Touches: scripts/lake.gd, scenes/lake.tscn, project.godot (debug_toggle_path F7)
- Done when: in debug builds (`OS.is_debug_build() or OS.has_feature("dev_tools")`) a translucent strip shows the corridor from `Hazards.corridor_x` so path_width and path_wander can be tuned by eye, toggled with a debug key (check: the gate is quoted) · the strip follows the planned path (play)
- GDD: —

### T15 · Angry geese guarding goslings · done · M · agent
- Depends on: T10
- Touches: scripts/systems/geese.gd (new), scripts/hazards/geese.gd (new), scenes/hazards/geese.tscn (new), data/hazards/geese.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+geese_radius, +geese_warning, +geese_attack_time, +geese_speed, +geese_peck_interval, +geese_peck_range, +geese_cooldown), tests/test_geese.gd (new)
- Done when: a flock hisses when the boat enters geese_radius, charges and pecks for geese_attack_time, each peck a beer overboard, then returns (test) · the warning and the attack read at a glance (play)
- GDD: Systems › Hazards

### T40 · The lake hands each hazard its tuning, so hazard scripts don't load lake_tuning.tres · todo · S · agent
- Depends on: T15
- Touches: scripts/lake.gd, scripts/hazards/geese.gd, scripts/hazards/log.gd
- Done when: lake.gd sets `tuning` (and `spec`) on each spawned hazard that declares it, and no hazard script loads data/lake_tuning.tres itself (check)
- GDD: —

### T16 · Motorboat wake · done · M · agent
- Depends on: T10
- Touches: scripts/systems/wake.gd (new), scripts/hazards/wake.gd (new), scenes/hazards/wake.tscn (new), data/hazards/wake.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+wake_trigger_radius, +wake_boat_speed, +wake_lead, +wake_speed, +wake_head_on_angle, +wake_shove, +wake_water), tests/test_wake.gd (new)
- Done when: a motorboat crosses ahead, then a wave front follows it; a head-on crossing does nothing, a broadside one knocks a beer overboard on the high side, shoves the boat sideways by wake_shove and puts wake_water aboard, which the guy on that side bails at bail_rate while his seat gives no strokes (test) · the boat is seen before the wave (play)
- GDD: Systems › Hazards

### T41 · Event triggers are placed on the path, objects beside it · todo · M · agent
- Depends on: T16
- Touches: scripts/resources/hazard.gd (+is_event), scripts/systems/hazards.gd, data/hazards/wake.tres, data/hazards/geese.tres, tests/test_hazards.gd, scripts/lake.gd (debug marker for triggers)
- Done when: a HazardSpec marked `is_event` is placed inside the corridor (on the path the boat must take) and objects outside it, so every event can fire (test) · in debug builds a small marker shows each trigger point with the F7 overlay (play)
- GDD: Systems › Hazards

### T17 · Wind: gusts and harsh-wind stretches · done · M · agent
- Depends on: T10, T14
- Touches: scripts/systems/gust.gd (new), scripts/systems/headwind.gd (new), scripts/hazards/gust.gd (new), scripts/hazards/headwind.gd (new), scenes/hazards/gust.tscn (new), scenes/hazards/headwind.tscn (new), data/hazards/gust.tres (new), data/hazards/headwind.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+gust_trigger_radius, +gust_warning, +gust_shove, +gust_time, +headwind_force, +headwind_length), scripts/autoload/run_state.gd (push/take_push, set_extra_drift), scripts/catamaran.gd, tests/test_gust.gd (new), tests/test_headwind.gd (new)
- Done when: ripples precede a gust by about a second, then the boat is shoved sideways by gust_shove for gust_time (test) · inside a headwind stretch the current is stronger by headwind_force, so only strong strokes gain water (test) · whitecaps mark the stretch before the boat reaches it (play)
- GDD: Systems › Hazards

### T42 · Shared base for hazard scene scripts (find the boat, the rect, the tuning) · todo · S · agent
- Depends on: T17, T40
- Touches: scripts/hazards/hazard_base.gd (new), scripts/hazards/wake.gd, scripts/hazards/gust.gd, scripts/hazards/headwind.gd, scripts/hazards/geese.gd, scripts/hazards/log.gd
- Done when: one base script holds `_find_boat()`, `_rect()` and the tuning/spec fields, and every hazard scene script extends it with no duplicate helper left (check)
- GDD: —

### T18 · Cross-current stripe · done · S · agent
- Depends on: T10
- Touches: scripts/systems/cross_current.gd (new), scripts/hazards/cross_current.gd (new), scenes/hazards/cross_current.tscn (new), data/hazards/cross_current.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+stripe_force, +stripe_length), tests/test_cross_current.gd (new)
- Done when: while the boat is inside the stripe it is pushed by stripe_force in the stripe's direction (test) · the stripe is visible as a band of faster water (play)
- GDD: Systems › Hazards

### T19 · Rock or buoy · done · S · agent
- Depends on: T10
- Touches: scripts/hazards/rock.gd (new), scenes/hazards/rock.tscn (new), data/hazards/rock.tres (new), data/lake_tuning.tres, tests/test_rock.gd (new)
- Done when: hitting it stops the boat and knocks a beer overboard on the side hit (test)
- GDD: Systems › Hazards

### T20 · Fishing line · done · S · agent
- Depends on: T10
- Touches: scripts/hazards/fishing_line.gd (new), scenes/hazards/fishing_line.tscn (new), data/hazards/fishing_line.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+snag_time, +line_length), tests/test_fishing_line.gd (new)
- Done when: crossing the line snags the paddle on the side that crossed it for snag_time (test) · the dinghy and the line are visible before the boat reaches them (play)
- GDD: Systems › Hazards

### T43 · Objects with an extent keep their whole footprint out of the corridor · todo · S · agent
- Depends on: T37, T20
- Touches: scripts/resources/hazard.gd (+half_width), scripts/systems/hazards.gd, data/hazards/fishing_line.tres, data/hazards/log.tres, data/hazards/rock.tres, data/hazards/geese.tres, tests/test_hazards.gd
- Done when: placement keeps a spec's half_width clear of the corridor on both sides, so a fishing line's full length never crosses the path (test)
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

### T23 · Guy animations: stroke, fumble, break warning, antic wind-ups, timing-bar tell · todo · M · agent
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

### T29 · Shared curve helper replaces the duplicate ramp() in DrinkTuning and StaminaTuning · todo · S · agent
- Depends on: T14
- Touches: scripts/resources/curves.gd (new), scripts/resources/drink_tuning.gd, scripts/resources/stamina_tuning.gd, tests/test_drunkenness.gd, tests/test_stamina.gd
- Done when: one `ramp()` helper exists and both tunings use it, with the existing tests still passing (check)
- GDD: —

### T30 · BoatTuning.current_speed doc says progress units; the boat applies pixels · done · S · agent
- Depends on: T6
- Touches: scripts/resources/boat_tuning.gd
- Done when: the field's doc comment says pixels per second, matching how catamaran.gd applies drift (check)
- GDD: —

### T28 · Win cutscene: the boys land, make camp and drink · todo · M · agent
- Depends on: T6
- Touches: scenes/win.tscn (new), scripts/win_cutscene.gd (new), scenes/lake.tscn (hand-off on `WON`)
- Done when: when RunState's phase becomes `WON` (already set by `arrive()`, T6) the cutscene plays: the boys step onto the island, set up camp and drink, then the crossing ends (play) · the check loads the scene (check)
- GDD: Win and Loss

### T13 · Antics: stand up, drop the paddle, nod off, pee, each with a wind-up · todo · M · agent
- Depends on: T5, T6, T9
- Touches: scripts/systems/antics.gd (new), scripts/resources/drink_tuning.gd (+antic_thresholds, +windup_time, +pee_time, +pee_fall_shove), scenes/catamaran.tscn, tests/test_antics.gd (new)
- Done when: crossing an antic threshold starts a wind-up of windup_time before the antic fires (test) · standing up rocks the boat, dropping the paddle disables that seat until it is fished out, nodding off makes the seat dead weight, peeing disables the seat for pee_time; each recovers on its own (test) · a shove of pee_fall_shove or more during a pee puts that guy in the water without a beer, handled by Rescue (test) · each antic reads at a glance on the guy (play)
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
- T34–T38 come from the human's first play (2026-10-17) and go before the hazard set: static objects, slow boat drift, the guaranteed path, a huge lake.
- T15–T21 are independent of each other once T10 is done; T17 also needs T14 (stamina). Objects (T15 flock, T18 stripe, T19 rock, T20 line) are fixed; events (T15 charge, T16, T17, T21) happen as the boat passes.
- Stages, as the human wants them: functionality (through T21), then pixel art and animation with telegraphs first (T22–T24), then audio with telegraphs first (T25–T26).
- Player settings have no item yet; the human will decide what they should do later.
- T3, T4, T5 and T14 don't share files and can be built in any order after T2.
